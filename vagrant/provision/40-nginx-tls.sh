#!/usr/bin/env bash
set -euxo pipefail
source /vagrant/provision/common.sh
echo "=== 40: nginx + TLS (mode: $TLS_MODE) ==="

apt-get update
apt-get install -y --no-install-recommends nginx apache2-utils

SSL_DIR=/etc/nginx/ssl
install -d -m 750 "$SSL_DIR"

case "$TLS_MODE" in
  mkcert)
    
    apt-get install -y --no-install-recommends mkcert libnss3-tools
    export CAROOT=/root/.local/share/mkcert
    CERT="$SSL_DIR/$DOMAIN.pem"; KEY="$SSL_DIR/$DOMAIN-key.pem"
    if [ ! -f "$CERT" ]; then
      mkcert -cert-file "$CERT" -key-file "$KEY" "$DOMAIN" localhost 127.0.0.1 ::1
      chmod 600 "$KEY"
    fi
    install -d /vagrant/certs
    install -m 644 "$CAROOT/rootCA.pem" /vagrant/certs/rootCA.pem
    ;;
  letsencrypt)
    
    : "${ACME_EMAIL:?set ACME_EMAIL}" "${CF_API_TOKEN:?set CF_API_TOKEN}"
    apt-get install -y --no-install-recommends certbot python3-certbot-dns-cloudflare
    install -d -m 700 /root/.secrets
    echo "dns_cloudflare_api_token = $CF_API_TOKEN" > /root/.secrets/cloudflare.ini
    chmod 600 /root/.secrets/cloudflare.ini
    certbot certonly --dns-cloudflare \
      --dns-cloudflare-credentials /root/.secrets/cloudflare.ini \
      --dns-cloudflare-propagation-seconds 30 \
      -d "$DOMAIN" -m "$ACME_EMAIL" --agree-tos --non-interactive --keep-until-expiring
    CERT="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
    KEY="/etc/letsencrypt/live/$DOMAIN/privkey.pem"
    install -d /etc/letsencrypt/renewal-hooks/deploy
    printf '#!/bin/sh\nsystemctl reload nginx\n' > /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh
    chmod +x /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh
    ;;
  *) echo "Unknown TLS_MODE: $TLS_MODE"; exit 1 ;;
esac

ADMIN_PASS=$(ensure_cred admin_password 12)
htpasswd -bc /etc/nginx/.htpasswd admin "$ADMIN_PASS"
chown root:www-data /etc/nginx/.htpasswd; chmod 640 /etc/nginx/.htpasswd

sed -e "s|__DOMAIN__|$DOMAIN|g" -e "s|__CERT__|$CERT|g" -e "s|__KEY__|$KEY|g" \
  "$SRC_CONF/nginx/myapp.conf.tpl" > /etc/nginx/sites-available/myapp
ln -sf /etc/nginx/sites-available/myapp /etc/nginx/sites-enabled/myapp
rm -f /etc/nginx/sites-enabled/default

cat > /etc/fail2ban/jail.d/nginx.local <<'EOF'
[nginx-http-auth]
enabled  = true
port     = http,https
logpath  = /var/log/nginx/error.log
maxretry = 5
bantime  = 1h
EOF

nginx -t
systemctl enable nginx
systemctl restart nginx
systemctl restart fail2ban

echo "=== 40 DONE ==="