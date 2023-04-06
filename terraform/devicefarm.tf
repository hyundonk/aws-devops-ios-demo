
resource "aws_devicefarm_project" "example" {
  provider = aws.uswest2

  name = "helloworld"
}

resource "aws_devicefarm_device_pool" "example" {
  provider = aws.uswest2

  name        = "mydevicepool"
  project_arn = aws_devicefarm_project.example.arn

  rule {
    attribute = "PLATFORM"
    operator  = "EQUALS"
    value     = "\"iOS\""
  }
  rule {
    attribute = "MODEL"
    operator  = "EQUALS"
    value     = "\"Apple iPhone 14\""
  }
}

resource "aws_devicefarm_network_profile" "example" {
  provider = aws.uswest2

  name        = "demoprofile"
  project_arn = aws_devicefarm_project.example.arn
}

output "devicefarm_project_id" {
  value = aws_devicefarm_project.example.arn
}

output "devicefarm_device_id" {
  value = aws_devicefarm_device_pool.example.arn
}
