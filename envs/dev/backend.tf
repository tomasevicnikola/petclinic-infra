terraform {
  backend "gcs" {
    bucket = "petclinic-capstone-tfstate"
    prefix = "envs/dev"
  }
}
