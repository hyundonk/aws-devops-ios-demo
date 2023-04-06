resource "aws_vpc" "demo" {
  cidr_block = var.vpc_address_range
  enable_dns_hostnames = true
  enable_dns_support = true

  tags = {
    Name = "DevOps Demo VPC"
  }
}

resource "aws_subnet" "public" {
  count = length(var.availability_zones)

  cidr_block = cidrsubnet(aws_vpc.demo.cidr_block, 8, count.index + 1)
  vpc_id = aws_vpc.demo.id
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "public subnet for ${var.availability_zones[count.index]}"
  }
}

resource "aws_subnet" "private" {
  count = length(var.availability_zones)

  cidr_block = cidrsubnet(aws_vpc.demo.cidr_block, 8, count.index + 101)
  vpc_id = aws_vpc.demo.id
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "private subnet for ${var.availability_zones[count.index]}"
  }

}

resource "aws_eip" "nat" {
  count = length(var.availability_zones)

  vpc   = true

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "eip for NAT gateway in ${var.availability_zones[count.index]}"
  }
}

resource "aws_nat_gateway" "nat_gateway" {
  count = length(var.availability_zones)

  allocation_id = element(aws_eip.nat.*.id, count.index)

  subnet_id = element(aws_subnet.public.*.id, count.index)

  tags = {
    Name = "nat-gateway in ${var.availability_zones[count.index]}"
  }
}

resource "aws_route_table" "route_table_private" {
  count = length(var.availability_zones)

  vpc_id = aws_vpc.demo.id

  tags = {
    Name = "private route-table in ${var.availability_zones[count.index]}"
  }
}

resource "aws_route" "private_nat" {
  count = length(var.availability_zones)

  route_table_id              = element(aws_route_table.route_table_private.*.id, count.index)
  destination_cidr_block      = "0.0.0.0/0"
  nat_gateway_id              = element(aws_nat_gateway.nat_gateway.*.id, count.index)
}

resource "aws_route_table_association" "route_table_association_private" {
  count = length(var.availability_zones)

  subnet_id      = element(aws_subnet.private.*.id, count.index)
  route_table_id = element(aws_route_table.route_table_private.*.id, count.index)
}

resource "aws_internet_gateway" "demo" {
  vpc_id = aws_vpc.demo.id
  tags = {
    Name = "demo internet gateway"
  }
}

resource "aws_route_table" "demo" {
  vpc_id = aws_vpc.demo.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.demo.id
  }
  tags = {
    Name = "public route-table"
  }
}

resource "aws_route_table_association" "public" {
  count = length(var.availability_zones)

  subnet_id      = element(aws_subnet.public.*.id, count.index)
  route_table_id = aws_route_table.demo.id
}

resource "aws_security_group" "bastion" {
  lifecycle {
    ignore_changes = [
      #ingress,
    ]
  }

  name = "bastion-security-group"
  vpc_id = aws_vpc.demo.id

  egress {
    description = "allow ssh to instancs"
    cidr_blocks = [
      var.vpc_address_range
    ]
    from_port = 22
    to_port = 22
    protocol = "tcp"
  }

  egress {
    description = "allow apple remote desktop to instances"
    cidr_blocks = [
      var.vpc_address_range
    ]
    from_port = 5900
    to_port = 5900
    protocol = "tcp"
  }

egress {
    description = "allow connection to jenkins instance"
    cidr_blocks = [
      var.vpc_address_range
    ]
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
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
    Name = "demo securty group"
  }
}

data "aws_ami" "amazon-linux-2" {
  most_recent = true
  owners  = ["amazon"]

filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }

  filter {
        name   = "virtualization-type"
        values = ["hvm"]
  }
}

