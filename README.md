# WordPress on GKE with Cloud SQL and Terraform

This project sets up a WordPress installation on Google Kubernetes Engine (GKE) using Cloud SQL for MySQL, with the infrastructure managed by Terraform and deployments handled by Cloud Build.

## Prerequisites

- Google Cloud Platform account
- Google Cloud SDK installed and configured
- Terraform installed (version 0.12+)
- Git

## Project Structure

```
.
├── terraform/
│   ├── main.tf
│   └── variables.tf
├── k8s/
│   ├── wordpress-volumeclaim.yaml
│   ├── wordpress-deployment.yaml
│   └── wordpress-service.yaml
├── cloudbuild.yaml
└── README.md
```

## Step-by-Step Guide

### 1. Clone the Repository

```bash
git clone <your-repo-url>
cd <your-repo-name>
```

### 2. Set Up Terraform

1. Navigate to the terraform directory:
   ```bash
   cd terraform
   ```

2. Update `variables.tf` with your project-specific values:
   - Set `project_id` to your GCP project ID
   - Update other variables as needed (region, zone, cluster name, etc.)

3. Initialize Terraform:
   ```bash
   terraform init
   ```

4. Plan the Terraform execution:
   ```bash
   terraform plan -out=tfplan
   ```

5. Apply the Terraform plan:
   ```bash
   terraform apply tfplan
   ```

6. Note the outputs, especially:
   - `cluster_endpoint`
   - `cloudsql_connection_name`
   - `wordpress_content_bucket`
   - `cloudsql_proxy_key`

### 3. Configure kubectl

After Terraform creates the GKE cluster, configure kubectl:

```bash
gcloud container clusters get-credentials <your-cluster-name> --zone <your-zone> --project <your-project-id>
```

### 4. Prepare Kubernetes Manifests

1. Navigate to the k8s directory:
   ```bash
   cd ../k8s
   ```

2. Update `wordpress-deployment.yaml`:
   - Replace `${INSTANCE_CONNECTION_NAME}` with the `cloudsql_connection_name` from Terraform output

3. (Optional) Adjust `wordpress-volumeclaim.yaml` if you need to change the storage size

### 5. Set Up Cloud Build

1. Enable the Cloud Build API in your GCP project

2. Connect your repository to Cloud Build:
   - Go to Cloud Build in GCP Console
   - Click "Triggers" and then "Connect Repository"
   - Follow the prompts to connect your Git repository

3. Create a Cloud Build trigger:
   - Click "Create Trigger"
   - Configure the trigger to run on pushes to your desired branch
   - Use the `cloudbuild.yaml` file in the root of your repository

4. Set up Cloud Build variables:
   - In the Cloud Build trigger settings, add the following substitution variables:
     - `_ZONE`: Your GKE cluster zone
     - `_CLUSTER_NAME`: Your GKE cluster name
     - `_DB_PASSWORD`: The WordPress database password (use a secure method to manage this)

5. Set up the CloudSQL proxy key:
   - Create a new Cloud Storage bucket to store the key securely
   - Upload the `cloudsql_proxy_key` (from Terraform output) to this bucket
   - Update the `_CLOUDSQL_KEY_PATH` in `cloudbuild.yaml` to point to this file in your bucket

### 6. Initial Deployment

1. Commit and push your changes:
   ```bash
   git add .
   git commit -m "Initial configuration"
   git push origin main
   ```

2. This should trigger the Cloud Build pipeline. Monitor the build in the GCP Console.

### 7. Access WordPress

1. After the build completes successfully, get the external IP of your WordPress service:
   ```bash
   kubectl get services
   ```

2. Access WordPress using the external IP in your web browser

3. Complete the WordPress installation process

### 8. Configure WordPress for GCS

1. Install and configure the [GCS plugin for WordPress](https://wordpress.org/plugins/gcs/) to use the created GCS bucket for media storage

## Maintenance and Updates

- To update WordPress or change configurations, modify the relevant files in the `k8s/` directory and push the changes. Cloud Build will automatically apply the updates.
- To make infrastructure changes, modify the Terraform files in the `terraform/` directory, then run `terraform plan` and `terraform apply`.

## Security Considerations

- Ensure that all secrets (database passwords, service account keys) are properly secured and not committed to the repository.
- Regularly update all components (WordPress, MySQL, GKE) to their latest versions.
- Configure proper network policies and firewall rules to secure your GKE cluster and Cloud SQL instance.

## Troubleshooting

- Check Cloud Build logs for deployment issues
- Use `kubectl logs` and `kubectl describe` for debugging Kubernetes resources
- Verify Cloud SQL connectivity using the Cloud SQL proxy

## Contributing

[Add your contributing guidelines here]

## License

[Add your license information here]