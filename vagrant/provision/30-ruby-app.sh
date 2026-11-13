#!/usr/bin/env bash
set -euxo pipefail
source /vagrant/provision/common.sh
echo "=== 30: Ruby, Rails app, Puma (systemd) ==="

[ -f "$SRC_APP/Gemfile" ] || { echo "ERROR: no Rails app found in ./myapp (Gemfile missing)"; exit 1; }

apt-get update
apt-get install -y --no-install-recommends \
  ruby-full build-essential libssl-dev libyaml-dev zlib1g-dev libgmp-dev \
  libreadline-dev libffi-dev libpq-dev libvips nodejs git rsync
gem install bundler --no-document


install -d -o "$APP_USER" -g "$APP_USER" "$APP_DIR"
rsync -rltp --delete --chown="$APP_USER:$APP_USER" \
  --exclude .git --exclude log --exclude tmp --exclude vendor/bundle --exclude .bundle \
  --exclude node_modules --exclude public/assets --exclude storage --exclude '*.sqlite3' \
  "$SRC_APP/" "$APP_DIR/"
for d in log tmp storage; do install -d -o "$APP_USER" -g "$APP_USER" "$APP_DIR/$d"; done
chmod +x "$APP_DIR"/bin/* || true


init_conf
ensure_secret SECRET_KEY_BASE 64 >/dev/null
env_set RAILS_ENV production
env_set RAILS_LOG_TO_STDOUT 1
env_set RAILS_SERVE_STATIC_FILES 1
env_set WEB_CONCURRENCY 2
env_set RAILS_MAX_THREADS 5

as_app() {
  sudo -u "$APP_USER" -H bash -c "set -euo pipefail; set -a; . $ENV_FILE; set +a; cd $APP_DIR; $*"
}
as_app "bundle config set --local path vendor/bundle"
as_app "bundle config set --local without 'development test'"
as_app "bundle install --jobs 4"
as_app "bin/rails db:prepare assets:precompile"


cat > /etc/systemd/system/myapp.service <<EOF
[Unit]
Description=Rails app (Puma)
After=network.target postgresql.service redis-server.service
Wants=postgresql.service redis-server.service

[Service]
Type=simple
User=$APP_USER
Group=$APP_USER
WorkingDirectory=$APP_DIR
EnvironmentFile=$ENV_FILE
ExecStart=/usr/local/bin/bundle exec rails server -b 127.0.0.1 -p 3000
Restart=always
RestartSec=3
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$APP_DIR

[Install]
WantedBy=multi-user.target
EOF

if grep -qi sidekiq "$APP_DIR/Gemfile"; then
  sed -e 's/Rails app (Puma)/Sidekiq worker/' \
      -e 's|^ExecStart=.*|ExecStart=/usr/local/bin/bundle exec sidekiq|' \
      /etc/systemd/system/myapp.service > /etc/systemd/system/myapp-sidekiq.service
  systemctl daemon-reload
  systemctl enable myapp-sidekiq
  systemctl restart myapp-sidekiq
fi

systemctl daemon-reload
systemctl enable myapp
systemctl restart myapp

echo "=== 30 DONE ==="