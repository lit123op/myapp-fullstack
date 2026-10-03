locals {
  name = "belandria-lab"

  tags = {
    Environment = "lab"
    ManagedBy   = "terraform"
    Project     = "belandria"
    Purpose     = "one-day-learning-lab"
  }

  secret_names = {
    default_connection = "${local.name}/ConnectionStrings/DefaultConnection"
    read_only          = "${local.name}/ConnectionStrings/ReadOnly"
    jwt                = "${local.name}/JWT"
  }

  subnet_cidrs = {
    public = ["10.42.0.0/24", "10.42.1.0/24"]
    ecs    = ["10.42.10.0/24", "10.42.11.0/24"]
    db     = ["10.42.20.0/24", "10.42.21.0/24"]
  }

  container_names = {
    frontend = "frontend"
    api      = "api"
  }
}