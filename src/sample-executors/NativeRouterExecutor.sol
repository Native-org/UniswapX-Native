// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {Owned} from "solmate/src/auth/Owned.sol";
import {SafeTransferLib} from "solmate/src/utils/SafeTransferLib.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {WETH} from "solmate/src/tokens/WETH.sol";
import {IReactorCallback} from "../interfaces/IReactorCallback.sol";
import {IReactor} from "../interfaces/IReactor.sol";
import {CurrencyLibrary} from "../lib/CurrencyLibrary.sol";
import {ResolvedOrder, OutputToken, SignedOrder} from "../base/ReactorStructs.sol";
import {INativeRouter} from "../external/INativeRouter.sol";
import {INativeRouter} from "../external/INativeRouter.sol";

/// @notice A fill contract that uses NativeRouter to execute trades
contract NativeRouterExecutor is IReactorCallback, Owned {
    using SafeTransferLib for ERC20;
    using CurrencyLibrary for address;

    /// @notice thrown if reactorCallback is called with a non-whitelisted filler
    error CallerNotWhitelisted();
    /// @notice thrown if reactorCallback is called by an address other than the reactor
    error MsgSenderNotReactor();

    INativeRouter private immutable nativeRouter;

    address private immutable whitelistedCaller;
    IReactor private immutable reactor;
    WETH private immutable weth;

    modifier onlyWhitelistedCaller() {
        if (msg.sender != whitelistedCaller) {
            revert CallerNotWhitelisted();
        }
        _;
    }

    modifier onlyReactor() {
        if (msg.sender != address(reactor)) {
            revert MsgSenderNotReactor();
        }
        _;
    }

    constructor(address _whitelistedCaller, IReactor _reactor, address _owner, INativeRouter _nativeRouter)
        Owned(_owner)
    {
        whitelistedCaller = _whitelistedCaller;
        reactor = _reactor;
        nativeRouter = _nativeRouter;
        weth = WETH(payable(_nativeRouter.WETH9()));
    }

    /// @notice assume that we already have all output tokens
    // function execute(SignedOrder calldata order, bytes calldata callbackData) external onlyWhitelistedCaller {
    //     reactor.executeWithCallback(order, callbackData);
    // }

    /// @notice assume that we already have all output tokens
    // function executeBatch(SignedOrder[] calldata orders, bytes calldata callbackData) external onlyWhitelistedCaller {
    //     reactor.executeBatchWithCallback(orders, callbackData);
    // }

    /// @notice fill UniswapX orders using nativeRouter
    /// @param callbackData It has the below encoded:
    /// address[] memory tokensToApproveFornativeRouter: Max approve these tokens to nativeRouter
    /// address[] memory tokensToApproveForReactor: Max approve these tokens to reactor
    /// bytes[] memory multicallData: Pass into nativeRouter.multicall()
    function reactorCallback(ResolvedOrder[] calldata, bytes calldata callbackData) external onlyReactor {
        (
            address[] memory tokensToApproveFornativeRouter,
            address[] memory tokensToApproveForReactor,
            bytes[] memory multicallData
        ) = abi.decode(callbackData, (address[], address[], bytes[]));

        unchecked {
            for (uint256 i = 0; i < tokensToApproveFornativeRouter.length; i++) {
                ERC20(tokensToApproveFornativeRouter[i]).safeApprove(address(nativeRouter), type(uint256).max);
            }

            for (uint256 i = 0; i < tokensToApproveForReactor.length; i++) {
                ERC20(tokensToApproveForReactor[i]).safeApprove(address(reactor), type(uint256).max);
            }
        }

        nativeRouter.multicall(multicallData);

        // transfer any native balance to the reactor
        // it will refund any excess
        if (address(this).balance > 0) {
            CurrencyLibrary.transferNative(address(reactor), address(this).balance);
        }
    }

    /// @notice This function can be used to convert ERC20s to ETH that remains in this contract
    /// @param tokensToApprove Max approve these tokens to nativeRouter
    /// @param multicallData Pass into nativeRouter.multicall()
    function multicall(ERC20[] calldata tokensToApprove, bytes[] calldata multicallData) external onlyOwner {
        for (uint256 i = 0; i < tokensToApprove.length; i++) {
            tokensToApprove[i].safeApprove(address(nativeRouter), type(uint256).max);
        }
        nativeRouter.multicall(multicallData);
    }

    /// @notice Unwraps the contract's WETH9 balance and sends it to the recipient as ETH. Can only be called by owner.
    /// @param recipient The address receiving ETH
    function unwrapWETH(address recipient) external onlyOwner {
        uint256 balanceWETH = weth.balanceOf(address(this));

        weth.withdraw(balanceWETH);
        SafeTransferLib.safeTransferETH(recipient, address(this).balance);
    }

    /// @notice Transfer all ETH in this contract to the recipient. Can only be called by owner.
    /// @param recipient The recipient of the ETH
    function withdrawETH(address recipient) external onlyOwner {
        SafeTransferLib.safeTransferETH(recipient, address(this).balance);
    }

    /// @notice Necessary for this contract to receive ETH when calling unwrapWETH()
    receive() external payable {}
}
