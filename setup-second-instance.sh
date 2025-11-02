# PowerShell Script to Setup Second Instance

# Set variables
$OLD_INSTANCE = "13.55.222.52"
$NEW_INSTANCE = "3.26.146.192"
$KEY_PATH = "D:\Work\Projects\Personal\minizon\project1.pem"

Write-Host "🚀 Setting up second instance..." -ForegroundColor Green

# Step 1: Get Docker image from old instance
Write-Host "📥 Downloading Docker image from old instance..." -ForegroundColor Yellow
ssh -i $KEY_PATH ec2-user@$OLD_INSTANCE "docker save minizon-shop-spark:latest > /tmp/minizon-shop-spark.tar"

# Step 2: Upload to new instance
Write-Host "📤 Uploading to new instance..." -ForegroundColor Yellow
scp -i $KEY_PATH ec2-user@$OLD_INSTANCE:/tmp/minizon-shop-spark.tar minizon-shop-spark.tar
scp -i $KEY_PATH minizon-shop-spark.tar ec2-user@$NEW_INSTANCE:/home/ec2-user/

# Step 3: Setup Docker and load image on new instance
Write-Host "🔧 Setting up new instance..." -ForegroundColor Yellow
$setupScript = @"
# Install Docker
sudo yum update -y
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -a -G docker ec2-user

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-Linux-x86_64" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Setup directories
sudo mkdir -p /opt/minizon
sudo chown ec2-user:ec2-user /opt/minizon

# Create docker-compose file
cd /opt/minizon
cat > docker-compose.yml << 'EOF'
version: '3.8'
services:
  minizon-frontend:
    image: minizon-shop-spark:latest
    ports:
      - "3000:80"
    restart: unless-stopped
EOF

# Load and start
docker load < ~/minizon-shop-spark.tar
docker-compose up -d

# Setup monitoring
mkdir -p ~/monitoring
cd ~/monitoring
cat > docker-compose.yml << 'EOF'
services:
  prometheus:
    image: prom/prometheus:latest
    ports: ["9090:9090"]
    volumes: [prometheus_data:/prometheus]
    restart: unless-stopped
  grafana:
    image: grafana/grafana:latest
    ports: ["3001:3000"]
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin123
    restart: unless-stopped
  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    ports: ["8080:8080"]
    privileged: true
    restart: unless-stopped
  node-exporter:
    image: prom/node-exporter:latest
    ports: ["9100:9100"]
    restart: unless-stopped
volumes:
  prometheus_data:
EOF
docker-compose up -d

# Start Jenkins
docker run -d --name jenkins \
  -p 8081:8080 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --restart unless-stopped \
  jenkins/jenkins:lts

sleep 30
docker ps
curl http://localhost:3000/health

echo "✅ Setup complete on new instance!"
"@

$setupScript | ssh -i $KEY_PATH ec2-user@$NEW_INSTANCE

Write-Host ""
Write-Host "🎉 Setup complete!" -ForegroundColor Green
Write-Host "📍 New Instance URL: http://$NEW_INSTANCE:3000" -ForegroundColor Cyan
Write-Host "📊 Grafana: http://$NEW_INSTANCE:3001" -ForegroundColor Cyan
Write-Host "🔧 Jenkins: http://$NEW_INSTANCE:8081" -ForegroundColor Cyan
