// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface ILottoBalls {
    
    //
    // @notice 
    function begin() external;

    function playDAI(uint256[8] calldata numbers) external;

    function playWithBalls(uint256[8] calldata numbers) external;

    function addLink() external;
    
    function externalBurn(address user, uint256 amount) external;

    function externalMint(address user, uint256 amount) external;

    // --------------------
    // getter functions
    // --------------------
    // function name() external view returns (string memory);

    // function symbol() external view returns (string memory);

    // function decimals() external view returns (uint8);

    function getDAIBalance() external view returns (uint256);

    // function plays(address user) external view returns(uint256);

    function roundNumber() external view returns(uint256);

    // function getUserGames(address user) external view returns(uint256[] memory);

    function getPendingPlay(address user) external view returns (bool isPending);

    function getNumOfUserGames(address user) external view returns(uint256);

    function getUserGameByIndex(address user, uint256 index) external view returns(
        bytes32 reqId,
        uint256[8] memory playedNumbers,
        uint256 randomNum,
        bool completed,
        uint256 DAIPrize,
        uint256 LTBPrize,
        bool isDAI
    );

    function getGameByIndex(uint256 index) external view returns (
        bytes32 reqId,
        address player,
        uint256[8] memory playedNumbers,
        uint256 randomNum,
        bool completed,
        uint256 DAIPrize,
        uint256 LTBPrize,
        bool isDAI
    );

    function getGameByReqId(bytes32 reqId) external view returns (
        address player,
        uint256[8] memory playedNumbers,
        uint256 randomNum,
        bool completed,
        uint256 DAIPrize,
        uint256 LTBPrize,
        bool isDAI
    );

    // ---------------------
    // Owner Functions
    // ---------------------

    function changeLinkReward(uint256 newReward) external;

    function addSpender(address newGame) external;

    function removeSpender(address existingGame) external;

    function unlock() external;

    // --------------------
    // ERC20 Functions
    // --------------------

    // function increaseAllowance(address spender, uint256 addedValue) external returns (bool);

    // function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool);

}
