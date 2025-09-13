terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"

  name = "robot-shop-vpc"
  cidr = "10.0.0.0/16"

  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
}

data "aws_availability_zones" "available" {}

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "~> 19.0"

  cluster_name    = var.cluster_name
  cluster_version = var.k8s_version
  subnet_ids        = module.vpc.private_subnets

  vpc_id = module.vpc.vpc_id

  node_groups = {
    robotshop_nodes = {
      desired_capacity = 2
      max_capacity     = 3
      min_capacity     = 1

      instance_type = "t3.medium"
    }
  }

  map_users = []
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

# Install NGINX ingress controller
resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.0.13"

  values = [file("./helm_values/nginx_values.yaml")]
}

# Install Argo CD
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argo-cd.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "5.12.0"

  values = [file("./helm_values/argocd_values.yaml")]

  depends_on = [helm_release.nginx_ingress]
}
