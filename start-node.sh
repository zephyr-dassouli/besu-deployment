#!/bin/bash

# Besu Node Startup Script
# Usage: ./start-node.sh <enode-url>
# Need to have run generate-keys.sh first to create the node key
# Also need to put genesis.json in the DVRE-Node directory

set -e

# Check if enode URL is provided
if [ $# -eq 0 ]; then
    echo "Error: No enode URL provided"
    echo "Usage: $0 <enode-url>"
    echo "Example: $0 enode://abcd1234...@192.168.1.100:30303"
    exit 1
fi

ENODE_URL="$1"

echo "Starting Besu node with bootnode: $ENODE_URL"

# Check if genesis.json exists
if [ ! -f "DVRE-Node/genesis.json" ]; then
    echo "Warning: genesis.json not found in current directory"
    echo "Make sure genesis.json is present before starting the node"
    exit 1
fi

# Create docker-compose.yml with the provided enode URL
cat > docker-compose.yml << EOF
services:
  besu-node:
    image: hyperledger/besu:latest
    container_name: besu-node
    ports:
      - "8550:8550"    # JSON-RPC port
      - "30310:30310"  # P2P port
      - "30303:30303"  # Bootnode port
    volumes:
      - ./DVRE-Node/:/opt/besu/
    command: >
      --data-path=/opt/besu/data
      --genesis-file=/opt/besu/genesis.json
      --bootnodes=$ENODE_URL
      --p2p-port=30310
      --rpc-http-port=8550
      --p2p-host=0.0.0.0
      --rpc-http-host=0.0.0.0
      --rpc-http-enabled
      --rpc-http-api=ETH,NET,IBFT
      --host-allowlist="*"
      --rpc-http-cors-origins="all"
      --profile=ENTERPRISE
      --min-gas-price=0
 
EOF

echo "Docker Compose file created with bootnode: $ENODE_URL"

# Stop any existing containers
echo "Stopping any existing Besu containers..."
docker-compose down 2>/dev/null || true

# Start the services
echo "Starting Besu node..."
docker-compose up -d