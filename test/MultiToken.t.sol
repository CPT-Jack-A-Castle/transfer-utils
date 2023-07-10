// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/MultiToken.sol";
import "openzeppelin/token/ERC20/ERC20.sol";

contract StubERC20 is ERC20 {
    constructor(string memory name) ERC20(name, "STB") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MultiTokenTest is Test {
    address owner = address(0x11);
    address proxy = address(0x01);
    address destination = address(0x02);
    address approver = address(0x12);
    address approver2 = address(0x13);

    uint256 MAX = type(uint256).max;

    MultiToken public sut;
    StubERC20 public usdc;
    StubERC20 public weth;

    function setUp() public {
        vm.prank(owner);
        sut = new MultiToken();
        usdc = new StubERC20("USDC");
        weth = new StubERC20("WETH");
    }

    function testListTokens() public {
        address[] memory tokens = sut.listTokens();
        assertEq(tokens.length, 0, "should have no tokens");
    }

    function testMissingApprovals() public {
        address[] memory tokens = sut.missingApprovals();
        assertEq(tokens.length, 0, "should have no tokens");
    }

    function test_transferAll() public {
        // give approver some tokens
        usdc.mint(approver, 100);
        weth.mint(approver, 200);

        // approver must approve contract to spend tokens
        setupApprovalsForApprover(approver, MAX);
        setupTokens();

        vm.prank(proxy);
        sut.transferAll(proxy);

        assertEq(usdc.balanceOf(approver), 0, "should have 0 token1");
        assertEq(weth.balanceOf(approver), 0, "should have 0 token2");
        assertEq(usdc.balanceOf(proxy), 100, "should have 100 token1");
        assertEq(weth.balanceOf(proxy), 200, "should have 200 token2");
    }

    function test_transferAll_should_notSendMoreThatApprovedAmount() public {
        // give approver some tokens
        usdc.mint(approver, 100);
        weth.mint(approver, 200);

        setupApprovalsForApprover(approver, 50);
        setupTokens();

        vm.prank(proxy);
        sut.transferAll(proxy);

        assertEq(usdc.balanceOf(approver), 50, "should have 50 token1");
        assertEq(weth.balanceOf(approver), 150, "should have 50 token2");
        assertEq(usdc.balanceOf(proxy), 50, "should have 50 token1");
        assertEq(weth.balanceOf(proxy), 50, "should have 50 token2");
    }

    function test_transferAll_should_notFailIfATokenHasNotBeenApprovedOrRevoked()
        public
    {
        // give approver some tokens
        usdc.mint(approver, 100);
        weth.mint(approver, 200);

        // approver must approve contract to spend tokens
        setupTokens();
        setupApprovalsForApprover(approver, 50);
        vm.prank(approver);
        weth.approve(address(sut), 0); // revoke approval for token2

        vm.prank(proxy);
        sut.transferAll(proxy);

        assertEq(usdc.balanceOf(proxy), 50, "should have 50 token1");
        assertEq(weth.balanceOf(proxy), 0, "should have 50 token2");
    }

    function test_transferAll_should_takeFundsFromMultipleApprovers() public {
        // give approver some tokens
        usdc.mint(approver, 100);
        weth.mint(approver, 200);
        usdc.mint(approver2, 50);
        weth.mint(approver2, 150);

        // approver must approve contract to spend tokens
        setupApprovalsForApprover(approver, 50);
        setupApprovalsForApprover(approver2, 25);
        setupTokens();

        vm.prank(proxy);
        sut.transferAll(destination);

        require(
            usdc.balanceOf(destination) == 75,
            "desitnation balance should be 75"
        );
        require(
            weth.balanceOf(destination) == 75,
            "desitnation balance should be 75"
        );
    }

    function test_transferAll_should_revertWhenSendingToZeroAddress() public {
        // give approver some tokens
        usdc.mint(approver, 100);
        weth.mint(approver, 200);

        // approver must approve contract to spend tokens
        setupApprovalsForApprover(approver, 50);
        setupTokens();

        vm.prank(owner);
        vm.expectRevert();
        sut.transferAll(address(0));
    }

    function test_transferAll_should_revertWhenProxyIsNotApprovedByApprover()
        public
    {
        setupTokens();

        // give approver some tokens
        usdc.mint(approver, 100);
        weth.mint(approver, 200);

        // approver must approve contract to spend tokens

        vm.startPrank(approver);
        //approve tokens to be spent
        usdc.approve(address(sut), MAX);
        weth.approve(address(sut), MAX);
        vm.stopPrank();

        vm.prank(proxy);
        vm.expectRevert();
        sut.transferAll(destination);
    }

    function setupTokens() internal {
        vm.startPrank(owner);
        address[] memory addresses = new address[](2);
        addresses[0] = (address(usdc));
        addresses[1] = (address(weth));
        sut.addTokens(addresses);
        vm.stopPrank();
    }

    function setupApprovalsForApprover(
        address _approver,
        uint256 amount
    ) internal {
        vm.startPrank(_approver);
        //approve tokens to be spent
        usdc.approve(address(sut), amount);
        weth.approve(address(sut), amount);
        sut.approveProxy(proxy); // approver approves proxy to spend tokens
        vm.stopPrank();
    }
}
