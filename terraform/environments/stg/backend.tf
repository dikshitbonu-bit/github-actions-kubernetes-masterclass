terraform {
  backend "s3" {
    bucket       = "skillpulse-terraform-state"
    key          = "stg/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}
