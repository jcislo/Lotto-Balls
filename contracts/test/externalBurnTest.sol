// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";


import "../interfaces/ILottoBalls.sol";

contract ExternalBurnTest {
    using SafeMath for uint256;
    
    ILottoBalls balls;
    constructor(address ballsAddr)  {
        balls = ILottoBalls(ballsAddr);

    }

    function burnBalls() external {
        balls.externalBurn(msg.sender, 1000000000000000000);
    }

    function mintBalls() external {
        balls.externalMint(msg.sender, 1000000000000000000);
    }
    
    
}