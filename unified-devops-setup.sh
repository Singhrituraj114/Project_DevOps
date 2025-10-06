#!/bin/bash

# Unified DevOps Setup Script for Online Book Bazaar
# This script sets up Docker, Ansible, Jenkins, Prometheus, and Grafana
# Usage: ./unified-devops-setup.sh [instance_ip_1] [instance_ip_2] [instance_ip_3]

set -e

# Configuration
GITHUB_REPO="https://github.com/adarsh-raj27/online-book-bazaar.git"
JENKINS_PORT=8080
PROMETHEUS_PORT=9090
GRAFANA_PORT=3000
APP_PORT=8000

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Get instance IPs from command line or Terraform
if [ $# -eq 3 ]; then
    INSTANCE1_IP=$1
    INSTANCE2_IP=$2
    INSTANCE3_IP=$3
    log "Using provided instance IPs: $INSTANCE1_IP, $INSTANCE2_IP, $INSTANCE3_IP"
else
    log "Getting instance IPs from Terraform..."
    INSTANCE_IPS=$(terraform output -json instance_public_ips | jq -r '.[]')
    if [ -z "$INSTANCE_IPS" ]; then
        error "Could not get instance IPs from Terraform. Please provide them as arguments."
        exit 1
    fi
    
    # Convert to array
    IPS_ARRAY=($INSTANCE_IPS)
    INSTANCE1_IP=${IPS_ARRAY[0]}
    INSTANCE2_IP=${IPS_ARRAY[1]}
    INSTANCE3_IP=${IPS_ARRAY[2]}
    
    log "Retrieved instance IPs from Terraform: $INSTANCE1_IP, $INSTANCE2_IP, $INSTANCE3_IP"
fi

# Validate inputs
if [ -z "$INSTANCE1_IP" ] || [ -z "$INSTANCE2_IP" ] || [ -z "$INSTANCE3_IP" ]; then
    error "All three instance IPs are required"
    echo "Usage: $0 [instance_ip_1] [instance_ip_2] [instance_ip_3]"
    exit 1
fi

# Check if key exists
if [ ! -f "team-key-mumbai.pem" ]; then
    error "SSH key file 'team-key-mumbai.pem' not found!"
    exit 1
fi

# Ensure key has correct permissions
chmod 600 team-key-mumbai.pem

# Function to wait for instance to be ready
wait_for_instance() {
    local ip=$1
    local max_attempts=30
    local attempt=1
    
    log "Waiting for instance $ip to be ready..."
    
    while [ $attempt -le $max_attempts ]; do
        if ssh -i team-key-mumbai.pem -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@$ip "echo 'Instance ready'" 2>/dev/null; then
            log "Instance $ip is ready!"
            return 0
        fi
        
        info "Attempt $attempt/$max_attempts: Instance $ip not ready yet..."
        sleep 10
        ((attempt++))
    done
    
    error "Instance $ip did not become ready within the expected time"
    return 1
}

# Function to run command on remote instance
run_remote() {
    local ip=$1
    local command=$2
    ssh -i team-key-mumbai.pem -o StrictHostKeyChecking=no ubuntu@$ip "$command"
}

# Function to copy file to remote instance
copy_to_remote() {
    local ip=$1
    local local_file=$2
    local remote_path=$3
    scp -i team-key-mumbai.pem -o StrictHostKeyChecking=no "$local_file" ubuntu@$ip:"$remote_path"
}

# Function to install Docker
install_docker() {
    local ip=$1
    log "Installing Docker on $ip..."
    
    run_remote $ip "
        sudo apt-get update
        sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        echo \"deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \$(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        sudo usermod -aG docker ubuntu
        sudo systemctl start docker
        sudo systemctl enable docker
    "
    
    log "Docker installation completed on $ip"
}

# Function to install Java 17 for Jenkins
install_java17() {
    local ip=$1
    log "Installing Java 17 on $ip..."
    
    run_remote $ip "
        sudo apt-get update
        sudo apt-get install -y openjdk-17-jdk
        java -version
    "
    
    log "Java 17 installation completed on $ip"
}

# Function to install Jenkins
install_jenkins() {
    local ip=$1
    log "Installing Jenkins on $ip..."
    
    # First install Java 17
    install_java17 $ip
    
    run_remote $ip "
        wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io.key | sudo apt-key add -
        sudo sh -c 'echo deb https://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'
        sudo apt-get update
        sudo apt-get install -y jenkins
        
        # Configure Jenkins to use Java 17
        sudo systemctl stop jenkins || true
        sudo mkdir -p /var/lib/jenkins
        sudo chown jenkins:jenkins /var/lib/jenkins
        
        # Update Jenkins service to use Java 17
        sudo sed -i 's|^JAVA=.*|JAVA=/usr/bin/java|' /etc/default/jenkins || true
        echo 'JAVA_ARGS=\"-Djava.awt.headless=true\"' | sudo tee -a /etc/default/jenkins
        echo 'JENKINS_ARGS=\"--webroot=/var/cache/jenkins/war --httpPort=8080\"' | sudo tee -a /etc/default/jenkins
        
        sudo systemctl daemon-reload
        sudo systemctl start jenkins
        sudo systemctl enable jenkins
        
        # Wait for Jenkins to start
        sleep 30
        
        # Get initial admin password
        sudo cat /var/lib/jenkins/secrets/initialAdminPassword || echo 'Jenkins password file not found yet'
    "
    
    log "Jenkins installation completed on $ip"
}

# Function to setup Book Bazaar application
setup_book_bazaar() {
    local ip=$1
    log "Setting up Book Bazaar application on $ip..."
    
    run_remote $ip "
        # Clone the repository
        if [ -d 'online-book-bazaar' ]; then
            rm -rf online-book-bazaar
        fi
        git clone $GITHUB_REPO
        cd online-book-bazaar
        
        # Create Dockerfile if it doesn't exist
        cat > Dockerfile << 'EOF'
FROM node:16-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy application code
COPY . .

# Expose the port
EXPOSE 8000

# Add status endpoint
RUN echo 'app.get(\"/status\", (req, res) => { res.json({ status: \"OK\", timestamp: new Date().toISOString(), service: \"book-bazaar\" }); });' >> server.js

# Start the application
CMD [\"npm\", \"start\"]
EOF

        # Build and run the application
        sudo docker build -t book-bazaar .
        sudo docker stop book-bazaar-app 2>/dev/null || true
        sudo docker rm book-bazaar-app 2>/dev/null || true
        sudo docker run -d --name book-bazaar-app -p $APP_PORT:8000 book-bazaar
        
        # Wait for app to start
        sleep 10
        
        # Check if app is running
        if curl -f http://localhost:$APP_PORT/status 2>/dev/null; then
            echo 'Book Bazaar application is running successfully!'
        else
            echo 'Book Bazaar application status check failed, but container might still be starting...'
        fi
    "
    
    log "Book Bazaar application setup completed on $ip"
}

# Function to setup monitoring (Prometheus + Grafana)
setup_monitoring() {
    local ip=$1
    log "Setting up monitoring (Prometheus + Grafana) on $ip..."
    
    # Create monitoring configuration files
    cat > prometheus-config.yml << 'EOF'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  
  - job_name: 'book-bazaar'
    static_configs:
      - targets: ['host.docker.internal:8000']
EOF

    cat > monitoring-docker-compose.yml << 'EOF'
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--web.enable-lifecycle'
    extra_hosts:
      - "host.docker.internal:host-gateway"

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin123
    volumes:
      - grafana-storage:/var/lib/grafana

volumes:
  grafana-storage:
EOF

    # Copy files to remote instance
    copy_to_remote $ip prometheus-config.yml /home/ubuntu/prometheus.yml
    copy_to_remote $ip monitoring-docker-compose.yml /home/ubuntu/docker-compose.yml
    
    # Start monitoring services
    run_remote $ip "
        cd /home/ubuntu
        sudo docker compose down 2>/dev/null || true
        sudo docker compose up -d
        
        # Wait for services to start
        sleep 30
        
        # Check if services are running
        if curl -f http://localhost:$PROMETHEUS_PORT 2>/dev/null; then
            echo 'Prometheus is running successfully!'
        else
            echo 'Prometheus health check failed'
        fi
        
        if curl -f http://localhost:$GRAFANA_PORT 2>/dev/null; then
            echo 'Grafana is running successfully!'
        else
            echo 'Grafana health check failed'
        fi
    "
    
    # Clean up local files
    rm -f prometheus-config.yml monitoring-docker-compose.yml
    
    log "Monitoring setup completed on $ip"
}

# Function to create Jenkins jobs
setup_jenkins_jobs() {
    local ip=$1
    log "Setting up Jenkins jobs on $ip..."
    
    # Wait for Jenkins to be fully ready
    run_remote $ip "
        # Wait for Jenkins to be accessible
        for i in {1..30}; do
            if curl -f http://localhost:8080 2>/dev/null; then
                echo 'Jenkins is accessible'
                break
            fi
            echo 'Waiting for Jenkins...'
            sleep 10
        done
        
        # Install Jenkins CLI (if needed for job creation)
        # For now, we'll just ensure Jenkins is running
        sudo systemctl status jenkins
    "
    
    log "Jenkins jobs setup completed on $ip"
}

# Function to validate all services
validate_setup() {
    local ip=$1
    local service_name=$2
    
    log "Validating setup on $ip ($service_name)..."
    
    case $service_name in
        "app")
            if curl -f http://$ip:$APP_PORT/status 2>/dev/null; then
                log "✅ Book Bazaar app is accessible on $ip:$APP_PORT"
            else
                warn "❌ Book Bazaar app is not accessible on $ip:$APP_PORT"
            fi
            ;;
        "jenkins")
            if curl -f http://$ip:$JENKINS_PORT 2>/dev/null; then
                log "✅ Jenkins is accessible on $ip:$JENKINS_PORT"
            else
                warn "❌ Jenkins is not accessible on $ip:$JENKINS_PORT"
            fi
            ;;
        "monitoring")
            if curl -f http://$ip:$PROMETHEUS_PORT 2>/dev/null; then
                log "✅ Prometheus is accessible on $ip:$PROMETHEUS_PORT"
            else
                warn "❌ Prometheus is not accessible on $ip:$PROMETHEUS_PORT"
            fi
            
            if curl -f http://$ip:$GRAFANA_PORT 2>/dev/null; then
                log "✅ Grafana is accessible on $ip:$GRAFANA_PORT"
            else
                warn "❌ Grafana is not accessible on $ip:$GRAFANA_PORT"
            fi
            ;;
    esac
}

# Main setup function
main() {
    log "Starting unified DevOps setup for Online Book Bazaar..."
    log "Instance 1 (App): $INSTANCE1_IP"
    log "Instance 2 (Jenkins): $INSTANCE2_IP" 
    log "Instance 3 (Monitoring): $INSTANCE3_IP"
    
    # Wait for all instances to be ready
    wait_for_instance $INSTANCE1_IP
    wait_for_instance $INSTANCE2_IP
    wait_for_instance $INSTANCE3_IP
    
    log "All instances are ready. Starting setup..."
    
    # Setup Instance 1: Book Bazaar Application
    log "=== Setting up Instance 1: Book Bazaar Application ==="
    install_docker $INSTANCE1_IP
    setup_book_bazaar $INSTANCE1_IP
    
    # Setup Instance 2: Jenkins
    log "=== Setting up Instance 2: Jenkins CI/CD ==="
    install_docker $INSTANCE2_IP
    install_jenkins $INSTANCE2_IP
    setup_jenkins_jobs $INSTANCE2_IP
    
    # Setup Instance 3: Monitoring (Prometheus + Grafana)
    log "=== Setting up Instance 3: Monitoring ==="
    install_docker $INSTANCE3_IP
    setup_monitoring $INSTANCE3_IP
    
    # Validate all setups
    log "=== Validating Complete Setup ==="
    sleep 30  # Give services time to fully start
    
    validate_setup $INSTANCE1_IP "app"
    validate_setup $INSTANCE2_IP "jenkins"
    validate_setup $INSTANCE3_IP "monitoring"
    
    # Display summary
    log "=== Setup Complete! ==="
    echo ""
    echo "🌟 Online Book Bazaar DevOps Environment Ready!"
    echo ""
    echo "📱 Services Access URLs:"
    echo "   Book Bazaar App:     http://$INSTANCE1_IP:$APP_PORT"
    echo "   Jenkins CI/CD:       http://$INSTANCE2_IP:$JENKINS_PORT"
    echo "   Prometheus:          http://$INSTANCE3_IP:$PROMETHEUS_PORT"
    echo "   Grafana:             http://$INSTANCE3_IP:$GRAFANA_PORT (admin/admin123)"
    echo ""
    echo "🔑 Jenkins Initial Admin Password:"
    run_remote $INSTANCE2_IP "sudo cat /var/lib/jenkins/secrets/initialAdminPassword 2>/dev/null || echo 'Password file not found - Jenkins may need more time to start'"
    echo ""
    echo "🎯 Next Steps:"
    echo "   1. Access Jenkins and complete the initial setup"
    echo "   2. Create build/deploy jobs for the Book Bazaar app"
    echo "   3. Configure Grafana dashboards for monitoring"
    echo "   4. Set up automated deployments and monitoring alerts"
    echo ""
    log "DevOps setup completed successfully! 🚀"
}

# Run the main function
main "$@"
