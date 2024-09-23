## Run the tf file
- Initialize Terraform:
- Copyterraform init

## Create a terraform.tfvars file with your specific values:
- Copyproject_id = "project-id"
- region = "us-central1"
- zone = "us-central1-a"
- db_instance_name = "db-instance-name"
- db_password = "db-password"

## Plan and apply the Terraform configuration:
- Copyterraform plan
- terraform apply

## After the apply is complete, Terraform will output the WordPress instance's external IP and the Cloud SQL connection name. Make note of these.
- SSH into the Compute Engine instance:
- run the startup script as well
- gcloud compute ssh wordpress-instance --zone=us-central1-a

## Check if the Cloud SQL proxy is running:
- sudo systemctl status cloud-sql-proxy