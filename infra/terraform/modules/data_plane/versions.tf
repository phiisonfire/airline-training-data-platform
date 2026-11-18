terraform {
  required_version = ">= 1.14.6, < 2.0.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "= 5.100.0" }
  }
}
