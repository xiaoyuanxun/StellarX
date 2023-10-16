// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {Withdraw} from "./utils/Withdraw.sol";
import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.0/token/ERC20/IERC20.sol";
import "hardhat/console.sol";

contract Sender is Withdraw {
    address immutable i_router;
    address immutable i_link;
    uint16  immutable i_maxTokensLength;

    struct MessageData {
        address user;
        bytes callData;        
        address destinationExacuteContract;
        uint chainId;
    }

    event MessageSent(bytes32 messageId);
    event Debug(string debugMessgae);

    mapping(uint32 => uint64) chainIdToSelector;

    constructor(address router, address link) {
        i_router = router;
        i_link = link;
        i_maxTokensLength = 5;
        LinkTokenInterface(i_link).approve(i_router, type(uint256).max);
    }

    receive() external payable {}

    function sendMessage(
        uint32 chainID, 
        //address receiver,  //不需要
        MessageData memory messageData
    ) external {
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
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

    function getChainSelector(uint32 chainID) internal view returns(uint64) {
        return chainIdToSelector[chainID];
    }

    function initChainIdToSelector(uint32 chainID, uint64 chainSelector) public onlyOwner {
        chainIdToSelector[chainID] = chainSelector;
    }

    // struct EVMTokenAmount {
    //     address token; // token address on the local chain.
    //     uint256 amount; // Amount of tokens.
    // }
    // 需要目标链有对应合约的Token
    function sendMessageAndToken(
        uint32 chainID,
        // address receiver,   //不需要
        MessageData memory messageData,
        address token,
        uint256 amount
    ) external {
        emit Debug("get chain selector");
        uint64 destinationChainSelector = getChainSelector(chainID);
        
        emit Debug("transfrom token");
        IERC20(token).transferFrom(
            messageData.user,
            address(this),
            amount
        );
        emit Debug("transfer token");
        IERC20(token).approve(
            i_router,
            amount
        );

        emit Debug("init message");
        Client.EVMTokenAmount memory tokenAmount = Client.EVMTokenAmount({
            token: token,
            amount: amount
        });
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = tokenAmount;

        emit Debug("init message 2");
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: abi.encode(messageData),
            tokenAmounts: tokenAmounts,
            extraArgs: "",
            feeToken: i_link
        });
        
        emit Debug("message id");
        bytes32 messageId;
        messageId = IRouterClient(i_router).ccipSend(
            destinationChainSelector,
            message
        );

        emit MessageSent(messageId);
    }

    function testSendMessageAndToken(
    ) external {
        uint32 chainID = 80001;
        address receiver = 0xdf9479F11f28A6e887175df04E36E6848f27E32b;
        MessageData memory messageData = MessageData({
            user: 0xca0601D27CCdBea2eAD4B659967bBEa606496DF8,
            callData: abi.encodeWithSignature("transfer(address, uint)", 0xca0601D27CCdBea2eAD4B659967bBEa606496DF8, 100),
            destinationExacuteContract: 0x326C977E6efc84E512bB9C30f76E30c160eD06FB,
            chainId: 80001
        });
        address token = 0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8;
        uint256 amount = 10000;

        uint64 destinationChainSelector = 12532609583862916517;
        
        IERC20(token).transferFrom(
            messageData.user,
            address(this),
            amount
        );
        emit Debug("transfer token");
        IERC20(token).approve(
            i_router,
            amount
        );

        emit Debug("init message");
        Client.EVMTokenAmount memory tokenAmount = Client.EVMTokenAmount({
            token: token,
            amount: amount
        });
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = tokenAmount;

        emit Debug("init message 2");
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: abi.encode(messageData),
            tokenAmounts: tokenAmounts,
            extraArgs: "",
            feeToken: i_link
        });

        emit Debug("message id");
        bytes32 messageId;
        messageId = IRouterClient(i_router).ccipSend(
            destinationChainSelector,
            message
        );

        emit MessageSent(messageId);
    }

    function sendToken(
        uint64 destinationChainSelector,
        address receiver,
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
            receiver: abi.encode(receiver),
            data: "",
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
    
}