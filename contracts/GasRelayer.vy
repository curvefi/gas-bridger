# pragma version 0.4.3

"""
@title Layer Zero Gas Sender

@notice Base contract for sending gas between chains through LayerZero

@license Copyright (c) Curve.Fi, 2025 - all rights reserved

@author curve.fi

@custom:security security@curve.fi
"""


################################################################
#                            MODULES                           #
################################################################

# Import ownership management
from snekmate.auth import ownable

initializes: ownable
exports: (
    ownable.owner,
    ownable.transfer_ownership,
    ownable.renounce_ownership,
)


# Import LayerZero module for cross-chain messaging
from .modules.oapp.src import OApp  # main module
from .modules.oapp.src import OptionsBuilder  # module for creating options

initializes: OApp[ownable := ownable]

exports: (
    OApp.peers,
    OApp.setPeer,
)


################################################################
#                           CONSTANTS                          #
################################################################

MAX_N_BROADCAST: constant(uint256) = 32

################################################################
#                            STORAGE                           #
################################################################

# Struct for broadcast info
struct BroadcastTarget:
    eid: uint32
    fee: uint256
    gas_limit: uint128


################################################################
#                            EVENTS                            #
################################################################

event MessageSent:
    sender: address
    receiver: address
    amount: uint128
    target: BroadcastTarget

event MessageReceived:
    source: uint32
    receiver: address
    amount: uint128


################################################################
#                          CONSTRUCTOR                         #
################################################################

@deploy
def __init__(
    _endpoint: address,
):
    """
    @notice Initialize contract with core settings
    @dev Can only be called once, assumes caller is owner, sets as delegate
    @param _endpoint LayerZero endpoint address
    @param _lz_receive_gas_limit Gas limit for lzReceive
    """
    ownable.__init__()
    ownable._transfer_ownership(tx.origin)  # origin to enable createx deployment

    OApp.__init__(_endpoint, tx.origin)  # origin also set as delegate


################################################################
#                      OWNER FUNCTIONS                         #
################################################################

@external
def set_peers(_eids: DynArray[uint32, MAX_N_BROADCAST], _peers: DynArray[address, MAX_N_BROADCAST]):
    """
    @notice Set peers for a corresponding endpoints. Batched version of OApp.setPeer that accept address (EVM only).
    @param _eids The endpoint IDs.
    @param _peers Addresses of the peers to be associated with the corresponding endpoints.
    """
    ownable._check_owner()

    assert len(_eids) == len(_peers), "Invalid peer arrays"
    for i: uint256 in range(0, len(_eids), bound=MAX_N_BROADCAST):
        OApp._setPeer(_eids[i], convert(_peers[i], bytes32))

@external
def withdraw_eth(_amount: uint256):
    """
    @notice Withdraw ETH from contract
    @dev ETH can be accumulated from LZ refunds
    @param _amount Amount to withdraw
    """
    ownable._check_owner()

    assert self.balance >= _amount, "Insufficient balance"
    send(msg.sender, _amount)


################################################################
#                     INTERNAL FUNCTIONS                       #
################################################################

@internal
def _send_gas(
    _target: address,
    _value: uint128,
    _broadcast_target: BroadcastTarget,
    _refund_address: address,
):
    """
    @notice Internal function to send gas to target eid
    @param _target Target address to receive funds
    @param _value Amount
    @param _broadcast_target Data for broadcasting
    @param _refund_address Excess fees receiver
    """
    message: Bytes[OApp.MAX_MESSAGE_SIZE] = abi_encode(_target)

    # Сreate options using OptionsBuilder module (same options for all targets)
    options: Bytes[OptionsBuilder.MAX_OPTIONS_TOTAL_SIZE] = OptionsBuilder.newOptions()
    options = OptionsBuilder.addExecutorLzReceiveOption(options, _broadcast_target.gas_limit, _value)

    if OApp.peers[_broadcast_target.eid] == empty(bytes32):
        return

    # Send message
    fees: OApp.MessagingFee = OApp.MessagingFee(nativeFee=_broadcast_target.fee, lzTokenFee=0)
    OApp._lzSend(_broadcast_target.eid, message, options, fees, _refund_address)

    log MessageSent(
        sender=msg.sender,
        receiver=_target,
        amount=_value,
        target=_broadcast_target,
    )


################################################################
#                     EXTERNAL FUNCTIONS                       #
################################################################

@external
@payable
def __default__():
    """
    @notice Default function to receive ETH
    @dev This is needed to receive refunds from LayerZero
    """
    pass

@external
@view
def quote_fees(
    _target_eid: uint32,
    _lz_receive_gas_limit: uint128,
) -> uint256:
    """
    @notice Quote fees for specified targets
    @param _target_eid Chain ID
    @param _lz_receive_gas_limit Gas limit for lzReceive
    @return Fee for target chain (0 if target not configured)
    """
    # Prepare dummy broadcast message (uint256 number, bytes32 hash)
    message: Bytes[OApp.MAX_MESSAGE_SIZE] = abi_encode(empty(address))

    # Prepare array of fees per chain
    fees: uint256 = 0

    # Prepare options (same for all targets)
    # non-zero value in wei
    options: Bytes[OptionsBuilder.MAX_OPTIONS_TOTAL_SIZE] = OptionsBuilder.newOptions()
    options = OptionsBuilder.addExecutorLzReceiveOption(options, _lz_receive_gas_limit, 10 ** 10)

    target: bytes32 = OApp.peers[_target_eid]  # Use peers directly
    if target == empty(bytes32):
        return fees

    # Get fee for target EID and append to array
    fees = OApp._quote(_target_eid, message, options, False).nativeFee
    return fees

@external
@payable
def send_gas(
    _target: address,
    _value: uint128,
    _target_eid: uint32,
    _target_fees: uint256,
    _lz_receive_gas_limit: uint128,
):
    """
    @notice Send gas funds to target chain
    @param _target Target address to receive funds
    @param _value Amount
    @param _target_eid Chain ID to broadcast to
    @param _target_fees Fees per chain
    @param _lz_receive_gas_limit Gas limit for lzReceive
    """

    # Prepare broadcast target
    broadcast_target: BroadcastTarget = BroadcastTarget(eid=_target_eid, fee=_target_fees, gas_limit=_lz_receive_gas_limit)

    self._send_gas(
        _target,
        _value,
        broadcast_target,
        msg.sender,
    )

@payable
@external
def lzReceive(
    _origin: OApp.Origin,
    _guid: bytes32,
    _message: Bytes[OApp.MAX_MESSAGE_SIZE],
    _executor: address,
    _extraData: Bytes[OApp.MAX_EXTRA_DATA_SIZE],
):
    """
    @notice Handle messages: read responses, and regular messages
    @dev Two types of messages:
         1. Read responses (from read channel)
         2. Regular messages (block hash broadcasts from other chains)
    @param _origin Origin information containing srcEid, sender, and nonce
    @param _guid Global unique identifier for the message
    @param _message The encoded message payload containing block number and hash
    @param _executor Address of the executor for the message
    @param _extraData Additional data passed by the executor
    """
    # Verify message source
    OApp._lzReceive(_origin, _guid, _message, _executor, _extraData)

    target: address = abi_decode(_message, address)
    # Send everything that received
    send(target, msg.value)

    log MessageReceived(
        source=_origin.srcEid,
        receiver=target,
        amount=convert(msg.value, uint128),
    )
