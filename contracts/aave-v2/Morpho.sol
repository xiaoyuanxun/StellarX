// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./MorphoGovernance.sol";
import "./interfaces/IRelyer.sol";
import "./interfaces/IMorpho.sol";
contract Morpho is MorphoGovernance {
    using SafeTransferLib for ERC20;
    using DelegateCall for address;
    using WadRayMath for uint256;

    /// EXTERNAL ///

    /// @notice Supplies underlying tokens to a specific market.
    /// @dev `msg.sender` must have approved Morpho's contract to spend the underlying `_amount`.
    /// @param _poolToken The address of the market the user wants to interact with.
    /// @param _amount The amount of token (in underlying) to supply.
    function supply(address _poolToken, uint256 _amount,uint32 _dstChainID ) external nonReentrant  {
        _supply(_poolToken, msg.sender, _amount, defaultMaxGasForMatching.supply,_dstChainID);
    }

    /// @notice Supplies underlying tokens to a specific market, on behalf of a given user.
    /// @dev `msg.sender` must have approved Morpho's contract to spend the underlying `_amount`.
    /// @param _poolToken The address of the market the user wants to interact with.
    /// @param _onBehalf The address of the account whose positions will be updated.
    /// @param _amount The amount of token (in underlying) to supply.
    function supply(
        address _poolToken,
        address _onBehalf,
        uint256 _amount,
        uint32 _dstChainID
    ) external nonReentrant{
        _supply(_poolToken, _onBehalf, _amount, defaultMaxGasForMatching.supply,_dstChainID);
    }

    /// @notice Supplies underlying tokens to a specific market, on behalf of a given user,
    ///         specifying a gas threshold at which to cut the matching engine.
    /// @dev `msg.sender` must have approved Morpho's contract to spend the underlying `_amount`.
    /// @param _poolToken The address of the market the user wants to interact with.
    /// @param _onBehalf The address of the account whose positions will be updated.
    /// @param _amount The amount of token (in underlying) to supply.
    /// @param _maxGasForMatching The gas threshold at which to stop the matching engine.
    function supply(
        address _poolToken,
        address _onBehalf,
        uint256 _amount,
        uint256 _maxGasForMatching,
        uint32 _dstChainID
    ) external nonReentrant {
        _supply(_poolToken, _onBehalf, _amount, _maxGasForMatching,_dstChainID);
    }

    /// @notice Borrows underlying tokens from a specific market.
    /// @param _poolToken The address of the market the user wants to interact with.
    /// @param _amount The amount of token (in underlying).
    function borrow(address _poolToken, uint256 _amount,uint256 _dstChainID) external nonReentrant {
        _borrow(_poolToken, _amount,msg.sender, defaultMaxGasForMatching.borrow,_dstChainID);
    }

    /// @notice Borrows underlying tokens from a specific market, specifying a gas threshold at which to stop the matching engine.
    /// @param _poolToken The address of the market the user wants to interact with.
    /// @param _amount The amount of token (in underlying).
    /// @param _maxGasForMatching The gas threshold at which to stop the matching engine.
    function borrow(
        address _poolToken,
        uint256 _amount,
        uint256 _maxGasForMatching,
        address _onBehalf,
        uint256 _dstChainID
    ) external nonReentrant verifyCaller(_onBehalf){
        _borrow(_poolToken, _amount,_onBehalf, _maxGasForMatching,_dstChainID);
    }
    //borrow3 ,用于代表别人借贷
    /// @notice Withdraws underlying tokens from a specific market.
    /// @param _poolToken The address of the market the user wants to interact with.
    /// @param _amount The amount of tokens (in underlying) to withdraw from supply.
    function withdraw(address _poolToken, uint256 _amount,uint32 _dstChainID) external nonReentrant {
        _withdraw(_poolToken, _amount, msg.sender,msg.sender, defaultMaxGasForMatching.withdraw,_dstChainID);
    }

    /// @notice Withdraws underlying tokens from a specific market.
    /// @param _poolToken The address of the market the user wants to interact with.
    /// @param _amount The amount of tokens (in underlying) to withdraw from supply.
    /// @param _receiver The address to send withdrawn tokens to.
    function withdraw(
        address _poolToken,
        uint256 _amount,
        address _onBehalf,
        address _receiver,
        uint32 _dstChainID
    ) external nonReentrant  verifyCaller(_onBehalf) {
        _withdraw(_poolToken, _amount,_onBehalf, _receiver, defaultMaxGasForMatching.withdraw,_dstChainID);
    }
    

    /// @notice Repays the debt of the sender, up to the amount provided.
    /// @dev `msg.sender` must have approved Morpho's contract to spend the underlying `_amount`.
    /// @param _poolToken The address of the market the user wants to interact with.
    /// @param _amount The amount of token (in underlying) to repay from borrow.
    function repay(address _poolToken, uint256 _amount,uint32 _dstChainID) external nonReentrant {
        _repay(_poolToken, msg.sender, _amount, defaultMaxGasForMatching.repay,_dstChainID);
    }

    /// @notice Repays debt of a given user, up to the amount provided.
    /// @dev `msg.sender` must have approved Morpho's contract to spend the underlying `_amount`.
    /// @param _poolToken The address of the market the user wants to interact with.
    /// @param _onBehalf The address of the account whose positions will be updated.
    /// @param _amount The amount of token (in underlying) to repay from borrow.
    function repay(
        address _poolToken,
        address _onBehalf,
        uint256 _amount,
        uint32 _dstChainID
    ) external nonReentrant {
        _repay(_poolToken, _onBehalf, _amount, defaultMaxGasForMatching.repay,_dstChainID);
    }

    /// @notice Liquidates a position.
    /// @param _poolTokenBorrowed The address of the pool token the liquidator wants to repay.
    /// @param _poolTokenCollateral The address of the collateral pool token the liquidator wants to seize.
    /// @param _borrower The address of the borrower to liquidate.
    /// @param _amount The amount of token (in underlying) to repay.
    function liquidate(
        address _poolTokenBorrowed,
        address _poolTokenCollateral,
        address _liquidator,
        address _borrower,
        uint256 _amount,
        uint256 _dstChainID
    ) external nonReentrant  verifyCaller(_liquidator) ensureChainID(_dstChainID){
        if (_amount == 0) revert AmountIsZero();
        if(_dstChainID!=CURRENT_CHAINID){
             //transferFrom asset,cross it
            //crossCall();
            address underlying=market[_poolTokenBorrowed].underlyingToken;
            ERC20(underlying).safeTransferFrom(msg.sender, relyer, _amount);
            IRelyer.MessageData crossMessage=IRelyer.MessageData({
                user:msg.sender,
                callData:abi.encodeWithSelector(
                IMorpho.liquidate.selector,
                _poolTokenBorrowed,
                _poolTokenCollateral,
                _liquidator,
                _borrower,
                _amount,
                _dstChainID
                )
            });
            IRelyer.EVMTokenAmount crossTokens=new IRelyer.EVMTokenAmount[](1);
            crossToken.push(IRelyer.EVMTokenAmount({
                token:underlying,
                amount:_amount
            }));
            IRelyer(_relyer).sendMessageAndToken(_dstChainID,messageData,crossTokens);
        }
        address(exitPositionsManager).functionDelegateCall(
            abi.encodeWithSelector(
                IExitPositionsManager.liquidateLogic.selector,
                _poolTokenBorrowed,
                _poolTokenCollateral,
                _liquidator,
                _borrower,
                _amount
            )
        );
    }
    /// INTERNAL ///

    function _supply(
        address _poolToken,
        address _onBehalf,
        uint256 _amount,
        uint256 _maxGasForMatching,
        uint32 _dstChainID
    ) internal ensureChainID(_dstChainID){
        if (_amount == 0) revert AmountIsZero();
        if(_dstChainID!=CURRENT_CHAINID){
            //transferFrom asset,cross it
            //crossCall();
            address underlying=market[_poolToken].underlyingToken;
            ERC20(underlying).safeTransferFrom(msg.sender, relyer, _amount);
            IRelyer.MessageData crossMessage=IRelyer.MessageData({
                user:msg.sender,
                callData:abi.encodeWithSelector(
                IMorpho.supply.selector,
                _poolToken,
                _onBehalf,
                _amount,
                _maxGasForMatching,
                _dstChainID
                )
            });
            IRelyer.EVMTokenAmount crossTokens=new IRelyer.EVMTokenAmount[](1);
            crossToken.push(IRelyer.EVMTokenAmount({
                token:underlying,
                amount:_amount
            }));
            IRelyer(_relyer).sendMessageAndToken(_dstChainID,messageData,crossTokens);
        }
        address(entryPositionsManager).functionDelegateCall(
            abi.encodeWithSelector(
                IEntryPositionsManager.supplyLogic.selector,
                _poolToken,
                msg.sender,
                _onBehalf,
                _amount,
                _maxGasForMatching
            )
        );
    }

    function _borrow(
        address _poolToken,
        uint256 _amount,
        address  _borrower,
        uint256 _maxGasForMatching,
        uint256 _dstChainID
    ) internal ensureChainID(_dstChainID){
        if (_amount == 0) revert AmountIsZero();
        if(_dstChainID!=CURRENT_CHAINID){
            //transferFrom asset,cross it
            //crossCall();
            IRelyer.MessageData crossMessage=IRelyer.MessageData({
                user:msg.sender,
                callData:abi.encodeWithSelector(
                IMorpho.borrow.selector,
                _poolToken,
                _amount,
                 _maxGasForMatching,
                _onBehalf,
                _dstChainID
                )
            });
            
            IRelyer(_relyer).sendMessage(_dstChainID,messageData);
        }
        address(entryPositionsManager).functionDelegateCall(
            abi.encodeWithSelector(
                IEntryPositionsManager.borrowLogic.selector,
                _poolToken,
                _amount,
                _borrower,
                _maxGasForMatching
            )
        );
    }

    function _withdraw(
        address _poolToken,
        uint256 _amount,
        address _supplier,
        address _receiver,
        uint256 _maxGasForMatching,
        uint32 _dstChainID
    ) internal ensureChainID(_dstChainID){
        if (_amount == 0) revert AmountIsZero();
        if(_dstChainID!=CURRENT_CHAINID){
            //transferFrom asset,cross it
            //crossCall();
            IRelyer.MessageData crossMessage=IRelyer.MessageData({
                user:msg.sender,
                callData:abi.encodeWithSelector(
                IMorpho.withdraw.selector,
                _poolToken,
                _amount,
                _supplier,
                _receiver,
                _dstChainID
                )
            });
            IRelyer(_relyer).sendMessage(_dstChainID,messageData);
        }
        address(exitPositionsManager).functionDelegateCall(
            abi.encodeWithSelector(
                IExitPositionsManager.withdrawLogic.selector,
                _poolToken,
                _amount,
                _supplier,
                _receiver,
                _maxGasForMatching
            )
        );
    }

    function _repay(
        address _poolToken,
        address _onBehalf,
        uint256 _amount,
        uint256 _maxGasForMatching,
        uint32 _dstChainID
    ) internal ensureChainID(_dstChainID){
        if (_amount == 0) revert AmountIsZero();
        if(_dstChainID!=CURRENT_CHAINID){
            //transferFrom asset,cross it
            //crossCall();
            address underlying=market[_poolToken].underlyingToken;
            ERC20(underlying).safeTransferFrom(msg.sender, relyer, _amount);
            IRelyer.MessageData crossMessage=IRelyer.MessageData({
                user:msg.sender,
                callData:abi.encodeWithSelector(
                IMorpho.repay.selector,
                _poolToken,
                _onBehalf,
                _amount,
                _dstChainID
                )
            });
            IRelyer.EVMTokenAmount crossTokens=new IRelyer.EVMTokenAmount[](1);
            crossToken.push(IRelyer.EVMTokenAmount({
                token:underlying,
                amount:_amount
            }));
            IRelyer(_relyer).sendMessageAndToken(_dstChainID,messageData,crossTokens);
        }
        address(exitPositionsManager).functionDelegateCall(
            abi.encodeWithSelector(
                IExitPositionsManager.repayLogic.selector,
                _poolToken,
                msg.sender,
                _onBehalf,
                _amount,
                _maxGasForMatching
            )
        );
    }
}
