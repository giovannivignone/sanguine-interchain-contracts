// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {AbstractProcessor} from "../../src/processors/AbstractProcessor.sol";

import {MockERC20} from "../mocks/MockERC20.sol";
import {MockInterchainERC20} from "../mocks/MockInterchainERC20.sol";
import {MockInterchainFactory} from "../mocks/MockInterchainFactory.sol";

import {Test} from "forge-std/Test.sol";

// solhint-disable func-name-mixedcase
// solhint-disable ordering
abstract contract AbstractProcessorTest is Test {
    AbstractProcessor public processor;
    MockInterchainERC20 public icToken;
    MockERC20 public token;
    MockInterchainFactory public factory;

    address public user;
    uint256 public constant START_BALANCE = 1000;

    function setUp() public {
        user = makeAddr("User");
        factory = new MockInterchainFactory();
        deployTokens();
        deployProcessor();
        // Mint initial balances
        token.mintPublic(user, START_BALANCE);
        icToken.mintPublic(user, START_BALANCE);
        // Setup mint/burn limits to infinite
        icToken.setMintLimit(address(processor), type(uint256).max);
        icToken.setBurnLimit(address(processor), type(uint256).max);
        // Approve user tokens for spending
        vm.prank(user);
        token.approve(address(processor), START_BALANCE);
        vm.prank(user);
        icToken.approve(address(processor), START_BALANCE);
    }

    function deployTokens() internal virtual;
    function deployProcessor() internal virtual;

    function test_constructor() public {
        assertEq(address(processor.INTERCHAIN_TOKEN()), address(icToken));
        assertEq(address(processor.UNDERLYING_TOKEN()), address(token));
    }

    function test_getToken() public {
        assertEq(address(processor.getToken(0)), address(icToken));
        assertEq(address(processor.getToken(1)), address(token));
    }

    function test_calculateSwap() public {
        assertEq(processor.calculateSwap(0, 1, 100), 100);
        assertEq(processor.calculateSwap(1, 0, 100), 100);
    }

    function test_calculateSwap_returnsZeroForSameToken() public {
        assertEq(processor.calculateSwap(0, 0, 100), 0);
        assertEq(processor.calculateSwap(1, 1, 100), 0);
    }

    function test_calculateSwap_returnsZeroForOutOfBoundsIndex() public {
        assertEq(processor.calculateSwap(2, 0, 100), 0);
        assertEq(processor.calculateSwap(0, 2, 100), 0);
    }

    function test_swap_revert_equalIndices() public {
        vm.expectRevert(abi.encodeWithSelector(AbstractProcessor.AbstractProcessor__EqualIndices.selector, 1));
        vm.prank(user);
        processor.swap(1, 1, 100, 0, type(uint256).max);
    }

    function test_swap_revert_fromIndexOutOfBounds() public {
        vm.expectRevert(abi.encodeWithSelector(AbstractProcessor.AbstractProcessor__IndexOutOfBounds.selector, 2));
        vm.prank(user);
        processor.swap(2, 0, 100, 0, type(uint256).max);
    }

    function test_swap_revert_toIndexOutOfBounds() public {
        vm.expectRevert(abi.encodeWithSelector(AbstractProcessor.AbstractProcessor__IndexOutOfBounds.selector, 3));
        vm.prank(user);
        processor.swap(0, 3, 100, 0, type(uint256).max);
    }
}
