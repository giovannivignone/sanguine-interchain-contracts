// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {LockingProcessor} from "../../src/processors/LockingProcessor.sol";

import {MockERC20} from "../mocks/MockERC20.sol";
import {MockInterchainERC20} from "../mocks/MockInterchainERC20.sol";

import {AbstractProcessor, AbstractProcessorTest} from "./AbstractProcessor.t.sol";

// solhint-disable func-name-mixedcase
// solhint-disable ordering
contract LockingProcessorTest is AbstractProcessorTest {
    function deployTokens() internal virtual override {
        token = new MockERC20("Token");
        icToken = new MockInterchainERC20("IC Token");
    }

    function deployProcessor() internal virtual override {
        address deployedProcessor = factory.deployLockingProcessor(address(icToken), address(token));
        processor = LockingProcessor(deployedProcessor);
        // Mint the underlying token to the processor (backing the user IC token balance)
        token.mintPublic(deployedProcessor, START_BALANCE);
    }

    function test_constructor_revert_interchainTokenZeroAddress() public {
        vm.expectRevert(AbstractProcessor.AbstractProcessor__TokenAddressZero.selector);
        factory.deployLockingProcessor(address(0), address(token));
    }

    function test_constructor_revert_underlyingTokenZeroAddress() public {
        vm.expectRevert(AbstractProcessor.AbstractProcessor__TokenAddressZero.selector);
        factory.deployLockingProcessor(address(icToken), address(0));
    }

    function test_calculateSwap_exactlyProcessorBalance() public {
        assertEq(processor.calculateSwap(0, 1, START_BALANCE), START_BALANCE);
        assertEq(processor.calculateSwap(1, 0, START_BALANCE), START_BALANCE);
    }

    function test_calculateSwap_overProcessorBalance() public {
        // Should not be possible to unlock more than the processor balance
        assertEq(processor.calculateSwap(0, 1, START_BALANCE + 1), 0);
        // Could lock any amount of tokens
        assertEq(processor.calculateSwap(1, 0, START_BALANCE + 1), START_BALANCE + 1);
    }

    // Lock token: token (1) -> icToken (0)
    function test_swap_lockUnderlyingToken() public {
        uint256 amount = 100;
        vm.prank(user);
        processor.swap(1, 0, amount, 0, type(uint256).max);
        // Check underlying token balances
        assertEq(token.balanceOf(user), START_BALANCE - amount);
        assertEq(token.balanceOf(address(processor)), START_BALANCE + amount);
        // Check IC token balance
        assertEq(icToken.balanceOf(user), START_BALANCE + amount);
        assertEq(icToken.balanceOf(address(processor)), 0);
    }

    // Unlock token: icToken (0) -> token (1)
    function test_swap_unlockUnderlyingToken() public {
        uint256 amount = 100;
        vm.prank(user);
        processor.swap(0, 1, amount, 0, type(uint256).max);
        // Check underlying token balance
        assertEq(token.balanceOf(user), START_BALANCE + amount);
        assertEq(token.balanceOf(address(processor)), START_BALANCE - amount);
        // Check IC token balance
        assertEq(icToken.balanceOf(user), START_BALANCE - amount);
        assertEq(icToken.balanceOf(address(processor)), 0);
    }
}
