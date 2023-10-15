// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {Withdraw} from "./utils/Withdraw.sol";

contract Receiver is CCIPReceiver, Withdraw {
    bytes32 latestMessageId;
    uint64 latestSourceChainSelector;
    address latestSender;
    RateMessageData latestMessage;
    struct RateMessageData {
        uint256 blockNumber;
        uint256 supplyRate;
        uint256 borrowRate;
    }

    struct RateData {
        uint64 sourceChainSelector;
        bytes32 messageId;
        RateMessageData rate;
    }

    mapping(bytes32 => RateData) public rateData;
    mapping(uint64 => RateData[]) public chainRateData;

    event MessageReceived(
        bytes32 latestMessageId,
        uint64 latestSourceChainSelector,
        address latestSender,
        RateMessageData latestMessage
    );

    constructor(address router) CCIPReceiver(router) {}

    function _ccipReceive(
        Client.Any2EVMMessage memory message
    ) internal override {
        latestMessageId = message.messageId;
        latestSourceChainSelector = message.sourceChainSelector;
        latestSender = abi.decode(message.sender, (address));
        latestMessage = abi.decode(message.data, (RateMessageData));

        RateData memory messageRateData = RateData({
            sourceChainSelector: latestSourceChainSelector,
            messageId: latestMessageId,
            rate: latestMessage
        });

        rateData[
            keccak256(abi.encodePacked(latestSourceChainSelector, latestMessage.blockNumber))
        ] = messageRateData;

        chainRateData[latestSourceChainSelector].push(messageRateData);

        emit MessageReceived(
            latestMessageId,
            latestSourceChainSelector,
            latestSender,
            latestMessage
        );
    }

    function getLatestMessageDetails()
        public
        view
        returns (bytes32, uint64, address, RateMessageData memory)
    {
        return (
            latestMessageId,
            latestSourceChainSelector,
            latestSender,
            latestMessage
        );
    }

    function getChainRateData(
        uint64 chainSelector,
        uint256 index
    )
        public
        view
        returns (RateData memory)
    {
        require(index < chainRateData[chainSelector].length, "Index out of bounds");
        return chainRateData[chainSelector][index];
    }

    function getChainAllRateData(
        uint64 chainSelector
    )
        public
        view
        returns (RateData[] memory)
    {
        return chainRateData[chainSelector];
    }

    function getRateData(
        uint64 chainSelector,
        uint256 blockNumber
    )
        public
        view
        returns (RateData memory)
    {
        return rateData[
            keccak256(abi.encodePacked(chainSelector, blockNumber))
        ];
    }
}