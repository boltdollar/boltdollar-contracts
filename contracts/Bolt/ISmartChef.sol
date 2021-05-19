// SPDX-License-Identifier: MIT
pragma solidity 0.7.3;

// For interacting with the pancake smart chef syrup pools
interface ISmartChef {

    function pendingReward(address _user) external view returns (uint256);

    function setRewardAmount(uint256 _rewardAmount) external;

    function deposit(uint256 _amount) external;

    function withdraw(uint256 _amount) external;

}