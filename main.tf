

# providers


terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

#create the vpc
resource "aws_vpc" "Tier2-vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = "true" #gives you an internal domain name
  enable_dns_hostnames = "true" #gives you an internal host name
  instance_tenancy     = "default"

  tags = {
    Name = "Tier2-vpc"
  }
}



#create the public and private subnet


#for public subnet1
resource "aws_subnet" "public_subnet1" {
  vpc_id                  = aws_vpc.Tier2-vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = "true" //it makes this a public subnet
  availability_zone       = "us-east-1a"
  tags = {
    Name = "public-subnet-1"
  }
}

#for public subnet2
resource "aws_subnet" "public_subnet2" {
  vpc_id                  = aws_vpc.Tier2-vpc.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = "true" //it makes this a public subnet
  availability_zone       = "us-east-1b"
  tags = {
    Name = "public-subnet-2"
  }
}



#for private subnet1
resource "aws_subnet" "privatesubnet1" {
  vpc_id                  = aws_vpc.Tier2-vpc.id
  cidr_block              = "10.0.3.0/24"
  map_public_ip_on_launch = "false" //it makes this a private subnet
  availability_zone       = "us-east-1a"
  tags = {
    Name = "private-subnet-1"
  }
}

#for private subnet2
resource "aws_subnet" "privatesubnet2" {
  vpc_id                  = aws_vpc.Tier2-vpc.id
  cidr_block              = "10.0.4.0/24"
  map_public_ip_on_launch = "false" //it makes this a private subnet
  availability_zone       = "us-east-1b"
  tags = {
    Name = "private-subnet-2"
  }
}

##---------------------------------------------------------------

#Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.Tier2-vpc.id

  tags = {
    Name = "Tier2_internet_gateway"
  }
}


# Route Table for public subnet

resource "aws_route_table" "RouteTablepublic" {
  vpc_id = aws_vpc.Tier2-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}


#Route table Association with Public Subnet 1
resource "aws_route_table_association" "PublicRTassociation1" {
  subnet_id      = aws_subnet.public_subnet1.id
  route_table_id = aws_route_table.RouteTablepublic.id
}


#Route table Association with Public Subnet 2
resource "aws_route_table_association" "PublicRTassociation2" {
  subnet_id      = aws_subnet.public_subnet2.id
  route_table_id = aws_route_table.RouteTablepublic.id
}




##create security Groups, we'll be creating for ec2 and RDS


#security group for ec2

resource "aws_security_group" "Tier2_ec2_sg" {
  name        = "Tier2_ec2_sg"
  description = "security group for public access"
  vpc_id      = aws_vpc.Tier2-vpc.id

  ingress {
    description = "ssh access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }


  ingress {
    description = "http access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ec2 security group"
  }
}


#Secrity group for load balancer
resource "aws_security_group" "alb_sg" {
  name        = "Tier2_alb_sg"
  description = "security group for alb"
  vpc_id      = aws_vpc.Tier2-vpc.id


  ingress {
    description = "http access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb security group"
  }
}




#security group for RDS

resource "aws_security_group" "Tier2_RDS_sg" {
  name        = "Tier2_RDS_sg"
  description = "security group for RDS"
  vpc_id      = aws_vpc.Tier2-vpc.id

  ingress {
    description     = "RDS access"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.Tier2_ec2_sg.id]
    cidr_blocks     = ["0.0.0.0/0"]

  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "RDS security group"
  }
}

#create ec2 for each public subnet.
# for public subnet 1
resource "aws_instance" "ec2_instance_public_1" {
  ami             = "ami-026b57f3c383c2eec"
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.public_subnet1.id
  security_groups = [aws_security_group.Tier2_ec2_sg.id]
}

# for public subnet 2
resource "aws_instance" "ec2_instance_public_2" {
  ami             = "ami-026b57f3c383c2eec"
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.public_subnet2.id
  security_groups = [aws_security_group.Tier2_ec2_sg.id]
}



#create the application load balancer

resource "aws_lb" "Tier2_alb" {
  name               = "Tier2-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = [aws_subnet.public_subnet1.id, aws_subnet.public_subnet2.id]
  security_groups    = [aws_security_group.alb_sg.id]

  enable_deletion_protection = false

  tags = {
    Environment = "Tier2_alb"
  }
}



#create alb target group

resource "aws_lb_target_group" "Tier2-TG" {
  name        = "Tier2-lb-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.Tier2-vpc.id
  health_check {
    interval            = 90
    enabled             = true
    path                = "/"
    matcher             = 200
    timeout             = 60
    protocol            = "HTTP"
    healthy_threshold   = 3
    unhealthy_threshold = 2
  }

}

#create alb listener
resource "aws_lb_listener" "Tier2_alb_listener" {
  load_balancer_arn = aws_lb.Tier2_alb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.Tier2-TG.arn
  }
}





#create alb target group attachment

resource "aws_lb_target_group_attachment" "ec2_instance_public_1" {
  target_group_arn = aws_lb_target_group.Tier2-TG.arn
  target_id        = aws_instance.ec2_instance_public_1.id
}


resource "aws_lb_target_group_attachment" "ec2_instance_public_2" {
  target_group_arn = aws_lb_target_group.Tier2-TG.arn
  target_id        = aws_instance.ec2_instance_public_2.id
}



#create db_instance subnet group

resource "aws_db_subnet_group" "db_instance" {
  name       = "db_instance"
  subnet_ids = [aws_subnet.privatesubnet1.id, aws_subnet.privatesubnet2.id]

  tags = {
    Name = " DB subnets"
  }
}


#create DB instance

resource "aws_db_instance" "tierdb" {
  allocated_storage    = 10
  db_name              = "mydb"
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t2.micro"
  username             = "admin"
  password             = "password"
  parameter_group_name = "default.mysql5.7"
  vpc_security_group_ids = [aws_security_group.Tier2_RDS_sg.id]
  db_subnet_group_name = "db_instance"
  skip_final_snapshot  = true
}