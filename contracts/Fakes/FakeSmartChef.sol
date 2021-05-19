// SPDX-License-Identifier: MIT
pragma solidity 0.7.3;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract FakeSmartChef{
    using SafeMath for uint256;

    // The CAKE TOKEN!
    address public depositToken;
    address public rewardToken;

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
    }

    // Info of each user that stakes LP tokens.
    mapping(address => UserInfo) public userInfo;

    uint256 public rewardAmount;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);

    constructor(address _depositToken, address _rewardToken) public {
        depositToken = _depositToken;
        rewardToken = _rewardToken;
    }

    // View function to see pending Reward on frontend.
    function pendingReward(address _user) external view returns (uint256) {
        return rewardAmount;
    }

    function setRewardAmount(uint256 _rewardAmount) public {
        rewardAmount = _rewardAmount;
    }




    // Stake depositToken tokens to SmartChef
    function deposit(uint256 _amount) public {

        UserInfo storage user = userInfo[msg.sender];
        
        if (user.amount > 0) {
            if (rewardAmount > 0) {
                IERC20(rewardToken).transfer(address(msg.sender), rewardAmount);
            }
        }
        if (_amount > 0) {
            IERC20(depositToken).transferFrom(
                address(msg.sender),
                address(this),
                _amount
            );
            user.amount = user.amount.add(_amount);
        }

        emit Deposit(msg.sender, _amount);
    }

    // Withdraw depositToken tokens from STAKING.
    function withdraw(uint256 _amount) public {
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= _amount, "withdraw: not good");

        if (rewardAmount > 0) {
            IERC20(rewardToken).transfer(address(msg.sender), rewardAmount);
        }
        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            IERC20(depositToken).transfer(address(msg.sender), _amount);
        }

        emit Withdraw(msg.sender, _amount);
    }
}
