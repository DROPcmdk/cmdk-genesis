// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Mock is ERC20("token", "TOKEN") {
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
