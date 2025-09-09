# Docker Deployment Guide

This guide explains how to deploy the Primus Network Attestor Node using Docker in production environments.

## Prerequisites

- OS: Ubuntu 22.04 LTS (Recommended)
- [Docker](https://docs.docker.com/engine/install/ubuntu/#install-using-the-convenience-script) and [Docker Compose](https://docs.docker.com/compose/install/standalone/) installed
- Valid EVM private key (with sufficient balance)
- A domain name
- Reliable RPC endpoints for Base and BNB Chain (for example, [Alchemy](https://www.alchemy.com/))

## Quick Start

### 1. Resource Requirements

#### Recommended for Production
- **CPU**: 4+ cores
- **Memory**: 8GB+ RAM
- **Storage**: 100GB+ SSD storage
- **Network**: High-bandwidth, low-latency connection

### 2. Clone and Prepare
```bash
git clone https://github.com/primus-labs/primus-network-startup.git
cd primus-network-startup
chmod +x ./run.sh
```

### 3. Deploy the Node with Docker Compose
You can run the node with Docker Compose. This starts all services:
- **Redis** (port 6379) - Caching storage
- **Attestor Node** (ports 8080-8083) - Main attestation service
- **Attestor Service** (port 8084) - Helper service for attestor-node

> The [Docker Compose](./docker-compose.yaml) file is in the project root.

You can configure the following environment variables in `docker-compose.yaml`:
#### Required Variables
- `PRIVATE_KEY`: EVM private key (must start with `0x`)

#### Network Configuration
- `BASE_RPC_URL`: Base network RPC URL (default: https://sepolia.base.org)
- `BASE_TASK_CONTRACT_ADDRESS`: Base network task contract address
- `BASE_CHAIN_ID`: Base network chain ID (default: 84532)
- `BNB_CHAIN_RPC_URL`: BNB Chain RPC URL (default: https://bsc-testnet.therpc.io)
- `BNB_CHAIN_TASK_CONTRACT_ADDRESS`: BNB Chain task contract address
- `BNB_CHAIN_CHAIN_ID`: BNB Chain chain ID (default: 97)

> Other parameters have sensible defaults.

#### Start the services
```shell
./run.sh start
```

### 4. Configure SSL/TLS and Reverse Proxy

> **Note: Before configuring SSL/TLS, point your domain to the server’s IP address.**

If your OS is Ubuntu, you can run the following command to complete all steps:

```shell
./run.sh cert <your_domain>
```

Otherwise, you can manually configure SSL/TLS and the reverse proxy with the steps below:


1. Install Nginx
```shell
# Ubuntu
# You can install Nginx on other operating systems as appropriate.
apt install nginx 
```
2. Obtain an SSL/TLS certificate
   We recommend using [Certbot](https://certbot.eff.org/instructions?ws=nginx&os=snap).

3. Configure Nginx
   Configure Nginx to proxy requests to your services. See [attestor-node-https.conf](files/attestor-node-https.conf).

4. Enable the SSL configuration
```shell
# Test the Nginx configuration
nginx -t
# Reload Nginx to apply the SSL configuration
nginx -s reload
```

> The deployment is now complete.

### 5. Register the Node
#### 6.1 Set Environment Variables
Based on the chain where your node is located, run the following command:
```bash
cp env_files/.env.<chain-name> .env
```
Then set your private key, RPC URL, and other parameters:
```bash
PRIVATE_KEY=0x
RPC=<Your RPC URL>
NODE_CONTRACT_ADDRESS=
# Attestor's address to sign attestations
ATTESTOR_ADDRESS=
# Address to receive rewards and fees
RECIPIENT_ADDRESS=
# Attestor node metadata
NODE_META_URL=https://api-dev.primuslabs.xyz/node1-meta.json
# Attestor node domain names. If you have multiple URLs, separate them with commas.
# Example: network-node1.primuslabs.xyz,test-network-node1-2.primuslabs.xyz
ATTESTOR_URLS=<node-domain1>,<node-domain2>
```
`NODE_META_URL` should point to a JSON document containing the following fields:
```json
{
    "name":"Your node name",
    "description":"Introduce your node",
    "website":"Your website URL",
    "x":"https://x.com/<your_x_username>",
    "logo":""
}
```
***MAKE SURE `NODE_META_URL` IS PUBLICLY ACCESSIBLE ON THE INTERNET.***

#### 5.2 Register the node
```bash
./run.sh register
```

### 6. Monitoring and Logging

#### View Logs
```bash
# View all service logs
./run.sh logs

# View specific service logs
./run.sh logs attestor-node
./run.sh logs attestor-service
```

### 7. Update Services
```bash
# Update image tags to the latest versions in docker-compose.yaml
./run.sh update
```

### 8. Reset the Environment
To reset the environment, including all data, run the following command:
```bash
# Remove volumes (WARNING: This will delete all data)
./run.sh clean
./run.sh start
```