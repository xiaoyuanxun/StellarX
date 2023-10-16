// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {Withdraw} from "./utils/Withdraw.sol";
import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.0/token/ERC20/IERC20.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";

contract Relyer is CCIPReceiver, Withdraw {
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

    address immutable i_link;
    uint16  immutable i_maxTokensLength;

    bytes32 latestMessageId;
    uint64 latestSourceChainSelector;
    address latestSender;
    MessageData latestMessage;
    address public protocolEndpoint;    //协议入口，用于执消息调用的对象

    mapping(uint32 => address) relyers; //各个链的relyer地址
    
    mapping(uint32 => uint64) chainIdToSelector;

    event MessageSent(bytes32 messageId);

    event MessageReceived(
        bytes32 latestMessageId,
        uint64 latestSourceChainSelector,
        address latestSender,
        MessageData latestMessage,
        Client.EVMTokenAmount token
    );

    constructor(address router, address link, address _protocolEndpoint) CCIPReceiver(router) {
        if (router == address(0)) revert InvalidRouter(address(0));
        i_link = link;
        i_maxTokensLength = 5;
        protocolEndpoint = _protocolEndpoint;
        LinkTokenInterface(i_link).approve(i_router, type(uint256).max);
    }

    receive() external payable {}

//--------as a sender
    function sendMessage(
        uint32 chainID,
        MessageData memory messageData
    ) external {
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(getRelyersAddress(chainID)),
            data: abi.encode(messageData),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: "",
            feeToken: i_link
        });
        uint64 destinationChainSelector = getChainSelector(chainID);
        bytes32 messageId;
        messageId = IRouterClient(i_router).ccipSend(
            destinationChainSelector,
            message
        );

        emit MessageSent(messageId);
    }

    function getChainSelector(uint32 chainID) internal returns(uint64) {
        return chainIdToSelector[chainID];
    }

    function getRelyersAddress(uint32 chainID) internal returns(address) {
        return relyers[chainID];
    }

    function initChainIdToSelector(uint32 chainID, uint64 chainSelector) public onlyOwner {
        chainIdToSelector[chainID] = chainSelector;
    }

    function initRelyers(uint32 chainId, address routerAddress) public onlyOwner {
        relyers[chainId] = routerAddress;
    }

    
    // struct EVMTokenAmount {
    //     address token; // token address on the local chain.
    //     uint256 amount; // Amount of tokens.
    // }
    function sendMessageAndToken(
        uint32 chainID,
        MessageData memory messageData,
        Client.EVMTokenAmount[] memory tokensToSendDetails
    ) external {
        uint64 destinationChainSelector = getChainSelector(chainID);
        uint256 length = tokensToSendDetails.length;
        require(
            length <= i_maxTokensLength,
            "Maximum 5 different tokens can be sent per CCIP Message"
        );

        for (uint256 i = 0; i < length; ) {
            IERC20(tokensToSendDetails[i].token).transferFrom(
                msg.sender,
                address(this),
                tokensToSendDetails[i].amount
            );
            IERC20(tokensToSendDetails[i].token).approve(
                i_router,
                tokensToSendDetails[i].amount
            );

            unchecked {
                ++i;
            }
        }

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(getRelyersAddress(chainID)),
            data: abi.encode(messageData),
            tokenAmounts: tokensToSendDetails,
            extraArgs: "",
            feeToken: i_link
        });
        
        bytes32 messageId;
        messageId = IRouterClient(i_router).ccipSend(
            destinationChainSelector,
            message
        );

        emit MessageSent(messageId);
    }

    function sendToken(
        uint32 chainId,
        //address receiver,
        Client.EVMTokenAmount[] memory tokensToSendDetails
    ) external {
        uint256 length = tokensToSendDetails.length;
        require(
            length <= i_maxTokensLength,
            "Maximum 5 different tokens can be sent per CCIP Message"
        );

        for (uint256 i = 0; i < length; ) {
            IERC20(tokensToSendDetails[i].token).transferFrom(
                msg.sender,
                address(this),
                tokensToSendDetails[i].amount
            );
            IERC20(tokensToSendDetails[i].token).approve(
                i_router,
                tokensToSendDetails[i].amount
            );

            unchecked {
                ++i;
            }
        }

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(getRelyersAddress(chainId)),
            data: "",
            tokenAmounts: tokensToSendDetails,
            extraArgs: "",
            feeToken: i_link
        });

        bytes32 messageId;

        messageId = IRouterClient(i_router).ccipSend(
            getChainSelector(chainId),
            message
        );

        emit MessageSent(messageId);
    }
//---------------------------
//as a reciver
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
        protocolEndpoint.call(
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
}