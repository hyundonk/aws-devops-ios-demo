
resource "aws_ec2_host" "test" {
  instance_type     = "mac1.metal"
  availability_zone = "ap-northeast-2a"
  host_recovery     = "off"
  auto_placement    = "off"

  tags = {
    Name = "mac1-demo-host"
  }
}

# aws ec2 describe-images --owners self amazon --output table
data "aws_ami" "macos_monterey" {
  most_recent = true
  owners  = ["amazon"]

filter {
    name   = "name"
    values = ["amzn-ec2-macos-12.6.3*"]
  }

  filter {
        name   = "virtualization-type"
        values = ["hvm"]
  }
}

resource "aws_security_group" "private" {
  lifecycle {
    ignore_changes = [
      #ingress,
    ]
  }

  name = "security-group-private"
  vpc_id = aws_vpc.demo.id

  ingress {
    description = "allow from bastion"
    security_groups = [aws_security_group.bastion.id]
    from_port = 22
    to_port = 22
    protocol = "tcp"
  }

  ingress {
    description = "allow ssh from self"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    self = true
  }


  ingress {
    description = "allow remote desktop from bastion"
    security_groups = [aws_security_group.bastion.id]
    from_port = 5900
    to_port = 5900
    protocol = "tcp"
  }

  ingress {
    description = "allow jenkins web/api"
    security_groups = [aws_security_group.bastion.id]
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
  }

  egress {
    description = "allow ssh from self"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    self = true
  }


  egress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]

    from_port = 80
    to_port   = 80
    protocol  = "TCP"
  }

  egress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]

    from_port = 443
    to_port   = 443
    protocol  = "TCP"
  }

  tags = {
    Name = "demo securty group for private subnet"
  }
}

resource "aws_iam_policy" "devicefarm" {
  name        = "DemoDeviceFarmPolicy"
  description = "GameLift Full Access"

  policy = jsonencode(
{
    "Version": "2012-10-17",
    "Statement": [
        {   // Caution. for demo simplicity, this allows every device farm projects which should be avoided for production.
            "Effect": "Allow",
            "Action": [
              "devicefarm:CreateUpload",
              "devicefarm:ScheduleRun",
            ],
            "Resource": "*"
        }
    ]
}
)
}

resource "aws_iam_policy" "secretmanager" {
  name        = "DemoSecretManagerReadPolicy"
  description = "GameLift Full Access"

  policy = jsonencode(
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
              "secretsmanager:GetResourcePolicy",
              "secretsmanager:GetSecretValue",
              "secretsmanager:DescribeSecret",
              "secretsmanager:ListSecretVersionIds"
            ],
            "Resource": "*"
        },
        {   // Caution. for demo simplicity, this allows every secretmanager resources which should be avoided for production.
            "Effect": "Allow",
            "Action": "secretsmanager:ListSecrets",
            "Resource": "*"
        }
    ]
}
)
}

resource "aws_iam_role" "jenkinsagent" {
  name = "DemoJenkinsAgentRole"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "ec2.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF
  managed_policy_arns = [
    aws_iam_policy.secretmanager.arn,
    "arn:aws:iam::aws:policy/AWSDeviceFarmFullAccess" # aws_iam_policy.devicefarm.arn,
  ]
}

resource "aws_iam_instance_profile" "demo" {
  name = "demo-profile-jenkinsagent"
  role = aws_iam_role.jenkinsagent.name
}

resource "aws_instance" "mac1" {
  lifecycle {
    ignore_changes = [
      ami,
      security_groups,
    ]
  }

  ami           = data.aws_ami.macos_monterey.id
  instance_type = "mac1.metal"
  key_name      = var.key_name

  iam_instance_profile = aws_iam_instance_profile.demo.name

  security_groups = [aws_security_group.private.id]

  subnet_id     = aws_subnet.private.0.id

  host_id = aws_ec2_host.test.id

  tags = {
    Name = "mac1 instance for jenkins agent"
  }
}

resource "aws_instance" "jenkins" {
  lifecycle {
    ignore_changes = [
      security_groups,
    ]
  }
  ami           = data.aws_ami.amazon-linux-2.id
  instance_type = "t2.micro"
  key_name      = var.key_name
  
  iam_instance_profile = aws_iam_instance_profile.demo.name
  
  security_groups = [aws_security_group.private.id]

  subnet_id     = aws_subnet.private.0.id
  tags = {
    Name = "jenkins linux instance"
  }
}

resource "aws_instance" "bastion" {
  lifecycle {
    ignore_changes = [
      ami,
      security_groups,
    ]
  }

  ami           = data.aws_ami.amazon-linux-2.id # "ami-0624dfd6daa8d36c8"
  instance_type = "t2.micro"
  key_name      = var.key_name
  security_groups = [aws_security_group.bastion.id]

  subnet_id     = aws_subnet.public.0.id
  tags = {
    Name = "bastion for ios app pipeline demo"
  }
}

resource "aws_eip" "bastion" {
  vpc = true
  instance                  = aws_instance.bastion.id
}

output "bastion_ip" {
  value = aws_eip.bastion.public_ip
}

