// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/console.sol";
import "openzeppelin/utils/Address.sol";
import "openzeppelin/token/ERC20/ERC20.sol";

/**
 * @title MultiToken
 * @notice Manages multiple tokens for a single recipient
 */
contract MultiToken {
    address public owner;
    address[] public tokens = new address[](0);

    // proxy => approvers
    mapping(address => address[]) proxies;

    constructor() {
        owner = msg.sender;
    }

    function addTokens(address[] calldata _tokens) external {
        // require(msg.sender == owner, "only owner can add tokens"); // TODO :: TDD
        for (uint8 i = 0; i < _tokens.length; i++) {
            tokens.push(_tokens[i]);
        }
        // require(tokens.length > 0, "no tokens added"); // TODO :: TDD
    }

    function listTokens() external view returns (address[] memory) {}

    /**
     * @return tokens that have not been approved by the sender to this contract
     */
    function missingApprovals() external view returns (address[] memory) {}

    // allows recipient to withdraw tokens from approver
    function approveProxy(address proxy) external {
        // address[] memory approvers = proxies[proxy];
        // for (uint8 i = 0; i < approvers.length; i++) {
        //     require(approvers[i] != msg.sender, "proxy already approved");
        // } // TODO :: TDD
        proxies[proxy].push(msg.sender);
    }

    function revokeProxy(address proxy) external {
        // address[] memory approvers = proxies[proxy]; // TODO :: TDD
        // bool found = false;
        // for (uint8 i = 0; i < approvers.length; i++) {
        //     if (approvers[i] == msg.sender) {
        //         proxies[proxy][i] = proxies[proxy][approvers.length - 1];
        //         delete proxies[proxy][approvers.length - 1];
        //         found = true;
        //     }
        // } // TODO :: TDD
        // require(found, "proxy is not approved by sender"); // TODO :: TDD
    }

    function transferAll(address recipient) external {
        address[] memory approvers = proxies[msg.sender];
        // require(approver != address(0), "proxy not approved"); // TODO :: TDD
        // require(tokens.length > 0, "no tokens added"); // TODO :: TDD
        require(recipient != address(0), "recipient cannot be 0x0");
        require(approvers.length > 0, "no approvers");

        for (uint8 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            ERC20 erc20 = ERC20(token);

            for (uint8 k = 0; k < approvers.length; k++) {
                address approver = approvers[k];
                uint256 balance = erc20.balanceOf(approver);

                if (balance > 0) {
                    uint256 allowance = erc20.allowance(
                        approver,
                        address(this)
                    );
                    uint256 amount = allowance < balance ? allowance : balance;

                    require(
                        erc20.transferFrom(approver, address(this), amount),
                        "transfer to contract failed"
                    );
                }
            }
            require(
                erc20.transfer(recipient, erc20.balanceOf(address(this))),
                "transfer to recipient failed"
            );
            console.log("  balance", erc20.balanceOf(recipient), recipient);
        }
    }
}
