# Template: __DOMAIN__, __CERT__, __KEY__ are replaced by 40-nginx-tls.sh
map $http_upgrade $connection_upgrade { default upgrade; '' close; }

limit_req_zone $binary_remote_addr zone=app:10m rate=10r/s;

upstream puma {
  server 127.0.0.1:3000;
  keepalive 16;
}

server {
  listen 80 default_server;
  server_name _;
  return 301 https://$host$request_uri;
}

server {
  listen 443 ssl http2;
  server_name __DOMAIN__;

  ssl_certificate     __CERT__;
  ssl_certificate_key __KEY__;
  ssl_protocols TLSv1.2 TLSv1.3;
  ssl_session_cache shared:SSL:10m;
  ssl_session_timeout 1d;
  ssl_session_tickets off;

  server_tokens off;
  add_header Strict-Transport-Security "max-age=63072000" always;
  add_header X-Content-Type-Options nosniff always;
  add_header X-Frame-Options SAMEORIGIN always;
  add_header Referrer-Policy strict-origin-when-cross-origin always;

  gzip on;
  gzip_types text/css application/javascript application/json image/svg+xml;
  client_max_body_size 20m;

  access_log /var/log/nginx/myapp.access.log;
  error_log  /var/log/nginx/error.log;

  root /var/www/myapp/public;

  # Static files straight from nginx, everything else to Puma
  location / { try_files $uri @puma; }

  location @puma {
    limit_req zone=app burst=20 nodelay;
    proxy_pass http://puma;
    proxy_http_version 1.1;
    proxy_set_header Connection "";
    proxy_set_header Host $http_host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto https;
  }

  # Grafana (has its own login)
  location /grafana/ {
    proxy_pass http://127.0.0.1:3001;
    proxy_http_version 1.1;
    proxy_set_header Host $http_host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto https;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $connection_upgrade;
  }

  # Prometheus UI behind HTTP basic auth
  location /prometheus/ {
    auth_basic "Prometheus";
    auth_basic_user_file /etc/nginx/.htpasswd;
    proxy_pass http://127.0.0.1:9090;
    proxy_set_header Host $http_host;
  }
}

# Internal only: consumed by the nginx exporter
server {
  listen 127.0.0.1:8081;
  location = /stub_status {
    stub_status;
    allow 127.0.0.1;
    deny all;
  }
}
