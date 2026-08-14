module "network" {
  source = "../../modules/network"

  project_id = var.project_id
  region     = var.region

  network_name = var.network_name
  subnet_name  = var.subnet_name
  subnet_cidr  = var.subnet_cidr
  psa_cidr     = var.psa_cidr
}
