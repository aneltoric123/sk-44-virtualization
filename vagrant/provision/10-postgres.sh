#!/usr/bin/env bash
set -euxo pipefail
source /vagrant/provision/common.sh
echo "=== 10: PostgreSQL ==="
cd /tmp

apt-get update
apt-get install -y --no-install-recommends postgresql postgresql-contrib

PGVER=$(ls /etc/postgresql | sort -V | tail -1)
DB_NAME=myapp_production
DB_USER=myapp
init_conf
DB_PASS=$(ensure_secret DB_PASSWORD 24)


cat > /etc/postgresql/$PGVER/main/conf.d/99-myapp.conf <<'EOF'
listen_addresses = 'localhost'
password_encryption = 'scram-sha-256'
shared_buffers = 256MB
log_min_duration_statement = 500
log_connections = on
log_disconnections = on
EOF
systemctl enable postgresql
systemctl restart postgresql


sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER'" | grep -q 1 \
  || sudo -u postgres psql -c "CREATE ROLE $DB_USER LOGIN"
sudo -u postgres psql -c "ALTER ROLE $DB_USER PASSWORD '$DB_PASS'"
sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" | grep -q 1 \
  || sudo -u postgres createdb -O "$DB_USER" "$DB_NAME"

env_set DATABASE_URL "postgres://$DB_USER:$DB_PASS@127.0.0.1:5432/$DB_NAME"


install -d -m 750 -o postgres -g postgres /var/backups/postgres
cat > /usr/local/bin/pg-backup.sh <<EOF
#!/usr/bin/env bash
set -euo pipefail
pg_dump -Fc $DB_NAME -f /var/backups/postgres/$DB_NAME-\$(date +%F_%H%M).dump
find /var/backups/postgres -name '*.dump' -mtime +7 -delete
EOF
chmod 755 /usr/local/bin/pg-backup.sh

cat > /etc/systemd/system/pg-backup.service <<'EOF'
[Unit]
Description=PostgreSQL backup
After=postgresql.service

[Service]
Type=oneshot
User=postgres
ExecStart=/usr/local/bin/pg-backup.sh
EOF
cat > /etc/systemd/system/pg-backup.timer <<'EOF'
[Unit]
Description=Daily PostgreSQL backup

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF
systemctl daemon-reload
systemctl enable --now pg-backup.timer
systemctl start pg-backup.service

echo "=== 10 DONE ==="