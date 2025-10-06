# 🚀 Online Book Bazaar - Unified DevOps Setup

This repository contains a **single, comprehensive script** that automates the complete DevOps setup for the Online Book Bazaar project.

## 🎯 What This Script Does

The `unified-devops-setup.sh` script is a **one-stop solution** that:

1. **🏗️ Infrastructure**: Sets up AWS EC2 instances using Terraform
2. **🔒 Security**: Configures security groups with all required ports
3. **🐳 Containerization**: Installs Docker and Docker Compose
4. **🔄 CI/CD**: Sets up Jenkins with Java 17 and automated jobs
5. **📊 Monitoring**: Deploys Prometheus and Grafana
6. **🔧 Configuration**: Installs and configures Ansible
7. **🌐 Application**: Deploys your Book Bazaar website
8. **✅ Testing**: Validates all services are working
9. **📋 Documentation**: Generates complete access guides

## 🚀 Quick Start

### Prerequisites
- AWS CLI configured (`aws configure`)
- Terraform installed
- SSH key file: `team-key-mumbai.pem` in current directory
- GitHub repository with your Book Bazaar code

### Run the Setup
```bash
# Clone this repository
git clone <your-repo-url>
cd online-book-bazaar-infra

# Run the unified setup script
./unified-devops-setup.sh
```

That's it! The script will:
- Guide you through the setup with prompts
- Ask for your GitHub repository URL
- Deploy everything automatically
- Provide you with all access URLs and credentials

## 📋 What You'll Get

After running the script, you'll have:

### 🌐 Live Services
- **Book Bazaar App**: `http://INSTANCE1_IP:3000`
- **Jenkins CI/CD**: `http://INSTANCE1_IP:8080`
- **Prometheus**: `http://INSTANCE2_IP:9090`
- **Grafana**: `http://INSTANCE2_IP:3001`

### 🔧 Automated Features
- ✅ Continuous Integration/Deployment pipeline
- ✅ Application monitoring and metrics
- ✅ Infrastructure as Code (Terraform)
- ✅ Container orchestration (Docker)
- ✅ Configuration management (Ansible)

### 📊 Monitoring Dashboard
- Real-time application metrics
- System performance monitoring
- Custom Grafana dashboards
- Prometheus alerts

## 🔐 Default Credentials

The script generates a `DEPLOYMENT_SUMMARY.md` file with all credentials and access information.

## 🧹 Repository Cleanup

This unified script **replaces all previous scripts**. The old scripts are automatically moved to an `archive/` folder to keep the repository clean and maintainable.

## 🛠️ Troubleshooting

If any service isn't working:

1. **Check the deployment summary**: `cat DEPLOYMENT_SUMMARY.md`
2. **Re-run the script**: It's designed to be idempotent
3. **Check individual services**: SSH instructions are in the summary

## 🗑️ Cleanup

To remove all AWS resources when done:
```bash
terraform destroy
```

## 📁 Project Structure

```
online-book-bazaar-infra/
├── unified-devops-setup.sh    # 🎯 THE ONLY SCRIPT YOU NEED
├── main.tf                    # Terraform infrastructure
├── variables.tf               # Terraform variables
├── outputs.tf                 # Terraform outputs
├── team-key-mumbai.pem       # SSH key (you provide this)
├── DEPLOYMENT_SUMMARY.md     # Generated after setup
└── archive/                  # Old scripts (auto-archived)
```

## 🎥 Demo Ready

This setup is perfect for:
- ✅ Live demonstrations
- ✅ Educational presentations
- ✅ Production deployments
- ✅ DevOps portfolio projects

---

**🚀 One script, complete DevOps setup. It's that simple!**
