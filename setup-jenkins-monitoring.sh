# Jenkins + Monitoring Deployment Script for Minizon E-commerce
# This script sets up Jenkins CI/CD and Grafana/Prometheus monitoring

param(
    [string]$EC2_IP = "3.27.83.16",
    [string]$KEY_PATH = "D:\Work\Projects\Personal\minizon\project1.pem"
)

Write-Host "🚀 Setting up Jenkins + Monitoring for Minizon E-commerce" -ForegroundColor Green
Write-Host "📍 EC2 Instance: $EC2_IP" -ForegroundColor Blue

# Function to execute SSH commands
function Invoke-SSHCommand {
    param([string]$Command)
    ssh -i $KEY_PATH -o StrictHostKeyChecking=no ec2-user@$EC2_IP $Command
}

# Function to upload files
function Upload-File {
    param([string]$LocalPath, [string]$RemotePath)
    scp -i $KEY_PATH -o StrictHostKeyChecking=no $LocalPath ec2-user@$EC2_IP:$RemotePath
}

try {
    Write-Host "📦 Installing Jenkins..." -ForegroundColor Yellow
    
    # Install Java and Jenkins
    $jenkinsSetup = @"
sudo yum update -y
sudo yum install -y java-11-amazon-corretto-headless

# Add Jenkins repository
sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

# Install Jenkins
sudo yum install -y jenkins

# Start Jenkins
sudo systemctl start jenkins
sudo systemctl enable jenkins

# Add ec2-user to docker group
sudo usermod -a -G docker ec2-user

echo "Jenkins installation complete!"
"@

    $jenkinsSetup | ssh -i $KEY_PATH -o StrictHostKeyChecking=no ec2-user@$EC2_IP

    Write-Host "✅ Jenkins installed successfully!" -ForegroundColor Green

    Write-Host "📊 Setting up monitoring stack..." -ForegroundColor Yellow
    
    # Upload monitoring files
    Upload-File "monitoring/docker-compose.yml" "/home/ec2-user/monitoring/"
    Upload-File "monitoring/prometheus.yml" "/home/ec2-user/monitoring/"
    Upload-File "monitoring/grafana/datasources/prometheus.yml" "/home/ec2-user/monitoring/grafana/datasources/"
    Upload-File "monitoring/grafana/dashboards/dashboard.yml" "/home/ec2-user/monitoring/grafana/dashboards/"

    # Deploy monitoring stack
    $monitoringSetup = @"
cd /home/ec2-user/monitoring
docker-compose up -d
echo "Monitoring stack deployed!"
"@

    $monitoringSetup | ssh -i $KEY_PATH -o StrictHostKeyChecking=no ec2-user@$EC2_IP

    Write-Host "✅ Monitoring stack deployed successfully!" -ForegroundColor Green

    Write-Host "🔧 Configuring Jenkins..." -ForegroundColor Yellow
    
    # Wait for Jenkins to start
    Start-Sleep -Seconds 30
    
    # Get Jenkins initial password
    $jenkinsPassword = Invoke-SSHCommand "sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
    
    Write-Host ""
    Write-Host "🎉 Setup Complete!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📋 Access Information:" -ForegroundColor Cyan
    Write-Host "🌐 Jenkins: http://$EC2_IP`:8080" -ForegroundColor White
    Write-Host "🔑 Jenkins Password: $jenkinsPassword" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "📊 Monitoring:" -ForegroundColor Cyan
    Write-Host "📈 Prometheus: http://$EC2_IP`:9090" -ForegroundColor White
    Write-Host "📊 Grafana: http://$EC2_IP`:3001 (admin/admin123)" -ForegroundColor White
    Write-Host ""
    Write-Host "🎯 Your Minizon E-commerce Application:" -ForegroundColor Cyan
    Write-Host "🌐 Main Site: http://$EC2_IP" -ForegroundColor White
    Write-Host "🏥 Health Check: http://$EC2_IP/health" -ForegroundColor White
    Write-Host ""
    Write-Host "📋 Next Steps:" -ForegroundColor Yellow
    Write-Host "1. Access Jenkins and complete initial setup" -ForegroundColor White
    Write-Host "2. Install suggested plugins" -ForegroundColor White
    Write-Host "3. Create new Pipeline job" -ForegroundColor White
    Write-Host "4. Use the Jenkinsfile from your repository" -ForegroundColor White
    Write-Host "5. Configure GitHub webhook for automatic builds" -ForegroundColor White

} catch {
    Write-Host "❌ Error during setup: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
