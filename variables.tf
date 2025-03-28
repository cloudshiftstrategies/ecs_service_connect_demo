variable "projectName" {
    type = string
    default = "SvcCxDemo"
}

variable "clusterName" {
    type = string
    description = "Name of the cluster (e.g., cluster-1 or cluster-2)"
}

variable "cidr" {
    type = string
    default = "10.0.0.0/16"
}

variable "region" {
    type = string
    default = "us-west-2"
} 