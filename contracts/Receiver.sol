// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {Withdraw} from "./utils/Withdraw.sol";

contract Receiver is CCIPReceiver, Withdraw {
    bytes32 latestMessageId;
    uint64 latestSourceChainSelector;
    address latestSender;
    MessageData latestMessage;

    struct MessageData {
        address user;
        bytes callData;        
        address destinationExacuteContract;
        uint chainId;
    }

    struct MessageReceiveData {
        bytes32 messageId;
        uint64 sourceChainSelector;
        address sender;
        MessageData message;
        Client.EVMTokenAmount token;
    }
    
    event MessageReceived(
        bytes32 latestMessageId,
        uint64 latestSourceChainSelector,
        address latestSender,
        MessageData latestMessage,
        Client.EVMTokenAmount token
    );

    constructor(address router) CCIPReceiver(router) {}

    function _ccipReceive(
        Client.Any2EVMMessage memory message
    ) internal override {
        latestMessageId = message.messageId;
        latestSourceChainSelector = message.sourceChainSelector;
        latestSender = abi.decode(message.sender, (address));
        latestMessage = abi.decode(message.data, (MessageData));

        // MessageReceiveData memory messageReceiveData= MessageReceiveData({
        //     MessageReceiveData
        //     sourceChainSelector: latestSourceChainSelector,
        //     messageId: latestMessageId,
        //     sender: latestSender,
        //     message: latestMessage,
        //     token: message.destTokenAmounts[0]
        // });

        // 跨链接收消息后的执行逻辑
        latestMessage.destinationExacuteContract.call(
            latestMessage.callData
        );

        emit MessageReceived(
            latestMessageId,
            latestSourceChainSelector,
            latestSender,
            latestMessage,
            message.destTokenAmounts[0]
        );
    }

    function getLatestMessageDetails()
        public
        view
        returns (bytes32, uint64, address, MessageData memory)
    {
        return (
            latestMessageId,
            latestSourceChainSelector,
            latestSender,
            latestMessage
        );
    }

}