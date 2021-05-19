// SPDX-License-Identifier: MIT
pragma solidity 0.7.3;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract FakeBUSD is ERC20("FakeBUSD", "FakeBUSD")
{
    function mint(address to, uint256 amount) public virtual {
        _mint(to, amount);
    }
}