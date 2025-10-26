variable "aws_region" {
    description = "AWS region to deploy to"
    type = string
    default = "us-east-1"
}

variable "instance_type" {
    description = "EC2 instance type"
    type = string
    default = "t3.micro"
}

variable "docker_image" {
    description = "Docker image to run"
    type = string
    default = "ryandominguez/ha-dr-app:latest"
}

variable "desired_capacity" {
    description = "Desired number of instances"
    type = number
    default = 2
}

variable "min_size" {
    description = "Minimum number of instances"
    type = number
    default = 1
}

variable "max_size" {
    description = "Maximum number of instances"
    type = number
    default = 4
}