variable "project_name" {
  description = "The name of the project"
  type        = string
  default     = "colour-in-backend"
}

variable "container_port" {
  description = "The port to expose on container"
  type        = number
  default     = 8080
}

variable "region" {
  description = "The region resources to be created in"
  type        = string
  default     = ""
}

variable "initial_image" {
  description = "The initial image url"
  type        = string
  default     = ""
}