# Declaring the Provider

provider "aws" {
  region = "eu-west-1"
}



# Declaring the VPC for the deployment
resource "aws_vpc" "martin_deployment_vpc" {
  cidr_block = "10.0.0.0/16"
}

# Declaring the first public subnet within the VPC
resource "aws_subnet" "public_subnet_1" {
  vpc_id            = aws_vpc.martin_deployment_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-west-1a"
}

# Declaring the second public subnet within the VPC
resource "aws_subnet" "public_subnet_2" {
  vpc_id            = aws_vpc.martin_deployment_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "eu-west-1b"
}

# Declaring the third public subnet within the VPC
resource "aws_subnet" "public_subnet_3" {
  vpc_id            = aws_vpc.martin_deployment_vpc.id
  cidr_block        = "10.0.5.0/24"
  availability_zone = "eu-west-1c"
}


# Declaring the private subnet within the VPC
resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.martin_deployment_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-west-1b"
}



# App instance Security Group

resource "aws_security_group" "app_sg" {
  name        = "app-sg"
  description = "Security group for the app instance"
  vpc_id      = aws_vpc.martin_deployment_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Database instance security group

resource "aws_security_group" "database_sg" {
  name        = "database-sg"
  description = "Security group for the database instance"
  vpc_id      = aws_vpc.martin_deployment_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}



# Declaring the Launch Template for the Auto Scaling Group
resource "aws_launch_template" "app-launch-template" {
  name_prefix   = "app-launch-template"
  image_id      = "ami-011e54f70c1c91e17"
  instance_type = "t2.micro"
  key_name      = "martin-key"
  security_group_names = [aws_security_group.app_sg.name]

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size = 20
      volume_type = "gp2"
    }
  }
}

# Declaring the Auto Scaling Group
resource "aws_autoscaling_group" "app-asg" {
  launch_template {
    id      = aws_launch_template.app-launch-template.id
    version = "$Latest"
  }

  vpc_zone_identifier  = [
    aws_subnet.public_subnet_1.id,
    aws_subnet.public_subnet_2.id,
    aws_subnet.public_subnet_3.id
  ]
  min_size             = 2
  max_size             = 3
  desired_capacity     = 2
  health_check_type    = "EC2"
  health_check_grace_period = 300
  protect_from_scale_in = false

  tag {
    key                 = "Name"
    value               = "app-instance"
    propagate_at_launch = true
  }
}


# Declaring the VM for the Database
resource "aws_instance" "database-vm" {
  ami           = "ami-011e54f70c1c91e17"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.private_subnet.id
  security_groups = [aws_security_group.database_sg.id]
  key_name = "martin-key"
  tags = {
    Name = "martin-database-vm"
  }
}

# S3 backend configuration
terraform {
  backend "s3" {
    bucket = "martin-bucket"
    key = "dev/terraform.tfstate"
    region = "eu-west-1"
  }
}

