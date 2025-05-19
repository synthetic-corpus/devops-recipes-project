variable "prefix" {
  description = "Prefix for resoruces in AWS"
  default     = "tra"
}

variable "project" {
  description = "This be the name of the project, yarg"
  default     = "terrform-rest-api"
}

variable "contact" {
  description = "who to contact about these resources"
  default     = "joel@joelgonzaga.com"
}

variable "db_username" {
  description = "For access the database"
  default     = "recipeapp"
}

variable "db_password" {
  description = "Password for the terraform database."
}