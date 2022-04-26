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

  tags = {
    Name = "ghost"
  }
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

  egress {
    from_port	= 0
    to_port	= 0
    protocol	= -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "ghost-website-ec2-instance" {
  instance_type 	= "t3.micro"
  ami			= "ami-0682e777b6c06bc9b" 
  key_name		= "EC2-eu-central-1"

  subnet_id		= aws_subnet.ghost-public-subnet.id
  vpc_security_group_ids= [aws_security_group.ghost-website-sg.id]
  associate_public_ip_address = true

  tags = {
    Name = "ghost"
  }

  user_data = <<EOF
#!/bin/bash
echo -e "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC+qmohGVLTdSqRhXXIoRhedqj5D59tpYQyGa4EvBtJMZ2pzA7/ZX7VbgFem8If5EPTyI0ZnzPFGBv1dXbBRjSHCOEPWKRl9q3Zodp507CfyyixcVjSGxoGQkbrWAJE4hg5nl6DJZ+DlBwv1N+ppgRk/IN8cIgcowecyLWRHkV2w8biGGKZSCfv7gxbXcckaEKFg6u++Fg34hNoyieUDlCshz5NLP8Nhcfilf3ZcCM87IYCaeU81J7LYiBBTllWk6qf6GiIoEg+c8Pf8bCbrf/d8LO6RRbvclttz2Mcka93Ncv/lN8Za6W8RcCTE0fZabziVHEAaQsVe3H1pm8eDkZz" >> /home/ec2-user/.ssh/authorized_keys

EOF
}

resource "aws_ebs_volume" "ghost-ebs-volume" {
  availability_zone = "eu-central-1c"
  size		    = 10
}

resource "aws_ebs_snapshot" "ghost-ebs-snapshot" {
  volume_id = aws_ebs_volume.ghost-ebs-volume.id
}

resource "aws_eip" "ghost-instance-eip" {
  instance	= aws_instance.ghost-website-ec2-instance.id
  vpc		= true
}

resource "aws_route53_health_check" "ghost-health-check-webroot-reachable" {
  fqdn 		    = "blog.jackwilson.uk"
  port 		    = 443
  type 		    = "HTTP"
  resource_path     = "/"
  failure_threshold = "5"
  request_interval  = "30"
}

resource "aws_cloudwatch_metric_alarm" "ghost-cw-metric-cpu-util" {
  alarm_name	      = "ghost-cpu-util-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ec2 cpu utilization"
}

resource "aws_route53_health_check" "ghost-health-check-cpu-util" {
  type 				  = "CLOUDWATCH_METRIC"
  cloudwatch_alarm_name  	  = aws_cloudwatch_metric_alarm.ghost-cw-metric-cpu-util.alarm_name
  cloudwatch_alarm_region	  = "eu-central-1"
  insufficient_data_health_status = "Healthy"
}
