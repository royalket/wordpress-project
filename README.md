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
git clone https://github.com/royalket/wordpress-project.git
cd wordpress-project
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
   It will ask for project id and Password for DB

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
gcloud container clusters get-credentials wordpress-cluster --zone us-central1-a --project wordpress-sigma-436504
```

### 4. Prepare Kubernetes Manifests

1. Navigate to the k8s directory:
   ```bash
   cd ../k8s
   ```

2. Update `wordpress-deployment.yaml`:
   - Replace `${INSTANCE_CONNECTION_NAME}` with the `cloudsql_connection_name` from Terraform output you got above

3.  Adjust `wordpress-volumeclaim.yaml` if you need to change the storage size

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

4. Set up Cloud Build variables

5. Set up the CloudSQL proxy key:
   terraform output -raw cloudsql_proxy_key | base64 --decode > key.json
   `by running that you will get a key paste that in the bucket. it will be used later to access the DB
### 6. Initial Deployment

1. Commit and push your changes:
   ```bash
   git add .
   git commit -m "Initial configuration"
   git push origin main
   ```

2. This should trigger the Cloud Build pipeline. Monitor the build in the GCP Console.
3. [Completion Image ]({650F9A2A-86F9-4992-93EF-D4BA419FCB87}-1.png)
4. [GKE]({CBA0AD52-8701-42CC-A047-DEBF823AAE06}.png)
5. [Cloud SQL]({F3AA3B43-D1D4-4D71-9020-42EC53A9886F}.png)
6. [Buckets]({9B4FAFBC-855E-4E1F-A7AB-A5A9A722C918}.png)
7. [k8s services]({3345D72F-811F-4B85-A072-77B7BD48AD0E}.png)

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

## Test to add in the CI/CD
 # Test: Verify secrets creation
  - name: "gcr.io/cloud-builders/kubectl"
    id: "test-secrets"
    entrypoint: "bash"
    args:
      - "-c"
      - |
        kubectl get secret cloudsql-db-credentials
        kubectl get secret cloudsql-instance-credentials
    env:
      - "CLOUDSDK_COMPUTE_ZONE=us-central1-a"
      - "CLOUDSDK_CONTAINER_CLUSTER=wordpress-cluster"

  # Test: Verify PVC creation
  - name: "gcr.io/cloud-builders/kubectl"
    id: "test-pvc"
    entrypoint: "bash"
    args:
      - "-c"
      - |
        kubectl get pvc wordpress-persistent-storage
    env:
      - "CLOUDSDK_COMPUTE_ZONE=us-central1-a"
      - "CLOUDSDK_CONTAINER_CLUSTER=wordpress-cluster"

  # Test: Verify WordPress deployment
  - name: "gcr.io/cloud-builders/kubectl"
    id: "test-deployment"
    entrypoint: "bash"
    args:
      - "-c"
      - |
        kubectl rollout status deployment/wordpress --timeout=300s
    env:
      - "CLOUDSDK_COMPUTE_ZONE=us-central1-a"
      - "CLOUDSDK_CONTAINER_CLUSTER=wordpress-cluster"

  # Test: Verify WordPress service and wait for External IP
  - name: "gcr.io/cloud-builders/kubectl"
    id: "test-service-and-wait-for-ip"
    entrypoint: "bash"
    args:
      - "-c"
      - |
        kubectl get service wordpress
        echo "Waiting for external IP (this may take a few minutes)..."
        external_ip=""
        while [ -z $external_ip ]; do
          echo "Waiting for end point..."
          external_ip=$(kubectl get svc wordpress --template="{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}")
          [ -z "$external_ip" ] && sleep 10
        done
        echo "End point ready: $external_ip"
        echo $external_ip > /workspace/external_ip.txt
    env:
      - "CLOUDSDK_COMPUTE_ZONE=us-central1-a"
      - "CLOUDSDK_CONTAINER_CLUSTER=wordpress-cluster"

  # Test: Basic HTTP check
  - name: "gcr.io/cloud-builders/curl"
    id: "test-http"
    entrypoint: "bash"
    args:
      - "-c"
      - |
        if [ ! -f /workspace/external_ip.txt ]; then
          echo "External IP file not found"
          exit 1
        fi
        external_ip=$(cat /workspace/external_ip.txt)
        for i in {1..30}; do
          http_status=$(curl -s -o /dev/null -w "%{http_code}" http://$external_ip)
          if [ $http_status -eq 200 ]; then
            echo "WordPress is responding with HTTP 200"
            exit 0
          fi
          echo "Attempt $i: WordPress is not ready yet. HTTP status: $http_status"
          sleep 10
        done
        echo "WordPress did not become ready in time"
        exit 1


## same can be deployed using compute engine(EC2) and cloud SQL 
Code is available in compute+Sql folder with readme