variable "tf_state_bucket" {
  description = "Name of an s3 bucket that stores the Terraform state"
  default     = "jtg-terraform-buckets"
}

variable "tf_state_lock_table" {
  description = "The DynamoDB table handles Terraform locks"
  default     = "terraform-lock-table"
}

variable "project" {
  description = "This be the name of the project, yarg"
  default     = "terrform-rest-api"
}

variable "contact" {
  description = "who to contact about these resources"
  default     = "joel@joelgonzaga.com"
}