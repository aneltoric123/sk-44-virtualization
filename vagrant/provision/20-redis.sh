#!/usr/bin/env bash
set -euxo pipefail
source /vagrant/provision/common.sh
echo "=== 20: Redis ==="

apt-get update
apt-get install -y --no-install-recommends redis-server

init_conf
REDIS_PASS=$(ensure_secret REDIS_PASSWORD 24)


sed -i '/^# BEGIN myapp$/,/^# END myapp$/d' /etc/redis/redis.conf
cat >> /etc/redis/redis.conf <<EOF
# BEGIN myapp
bind 127.0.0.1 -::1
protected-mode yes
requirepass $REDIS_PASS
maxmemory 256mb
maxmemory-policy volatile-lru
# END myapp
EOF

env_set REDIS_URL "redis://:$REDIS_PASS@127.0.0.1:6379/0"

systemctl enable redis-server
systemctl restart redis-server
redis-cli -a "$REDIS_PASS" --no-auth-warning ping

echo "=== 20 DONE ==="