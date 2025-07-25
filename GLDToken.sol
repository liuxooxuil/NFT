// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
contract GLDToken is ERC20 {
    // Gold 是Token的名字
	// GLD  是Token的符号
    constructor(uint256 initialSupply) ERC20("Goldss", "GLDss") {
        _mint(msg.sender, initialSupply);
    }
}