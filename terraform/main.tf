terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

data "docker_image" "backend" {
  name = "test-build:latest"
}

# Shared network para makapag-usap ang backend containers, nginx, at database
# gamit ang pangalan (hindi na IP address)
resource "docker_network" "app_network" {
  name = "tf-loadbalancer-net"
}

# === PRIMARY database (tumatanggap ng writes) ===
# Gumagamit tayo ng plain postgres:16-alpine (parehong image sa docker-
# compose mo), hindi na Bitnami dahil na-deprecate na ang kanilang
# libreng images noong 2026.
resource "docker_container" "db_primary" {
  name  = "tf-db-primary"
  image = "postgres:16-alpine"

  networks_advanced {
    name = docker_network.app_network.name
  }

  ports {
    internal = 5432
    external = 5433
  }

  env = [
    "POSTGRES_USER=postgres",
    "POSTGRES_PASSWORD=${var.db_password}",
    "POSTGRES_DB=App"
  ]

  volumes {
    host_path      = "${abspath(path.module)}/primary-init.sh"
    container_path = "/docker-entrypoint-initdb.d/primary-init.sh"
    read_only      = true
  }

  command = [
    "postgres",
    "-c", "wal_level=replica",
    "-c", "max_wal_senders=5",
    "-c", "max_replication_slots=5"
  ]

  healthcheck {
    test     = ["CMD-SHELL", "pg_isready -U postgres"]
    interval = "5s"
    timeout  = "5s"
    retries  = 10
  }

  wait         = true
  wait_timeout = 60
}

# === REPLICA database (read-only, kinokopya ang primary) ===
resource "docker_container" "db_replica" {
  name  = "tf-db-replica"
  image = "postgres:16-alpine"

  networks_advanced {
    name = docker_network.app_network.name
  }

  ports {
    internal = 5432
    external = 5434
  }

  env = [
    "POSTGRES_PASSWORD=${var.db_password}",
    "POSTGRES_REPLICATION_PASSWORD=${var.db_password}"
  ]

  volumes {
    host_path      = "${abspath(path.module)}/replica-init.sh"
    container_path = "/replica-init.sh"
    read_only      = true
  }

  entrypoint = ["sh", "/replica-init.sh"]

  depends_on = [docker_container.db_primary]
}

# 3 replicas gamit ang "count" -- ito ang Terraform way ng "--scale backend=3"
resource "docker_container" "backend_instance" {
  count = 3
  name  = "tf-backend-${count.index + 1}"
  image = data.docker_image.backend.id

  networks_advanced {
    name = docker_network.app_network.name
  }

  # NOTE: "env" dito ay FIXED na pangalan mula sa Docker provider mismo
  # (hindi ito related sa .env file mo -- Docker terminology lang ito,
  # katulad ng "docker run -e VARIABLE=value")
  env = [
    "DOTNET_hostBuilder__reloadConfigOnChange=false",
    "ASPNETCORE_ENVIRONMENT=Development",

    # WRITE connection -- papunta sa PRIMARY. Ito ang ginagamit ng
    # AppDbContext sa code para sa AddInventoryAsync, UpdateAsync,
    # DeleteInventoryAsync (mga operations na nag-SaveChanges)
    "ConnectionStrings__DefaultConnection=Host=tf-db-primary;Port=5432;Database=App;Username=postgres;Password=${var.db_password}",

    # BAGONG DAGDAG: READ-ONLY connection -- papunta sa REPLICA.
    # Ito ang ginagamit ng AppReadOnlyDbContext sa code, partikular
    # sa GetAllInventoryAsync (pure read lang, walang SaveChanges)
    "ConnectionStrings__ReadOnlyConnection=Host=tf-db-replica;Port=5432;Database=App;Username=postgres;Password=${var.db_password}"
  ]

  depends_on = [docker_container.db_primary]
}

# Ito ang "load balancer" -- si Nginx na kumakausap sa 3 backend replicas
# sa itaas, gamit ang parehong network para magkakilala sila via pangalan
resource "docker_container" "loadbalancer" {
  name  = "tf-loadbalancer"
  image = "nginx:alpine"

  networks_advanced {
    name = docker_network.app_network.name
  }

  ports {
    internal = 80
    external = 5002
  }

  volumes {
    host_path      = "${abspath(path.module)}/nginx.conf"
    container_path = "/etc/nginx/nginx.conf"
    read_only      = true
  }

  depends_on = [docker_container.backend_instance]
}

# ============================================================
# MONITORING STACK -- Prometheus + Grafana + cAdvisor + 
# postgres_exporter + node_exporter. Kapalit ito ng CloudWatch
# kung sa totoong AWS/OCI/Azure sana ito ideploy.
# ============================================================

# === PROMETHEUS -- kokolekta ng metrics mula sa lahat ng exporters ===
resource "docker_container" "prometheus" {
  name  = "tf-prometheus"
  image = "prom/prometheus:latest"

  networks_advanced {
    name = docker_network.app_network.name
  }

  ports {
    internal = 9090
    external = 9090
  }

  volumes {
    host_path      = "${abspath(path.module)}/prometheus.yml"
    container_path = "/etc/prometheus/prometheus.yml"
    read_only      = true
  }
}

# === GRAFANA -- visualization dashboard ===
resource "docker_container" "grafana" {
  name  = "tf-grafana"
  image = "grafana/grafana:latest"

  networks_advanced {
    name = docker_network.app_network.name
  }

  ports {
    internal = 3000
    external = 3001
  }

  env = [
    "GF_SECURITY_ADMIN_PASSWORD=${var.grafana_password}"
  ]

  depends_on = [docker_container.prometheus]
}

# === CADVISOR -- container-level CPU/memory metrics ===
# (ito yung magbibigay ng data para makita mo kung tunay na
# naka-distribute ang traffic sa 3 backend replicas mo)
resource "docker_container" "cadvisor" {
  name  = "tf-cadvisor"
  image = "gcr.io/cadvisor/cadvisor:latest"

  networks_advanced {
    name = docker_network.app_network.name
  }

  ports {
    internal = 8080
    external = 8081
  }

  volumes {
    host_path      = "/"
    container_path = "/rootfs"
    read_only      = true
  }
  volumes {
    host_path      = "/var/run"
    container_path = "/var/run"
    read_only      = true
  }
  volumes {
    host_path      = "/sys"
    container_path = "/sys"
    read_only      = true
  }
  volumes {
    host_path      = "/var/lib/docker/"
    container_path = "/var/lib/docker"
    read_only      = true
  }
}

# === POSTGRES EXPORTER -- database metrics (connections, replication lag) ===
resource "docker_container" "postgres_exporter" {
  name  = "tf-postgres-exporter"
  image = "prometheuscommunity/postgres-exporter:latest"

  networks_advanced {
    name = docker_network.app_network.name
  }

  ports {
    internal = 9187
    external = 9187
  }

  env = [
    "DATA_SOURCE_NAME=postgresql://postgres:${var.db_password}@tf-db-primary:5432/App?sslmode=disable"
  ]

  depends_on = [docker_container.db_primary]
}

# === NODE EXPORTER -- host-level system metrics (CPU, disk, uptime, swap) ===
# Ito yung magpupuno sa "N/A" panels sa dashboard (Uptime, Disk, Swap, Load, atbp.)
resource "docker_container" "node_exporter" {
  name  = "tf-node-exporter"
  image = "prom/node-exporter:latest"

  networks_advanced {
    name = docker_network.app_network.name
  }

  ports {
    internal = 9100
    external = 9100
  }

  volumes {
    host_path      = "/proc"
    container_path = "/host/proc"
    read_only      = true
  }
  volumes {
    host_path      = "/sys"
    container_path = "/host/sys"
    read_only      = true
  }
  volumes {
    host_path      = "/"
    container_path = "/rootfs"
    read_only      = true
  }

  command = [
    "--path.procfs=/host/proc",
    "--path.sysfs=/host/sys",
    "--path.rootfs=/rootfs"
  ]
}