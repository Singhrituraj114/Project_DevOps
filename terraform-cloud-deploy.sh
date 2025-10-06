#!/bin/bash

# Terraform Cloud Quick Start Script for Online Book Bazaar
# This script automates the entire deployment process

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed. Please install Terraform CLI."
        exit 1
    fi
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_warning "AWS CLI not found. Make sure AWS credentials are configured in Terraform Cloud."
    fi
    
    # Check if logged into Terraform Cloud
    if ! terraform version | grep -q "Cloud"; then
        print_warning "Not logged into Terraform Cloud. Running 'terraform login'..."
        terraform login
    fi
    
    print_success "Prerequisites check completed"
}

# Initialize Terraform
init_terraform() {
    print_status "Initializing Terraform..."
    terraform init
    print_success "Terraform initialized"
}

# Plan infrastructure
plan_infrastructure() {
    print_status "Planning infrastructure deployment..."
    terraform plan -out=tfplan
    print_success "Infrastructure plan created"
}

# Apply infrastructure
apply_infrastructure() {
    print_status "Applying infrastructure..."
    terraform apply tfplan
    print_success "Infrastructure deployed successfully"
}

# Get instance IPs
get_instance_ips() {
    print_status "Retrieving instance IPs..."
    INSTANCE_IPS=$(terraform output -json instance_public_ips | jq -r '.[]' | tr '\n' ' ')
    echo "Instance IPs: $INSTANCE_IPS"
    return 0
}

# Wait for instances to be ready
wait_for_instances() {
    print_status "Waiting for instances to be ready..."
    
    for ip in $INSTANCE_IPS; do
        print_status "Checking connectivity to $ip..."
        
        # Wait up to 5 minutes for SSH to be ready
        timeout=300
        elapsed=0
        
        while [ $elapsed -lt $timeout ]; do
            if ssh -i team-key-mumbai.pem -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@$ip 'echo "SSH Ready"' 2>/dev/null; then
                print_success "Instance $ip is ready"
                break
            fi
            
            sleep 10
            elapsed=$((elapsed + 10))
            echo -n "."
        done
        
        if [ $elapsed -ge $timeout ]; then
            print_error "Instance $ip is not responding after 5 minutes"
            return 1
        fi
    done
    
    print_success "All instances are ready"
}

# Run DevOps setup
run_devops_setup() {
    print_status "Running DevOps setup on all instances..."
    
    # Make script executable
    chmod +x unified-devops-setup.sh
    
    # Run setup
    ./unified-devops-setup.sh $INSTANCE_IPS
    
    print_success "DevOps setup completed"
}

# Validate deployment
validate_deployment() {
    print_status "Validating deployment..."
    
    instance_array=($INSTANCE_IPS)
    
    # Check web application (Instance 1)
    if curl -s "http://${instance_array[0]}:3000" > /dev/null; then
        print_success "Book Bazaar application is accessible"
    else
        print_warning "Book Bazaar application may not be ready yet"
    fi
    
    # Check Jenkins (Instance 2)
    if curl -s "http://${instance_array[1]}:8080" > /dev/null; then
        print_success "Jenkins is accessible"
    else
        print_warning "Jenkins may not be ready yet"
    fi
    
    # Check Prometheus (Instance 3)
    if curl -s "http://${instance_array[2]}:9090" > /dev/null; then
        print_success "Prometheus is accessible"
    else
        print_warning "Prometheus may not be ready yet"
    fi
    
    # Check Grafana (Instance 3)
    if curl -s "http://${instance_array[2]}:3000" > /dev/null; then
        print_success "Grafana is accessible"
    else
        print_warning "Grafana may not be ready yet"
    fi
}

# Display access information
display_access_info() {
    print_status "Deployment completed! Access information:"
    
    instance_array=($INSTANCE_IPS)
    
    echo
    echo "🌐 Web Services:"
    echo "   Book Bazaar:  http://${instance_array[0]}:3000"
    echo "   Jenkins:      http://${instance_array[1]}:8080"
    echo "   Prometheus:   http://${instance_array[2]}:9090"
    echo "   Grafana:      http://${instance_array[2]}:3000"
    echo
    echo "🔑 Default Credentials:"
    echo "   Grafana: admin/admin"
    echo "   Jenkins: Check initial admin password on instance"
    echo
    echo "📊 Health Check:"
    echo "   curl http://${instance_array[0]}:3000/status"
    echo
    echo "🧹 Cleanup:"
    echo "   terraform destroy"
    echo
}

# Cleanup function
cleanup() {
    if [ -f "tfplan" ]; then
        rm tfplan
    fi
}

# Trap to cleanup on exit
trap cleanup EXIT

# Main execution
main() {
    echo "==========================================="
    echo "🚀 Terraform Cloud Deployment Script"
    echo "   Online Book Bazaar DevOps Environment"
    echo "==========================================="
    echo
    
    # Prompt for confirmation
    read -p "This will deploy infrastructure to AWS. Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Deployment cancelled"
        exit 0
    fi
    
    check_prerequisites
    init_terraform
    plan_infrastructure
    
    echo
    read -p "Review the plan above. Apply infrastructure? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Deployment cancelled"
        exit 0
    fi
    
    apply_infrastructure
    get_instance_ips
    wait_for_instances
    run_devops_setup
    
    # Wait a bit for services to start
    print_status "Waiting for services to start..."
    sleep 30
    
    validate_deployment
    display_access_info
    
    print_success "🎉 Deployment completed successfully!"
}

# Run main function
main "$@"
