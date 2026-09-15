variable "db_password" {
  description = "Password para sa local Postgres database"
  type        = string
  sensitive   = true
}
variable "grafana_password" {
  description = "Admin password para sa Grafana dashboard"
  type        = string
  sensitive   = true
}