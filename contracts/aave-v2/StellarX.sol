// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./StellarXGovernance.sol";
import "./interfaces/IRelyer.sol";
import "./interfaces/IMorpho.sol";
contract StellarX is StellarXGovernance {
    using SafeTransferLib for ERC20;
    using DelegateCall for address;
    using WadRayMath for uint256;

    error AmountIsZero( );

    function supply(address _poolToken, uint256 _amount,uint32 _dstChainID ) external nonReentrant  {
        _supply(_poolToken, msg.sender, _amount, defaultMaxGasForMatching.supply,_dstChainID);
    }

    function supply(
        address _poolToken,
        address _onBehalf,
        uint256 _amount,
        uint32 _dstChainID
    ) external nonReentrant{
        _supply(_poolToken, _onBehalf, _amount, defaultMaxGasForMatching.supply,_dstChainID);
    }

    function supply(
        address _poolToken,
        address _onBehalf,
        uint256 _amount,
        uint256 _maxGasForMatching,
        uint32 _dstChainID
    ) external nonReentrant {
        _supply(_poolToken, _onBehalf, _amount, _maxGasForMatching,_dstChainID);
    }

    function borrow(address _poolToken, uint256 _amount,uint32 _dstChainID) external nonReentrant {
        _borrow(_poolToken, _amount,msg.sender, defaultMaxGasForMatching.borrow,_dstChainID);
    }

    function borrow(
        address _poolToken,
        uint256 _amount,
        uint256 _maxGasForMatching,
        address _onBehalf,
        uint32 _dstChainID
    ) external nonReentrant verifyCaller(_onBehalf){
        _borrow(_poolToken, _amount,_onBehalf, _maxGasForMatching,_dstChainID);
    }
    //borrow3 ,用于代表别人借贷
    function withdraw(address _poolToken, uint256 _amount,uint32 _dstChainID) external nonReentrant {
        _withdraw(_poolToken, _amount, msg.sender,msg.sender, defaultMaxGasForMatching.withdraw,_dstChainID);
    }

    function withdraw(
        address _poolToken,
        uint256 _amount,
        address _onBehalf,
        address _receiver,
        uint32 _dstChainID
    ) external nonReentrant  verifyCaller(_onBehalf) {
        _withdraw(_poolToken, _amount,_onBehalf, _receiver, defaultMaxGasForMatching.withdraw,_dstChainID);
    }
    
    function repay(address _poolToken, uint256 _amount,uint32 _dstChainID) external nonReentrant {
        _repay(_poolToken, msg.sender, _amount, defaultMaxGasForMatching.repay,_dstChainID);
    }
    function repay(
        address _poolToken,
        address _onBehalf,
        uint256 _amount,
        uint32 _dstChainID
    ) external nonReentrant {
        _repay(_poolToken, _onBehalf, _amount, defaultMaxGasForMatching.repay,_dstChainID);
    }

    function liquidate(
        address _poolTokenBorrowed,
        address _poolTokenCollateral,
        address _liquidator,
        address _borrower,
        uint256 _amount,
        uint32 _dstChainID
    ) external nonReentrant  verifyCaller(_liquidator) ensureChainID(_dstChainID){
        if (_amount == 0) revert AmountIsZero();
        if(_dstChainID!=CURRENT_CHAINID){
             //transferFrom asset,cross it
            //crossCall();
            address underlying=market[_poolTokenBorrowed].underlyingToken;
            ERC20(underlying).safeTransferFrom(msg.sender, relyer, _amount);
            IRelyer.MessageData memory crossMessage=IRelyer.MessageData({
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
            IRelyer.EVMTokenAmount[] memory crossTokens=new IRelyer.EVMTokenAmount[](1);
            crossTokens[0] = (IRelyer.EVMTokenAmount({
                token:underlying,
                amount:_amount
            }));
            IRelyer(relyer).sendMessageAndToken(_dstChainID,crossMessage,crossTokens);
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
            IRelyer.MessageData memory crossMessage=IRelyer.MessageData({
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
            IRelyer.EVMTokenAmount[] memory crossTokens=new IRelyer.EVMTokenAmount[](1);
            crossTokens[0] = (IRelyer.EVMTokenAmount({
                token:underlying,
                amount:_amount
            }));
            IRelyer(relyer).sendMessageAndToken(_dstChainID,crossMessage,crossTokens);
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
        uint32 _dstChainID
    ) internal ensureChainID(_dstChainID){
        if (_amount == 0) revert AmountIsZero();
        if(_dstChainID!=CURRENT_CHAINID){
            //transferFrom asset,cross it
            //crossCall();
            IRelyer.MessageData memory crossMessage=IRelyer.MessageData({
                user:msg.sender,
                callData:abi.encodeWithSelector(
                IMorpho.borrow.selector,
                _poolToken,
                _amount,
                 _maxGasForMatching,
                _borrower,
                _dstChainID
                )
            });
            
            IRelyer(relyer).sendMessage(_dstChainID,crossMessage);
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
            IRelyer.MessageData memory crossMessage=IRelyer.MessageData({
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
            IRelyer(relyer).sendMessage(_dstChainID,crossMessage);
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
            IRelyer.MessageData memory crossMessage=IRelyer.MessageData({
                user:msg.sender,
                callData:abi.encodeWithSelector(
                IMorpho.repay.selector,
                _poolToken,
                _onBehalf,
                _amount,
                _dstChainID
                )
            });
            IRelyer.EVMTokenAmount[] memory crossTokens=new IRelyer.EVMTokenAmount[](1);
            crossTokens[0] = (IRelyer.EVMTokenAmount({
                token:underlying,
                amount:_amount
            }));
            IRelyer(relyer).sendMessageAndToken(_dstChainID,crossMessage,crossTokens);
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
