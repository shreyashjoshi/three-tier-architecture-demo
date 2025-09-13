variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "cluster_name" {
  type    = string
  default = "robot-shop-eks"
}

variable "k8s_version" {
  type    = string
  default = "1.26"
}

variable "tags" {
  type    = map(string)
  default = {}
}
