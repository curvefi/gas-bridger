# Gas Bridger using LayerZero V2

This repository contains a smart contract for bridging gas (ETH/native tokens) between different chains using LayerZero V2 protocol.

## Contract

### GasRelayer.vy
- Sends and receives native tokens (ETH) across chains through LayerZero
- Built-in ownership management using Snekmate
- Configurable gas limits and peer management
- Secure message validation and value handling
- Includes safety features like owner controls and trusted peer validation

## Setup

1. Install dependencies using uv:
```bash
# Install uv if you haven't already
curl -LsSf https://astral.sh/uv/install.sh | sh

# Create virtual environment and install dependencies
uv venv
uv sync
source .venv/bin/activate  # On Unix
# or
.venv\Scripts\activate  # On Windows
```

2. Deploy contract:
   - Deploy `GasRelayer.vy` on each chain you want to bridge between
   - Set trusted peers using `set_peer()` to establish trust between contracts

## Usage

1. To bridge gas between chains:
   - Send ETH to `GasRelayer.send_message()` with destination chain ID and receiver address
   - The contract will handle the cross-chain messaging through LayerZero
   - Funds will be received by the target address on the destination chain

2. Security features:
   - Two-step ownership transfers
   - Only trusted peer contracts can trigger value transfers
   - Owner can withdraw stuck funds if necessary
   - Built-in LayerZero security features

## Requirements

- Python 3.12+
- Vyper 0.4.0+
- LayerZero V2 endpoint contracts deployed on target chains
