#!/bin/bash

# This script initializes a Besu blockchain
# A genesis file will be created

# Need for :
# - Besu to be installed
# - Docker to be installed

# Exit immediately if a command exits with a non-zero status
set -e

# Check if three arguments are provided
if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <validator_adress_1> <validator_adress_2> <validator_adress_3>"
  exit 1
fi

# Assign arguments to variables
VALIDATOR_ADDRESS_1=$1
VALIDATOR_ADDRESS_2=$2
VALIDATOR_ADDRESS_3=$3

mkdir -p DVRE-Node/data

# Generate the node key pair
besu --data-path="DVRE-Node/data" public-key export --to="DVRE-Node/data/key.pub"

NODE_ADDR_FILE="DVRE-Node/node1.address"
besu --data-path="DVRE-Node/data" public-key export-address --node-private-key-file=DVRE-Node/data/key --to="$NODE_ADDR_FILE"

VALIDATOR_ADDRESS_0=$(cat "$NODE_ADDR_FILE")
echo "Node 1 address: $VALIDATOR_ADDRESS_0"

cat > DVRE-Node/toEncode.json <<EOL
["${VALIDATOR_ADDRESS_0:2}", "${VALIDATOR_ADDRESS_1:2}", "${VALIDATOR_ADDRESS_2:2}", "${VALIDATOR_ADDRESS_3:2}"]
EOL

besu rlp encode --from=DVRE-Node/toEncode.json --to=DVRE-Node/encoded

# Create genesis.json
cat > DVRE-Node/genesis.json <<EOL
{
  "config" : {
    "chainId" : 1337,
    "berlinBlock" : 0,
    "ibft2" : {
      "blockperiodseconds" : 1,
      "epochlength" : 1000000,
      "requesttimeoutseconds" : 1
    }
  },
  "nonce" : "0x0",
  "timestamp" : "0x58ee40ba",
  "gasLimit" : "0x1fffffffffffff",
  "difficulty" : "0x1",
  "mixHash" : "0x63746963616c2062797a616e74696e65206661756c7420746f6c6572616e6365",
  "coinbase" : "0x0000000000000000000000000000000000000000",
  "extraData" : "$(cat DVRE-Node/encoded)"  
}
EOL

echo "Genesis file and network configuration generated in DVRE-Node directory."