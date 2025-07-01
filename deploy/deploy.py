import json
import logging
import os
from pathlib import Path

import boa
import yaml
from eth_account import Account

from gas_bridger.settings import BASE_DIR, settings

createX_address = "0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed"
deployer = Account.from_key(settings.WEB3_PK)

logging.basicConfig(level=logging.INFO, format="%(asctime)s -  %(levelname)s - %(message)s")

yaml_file_path = Path(BASE_DIR, "deploy", "deployments.yaml")
json_config_path = Path(BASE_DIR, "gas_bridger", "deployments.json")

lz_endpoints = {
    421614: "0x6EDCE65403992e310A62460808c4b910D972f10f",
    11155111: "0x6EDCE65403992e310A62460808c4b910D972f10f",
}


def deploy():
    boa.set_network_env(settings.WEB3_PROVIDER_URL)
    boa.env.add_account(deployer)
    chain_id = boa.env.evm.patch.chain_id

    guard_bytes = bytes.fromhex(boa.env.eoa[2:] + "00")
    bytes_view = os.urandom(11)
    salt_view = guard_bytes + bytes_view

    with open(Path(BASE_DIR, "deploy", "abi", "createX.json")) as f:
        createX_abi = f.read()

    contract_deployer = boa.load_partial(Path(BASE_DIR, "contracts", "GasRelayer.vy"))
    bytecode = contract_deployer.compiler_data.bytecode
    args = boa.util.abi.abi_encode("(address,uint256)", (lz_endpoints[chain_id], 500_000))
    deploycode = bytecode + args

    address = boa.loads_abi(createX_abi).at(createX_address).deployCreate3(salt_view, deploycode)
    logging.info(f"Gas relayer deployed at {address} on chain: {chain_id}")

    abi_path = Path(BASE_DIR, "gas_bridger", "abi", "gas_relayer.json")
    with open(abi_path, "w") as abi_file:
        json.dump(contract_deployer.at(address).abi, abi_file, indent=4)
        abi_file.write("\n")

    deployments = {}
    if yaml_file_path.exists():
        with open(yaml_file_path, "r") as file:
            deployments = yaml.safe_load(file)

    deployments[chain_id] = str(address)

    with open(yaml_file_path, "w") as file:
        yaml.safe_dump(deployments, file)

    if chain_id != 11155111:
        set_peer()


def set_peer():
    boa.set_network_env(settings.WEB3_PROVIDER_URL)
    boa.env.add_account(deployer)
    chain_id = boa.env.evm.patch.chain_id

    deployments = {}
    if yaml_file_path.exists():
        with open(yaml_file_path, "r") as file:
            deployments = yaml.safe_load(file)

    contract = boa.load_partial(Path(BASE_DIR, "contracts", "GasRelayer.vy")).at(deployments[chain_id])
    contract.set_peer(4294967294, deployments[11155111])


if __name__ == "__main__":
    deploy()
