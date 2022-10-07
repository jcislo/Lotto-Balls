// // SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/dev/VRFConsumerBase.sol";

import "../interfaces/ILottoBalls.sol";

// / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / //
//                                                                                                   //
//             /////         //////            ////       ////           //////                      //
//            /////        ////  ////    /////////////////////////     ////  ////                    //
//           /////       ////     ////       ////       ////         ////     ////                   //
//          /////         ////  ////        ////       ////           ////  ////                     //
//         //////////       /////          ////       ////              /////                        //
//                                                                                                   //
//               /////////          ////           ////     ////        /////                        //
//              ///    /////       // //          ////     ////      ////   ////                     //
//             //       /////     //  //         ////     ////     ////       ///                    //
//            ///    //////      //   //        ////     ////       ////                             //
//           ///////////        ////////       ////     ////          //////                         //
//          //       ////      //     //      ////     ////                ////                      //
//         //      ////       //      //     ////     ////        ////   ////                        //
//         /////////         //       //    ////     ////            ////                            //
//                                                                                                   //
// / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / //
// Mr.Ballz Productions /////////
////////////////////////////////

contract LottoBallsTest is IERC20, ERC20, VRFConsumerBase, ILottoBalls {
    using SafeMath for uint256;

    // events
    event Mint(address user, uint256 amount);
    event Burn(address user, uint256 amount);
    event Game(address player, bytes32 gameId, uint256 playIndex);
    event LinkAdded(address user, uint256 Link, uint256 newBalls);

    address private _owner;

    string private _name;
    string private _symbol;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(bytes32 => GameCard) data;
    // mapping(address => bytes32) usersReqId;
    mapping(address => bytes32[]) public userGames;
    // mapping(address => uint256) public override plays;
    mapping(address => bool) pendingPlay;
    mapping(address => bool) approvedSpenders;

    uint256 private _totalSupply;
    uint256 internal fee; 
    uint256 Bone = 10 ** 18;  
    uint256 linkReward = 10000;
    uint256 public gamePrice = 5 * Bone; // 2 DAI
    uint256 public devShare = gamePrice.div(10); // 10% dev fee
    uint256 ballPrice;
    uint256 yieldPrize;
    uint256 public override roundNumber = 0;
    uint256 bonus;

    uint256[8] ballPrize = [400000, 40000, 4000, 400, 40, 20, 8, 4];
    
    uint8 private _decimals;

    bytes32 internal keyHash;

    bool initialized;
    bool lock = false;

    IERC20 DAI;
    IERC20 Link;

    GameCard[] listOfGames;

    struct GameCard {
      bytes32 reqId;
      address player;
      uint256[8] playedNumbers;
      uint256 randomNum;
      bool completed;
      uint256 DAIPrize;
      uint256 LTBPrize;
      bool isDAI;
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "Ownable: caller is not the owner");
        _;
    }

    modifier checkNumbers(uint256[8] calldata numbers) {
        for (uint8 i = 0; i < 8; i++) {
            require(numbers[i] <= 6, "LottoBalls: Invalid number set");
        }
        _;
    }

    constructor(
        address DAIAddr,
        address LinkAddr,
        address VRFCoordinator
    ) VRFConsumerBase(
        VRFCoordinator,
        LinkAddr
    ) ERC20("Lotto Balls", "LTB") {

        // _name = "Lotto Balls";
        // _symbol = "LTB";
        // _decimals = 18;
        _owner = msg.sender;
        // _totalSupply = 0;  

        DAI = IERC20(DAIAddr);
        Link = IERC20(LinkAddr);

        // Mumbai KeyHash
        keyHash = 0x6e75b569a01ef56d18cab6a8e71e6600d6ce853834d4a5748b720d06f878b3a4;
        fee = 0.0001 * 10 ** 18;

        bonus = 10;
        ballPrice = uint256(100).mul(Bone);
        yieldPrize = uint256(40).mul(Bone);
    }

    //
    // @notice called by owner to deposit initial LINK and mint promo LTB
    //
    function begin() external override onlyOwner {
      require(!initialized, "LottoBalls: INVALID");

      _mint(msg.sender, uint256(100000).mul(Bone));
      initialized = true;
      Link.transferFrom(msg.sender, address(this), uint256(1).mul(Bone));
    }

    //
    // @notice plays the game using DAI. requires 2 DAI to play.
    // @param numbers: array of 8 integers from 0 to 7. Checked by modifier.
    //
    function playDAI(uint256[8] calldata numbers) external override checkNumbers(numbers) {
        
      require(!pendingPlay[msg.sender], "LottoBalls: previous play must resolve");
      require(msg.sender != address(0), "LottoBalls: invalid sender");
      require(DAI.balanceOf(msg.sender) >= gamePrice, "LottoBalls: Insufficient DAI");
      require(Link.balanceOf(address(this)) >= fee, "LottoBalls: Insufficient LINK");
      
      
      uint256 userProvidedSeed = uint256(keccak256(abi.encodePacked(numbers[4], block.number)));
      bytes32 requestId = keccak256(abi.encodePacked(keyHash, fee, userProvidedSeed));
      
      data[requestId].reqId = requestId;
      data[requestId].player = msg.sender;
      data[requestId].playedNumbers = numbers; 
      data[requestId].isDAI = true;

      userGames[msg.sender].push(requestId);

      pendingPlay[msg.sender] = true;
    //   usersReqId[msg.sender] = requestId;
      
      require(DAI.transferFrom(msg.sender, address(this), gamePrice), "LottoBalls: DAI Payment Failed");
      require(DAI.transfer(_owner, devShare), "LottoBalls: devshare not sent");
      
      // TEST SECTION
      uint256 RNG = uint256(keccak256(abi.encodePacked(requestId, block.timestamp -1, block.number, numbers[7])));
      fulfillRandomness(requestId, RNG);
      Link.transfer(msg.sender, fee);
    }

    //
    // @notice plays the game using LTB. Requires 100 LTB to play.
    // @param numbers: array of 8 integers from 0 to 7. Checked by modifier
    //
    function playWithBalls(uint256[8] calldata numbers) external override checkNumbers(numbers) {
      
      require(!pendingPlay[msg.sender], "LottoBalls: previous play must resolve");
      require(msg.sender != address(0), "LottoBalls: invalid sender");
      require(Link.balanceOf(address(this)) >= fee, "LottoBalls: Insufficient LINK");
      
      require(balanceOf(msg.sender) >= ballPrice, "LottoBalls: You don't have enough Balls lol");
      _burn(msg.sender, ballPrice);
      
      uint256 userProvidedSeed = uint256(keccak256(abi.encodePacked(numbers[4], block.number)));
      bytes32 requestId = keccak256(abi.encodePacked(keyHash, fee, userProvidedSeed));

      data[requestId].reqId = requestId;
      data[requestId].player = msg.sender;
      data[requestId].playedNumbers = numbers; 
      // data[requestId].isDAI = false;
      
      userGames[msg.sender].push(requestId);
      pendingPlay[msg.sender] = true;
      // usersReqId[msg.sender] = requestId;

      // TEST SECTION
      uint256 RNG = uint256(keccak256(abi.encodePacked(requestId, block.timestamp -1, block.number, numbers[7])));
      fulfillRandomness(requestId, RNG);
      Link.transfer(msg.sender, fee);
    }

    //
    // @notice contains logic for determining matches and assigning prize amounts
    //
    function getGame(uint256 randomValue, bytes32 requestId) internal {
        // uint256[8] memory set;
        uint256 matches = 0;
        data[requestId].randomNum = randomValue;
        // uint256 random = randomValue;
        for (uint256 i = 0; i < 8; i++) {
            // set[i] 
            // data[requestId].drawnNumbers[i] = random.mod(8); // uint256(keccak256(abi.encode(randomValue, i))) % 8;
            
            if (data[requestId].playedNumbers[i] == uint256(keccak256(abi.encode(randomValue, i))).mod(7)) { // random.mod(7)) {
                matches = matches.add(1);
            }
            // random = random.div(7);
        }

        if (matches == 0) {
            if (roundNumber >= bonus) {
                data[requestId].LTBPrize = Bone.mul(ballPrize[7]);
            } else {
                data[requestId].LTBPrize = Bone.mul(ballPrize[7]).mul(5);
            }
            
        } else if (matches == 1) {
            // data[requestId].LTBPrize = Bone.mul(ballPrize[6]);
            if (roundNumber >= bonus) {
                data[requestId].LTBPrize = Bone.mul(ballPrize[6]);
            } else {
                data[requestId].LTBPrize = Bone.mul(ballPrize[6]).mul(5);
            }
        } else if (matches == 2) {
            // data[requestId].LTBPrize = Bone.mul(ballPrize[5]);
            if (roundNumber >= bonus) {
                data[requestId].LTBPrize = Bone.mul(ballPrize[5]);
            } else {
                data[requestId].LTBPrize = Bone.mul(ballPrize[5]).mul(5);
            }
        } else if (matches == 3) {
            // data[requestId].DAIPrize = DAI.balanceOf(address(this)).div(1000000).mul(5);
            // data[requestId].LTBPrize = Bone.mul(ballPrize[4]);
            if (roundNumber >= bonus) {
                data[requestId].LTBPrize = Bone.mul(ballPrize[4]);
            } else {
                data[requestId].LTBPrize = Bone.mul(ballPrize[4]).mul(5);
            }
        } else if (matches == 4) {
            data[requestId].DAIPrize = DAI.balanceOf(address(this)).div(100000); // 0.001%
            // data[requestId].LTBPrize = Bone.mul(ballPrize[3]);
            if (roundNumber >= bonus) {
                data[requestId].LTBPrize = Bone.mul(ballPrize[3]);
            } else {
                data[requestId].LTBPrize = Bone.mul(ballPrize[3]).mul(5);
            }
        } else if (matches == 5) {
            data[requestId].DAIPrize = DAI.balanceOf(address(this)).div(10000); // 0.01%
            // data[requestId].LTBPrize = Bone.mul(ballPrize[2]); 
            if (roundNumber >= bonus) {
                data[requestId].LTBPrize = Bone.mul(ballPrize[2]);
            } else {
                data[requestId].LTBPrize = Bone.mul(ballPrize[2]).mul(5);
            }
        } else if (matches == 6) {
            data[requestId].DAIPrize = DAI.balanceOf(address(this)).div(1000); // 0.1%
            // data[requestId].LTBPrize = Bone.mul(ballPrize[1]);
            if (roundNumber >= bonus) {
                data[requestId].LTBPrize = Bone.mul(ballPrize[1]);
                
            } else {
                data[requestId].LTBPrize = Bone.mul(ballPrize[1]).mul(5);
            } 
        } else if (matches == 7) {
            data[requestId].DAIPrize = DAI.balanceOf(address(this)).div(100);  // 1%
            // data[requestId].LTBPrize = Bone.mul(ballPrize[0]);
            if (roundNumber >= bonus) {
                data[requestId].LTBPrize = Bone.mul(ballPrize[0]);
            } else {
                data[requestId].LTBPrize = Bone.mul(ballPrize[0]).mul(5); 
            }
        } else if (matches == 8) {
            data[requestId].DAIPrize = DAI.balanceOf(address(this)).div(10).mul(9);  // about 90%
        }
        
        // data[requestId].drawnNumbers = set;
        data[requestId].completed = true;
        
    }

    //
    // @notice callback function called by chainlink VRF. Provides the RNG response, generates a random set, and assigns prizes
    // @param randomValue - The random value obtained from VRF
    // @param requestId - The requestId generated by a play
    // 
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        getGame(randomness, requestId);
        
        listOfGames.push(data[requestId]);
        // plays[data[requestId].player] += 1; 
        // userGames[data[requestId].player].push(roundNumber);
        roundNumber++;

        // distribute prizes
        if (data[requestId].LTBPrize > 0) {
            _mint(data[requestId].player, data[requestId].LTBPrize);
        }

        if (data[requestId].DAIPrize > 0) {
            DAI.transfer(data[requestId].player, data[requestId].DAIPrize);
        }
        pendingPlay[data[requestId].player] = false;
        
        emit Game(data[requestId].player, data[requestId].reqId, listOfGames.length.sub(1));

    }

    // 
    // @notice allows the user to add 1 LINK to the contract
    // @notice provides user with LTB as a reward
    // @notice reverts if contract balance of LINK is greater than 50
    //
    function addLink() external override {
        require(Link.balanceOf(address(this)) <= uint256(50).mul(Bone), "Too much LINK");
        require(Link.balanceOf(msg.sender) >= Bone, "LottoBalls: Insufficient LINK");
        uint256 newBalls = linkReward.mul(Bone);
        _mint(msg.sender, newBalls);

        require(Link.transferFrom(msg.sender, address(this), Bone), "LottoBalls: Transfer Failed");
        emit LinkAdded(msg.sender, Bone, newBalls);
    }
    
    // 
    // @notice burn function callable from future games utilizing LTB
    // @dev authorized game contracts must be approved by owner.
    // @dev if you are interested in developing your own game using LTB, contact admin at community discord
    // 
    function externalBurn(address user, uint256 amount) external override {
        require(lock, "LottoBalls: this feature is locked");
        require(approvedSpenders[msg.sender], "LottoBalls: sender not approved");

        _burn(user, amount);
    }

    // 
    // @notice mint function callable from future games utilizing LTB
    // @dev authorized game contracts must be approved by owner.
    // @dev if you are interested in developing your own game using LTB, contact admin at community discord
    // 
    function externalMint(address user, uint256 amount) external override {
        require(lock, "LottoBalls: this feature is locked");
        require(approvedSpenders[msg.sender], "LottoBalls: sender not approved");

        _mint(user, amount);
    }

    // --------------------
    // getter functions
    // --------------------
    

    function getDAIBalance() public view override returns (uint256) {
        return DAI.balanceOf(address(this));
    }

    //
    // @notice returns a flag indicating if the user is awaiting a VRF response.
    // @dev an address can only have one pending game at a time
    // @dev if this function returns true, user must wait for the VRF response before being able to play again
    // @param user - address of user
    //
    function getPendingPlay(address user) external view override returns (bool isPending) {
        isPending = pendingPlay[user];
    }

    //
    // @notice returns length of userGames array containing requestId's
    // @param user - address of user
    //
    function getNumOfUserGames(address user) external view override returns(uint256) {
        return userGames[user].length;
    }

    //
    // @notice returns game data based on reqID 
    // @param user - address of user
    // @param index - position of reqID in userGames array
    //
    function getUserGameByIndex(address user, uint256 index) external view override returns(
        bytes32 reqId,
        uint256[8] memory playedNumbers,
        uint256 randomNum,
        bool completed,
        uint256 DAIPrize,
        uint256 LTBPrize,
        bool isDAI
    ) {
        require(index < userGames[user].length, "Invalid");
        reqId = data[userGames[user][index]].reqId;
        playedNumbers = data[userGames[user][index]].playedNumbers;
        randomNum = data[userGames[user][index]].randomNum;
        completed = data[userGames[user][index]].completed;
        DAIPrize = data[userGames[user][index]].DAIPrize;
        LTBPrize = data[userGames[user][index]].LTBPrize;
        isDAI = data[userGames[user][index]].isDAI;
    }

    //
    // @notice returns data stored in game struct
    // @param index - game number, starts at 0 and increases by 1 as games are completed
    //
    function getGameByIndex(uint256 index) external view override returns (
        bytes32 reqId,
        address player,
        uint256[8] memory playedNumbers,
        uint256 randomNum,
        bool completed,
        uint256 DAIPrize,
        uint256 LTBPrize,
        bool isDAI
    ) {
        require(index < listOfGames.length, "Invalid");
        reqId = listOfGames[index].reqId;
        player = listOfGames[index].player;
        playedNumbers = listOfGames[index].playedNumbers;
        randomNum = listOfGames[index].randomNum;
        completed = listOfGames[index].completed;
        DAIPrize = listOfGames[index].DAIPrize;
        LTBPrize = listOfGames[index].LTBPrize;
        isDAI = listOfGames[index].isDAI;
    }

    //
    // @notice returns data stored in game struct
    // @param reqId - requestID for a game
    //
    function getGameByReqId(bytes32 reqId) external view override returns (
        address player,
        uint256[8] memory playedNumbers,
        uint256 randomNum,
        bool completed,
        uint256 DAIPrize,
        uint256 LTBPrize,
        bool isDAI
    ) {
        
        player = data[reqId].player;
        playedNumbers = data[reqId].playedNumbers;
        randomNum = data[reqId].randomNum;
        completed = data[reqId].completed;
        DAIPrize = data[reqId].DAIPrize;
        LTBPrize = data[reqId].LTBPrize;
        isDAI = data[reqId].isDAI;
    }

    // ---------------------
    // Owner Functions
    // ---------------------

    //
    // @notice owner can add game contract that uses LTB
    // @notice unlock() function must be called first
    // @param newGame - address of game contract to be able to use LTB
    //
    function addSpender(address newGame) external override onlyOwner {
        require(lock, "LottoBalls: Feature locked");
        require(newGame != address(0) && newGame != address(this), "Invalid");
        approvedSpenders[newGame] = true;
    }

    //
    // @notice adjust LTB reward for LINK deposits
    // @param newReward - new amount of LTB to be given on "addLink()" calls
    //
    function changeLinkReward(uint256 newReward) external override onlyOwner {
        require(newReward > 600 && newReward <= 60000, "LottoBalls: reward amount invalid");
        linkReward = newReward;
    }

    //
    // @notice owner can remove game contracts to stop them from burning LTB
    // @notice unlock() function must be called first
    // @param existingGame - contract address of game that is already approved for burning LTB
    //
    function removeSpender(address existingGame) external override onlyOwner {
        require(lock, "LottoBalls: Feature locked");
        require(approvedSpenders[existingGame], "Invalid");
        approvedSpenders[existingGame] = false;
    }

    //
    // @notice allows owner to call "addSpender()" and "removeSpender()"
    //
    function unlock() external override onlyOwner {
        require(!lock, "LottoBalls: Feature locked");
        lock = true;
    }

}
