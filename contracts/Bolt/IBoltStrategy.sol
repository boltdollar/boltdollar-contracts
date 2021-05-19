// SPDX-License-Identifier: MIT
pragma solidity 0.7.3;

// For interacting with our own strategy
interface IBoltStrategy {
    // Total want tokens managed by stratfegy
    function DepositedLockedTotal() external view returns (uint256);

    // Gets the pending yield from the current earned tokens
    function PendingYieldTotal() external view returns (uint256);

    // Transfer want tokens yetiFarm -> strategy
    function deposit(uint256 _wantAmt)
        external
        returns (uint256);

    // Transfer want tokens strategy -> yetiFarm
    function withdraw(uint256 _wantAmt)
        external
        returns (uint256);

    // Converts 3rd party earned tokens to yield tokens and sends back to master
    function fetchYield() external;

    function depositTokenAddress() external returns (address);
}