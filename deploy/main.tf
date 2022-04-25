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

resource "aws_s3_bucket" "tfstate-ghost-website_jackwilson_uk" {
	bucket = "tfstate-ghost-website.jackwilson.uk"

	versioning {
	    enabled = true
	}
	server_side_encryption_configuration {
    	rule {
      	  apply_server_side_encryption_by_default {
          sse_algorithm = "AES256"
	}
    }
}
