terraform {
    required_providers {
      aws = {
          source    = "hashicorp/aws"
          version   = "~> 3.0"
      }
    }
   backend "s3" {
     bucket = "tfstate-ghost-website.jackwilson.uk"
     key    = "terraform.tfstate"
     region = "eu-central-1"
   }
 }

provider "aws" {
  region  = "eu-central-1"
}

resource "aws_vpc" "ghost-vpc" {
 cidr_block = "10.0.0.0/16" 
}

resource "aws_subnet" "ghost-public-subnet" {
  vpc_id		= aws_vpc.ghost-vpc.id
  cidr_block		= "10.0.1.0/24"
}

resource "aws_internet_gateway" "ghost-igw" {
  vpc_id		= aws_vpc.ghost-vpc.id
}

resource "aws_route_table" "ghost-route-table" {
  vpc_id		= aws_vpc.ghost-vpc.id

  route	{
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ghost-igw.id
  }
}

resource "aws_route_table_association" "ghost-rta" {
  subnet_id		= aws_subnet.ghost-public-subnet.id
  route_table_id	= aws_route_table.ghost-route-table.id
}

resource "aws_security_group" "ghost-website-sg" {
  name		= "ghost-security-group"
  vpc_id	= aws_vpc.ghost-vpc.id

  ingress {
    from_port	= 80
    to_port 	= 80
    protocol	= "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port	= 443
    to_port	= 443
    protocol	= "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port	= 22
    to_port	= 22
    protocol	= "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port	= 0
    to_port	= 0
    protocol	= -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "ghost-website-ec2-instance" {
  instance_type 	= "t3.micro"
  ami			= "ami-0006ba1ba3732dd33" 
  key_name		= "EC2-eu-central-1"

  subnet_id		= aws_subnet.ghost-public-subnet.id
  vpc_security_group_ids= [aws_security_group.ghost-website-sg.id]
  associate_public_ip_address = true

  tags {
    Name = "ghost"
  }
}

