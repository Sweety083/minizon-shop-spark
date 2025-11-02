# Simple EC2 deployment script
$EC2_IP = "44.251.54.141"
$KEY_FILE = "minizon-key.pem"

Write-Host "🚀 Deploying Minizon E-commerce to EC2..." -ForegroundColor Green
Write-Host "📍 EC2 Instance IP: $EC2_IP" -ForegroundColor Blue

# Wait for SSH to be available
Write-Host "⏳ Waiting for SSH to be available..." -ForegroundColor Yellow
do {
    try {
        $result = Test-NetConnection -ComputerName $EC2_IP -Port 22 -InformationLevel Quiet
        if ($result) {
            Write-Host "✅ SSH is available!" -ForegroundColor Green
            break
        }
    }
    catch {
        Write-Host "⏳ Still waiting for SSH..." -ForegroundColor Yellow
    }
    Start-Sleep -Seconds 10
} while ($true)

# Execute setup commands on EC2
Write-Host "🔧 Setting up EC2 instance..." -ForegroundColor Blue

# Create setup script
$setupScript = @"
#!/bin/bash
sudo yum update -y
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -a -G docker ec2-user

sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-\$(uname -s)-\$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

sudo yum install -y nginx
sudo systemctl start nginx
sudo systemctl enable nginx

mkdir -p /opt/minizon
cd /opt/minizon

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

sudo tee /etc/nginx/conf.d/minizon.conf > /dev/null << 'EOF'
server {
    listen 80;
    server_name _;
    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

sudo nginx -t
sudo systemctl reload nginx

echo "Setup complete!"
"@

# Execute the setup script
$setupScript | ssh -i $KEY_FILE -o StrictHostKeyChecking=no ec2-user@$EC2_IP

Write-Host ""
Write-Host "🎉 EC2 instance setup complete!" -ForegroundColor Green
Write-Host "📍 Your Minizon e-commerce website will be available at: http://$EC2_IP" -ForegroundColor Cyan
Write-Host ""
Write-Host "📋 Manual steps to complete deployment:" -ForegroundColor Yellow
Write-Host "1. Upload Docker image:" -ForegroundColor White
Write-Host "   scp -i $KEY_FILE minizon-shop-spark.tar ec2-user@${EC2_IP}:/opt/minizon/" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Load and start application:" -ForegroundColor White
Write-Host "   ssh -i $KEY_FILE ec2-user@${EC2_IP} 'cd /opt/minizon; docker load < minizon-shop-spark.tar; docker-compose up -d'" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Test your application:" -ForegroundColor White
Write-Host "   http://$EC2_IP" -ForegroundColor Cyan
Write-Host "   http://$EC2_IP/health" -ForegroundColor Cyan
