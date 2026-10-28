variable "resource_group_name" {
  default = "rg-network-guard"
}

variable "location" {
  default = "southafricanorth" # Make sure this is an allowed region!
}

variable "sql_admin_password" {
  description = "The password for the SQL admin"
  type        = string
  sensitive   = true
  default     = "P@ssw0rd1234!" # Change this!
}