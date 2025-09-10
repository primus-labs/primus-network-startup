#!/bin/bash

set -euo pipefail

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

  # Check nginx installed
  if ! command -v nginx >/dev/null 2>&1; then
    echo "Nginx is not installed; installing..."
    sudo apt update
    sudo apt install -y nginx
    nginx -v
  fi
}

apply_ssl_cert(){
  domain=${1:-}
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
  sudo certbot certonly --nginx -d "$domain"

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
  # Check .env  exists
  if [ ! -f .env ]; then
    echo "Please copy .env.<chain-name> to .env and edit it!"
    exit 1
  fi
  docker run --rm --env-file .env primuslabs/attestor-tools:latest node src/nodeMgt.js registerNode
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
      register_node
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
      echo "  $0 register              # Register node on-chain"
      echo "  $0 clean                 # Remove all containers and volumes"
      exit 1
      ;;
  esac
}

main "$@"
