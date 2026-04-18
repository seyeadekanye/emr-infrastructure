variable "repo_names" {
  type = list(string)
}

variable "replication_regions" {
  type        = list(string)
  default     = []
  description = "Regions to replicate all ECR images to (e.g. [\"us-west-2\"])"
}
