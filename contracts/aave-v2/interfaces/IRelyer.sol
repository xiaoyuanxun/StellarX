pragma solidity >=0.5.0;

interface IRelyer {
    struct MessageData {
        address user;
        bytes callData;        
       /* address destinationExacuteContract;
        uint chainId;*/
    }
    function sendMessageAndToken(
        uint32 chainID,
        MessageData memory messageData,
        EVMTokenAmount[] memory tokensToSendDetails
    ) external;
    function sendMessage(
        uint32 dstChainID, 
        MessageData memory messageData
    ) external ;
    struct EVMTokenAmount {
        address token; // token address on the local chain.
        uint256 amount; // Amount of tokens.
    }
}