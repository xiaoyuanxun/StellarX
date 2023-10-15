// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {Withdraw} from "./utils/Withdraw.sol";
import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.0/token/ERC20/IERC20.sol";

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

    mapping(uint32 => uint64) chainIdToSelector;

    constructor(address router, address link) {
        i_router = router;
        i_link = link;
        i_maxTokensLength = 5;
        LinkTokenInterface(i_link).approve(i_router, type(uint256).max);
    }

    receive() external payable {}

    function sendMessage(
        uint64 destinationChainSelector, 
        address receiver,
        MessageData memory messageData
    ) external {
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: abi.encode(messageData),
            tokenAmounts: new Client.EVMTokenAmount[](0),
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

    function getChainSelector(uint32 chainID) internal returns(uint64) {
        return chainIdToSelector[chainID];
    }

    function initChainIdToSelector(uint32 chainID, uint64 chainSelector) public onlyOwner {
        chainIdToSelector[chainID] = chainSelector;
    }

    function sendMessageAndToken(
        uint32 chainID,
        address receiver,
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
            receiver: abi.encode(receiver),
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