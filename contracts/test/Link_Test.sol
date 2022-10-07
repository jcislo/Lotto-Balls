// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LINK is ERC20 {
    using SafeMath for uint256;

    constructor(address a, address b) ERC20("Link", "LINK") {
        _mint(msg.sender, 100000000000000000000000000000000000);
        _mint(a, 100000000000000000000000000000000000);
        _mint(b, 100000000000000000000000000000000000);

    }
    function decimals() public view virtual override returns (uint8) {
        return 6;
    }
    
}