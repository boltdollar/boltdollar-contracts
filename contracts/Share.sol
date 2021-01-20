// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import './owner/Operator.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol';

contract Share is ERC20Burnable, Operator {
    constructor() public ERC20('Bat True Share', 'BTS') {
        // Mints 1 Bat True Share to contract creator for initial Uniswap oracle deployment.
        _mint(msg.sender, 1 ether);
    }

    /**
     * @notice Operator mints basis cash to a recipient
     * @param recipient_ The address of recipient
     * @param amount_ The amount of basis cash to mint to
     */
    function mint(address recipient_, uint256 amount_)
        public
        onlyOperator
        returns (bool)
    {
        uint256 balanceBefore = balanceOf(recipient_);
        _mint(recipient_, amount_);
        uint256 balanceAfter = balanceOf(recipient_);
        return balanceAfter >= balanceBefore;
    }

    function burn(uint256 amount) public override onlyOperator {
        super.burn(amount);
    }

    function burnFrom(address account, uint256 amount)
        public
        override
        onlyOperator
    {
        super.burnFrom(account, amount);
    }
}