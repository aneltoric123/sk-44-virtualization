#!/usr/bin/env bash
set -euxo pipefail
source /vagrant/provision/common.sh
echo "=== 50: monitoring and logging ==="


install -d -m 755 /etc/apt/keyrings
if [ ! -f /etc/apt/keyrings/grafana.gpg ]; then
  curl -fsSL https://apt.grafana.com/gpg.key | gpg --dearmor -o /etc/apt/keyrings/grafana.gpg
fi
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" \
  > /etc/apt/sources.list.d/grafana.list

apt-get update
apt-get install -y \
  prometheus prometheus-node-exporter prometheus-postgres-exporter \
  prometheus-redis-exporter prometheus-nginx-exporter \
  grafana loki alloy

REDIS_PASS=$(env_get REDIS_PASSWORD)
ADMIN_PASS=$(cred_get admin_password)


echo 'ARGS="--web.listen-address=127.0.0.1:9100"' > /etc/default/prometheus-node-exporter

cat > /etc/default/prometheus-postgres-exporter <<'EOF'
DATA_SOURCE_NAME='user=postgres host=/run/postgresql dbname=postgres'
ARGS="--web.listen-address=127.0.0.1:9187"
EOF

echo "ARGS=\"--redis.addr=redis://127.0.0.1:6379 --redis.password=$REDIS_PASS --web.listen-address=127.0.0.1:9121\"" \
  > /etc/default/prometheus-redis-exporter
chown root:prometheus /etc/default/prometheus-redis-exporter
chmod 640 /etc/default/prometheus-redis-exporter

echo 'ARGS="--nginx.scrape-uri=http://127.0.0.1:8081/stub_status --web.listen-address=127.0.0.1:9113"' \
  > /etc/default/prometheus-nginx-exporter

cp "$SRC_CONF/prometheus/prometheus.yml" /etc/prometheus/prometheus.yml
cat > /etc/default/prometheus <<'EOF'
ARGS="--web.listen-address=127.0.0.1:9090 --web.external-url=/prometheus/ --web.route-prefix=/prometheus/ --storage.tsdb.retention.time=7d"
EOF


cp "$SRC_CONF/loki/config.yml" /etc/loki/config.yml
LOKI_USER=$(systemctl show -p User --value loki)
LOKI_USER=${LOKI_USER:-root}
install -d /var/lib/loki
chown -R "$LOKI_USER:$(id -gn "$LOKI_USER")" /var/lib/loki

cp "$SRC_CONF/alloy/config.alloy" /etc/alloy/config.alloy
ALLOY_USER=$(systemctl show -p User --value alloy)
ALLOY_USER=${ALLOY_USER:-root}
[ "$ALLOY_USER" = root ] || usermod -aG adm,systemd-journal "$ALLOY_USER"


PORT_SUFFIX=""; [ "$PUBLIC_HTTPS_PORT" = "443" ] || PORT_SUFFIX=":$PUBLIC_HTTPS_PORT"
install -d /etc/systemd/system/grafana-server.service.d
cat > /etc/systemd/system/grafana-server.service.d/override.conf <<'EOF'
[Service]
EnvironmentFile=/etc/myapp/grafana.env
EOF
cat > /etc/myapp/grafana.env <<EOF
GF_SERVER_HTTP_ADDR=127.0.0.1
GF_SERVER_HTTP_PORT=3001
GF_SERVER_DOMAIN=$DOMAIN
GF_SERVER_ROOT_URL=https://$DOMAIN$PORT_SUFFIX/grafana/
GF_SERVER_SERVE_FROM_SUB_PATH=true
GF_SECURITY_ADMIN_USER=admin
GF_SECURITY_ADMIN_PASSWORD=$ADMIN_PASS
GF_SECURITY_COOKIE_SECURE=true
GF_USERS_ALLOW_SIGN_UP=false
GF_AUTH_ANONYMOUS_ENABLED=false
GF_ANALYTICS_REPORTING_ENABLED=false
GF_ANALYTICS_CHECK_FOR_UPDATES=false
EOF
chmod 600 /etc/myapp/grafana.env

cp "$SRC_CONF/grafana/datasources.yml" /etc/grafana/provisioning/datasources/myapp.yml
cp "$SRC_CONF/grafana/dashboards.yml"  /etc/grafana/provisioning/dashboards/myapp.yml

# Community dashboards: Node Exporter Full, PostgreSQL, Redis (best effort)
install -d -o grafana -g grafana /var/lib/grafana/dashboards
for d in 1860:node 9628:postgres 11835:redis; do
  id=${d%%:*}; name=${d##*:}
  curl -fsSL "https://grafana.com/api/dashboards/$id/revisions/latest/download" \
    | sed 's/${DS_PROMETHEUS}/prometheus/g' > /var/lib/grafana/dashboards/$name.json \
    || echo "WARN: could not download dashboard $id"
done
chown -R grafana:grafana /var/lib/grafana/dashboards

systemctl daemon-reload
systemctl enable prometheus prometheus-node-exporter prometheus-postgres-exporter \
  prometheus-redis-exporter prometheus-nginx-exporter grafana-server loki alloy
systemctl restart prometheus prometheus-node-exporter prometheus-postgres-exporter \
  prometheus-redis-exporter prometheus-nginx-exporter loki alloy grafana-server

echo "=== 50 DONE ==="