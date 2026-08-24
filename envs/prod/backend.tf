terraform {
  backend "gcs" {
    bucket = "petclinic-capstone-tfstate"
    prefix = "envs/prod"
  }
}
