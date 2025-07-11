#!/bin/bash

# Besu + IPFS Node Startup Script
# Usage: ./start-first-node.sh
# Need to run init-blockchain.sh first to create the genesis.json with the correct ethereum addresses
# Also need to put genesis.json in the DVRE-Node directory

set -e

echo "Starting Besu + IPFS hybrid node"

# Check if genesis.json exists
if [ ! -f "DVRE-Node/genesis.json" ]; then
    echo "Warning: genesis.json not found in current directory"
    echo "Make sure genesis.json is present before starting the node"
    exit 1
fi

# Check if swarm.key exists for IPFS private network
if [ ! -f "swarm.key" ]; then
    echo "Warning: swarm.key not found. Generating one..."
    ./generate-swarm-key.sh
fi

# Create IPFS data directory
mkdir -p DVRE-Node/ipfs-data

# Fetch public IP once
PUBLIC_IP=$(curl -s https://api.ipify.org)
if [ -z "$PUBLIC_IP" ]; then
    echo "Error: Could not fetch public IP"
    exit 1
fi

echo "Starting Besu + IPFS hybrid node with public IP: $PUBLIC_IP"

# Create docker-compose.yml with both Besu and IPFS services
cat > docker-compose.yml << EOF
version: '3.8'

services:
  besu-node:
    image: hyperledger/besu:latest
    container_name: besu-node
    ports:
      - "8550:8550"    # JSON-RPC port
      - "30310:30310/tcp"  # P2P port
      - "30310:30310/udp"  # P2P port
      - "30303:30303"  # Bootnode port
    volumes:
      - ./DVRE-Node/data:/opt/besu/data
      - ./DVRE-Node/genesis.json:/opt/besu/genesis.json
    command: >
      --data-path=/opt/besu/data
      --genesis-file=/opt/besu/genesis.json
      --p2p-port=30310
      --rpc-http-port=8550
      --p2p-host=$PUBLIC_IP
      --rpc-http-host=0.0.0.0
      --rpc-http-enabled
      --rpc-http-api=ETH,NET,IBFT
      --host-allowlist="*"
      --rpc-http-cors-origins="all"
      --profile=ENTERPRISE
      --min-gas-price=0
    networks:
      - hybrid-network

  ipfs-node:
    image: ipfs/kubo:latest
    container_name: ipfs-node
    ports:
      - "4001:4001"     # IPFS Swarm port
      - "5001:5001"     # IPFS API port
      - "8080:8080"     # IPFS Gateway port
    volumes:
      - ./DVRE-Node/ipfs-data:/data/ipfs
      - ./swarm.key:/tmp/swarm.key:ro
    entrypoint: ["/sbin/tini", "--"]
    command: >
      /bin/sh -c "
        if [ ! -f /data/ipfs/config ]; then
          ipfs init --profile server
          cp /tmp/swarm.key /data/ipfs/swarm.key
          ipfs config --json API.HTTPHeaders.Access-Control-Allow-Origin '[\"*\"]'
          ipfs config --json API.HTTPHeaders.Access-Control-Allow-Methods '[\"GET\", \"POST\"]'
          ipfs config --json API.HTTPHeaders.Access-Control-Allow-Headers '[\"Authorization\"]'
          ipfs config --json Swarm.AddrFilters '[]'
          ipfs config --json Discovery.MDNS.Enabled false
          ipfs config --json Bootstrap '[]'
          ipfs config Addresses.API /ip4/0.0.0.0/tcp/5001
          ipfs config Addresses.Gateway /ip4/0.0.0.0/tcp/8080
        fi &&
        ipfs daemon --enable-gc
      "
    networks:
      - hybrid-network
    depends_on:
      - besu-node

networks:
  hybrid-network:
    driver: bridge
 
EOF

echo "Docker Compose file created with Besu + IPFS services"

# Stop any existing containers
echo "Stopping any existing containers..."
docker compose down 2>/dev/null || true

# Start the services
echo "Starting Besu + IPFS hybrid node..."
docker compose up