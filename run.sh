#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_ENV_FILE="$SCRIPT_DIR/.env"
ENV_DIR="$SCRIPT_DIR/env_files"

check_environment(){
  # Check docker installed
  if ! command -v docker >/dev/null 2>&1; then
    echo "Docker is not installed, please install it!"
    exit 1
  fi

  # Check docker compose (support both docker-compose and docker compose)
  if command -v docker-compose >/dev/null 2>&1; then
    DOCKER_COMPOSE="docker-compose"
  elif docker compose version >/dev/null 2>&1; then
    DOCKER_COMPOSE="docker compose"
  else
    echo "Docker Compose is not installed, please install it!"
    exit 1
  fi
}

ensure_env_file(){
  local env_file="$1"

  if [[ ! -f "$env_file" ]]; then
    echo "Environment file not found: $env_file"
    exit 1
  fi
}

resolve_env_file(){
  local chain_name="${1:-}"

  if [[ -n "$chain_name" ]]; then
    local chain_env_file="$ENV_DIR/.env.$chain_name"
    ensure_env_file "$chain_env_file"
    echo "$chain_env_file"
    return
  fi

  ensure_env_file "$DEFAULT_ENV_FILE"
  echo "$DEFAULT_ENV_FILE"
}

run_attestor_tools(){
  local command_name="$1"
  local env_file="$2"

  docker pull primuslabs/attestor-tools:latest
  docker run --rm --env-file "$env_file" primuslabs/attestor-tools:latest node src/nodeMgt.js "$command_name"
}

apply_ssl_cert(){
  domain=${1:-}
  # Check nginx installed
  if ! command -v nginx >/dev/null 2>&1; then
    echo "Nginx is not installed; installing..."
    sudo apt update
    sudo apt install -y nginx
    nginx -v
  fi
  if [[ -z "$domain" ]]; then
    echo "Usage: $0 cert <domain>"
    exit 1
  fi

  echo "Apply SSL cert for $domain ..."

  # Install certbot (snap recommended on Ubuntu)
  if ! command -v certbot >/dev/null 2>&1; then
    echo "Installing Certbot via snap..."
    sudo apt update
    sudo apt install -y snapd
    sudo snap install core
    sudo snap refresh core
    sudo snap install --classic certbot
    sudo ln -sf /snap/bin/certbot /usr/bin/certbot
  fi

  # Apply HTTP config for HTTP-01 challenge
  sudo cp ./files/attestor-node-http.conf /etc/nginx/conf.d/attestor-node-$domain-http.conf
  sudo sed -i "s/<domain>/$domain/g" /etc/nginx/conf.d/attestor-node-$domain-http.conf
  sudo nginx -t
  sudo nginx -s reload

  # Obtain certificate
  sudo certbot certonly --non-interactive --agree-tos --email "" --nginx -d "$domain"

  # Enable HTTPS config
  sudo cp ./files/attestor-node-https.conf /etc/nginx/conf.d/attestor-node-$domain-https.conf
  sudo sed -i "s/<domain>/$domain/g" /etc/nginx/conf.d/attestor-node-$domain-https.conf
  sudo nginx -t
  sudo nginx -s reload

  echo "-----Done!"
}

clean(){
  echo "Cleaning attestor node..."
  $DOCKER_COMPOSE down -v
  echo "Done."
}

start(){
  echo "Starting attestor node..."
  $DOCKER_COMPOSE up -d
  echo "Done."
}

update(){
  echo "Updating attestor node..."
  $DOCKER_COMPOSE pull
  $DOCKER_COMPOSE up -d
  echo "Done."
}

down(){
  echo "Stopping attestor node..."
  $DOCKER_COMPOSE down
  echo "Done."
}

logs(){
    service=${1:-}
    if [[ -z "$service" ]]; then
      $DOCKER_COMPOSE logs -f
    else
      docker logs $service --tail 100 -f
    fi
}

register_node(){
  local env_file
  env_file="$(resolve_env_file "${1:-}")"
  run_attestor_tools registerNode "$env_file"
}


unregister_node(){
  local env_file
  env_file="$(resolve_env_file "${1:-}")"
  run_attestor_tools unRegisterNode "$env_file"
}

register_and_stake_node(){
  local env_file
  env_file="$(resolve_env_file "${1:-}")"
  run_attestor_tools registerAndStake "$env_file"
}

request_exit_node(){
  local env_file
  env_file="$(resolve_env_file "${1:-}")"
  run_attestor_tools requestExit "$env_file"
}

withdraw_node_stake_and_unregister(){
  local env_file
  env_file="$(resolve_env_file "${1:-}")"
  run_attestor_tools withdrawNodeStakeAndUnregister "$env_file"
}

main(){
  option=${1:-}

  check_environment

  case $option in
    start)
      start
      ;;
    down)
      down
      ;;
    cert)
      apply_ssl_cert "${2:-}"
      ;;
    clean)
      clean
      ;;
    update)
      update
      ;;
    register)
      register_node "${2:-}"
      ;;
    registerAndStake)
      register_and_stake_node "${2:-}"
      ;;
    requestExit)
      request_exit_node "${2:-}"
      ;;
    withdrawNodeStakeAndUnregister)
      withdraw_node_stake_and_unregister "${2:-}"
      ;;
    unregister)
      unregister_node "${2:-}"
      ;;
    logs)
      logs "${2:-}"
      ;;
    *)
      echo "Usage:"
      echo "  $0 start                 # Start all services"
      echo "  $0 down                  # Stop all services"
      echo "  $0 update                # Pull latest images and restart"
      echo "  $0 logs [service]        # Tail logs (optional: service name)"
      echo "  $0 cert <domain>         # Obtain SSL cert via Nginx + Certbot"
      echo "  $0 register [chain]      # Register node on-chain"
      echo "  $0 registerAndStake [chain] # Register node and stake on-chain"
      echo "  $0 requestExit [chain]   # Request exit then unstake on-chain"
      echo "  $0 withdrawNodeStakeAndUnregister [chain] # Withdraw stake then unregister"
      echo "  $0 unregister [chain]    # Unregister node on-chain"
      echo "  $0 clean                 # Remove all containers and volumes"
      exit 1
      ;;
  esac
}

main "$@"
