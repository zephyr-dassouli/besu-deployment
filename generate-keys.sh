#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

mkdir -p DVRE-Node/data

# Generate the node key pair
besu --data-path="DVRE-Node/data" public-key export --to="DVRE-Node/data/key.pub"

echo "Node key pair generated and stored in DVRE-Node/data"
besu public-key export-address --node-private-key-file=DVRE-Node/data/key
