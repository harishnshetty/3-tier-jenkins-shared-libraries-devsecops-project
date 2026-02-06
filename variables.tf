variable "region" {
  type = string
}

variable "cluster_name" {
  type = string
}
variable "node_group_name" {
  type = string
}
variable "desired_size" {
  type = number
}

variable "max_size" {
  type = number
}

variable "min_size" {
  type = number
}

variable "instance_types" {
  type = list(string)
}



variable "is_alb_controller_enabled" {
  type    = bool
  default = true
}

variable "is_eks_role_enabled" {
  type    = bool
  default = true
}

variable "addons" {
  type = map(object({
    name    = string
    version = string
  }))
}
