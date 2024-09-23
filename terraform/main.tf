# main.tf

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Enable required APIs
resource "google_project_service" "container" {
  service = "container.googleapis.com"
}

resource "google_project_service" "sqladmin" {
  service = "sqladmin.googleapis.com"
}

# Create GKE Cluster
resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.zone

  remove_default_node_pool = true
  initial_node_count       = 1

  depends_on = [google_project_service.container]
}

resource "google_container_node_pool" "primary_nodes" {
  name       = "${google_container_cluster.primary.name}-node-pool"
  location   = var.zone
  cluster    = google_container_cluster.primary.name
  node_count = var.gke_num_nodes

  node_config {
    machine_type = "e2-medium"
  }
}

# Create Cloud SQL instance
resource "google_sql_database_instance" "wordpress" {
  name             = var.db_instance_name
  database_version = "MYSQL_8_0"
  region           = var.region

  settings {
    tier = "db-f1-micro"
  }

  deletion_protection = false

  depends_on = [google_project_service.sqladmin]
}

# Create WordPress database
resource "google_sql_database" "wordpress" {
  name     = "wordpress"
  instance = google_sql_database_instance.wordpress.name
}

# Create WordPress user
resource "google_sql_user" "wordpress" {
  name     = "wordpress"
  instance = google_sql_database_instance.wordpress.name
  password = var.db_password
}

# Create Storage Bucket for WordPress content
resource "google_storage_bucket" "wordpress_content" {
  name     = "${var.project_id}-wordpress-content"
  location = var.region
}

# Create service account for Cloud SQL proxy
resource "google_service_account" "cloudsql_proxy" {
  account_id   = "cloudsql-proxy"
  display_name = "CloudSQL Proxy"
}

# Grant necessary permissions to the service account
resource "google_project_iam_member" "cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.cloudsql_proxy.email}"
}

# Generate and download the service account key
resource "google_service_account_key" "cloudsql_proxy_key" {
  service_account_id = google_service_account.cloudsql_proxy.name
}

# Output the service account key (be careful with this in production)
output "cloudsql_proxy_key" {
  value     = google_service_account_key.cloudsql_proxy_key.private_key
  sensitive = true
}

# Output cluster endpoint
output "cluster_endpoint" {
  value = google_container_cluster.primary.endpoint
}

# Output Cloud SQL connection name
output "cloudsql_connection_name" {
  value = google_sql_database_instance.wordpress.connection_name
}

# Output WordPress content bucket name
output "wordpress_content_bucket" {
  value = google_storage_bucket.wordpress_content.name
}