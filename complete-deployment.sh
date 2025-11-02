# Complete EC2 deployment script
$EC2_IP = "44.251.54.141"
$KEY_FILE = "minizon-key.pem"

Write-Host "🚀 Completing Minizon E-commerce deployment..." -ForegroundColor Green
Write-Host "📍 EC2 Instance IP: $EC2_IP" -ForegroundColor Blue

# Step 1: Upload Docker image
Write-Host "📤 Uploading Docker image to EC2..." -ForegroundColor Yellow
scp -i $KEY_FILE -o StrictHostKeyChecking=no minizon-shop-spark.tar ec2-user@$EC2_IP:/opt/minizon/

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Docker image uploaded successfully!" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to upload Docker image" -ForegroundColor Red
    exit 1
}

# Step 2: Setup and start application
Write-Host "🔧 Setting up and starting application..." -ForegroundColor Yellow

$deployCommands = @"
#!/bin/bash
cd /opt/minizon

# Install Docker if not already installed
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -a -G docker ec2-user

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-\$(uname -s)-\$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Install Nginx
sudo yum install -y nginx
sudo systemctl start nginx
sudo systemctl enable nginx

# Create Docker Compose file
cat > docker-compose.yml << 'EOF'
version: '3.8'
services:
  minizon-frontend:
    image: minizon-shop-spark:latest
    ports:
      - "3000:80"
    environment:
      - NODE_ENV=production
    restart: unless-stopped
EOF

# Create Nginx configuration
sudo tee /etc/nginx/conf.d/minizon.conf > /dev/null << 'EOF'
server {
    listen 80;
    server_name _;
    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    location /health {
        proxy_pass http://localhost:3000/health;
        access_log off;
    }
}
EOF

# Load Docker image
docker load < minizon-shop-spark.tar

# Start application
docker-compose up -d

# Reload Nginx
sudo nginx -t && sudo systemctl reload nginx

# Wait for application to start
sleep 10

# Check if application is running
if curl -f http://localhost:3000/health; then
    echo "✅ Application is running!"
    echo "🌐 Website available at: http://$EC2_IP"
else
    echo "❌ Application failed to start"
    docker-compose logs
fi
"@

# Execute deployment commands
$deployCommands | ssh -i $KEY_FILE -o StrictHostKeyChecking=no ec2-user@$EC2_IP

Write-Host ""
Write-Host "🎉 Deployment completed!" -ForegroundColor Green
Write-Host "🌐 Your Minizon e-commerce website is now live at:" -ForegroundColor Cyan
Write-Host "   http://$EC2_IP" -ForegroundColor White
Write-Host "   http://$EC2_IP/health" -ForegroundColor White
