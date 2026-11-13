#!/usr/bin/env bash

export DEBIAN_FRONTEND=noninteractive

APP_NAME=myapp
APP_USER=deploy
APP_DIR=/var/www/myapp
CONF_DIR=/etc/myapp
ENV_FILE="$CONF_DIR/myapp.env"          
CRED_FILE="$CONF_DIR/credentials.txt"   
SRC_APP=/vagrant/myapp
SRC_CONF=/vagrant/config

DOMAIN="${DOMAIN:-myapp.local}"
TLS_MODE="${TLS_MODE:-mkcert}"
PUBLIC_HTTPS_PORT="${PUBLIC_HTTPS_PORT:-8443}"

rand() { openssl rand -hex "${1:-24}"; }

init_conf() {
  install -d -m 750 -o root -g "$APP_USER" "$CONF_DIR"
  touch "$ENV_FILE" "$CRED_FILE"
  chown root:"$APP_USER" "$ENV_FILE"; chmod 640 "$ENV_FILE"
  chown root:root "$CRED_FILE";       chmod 600 "$CRED_FILE"
}

env_get() { grep -m1 "^$1=" "$ENV_FILE" | cut -d= -f2- || true; }
env_set() {   
  if grep -q "^$1=" "$ENV_FILE"; then sed -i "s|^$1=.*|$1=$2|" "$ENV_FILE"
  else echo "$1=$2" >> "$ENV_FILE"; fi
}
ensure_secret() {  
  local v; v=$(env_get "$1")
  if [ -z "$v" ]; then v=$(rand "${2:-24}"); env_set "$1" "$v"; fi
  echo "$v"
}

cred_get() { grep -m1 "^$1: " "$CRED_FILE" | cut -d' ' -f2- || true; }
cred_set() { sed -i "/^$1: /d" "$CRED_FILE"; echo "$1: $2" >> "$CRED_FILE"; }
ensure_cred() {    
  local v; v=$(cred_get "$1")
  if [ -z "$v" ]; then v=$(rand "${2:-12}"); cred_set "$1" "$v"; fi
  echo "$v"
}

public_url() {
  if [ "$PUBLIC_HTTPS_PORT" = "443" ]; then echo "https://$DOMAIN"; else echo "https://$DOMAIN:$PUBLIC_HTTPS_PORT"; fi
}