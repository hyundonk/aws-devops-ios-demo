terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  profile = "default"
  region  = "ap-northeast-2"
}

provider "aws" {
  region = "us-west-2"
  alias = "uswest2"
}

provider "aws" {
  region = "us-east-1"
  alias = "useast1"
}


