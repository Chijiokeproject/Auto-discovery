#!/bin/bash
set -e

# Update and install dependencies
apt update -y
apt install -y openjdk-17-jdk unzip wget gnupg2 nginx

# Create a dedicated SonarQube user
useradd -m -d /opt/sonarqube -s /bin/bash sonar
echo 'sonar ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Download and install SonarQube
cd /opt
SONAR_VERSION="10.5.1.90531"
wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-${SONAR_VERSION}.zip
unzip sonarqube-${SONAR_VERSION}.zip
mv sonarqube-${SONAR_VERSION} sonarqube
chown -R sonar:sonar /opt/sonarqube

# Setup systemd service
cat <<EOF > /etc/systemd/system/sonarqube.service
[Unit]
Description=SonarQube service
After=syslog.target network.target

[Service]
Type=forking
ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
User=sonar
Group=sonar
Restart=always
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOF

# Enable and start SonarQube
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable sonarqube
systemctl start sonarqube
EOF
# Configure Nginx as reverse proxy
cat <<EONGINX > /etc/nginx/sites-available/sonarqube
server {
    listen 443 ssl;
    server_name sonar.${var.domain};

    ssl_certificate     /etc/ssl/certs/ssl-cert-snakeoil.pem;
    ssl_certificate_key /etc/ssl/private/ssl-cert-snakeoil.key;

    location / {
        proxy_pass http://127.0.0.1:9000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EONGINX

# Enable Nginx config
ln -s /etc/nginx/sites-available/sonarqube /etc/nginx/sites-enabled/sonarqube
rm /etc/nginx/sites-enabled/default
systemctl restart nginx
