// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";

interface RandomCandyInterface {
  function receivedNumber(uint _resultId, uint _number) external;
}

contract RandomCandyContract is VRFConsumerBaseV2, ConfirmedOwner {
  VRFCoordinatorV2Interface coordinator;
  uint32 public callbackGasLimit = 2500000;
  uint16 requestConfirmations = 3;
  uint32 numWords = 1;
  uint64 subId;
  bytes32 keyHash;
  LinkTokenInterface LINK;
  address linkAddress = 0x779877A7B0D9E8603169DdbD7836e478b4624789;

  mapping (uint => address) receivers;
  mapping (address => uint) balances;
  event RequestStarted(uint _resultId);
  event RequestEnded(uint _resultId, uint _number);

  constructor(
    uint64 _subId,
    address coordinatorAddr,
    bytes32 _keyHash
  ) VRFConsumerBaseV2(coordinatorAddr) ConfirmedOwner(msg.sender) {
    coordinator = VRFCoordinatorV2Interface(coordinatorAddr);
    subId = _subId;
    keyHash = _keyHash;
    LINK = LinkTokenInterface(linkAddress);
  }

  function addFunds(uint256 amount, address forContract) external {
    require(LINK.allowance(msg.sender, address(this)) >= amount, "Contract not allowed to transfer enough tokens");
    LINK.transferFrom(msg.sender, address(this), amount);
    LINK.transferAndCall(
      address(coordinator),
      amount,
      abi.encode(subId)
    );
    balances[forContract] += amount;
  }

  function requestNumber() public returns (uint) {
    require(balances[msg.sender] >= 0.5 ether, "Not allowed");
    uint requestId = coordinator.requestRandomWords(
      keyHash,
      subId,
      requestConfirmations,
      callbackGasLimit,
      numWords
    );
    balances[msg.sender] -= 0.5 ether;
    emit RequestStarted(requestId);
    receivers[requestId] = msg.sender;
    return requestId;
  }

  function fulfillRandomWords(
    uint256 _requestId,
    uint256[] memory _randomWords
  ) virtual internal override {
    emit RequestEnded(_requestId, _randomWords[0]);
    RandomCandyInterface receiver = RandomCandyInterface(receivers[_requestId]);
    receiver.receivedNumber(_requestId, _randomWords[0]);
  }
}
