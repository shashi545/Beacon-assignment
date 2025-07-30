variable "region" {
  default = "ap-south-1"
}

variable "profile" {
  default = "beacon" #add your aws profile name here
}

variable "production_vpc_cidr" {
  default = "10.1.0.0/16"
}

variable "vpc_name" {
  default = "beacon"
}


variable "environment_name" {
  default = "production"
}

