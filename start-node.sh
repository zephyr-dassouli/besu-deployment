#!/bin/bash

# Besu + IPFS Node Startup Script
# Usage: ./start-node.sh <enode-url> [node-number]
# Need to have run generate-keys.sh first to create the node keys
# Also need to put genesis.json in the DVRE-Node directory
# Optional node-number parameter for running multiple nodes on same machine (default: 2)

set -e

# Check if enode URL is provided
if [ $# -eq 0 ]; then
    echo "Error: No enode URL provided"
    echo "Usage: $0 <enode-url> [node-number]"
    echo "Example: $0 enode://abcd1234...@192.168.1.100:30303"
    echo "Example: $0 enode://abcd1234...@192.168.1.100:30303 3"
    exit 1
fi

ENODE_URL="$1"
NODE_NUM="${2:-2}"  # Default to node 2 if not specified

# Calculate port offsets based on node number
BESU_RPC_PORT=$((8550 + NODE_NUM - 1))
BESU_P2P_PORT=$((30310 + NODE_NUM - 1))
BESU_BOOTNODE_PORT=$((30303 + NODE_NUM - 1))
IPFS_SWARM_PORT=$((4001 + NODE_NUM - 1))
IPFS_API_PORT=$((5001 + NODE_NUM - 1))
IPFS_GATEWAY_PORT=$((8080 + NODE_NUM - 1))

# Fetch public IP once
PUBLIC_IP=$(curl -s https://api.ipify.org)
if [ -z "$PUBLIC_IP" ]; then
    echo "Error: Could not fetch public IP"
    exit 1
fi

echo "Starting Besu + IPFS hybrid node #$NODE_NUM with bootnode: $ENODE_URL and public IP: $PUBLIC_IP"
echo "Ports - Besu RPC: $BESU_RPC_PORT, Besu P2P: $BESU_P2P_PORT, IPFS API: $IPFS_API_PORT, IPFS Gateway: $IPFS_GATEWAY_PORT"

# Check if genesis.json exists
if [ ! -f "DVRE-Node/genesis.json" ]; then
    echo "Warning: genesis.json not found in DVRE-Node directory"
    echo "Make sure genesis.json is present before starting the node"
    exit 1
fi

# Check if swarm.key exists for IPFS private network
if [ ! -f "swarm.key" ]; then
    echo "Warning: swarm.key not found. Make sure swarm.key is present for IPFS private network"
    echo "Copy swarm.key from the bootstrap node or generate one with ./generate-swarm-key.sh"
    exit 1
fi

# Create IPFS data directory for this node
mkdir -p DVRE-Node/ipfs-data-node${NODE_NUM}

# Create docker-compose.yml with both Besu and IPFS services
cat > docker-compose.yml << EOF
version: '3.8'

services:
  besu-node:
    image: hyperledger/besu:latest
    container_name: besu-node-${NODE_NUM}
    ports:
      - "${BESU_RPC_PORT}:8550"         # JSON-RPC port
      - "${BESU_P2P_PORT}:30310/tcp"    # P2P port
      - "${BESU_P2P_PORT}:30310/udp"    # P2P port
      - "${BESU_BOOTNODE_PORT}:30303"   # Bootnode port
    volumes:
      - ./DVRE-Node/data:/opt/besu/data
      - ./DVRE-Node/genesis.json:/opt/besu/genesis.json
    command: >
      --data-path=/opt/besu/data
      --genesis-file=/opt/besu/genesis.json
      --bootnodes=$ENODE_URL
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
    container_name: ipfs-node-${NODE_NUM}
    ports:
      - "${IPFS_SWARM_PORT}:4001"       # IPFS Swarm port
      - "${IPFS_API_PORT}:5001"         # IPFS API port
      - "${IPFS_GATEWAY_PORT}:8080"     # IPFS Gateway port
    volumes:
      - ./DVRE-Node/ipfs-data-node${NODE_NUM}:/data/ipfs
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

echo "Docker Compose file created with Besu + IPFS services for node #$NODE_NUM"
echo "Access URLs:"
echo "  Besu JSON-RPC: http://localhost:$BESU_RPC_PORT"
echo "  IPFS API: http://localhost:$IPFS_API_PORT"
echo "  IPFS Gateway: http://localhost:$IPFS_GATEWAY_PORT"

# Stop any existing containers
echo "Stopping any existing containers..."
docker compose down 2>/dev/null || true

# Start the services
echo "Starting Besu + IPFS hybrid node #$NODE_NUM..."
docker compose up