terraform {
  backend "s3" {
    bucket  = "skillpulse-terraform-state"
    key     = "prd/terraform.tfstate"
    region  = "ap-south-1"
    encrypt = true
  }
}
