// SPDX-License-Identifier: MIT
pragma solidity 0.7.3;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./IBoltStrategy.sol";
import "./IBoltMaster.sol";

contract BoltMaster is Ownable, Pausable, ReentrancyGuard, IBoltMaster {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many amount tokens the user has provided.
        uint256 rewardDebt; //unentitled rewards
    }

    struct PoolInfo {
        address want; // Address of the want token.
        uint256 accumulatedYieldPerShare; // Accumulated per share, times 1e12. See below.
        address strat; // Strategy address that will farm from want tokens
    }

    address private burnAddress = 0x0000000000000000000000000000000000000000;

    address public yieldToken;

    PoolInfo public poolInfo;
    mapping(address => UserInfo) public userInfo; // Info of each user that stakes LP tokens.

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);

    constructor(address _depositToken, address _yieldToken)
    {
        yieldToken = _yieldToken;
        poolInfo = PoolInfo({
            want: _depositToken,
            accumulatedYieldPerShare: 0,
            strat: burnAddress
        });
    }


    // Update reward variables of the given pool to be up-to-date.
    // Because yield from external pools isn't deterministic, we have to update users after the next deposit/witdraw.
    modifier updatePool()
    {
        IBoltStrategy strat = IBoltStrategy(poolInfo.strat);
        uint256 totalShares = strat.DepositedLockedTotal();

        if (totalShares > 0) {
            strat.fetchYield();
            uint256 totalYielded = IERC20(poolInfo.want).balanceOf(address(this));

            poolInfo.accumulatedYieldPerShare = poolInfo.accumulatedYieldPerShare.add(
                totalYielded.mul(1e12).div(totalShares)
            );
        }
        _;
    }

    function pendingYield(address _user) public view returns (uint256)
    {
        UserInfo memory user = userInfo[_user];
        return poolInfo.accumulatedYieldPerShare.mul(user.amount).div(1e12).sub(user.rewardDebt);
    }

    function swapPool(address _newStrategy) public onlyOwner
    {
        IBoltStrategy oldStrat = IBoltStrategy(poolInfo.strat);
        IBoltStrategy newStrat = IBoltStrategy(_newStrategy);

        require(oldStrat.depositTokenAddress() == newStrat.depositTokenAddress(), "!wantToken");

        pullStratDeposit();

        poolInfo.strat = _newStrategy;
        IERC20(poolInfo.want).safeApprove(_newStrategy, uint256(-1) );

        depositAll();
    }

    function pullStratDeposit() private updatePool
    {
        uint256 stratBal = IERC20(poolInfo.want).balanceOf(poolInfo.strat);
        IBoltStrategy(poolInfo.strat).withdraw(stratBal);
    } 

    function depositAll() private
    {
        IBoltStrategy strat = IBoltStrategy(poolInfo.strat);
        uint256 balance = IERC20(poolInfo.want).balanceOf(address(this));
        strat.deposit(balance);
    }
    
    function deposit(uint256 _wantAmt) public whenNotPaused nonReentrant updatePool
    {
        UserInfo storage user = userInfo[msg.sender];

        // Send sender what we owe them.
        if (user.amount > 0) {
            uint256 pending = pendingYield(msg.sender);
            safeYieldTransfer(msg.sender, pending);
        }

        uint256 amountDeposited = 0;

        // Deposit into strat
        if (_wantAmt > 0) {
            // Get from user
            IERC20(poolInfo.want).safeTransferFrom(msg.sender, address(this), _wantAmt);
            // Track user deposit
            user.amount = user.amount.add(_wantAmt);
            // Send deposit to strategy.
            amountDeposited = IBoltStrategy(poolInfo.strat).deposit(_wantAmt);
        }

        user.rewardDebt = user.amount.mul(poolInfo.accumulatedYieldPerShare).div(1e12);

        emit Deposit(msg.sender, amountDeposited);
    }

    // Withdraw LP tokens from BoltMaster.
    function withdraw(uint256 _wantAmt) public whenNotPaused nonReentrant updatePool
    {
        PoolInfo storage pool = poolInfo; 
        UserInfo storage user = userInfo[msg.sender];
        uint256 total = IBoltStrategy(pool.strat).DepositedLockedTotal();
        require(user.amount > 0, "user.amount is 0");
        require(total > 0, "Total is 0");
        // Withdraw pending yield
        uint256 pending = pendingYield(msg.sender);
        if (pending > 0) {
            safeYieldTransfer(msg.sender, pending);
        }

        //Withdraw want tokens
        _wantAmt = Math.min(_wantAmt, user.amount);
        uint256 amountRemoved = 0;
        if (_wantAmt > 0) {
            amountRemoved = IBoltStrategy(pool.strat).withdraw(_wantAmt);
            if (amountRemoved > user.amount) {
                user.amount = 0;
            } else {
                user.amount = user.amount.sub(amountRemoved);
            }
            uint256 wantBal = IERC20(pool.want).balanceOf(address(this));
            _wantAmt = Math.min(wantBal, _wantAmt);
            IERC20(pool.want).safeTransfer(address(msg.sender), _wantAmt);
        }
        user.rewardDebt = user.amount.mul(pool.accumulatedYieldPerShare).div(1e12);

        emit Withdraw(msg.sender, amountRemoved);
    }

    // Safe transfer function, just in case if rounding error causes pool to not have enough
    function safeYieldTransfer(address _to, uint256 toTransfer) private
    {
        toTransfer = Math.min(toTransfer, IERC20(yieldToken).balanceOf(address(this)));
        IERC20(yieldToken).safeTransfer(_to, toTransfer);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw() public nonReentrant
    {
        PoolInfo storage pool = poolInfo;
        UserInfo storage user = userInfo[msg.sender];

        uint256 amount = user.amount;

        uint256 withdrawn = IBoltStrategy(pool.strat).withdraw(amount);

        user.amount = 0;
        user.rewardDebt = 0;
        IERC20(pool.want).safeTransfer(address(msg.sender), withdrawn);
        emit EmergencyWithdraw(msg.sender, withdrawn);
    }

}
