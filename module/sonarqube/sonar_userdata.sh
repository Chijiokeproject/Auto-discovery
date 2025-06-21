
#  install newrelic agent
curl -Ls https://download.newrelic.com/install/newrelic-cli/scipts/install.sh | bash && sudo NEW_RELIC_API_KEY="${nr_key}" NEW_RELIC_ACCOUNT_ID="${nr_acct_id}" NEW_RELIC_REGION=EU /usr/local/bin/newrelic install -y
sudo hostnamectl set-hostname sonarqube


#!/bin/bash
set -e

# === CONFIGURATION ===
SONAR_VERSION="10.5.1.90531"
SONAR_USER="sonaruser"
SONAR_DIR="/opt/sonarqube"
DB_USER="sonar"
DB_PASSWORD="StrongPassword123"
DB_NAME="sonarqube"
SONAR_ZIP="sonarqube-${SONAR_VERSION}.zip"
SONAR_URL="https://binaries.sonarsource.com/Distribution/sonarqube/${SONAR_ZIP}"

echo "Downloading SonarQube from: $SONAR_URL"
echo "Using zip file: $SONAR_ZIP"

# === INSTALL DEPENDENCIES ===
sudo apt update
sudo apt install -y openjdk-17-jdk unzip wget postgresql ufw nginx

# === CREATE SONAR SYSTEM USER WITHOUT LOGIN ===
if ! id "$SONAR_USER" &>/dev/null; then
  sudo useradd -r -s /bin/false "$SONAR_USER"
fi

# === DOWNLOAD AND EXTRACT SONARQUBE ===
cd /opt
sudo wget "$SONAR_URL"
sudo unzip "$SONAR_ZIP"
sudo mv "sonarqube-${SONAR_VERSION}" sonarqube
sudo chown -R "$SONAR_USER":"$SONAR_USER" "$SONAR_DIR"


# === CONFIGURE POSTGRESQL ===
sudo -u postgres psql <<EOF
CREATE USER $DB_USER WITH ENCRYPTED PASSWORD '${DB_PASSWORD}';
CREATE DATABASE $DB_NAME OWNER $DB_USER;
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
EOF

# === CONFIGURE sonar.properties ===
SONAR_PROP="$SONAR_DIR/conf/sonar.properties"
sudo sed -i "s|#sonar.jdbc.username=.*|sonar.jdbc.username=${DB_USER}|" "$SONAR_PROP"
sudo sed -i "s|#sonar.jdbc.password=.*|sonar.jdbc.password=${DB_PASSWORD}|" "$SONAR_PROP"
sudo sed -i "s|#sonar.jdbc.url=.*|sonar.jdbc.url=jdbc:postgresql://localhost/${DB_NAME}|" "$SONAR_PROP"

# === INCREASE FILE LIMITS ===
echo "$SONAR_USER soft nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "$SONAR_USER hard nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
sudo sysctl -w vm.max_map_count=262144

# === CREATE SYSTEMD SERVICE ===
sudo tee /etc/systemd/system/sonarqube.service > /dev/null <<EOF
[Unit]
Description=SonarQube service
After=syslog.target network.target postgresql.service

[Service]
Type=forking
ExecStart=$SONAR_DIR/bin/linux-x86-64/sonar.sh start
ExecStop=$SONAR_DIR/bin/linux-x86-64/sonar.sh stop
User=$SONAR_USER
Group=$SONAR_USER
LimitNOFILE=65536
LimitNPROC=4096
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# === OPEN FIREWALL PORT ===
sudo ufw allow 9000/tcp

# === ENABLE AND START SONARQUBE ===
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable sonarqube
sudo systemctl start sonarqube

echo "✅ SonarQube $SONAR_VERSION installed and running."

# ====== CONFIGURE NGINX ===========

# === Configure NGINX for SonarQube ===
sudo tee /etc/nginx/sites-available/sonarqube > /dev/null <<EOF
server {
    listen 80;
    server_name sonarqube.chijiokedevops.space;

    location / {
        proxy_pass http://localhost:9000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        client_max_body_size 100M;
    }

    access_log /var/log/nginx/sonarqube_access.log;
    error_log /var/log/nginx/sonarqube_error.log;
}
EOF

# Enable the site and restart NGINX
sudo ln -s /etc/nginx/sites-available/sonarqube /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl restart nginx

# === INSTALL NEW RELIC AGENT ===
curl -Ls https://download.newrelic.com/install/newrelic-cli/scripts/install.sh | bash
sudo NEW_RELIC_API_KEY="${nr_key}" \
     NEW_RELIC_ACCOUNT_ID="${nr_acct_id}" \
     NEW_RELIC_REGION="EU" \
     /usr/local/bin/newrelic install -y

# Set the hostname
sudo hostnamectl set-hostname sonarqube
