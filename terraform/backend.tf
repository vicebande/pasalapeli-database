terraform {
  backend "s3" {
    bucket         = "pasalapeli-terraform-state"
    key            = "$repo/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
  }
