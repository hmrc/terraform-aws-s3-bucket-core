
variable "test_name" {
  description = "short name to ensure unique resources are created during test runs"
  type        = string
}

variable "data_expiry" {
  description = "allow the test to select different expiry periods"
  type        = string
}