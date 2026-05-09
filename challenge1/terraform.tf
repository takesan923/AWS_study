terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.0"
    }
  }
  backend "s3" {
    bucket  = "kono-terraform-tfstate"
    key     = "kono_challenge1.tfstate"
    region  = "ap-northeast-1"
    profile = "default"
  }
}
