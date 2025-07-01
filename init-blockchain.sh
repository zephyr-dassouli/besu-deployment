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
  "extraData" : "$(cat DVRE-Node/encoded)",
  "alloc": {
    "0x0000000000000000000000000000000000001000": {
      "balance": "0",
      "nonce": "0x1",
      "code": "0x608060405234801561001057600080fd5b50600436106100365760003560e01c80631e59c5291461003b578063693ec85e14610050575b600080fd5b61004e610049366004610143565b61007f565b005b61006361005e3660046101a6565b6100c6565b6040516001600160a01b03909116815260200160405180910390f35b80600084846040516100929291906101e8565b90815260405190819003602001902080546001600160a01b03929092166001600160a01b0319909216919091179055505050565b60008083836040516100d99291906101e8565b908152604051908190036020019020546001600160a01b0316905092915050565b60008083601f84011261010c57600080fd5b50813567ffffffffffffffff81111561012457600080fd5b60208301915083602082850101111561013c57600080fd5b9250929050565b60008060006040848603121561015857600080fd5b833567ffffffffffffffff81111561016f57600080fd5b61017b868287016100fa565b90945092505060208401356001600160a01b038116811461019b57600080fd5b809150509250925092565b600080602083850312156101b957600080fd5b823567ffffffffffffffff8111156101d057600080fd5b6101dc858286016100fa565b90969095509350505050565b818382376000910190815291905056fea26469706673582212204b0030ff3eea382483ed0e6d3b96930f44cb3660ec7ed812b96068104a24269364736f6c634300081c0033"
    }
  }
}
EOL

echo "Genesis file and network configuration generated in DVRE-Node directory."