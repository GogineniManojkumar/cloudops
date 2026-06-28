provider "kubernetes" {
  host                   = var.cluster_host
  token                  = var.cluster_token
  cluster_ca_certificate = var.cluster_ca_certificate == null ? null : base64decode(var.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = var.cluster_host
    token                  = var.cluster_token
    cluster_ca_certificate = var.cluster_ca_certificate == null ? null : base64decode(var.cluster_ca_certificate)
  }
}
