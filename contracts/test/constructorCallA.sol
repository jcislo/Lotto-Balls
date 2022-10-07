// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../interfaces/ILottoBalls.sol";

contract ConstructorCallA {
    using SafeMath for uint256;
    uint256[8] ballSet = [0,0,0,0,0,0,0,0];
    constructor(address balls)  {
        ILottoBalls(balls).playWithBalls(ballSet);

    }
    
    
}