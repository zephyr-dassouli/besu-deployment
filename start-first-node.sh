#!/bin/bash

# Besu Node Startup Script
# Usage: ./start-first-node.sh
# Need to have run generate-keys.sh first to create the node key
# Also need to put genesis.json in the DVRE-Node directory

set -e


echo "Starting Besu node"


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

echo "Docker Compose file created"

# Stop any existing containers
echo "Stopping any existing Besu containers..."
docker-compose down 2>/dev/null || true

# Start the services
echo "Starting Besu node..."
docker-compose up -d