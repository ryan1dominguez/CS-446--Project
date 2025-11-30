# Use the default VPC
data "aws_vpc" "default" {
  default = true
}

# Get all subnets in the default VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Get details of each subnet to filter out us-east-1e
data "aws_subnet" "all" {
  for_each = toset(data.aws_subnets.default.ids)
  id       = each.value
}

# Create a list of subnet IDs excluding us-east-1e
locals {
  available_subnet_ids = [
    for subnet in data.aws_subnet.all : subnet.id
    if subnet.availability_zone != "us-east-1e"
  ]
}