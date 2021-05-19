// SPDX-License-Identifier: MIT
pragma solidity 0.7.3;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./IPancakeswapFarm.sol";
import "./IPancakeRouter02.sol";
import "./ISmartChef.sol";
import "./IBoltStrategy.sol";
import "./IBoltMaster.sol";

contract CakeBTDStrategy is Ownable, ReentrancyGuard, Pausable, IBoltStrategy {
    // Maximises yields in pancakeswap

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public farmContractAddress; // address of farm, eg, PCS, Thugs etc.

    address public uniRouterAddress; // uniswap, pancakeswap etc

    address public BoltMasterAddress;
    address public govAddress; // timelock contract
    bool public onlyGov = false;

    uint256 public depositedLockedTotal = 0;


    address[] public earnedToYieldPath;

    address public earnedTokenAddress; // Address of token from syrup pool.
    address public yieldTokenAddress; // Address of token to buy and return
    address public override depositTokenAddress;
    address public busdTokenAddress;

    address public treasuryAddress;
    address public devAddress;
    uint256 public devFees;
    uint256 public treasuryFees;
    uint256 private devFeesMax = 10000;
    uint256 private treasuryFeesMax = 10000;


    constructor(
        address _BoltMasterAddress,
        address _farmContractAddress, // Pancake Farm address
        address _depositTokenAddress, // token we're using to farm
        address _earnedTokenAddress, // token that we get back from farm.
        address _yieldTokenAddress, // token that we sell earned to.
        address _busdTokenAddress,
        address _uniRouterAddress,
        address _treasuryAddress,
        address _devAddress
    ) public {
        govAddress = msg.sender;
        BoltMasterAddress = _BoltMasterAddress;
        depositTokenAddress = _depositTokenAddress;
        yieldTokenAddress = _yieldTokenAddress;
        earnedTokenAddress = _earnedTokenAddress;
        farmContractAddress = _farmContractAddress;
        busdTokenAddress = _busdTokenAddress;
        uniRouterAddress = _uniRouterAddress;
        devAddress = _devAddress;
        treasuryAddress = _treasuryAddress;

        devFees = 0;
        treasuryFees = 0;

        // TODO check this based on earned and yield
        earnedToYieldPath = [
        earnedTokenAddress,
        busdTokenAddress,
        yieldTokenAddress
        ];

        // TODO on this - Off for testing
        transferOwnership(BoltMasterAddress);


        // infinite approve friendly needed contracts
        IERC20(depositTokenAddress).approve(uniRouterAddress, uint(~0));
        IERC20(yieldTokenAddress).approve(BoltMasterAddress, uint(~0));
        IERC20(depositTokenAddress).approve(farmContractAddress, uint(~0));

    }

    function DepositedLockedTotal() external override view returns (uint256)
    {
        return depositedLockedTotal;
    }

    function PendingYieldTotal() external override view returns (uint256)
    {
        uint256 pendingEarnedTokens = ISmartChef(farmContractAddress).pendingReward(address(this));

        if (pendingEarnedTokens > 0) {
            uint[] memory amounts = IPancakeRouter02(uniRouterAddress).getAmountsOut(pendingEarnedTokens, earnedToYieldPath);
            return amounts[amounts.length - 1];
        }

        return 0;
    }

    // Receives new deposits from user
    function deposit(uint256 _depositAmt)
    public
    onlyOwner
    whenNotPaused
    override
    returns (uint256)
    {
        IERC20(depositTokenAddress).safeTransferFrom(
            address(msg.sender),
            address(this),
            _depositAmt
        );

        _farm(_depositAmt);
        _sellEarnedToYieldToken();

        return _depositAmt;
    }

    function fetchYield()
    public
    onlyOwner
    override
    {
        ISmartChef(farmContractAddress).withdraw(0);
        _sellEarnedToYieldToken();
    }


    function _sellEarnedToYieldToken() internal
    {
        // Get Balance
        uint256 contractEarnedBalance = IERC20(earnedTokenAddress).balanceOf(address(this));
        uint256 contractYieldBalance = IERC20(yieldTokenAddress).balanceOf(address(this));

        if (contractEarnedBalance > 0)
        {
            IPancakeRouter02(uniRouterAddress).swapExactTokensForTokensSupportingFeeOnTransferTokens(
                contractEarnedBalance,
                0,
                earnedToYieldPath,
                address(this),
                block.timestamp + 600
            );

            uint256 yieldBalance = IERC20(yieldTokenAddress).balanceOf(address(this));
            uint256 yieldAfterFees = distributeFees(yieldBalance);
        }
    }

    function _farm(uint256 _depositAmt) internal {
        depositedLockedTotal = depositedLockedTotal.add(_depositAmt);
        ISmartChef(farmContractAddress).deposit(_depositAmt);
    }

    function withdraw(uint256 _depositAmt)
    public
    override
    onlyOwner
    nonReentrant
    returns (uint256)
    {
        ISmartChef(farmContractAddress).withdraw(_depositAmt);

        _sellEarnedToYieldToken();

        uint256 wantAmt = IERC20(depositTokenAddress).balanceOf(address(this));
        if (_depositAmt > wantAmt) {
            _depositAmt = wantAmt;
        }

        if (depositedLockedTotal < _depositAmt) {
            _depositAmt = depositedLockedTotal;
        }


        depositedLockedTotal = depositedLockedTotal.sub(_depositAmt);

        IERC20(depositTokenAddress).safeTransfer(BoltMasterAddress, _depositAmt);

        return _depositAmt;
    }

    ///

    function distributeFees(uint256 _earnedAmt)
    internal
    returns (uint256)
    {
        uint256 devFee = _earnedAmt.mul(devFees).div(devFeesMax);
        uint256 treasuryFee = _earnedAmt.mul(treasuryFees).div(treasuryFeesMax);

        if (devFee > 0)
        {
            IERC20(yieldTokenAddress).transfer(devAddress, devFee);
        }

        if (treasuryFee > 0)
        {
            IERC20(yieldTokenAddress).transfer(treasuryAddress, treasuryFee);
        }

        return _earnedAmt.sub(devFee).sub(treasuryFee);
    }

    function setDevFees(uint256 _devFees)
    external
    {
        require(msg.sender == govAddress, "!gov");

        devFees = _devFees;
    }

    function setTreasuryFees(uint256 _treasuryFees)
    external
    {
        require(msg.sender == govAddress, "!gov");

        treasuryFees = _treasuryFees;
    }


    function setDevAddress(address _devAddress)
    external
    {
        require(msg.sender == govAddress, "!gov");

        devAddress = _devAddress;
    }

    function setTreasuryAddress(address _treasuryAddress)
    external
    {
        require(msg.sender == govAddress, "!gov");

        treasuryAddress = _treasuryAddress;
    }

    function pause() public
    {
        require(msg.sender == govAddress, "Not authorised");
        _pause();
    }

    function unpause() external {
        require(msg.sender == govAddress, "Not authorised");
        _unpause();
    }

    function setGov(address _govAddress) public
    {
        require(msg.sender == govAddress, "!gov");
        govAddress = _govAddress;
    }

    function setOnlyGov(bool _onlyGov) public {
        require(msg.sender == govAddress, "!gov");
        onlyGov = _onlyGov;
    }

}