#terraform {
#  backend "s3" {
#    bucket         = "beacon"
#    key            = "VPC-region/terraform.tfstate"
#    region         = "ap-south-1"
#    profile        = "beacon" #add your aws profile name here
#    encrypt        = true
#    dynamodb_table = "beacon-db"
#  }
#}