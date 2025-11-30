resource "aws_security_group" "alb" {
    name =  "ha-dr-alb-sg"
    description = "Security group for app load balancer"
    vpc_id = data.aws_vpc.default.id
    ingress {
        description = "http from the internet"
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        description = "All outbound traffic"
        from_port = "0"
        to_port = "0"
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "ha-dr-alb-sg"
    }

}



resource "aws_security_group" "alb_secondary"{
    provider =aws.secondary
    name="ha-dr-alb-sg-secondary"
    description="ALB security group for second region"
    vpc_id =data.aws_vpc.default_secondary.id

    ingress {
        from_port = 80
        to_port   = 80
        protocol  ="tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress{
        from_port =0
        to_port=0
        protocol= "-1"
        cidr_blocks =["0.0.0.0/0"]
    }
    tags= {
        Name="ha-dr-alb-sg-secondary"
    }
}



resource "aws_security_group" "app" {
    name = "ha-dr-app-sg"
    description = "Security group for app instances"
    vpc_id = data.aws_vpc.default.id

    ingress {
        description = "HTTP from ALB"
        from_port = 3000
        to_port = 3000
        protocol = "tcp"
        security_groups = [aws_security_group.alb.id]
    }

    egress {
        description = "All outbound traffic"
        from_port = "0"
        to_port = "0"
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "ha-dr-app-sg"
    }
}

resource "aws_security_group" "app_secondary" {
    provider =aws.secondary
    name = "ha-dr-app-sg-secondary"
    description = "Security group for app instances secondary region"
    vpc_id = data.aws_vpc.default_secondary.id

    ingress {
        description = "HTTP from ALB"
        from_port = 3000
        to_port = 3000
        protocol = "tcp"
        security_groups = [aws_security_group.alb_secondary.id]
    }

    egress {
        description = "All outbound traffic"
        from_port = "0"
        to_port = "0"
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "ha-dr-app-secondary"
    }
}


