# Terraform Cloud Setup Guide

## Overview
This guide will help you set up and deploy the Online Book Bazaar infrastructure using Terraform Cloud for complete automation and state management.

## Prerequisites
1. **Terraform Cloud Account**: Sign up at [app.terraform.io](https://app.terraform.io)
2. **AWS Account**: With appropriate permissions for EC2, VPC, etc.
3. **Terraform CLI**: Installed on your local machine

## Step 1: Terraform Cloud Setup

### 1.1 Create Organization and Workspace
1. Login to [app.terraform.io](https://app.terraform.io)
2. Create an organization named: `online-book-bazaar`
3. Create a workspace named: `book-bazaar-infrastructure`
4. Choose "Version Control Workflow" and connect your repository

### 1.2 Configure AWS Credentials
In your Terraform Cloud workspace:
1. Go to **Variables** tab
2. Add the following **Environment Variables**:
   - `AWS_ACCESS_KEY_ID` (sensitive)
   - `AWS_SECRET_ACCESS_KEY` (sensitive)
   - `AWS_DEFAULT_REGION` = `ap-south-1`

### 1.3 Configure Terraform Variables
Add these **Terraform Variables**:
- `aws_region` = `ap-south-1`
- `instance_count` = `3`
- `instance_type` = `t2.micro`

## Step 2: Local Setup

### 2.1 Login to Terraform Cloud
```bash
terraform login
```
Follow the prompts to authenticate.

### 2.2 Initialize Terraform
```bash
cd /Users/adarshraj/Desktop/devops/online-book-bazaar-infra
terraform init
```

## Step 3: Deploy Infrastructure

### 3.1 Plan Deployment
```bash
terraform plan
```

### 3.2 Apply Infrastructure
```bash
terraform apply
```

Or trigger from Terraform Cloud UI for full automation.

## Step 4: Post-Deployment Setup

### 4.1 Get Instance IPs
```bash
terraform output instance_public_ips
```

### 4.2 Run DevOps Setup
```bash
# Make script executable
chmod +x unified-devops-setup.sh

# Run setup on all instances
./unified-devops-setup.sh $(terraform output -raw instance_public_ips | tr -d '[]," ')
```

## Step 5: Access Services

After successful deployment and setup:

### Web Application
- **Instance 1**: `http://<IP1>:3000` - Main Book Bazaar Application

### Jenkins
- **Instance 2**: `http://<IP2>:8080` - Jenkins CI/CD
- Default admin password: Check `/var/lib/jenkins/secrets/initialAdminPassword`

### Monitoring
- **Instance 3**: `http://<IP3>:9090` - Prometheus Metrics
- **Instance 3**: `http://<IP3>:3000` - Grafana Dashboard
- Grafana default: admin/admin

## Step 6: Validation

### 6.1 Health Checks
```bash
# Check all services
for ip in $(terraform output -raw instance_public_ips | tr -d '[]," '); do
  echo "Checking $ip..."
  curl -s "http://$ip:3000/status" || echo "Service not ready"
done
```

### 6.2 Demo Flow
1. Access Book Bazaar website
2. Trigger Jenkins build
3. View metrics in Prometheus
4. Create dashboard in Grafana

## Cleanup

### Destroy Infrastructure
```bash
terraform destroy
```

Or use Terraform Cloud UI to destroy.

## Troubleshooting

### Common Issues
1. **SSH Connection Issues**: Check security groups and key permissions
2. **Service Not Starting**: Re-run setup script on specific instance
3. **Port Access Issues**: Verify security group rules

### Reset Individual Instance
```bash
# Get instance IP
INSTANCE_IP=$(terraform output -json instance_public_ips | jq -r '.[0]')

# Re-run setup
./unified-devops-setup.sh $INSTANCE_IP
```

## Best Practices

1. **Version Control**: All infrastructure changes via Git
2. **State Management**: Always use Terraform Cloud for state
3. **Security**: Use IAM roles instead of access keys when possible
4. **Monitoring**: Set up Terraform Cloud notifications
5. **Backup**: Regular workspace backups in Terraform Cloud

## Next Steps

1. Set up automated deployments via webhooks
2. Configure Terraform Cloud notifications
3. Add environment-specific workspaces (dev/staging/prod)
4. Implement drift detection
5. Set up cost monitoring

---

**Note**: This setup provides a complete DevOps environment with infrastructure as code, CI/CD, monitoring, and application deployment all managed through Terraform Cloud.
