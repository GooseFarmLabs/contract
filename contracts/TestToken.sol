// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20{

    constructor() ERC20(string.concat("Test","USD Token"), "TUSD"){
        _mint(msg.sender,1e36);
    }
}
