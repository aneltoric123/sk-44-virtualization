#!/usr/bin/env bash
set -euxo pipefail
source /vagrant/provision/common.sh
echo "=== 01: adding hosts to your device ==="
cat > /etc/hosts <<EOF
172.16.21.10 myapp.local
EOF

echo "=== 01 DONE ==="

