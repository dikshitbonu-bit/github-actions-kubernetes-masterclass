terraform {
  backend "s3" {
    bucket  = "skillpulse-terraform-state"
    key     = "dev/terraform.tfstate"
    region  = "ap-south-1"
    encrypt = true
  }
}
