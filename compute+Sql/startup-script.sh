#!/bin/bash
set -e

# Install necessary packages
apt-get update
apt-get install -y apache2 php php-mysql

# Install the Cloud SQL proxy
wget https://dl.google.com/cloudsql/cloud_sql_proxy.linux.amd64 -O /usr/local/bin/cloud_sql_proxy
chmod +x /usr/local/bin/cloud_sql_proxy

# Create a systemd service for the Cloud SQL proxy
cat << EOF > /etc/systemd/system/cloud-sql-proxy.service
[Unit]
Description=Cloud SQL Proxy
After=network.target

[Service]
ExecStart=/usr/local/bin/cloud_sql_proxy -instances=${cloudsql_connection_name}=tcp:3306
Restart=always
User=nobody

[Install]
WantedBy=multi-user.target
EOF

# Start and enable the Cloud SQL proxy service
systemctl enable cloud-sql-proxy
systemctl start cloud-sql-proxy

# Download and configure WordPress
cd /var/www/html
rm index.html
wget https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz
mv wordpress/* .
rmdir wordpress
rm latest.tar.gz

# Set up wp-config.php
cp wp-config-sample.php wp-config.php
sed -i "s/database_name_here/wordpress/" wp-config.php
sed -i "s/username_here/wordpress/" wp-config.php
sed -i "s/password_here/${db_password}/" wp-config.php
sed -i "s/localhost/127.0.0.1/" wp-config.php

# Set correct permissions
chown -R www-data:www-data /var/www/html

# Restart Apache
systemctl restart apache2
Last edited 2 minutes ago