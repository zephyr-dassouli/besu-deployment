#!/bin/bash

# Besu Node Startup Script
# Usage: ./start-first-node.sh
# Need to run init-blockchain.sh first to create the genesis.json with the correct ethereum addresses
# Also need to put genesis.json in the DVRE-Node directory

set -e

echo "Starting Besu node"

# Check if genesis.json exists
if [ ! -f "DVRE-Node/genesis.json" ]; then
    echo "Warning: genesis.json not found in current directory"
    echo "Make sure genesis.json is present before starting the node"
    exit 1
fi


# Fetch public IP once
PUBLIC_IP=$(curl -s https://api.ipify.org)
if [ -z "$PUBLIC_IP" ]; then
    echo "Error: Could not fetch public IP"
    exit 1
fi

echo "Starting Besu node with public IP: $PUBLIC_IP"


# Create docker-compose.yml with the provided enode URL
cat > docker-compose.yml << EOF
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
 
EOF

echo "Docker Compose file created"

# Stop any existing containers
echo "Stopping any existing Besu containers..."
docker compose down 2>/dev/null || true

# Start the services
echo "Starting Besu node..."
docker compose up