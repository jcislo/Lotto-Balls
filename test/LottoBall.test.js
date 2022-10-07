const { BN, constants, balance, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');
const { web3 } = require('@openzeppelin/test-helpers/src/setup');
const { assert } = require('chai')

const LottoBalls = artifacts.require('LottoBallsTest');
const LINK = artifacts.require("LINK")
const DAI = artifacts.require("DAITEST");
const burnTest = artifacts.require("ExternalBurnTest");

const constructorA = artifacts.require("ConstructorCallA");
const constructorB = artifacts.require("ConstructorCallB");

// const web3 = new Web3("https://rpc-mumbai.maticvigil.com/v1/e0a0cd4b53a1f066d1a6c7655a70cde64ab88894")
let END = false;

contract('Lotto Balls', accounts => {
  // Initial settings
  const owner = accounts[0]
  const setter = accounts[1]
  const player1 = accounts[2]
  const player2 = accounts[3]
  const player3 = accounts[4]
  const player4 = accounts[5]

  
  const Bone = new BN("1000000000000000000");

  const gamePrice = (new BN("5")).mul(Bone);
  const devShare = gamePrice.div(new BN("10"));

  const linkReward = (new BN("10000")).mul(Bone);

  const ballPrice = (new BN("100")).mul(Bone);
  

  let count = 0;
  

  before(async () => {
    this.balls = await LottoBalls.deployed();
    this.DAI = await DAI.deployed();
    this.link = await LINK.deployed();
    this.external = await burnTest.deployed();
    
  })

  describe('Default values - LottoBallz', async () => {
    it('check bot reward', async () => {
        const botRew = await this.balls.name();
        assert.equal(botRew.toString(), "Lotto Balls", 'Invalid Name')
    })

    it('check symbol', async () => {
        const botRew = await this.balls.symbol();
        assert.equal(botRew.toString(), "LTB", 'Invalid symbol');
    })

    it('check decimals', async () => {
        const botRew = await this.balls.decimals();
        assert.equal(botRew.toString(), "18", 'Invalid decimal');
    })

    it('check DAIBalance', async () => {
        const botRew = await this.balls.getDAIBalance();
        assert.equal(botRew.toString(), "0", 'Invalid DAI')
    })

    it('check Link Bal', async () => {
        const bal = await this.link.balanceOf(this.balls.address);
        assert.equal(bal.toString(), "0", "Invalid Link");
    })

    it('check gameByIndex', async () => {
        await expectRevert(this.balls.getGameByIndex(0), "Invalid");
    })
    
  })

  function getRandomInt(max) {
    return Math.floor(Math.random() * max)
  }

  const makeBalls = () => {
    let gameCard = []
    for (let i = 0; i < 8; i++) {
        gameCard.push(getRandomInt(7));
    }
    return gameCard;
  }

  describe('Functions', async () => {
    it('cannot call without Link', async () => {
        await expectRevert(this.balls.playDAI(makeBalls()), "LottoBalls: Insufficient LINK");
        await expectRevert(this.balls.playWithBalls(makeBalls(), {from: player1}), "LottoBalls: Insufficient LINK");
        
    })

    it("cannot call with bad numbers", async () => {
        let badNumbers = [1, 4, 9, 9, 8, 1, 0, 1]
        // let shortNumbers = [1, 4, 2, 2, 2, 1, 0]
        await expectRevert(this.balls.playDAI(badNumbers), "LottoBalls: Invalid number set");
        await expectRevert(this.balls.playWithBalls(badNumbers), "LottoBalls: Invalid number set");
        // console.log(1)
        // await expectRevert(this.balls.playWithBalls(shortNumbers), "LottoBalls: Invalid number set");
    })

    it('cannot call without DAI', async () => {
        await expectRevert(this.balls.playDAI(makeBalls(), {from: player4}), "LottoBalls: Insufficient DAI");
    })

    // TEST CALLS FROM CONSTRUCTOR
    // it("cannot call from constructor", async () => {
    //     console.log(1)
    //     await expectRevert( constructorA.new(this.balls.address), "LottoBalls: invalid sender");
    //     console.log(2)
    //     await expectRevert(constructorB.new(this.balls.address), "LottoBalls: invalid sender");
    // })

    it("call begin", async () => {
        const linkBefore = await this.link.balanceOf(owner);
        const ballsBefore = await this.balls.balanceOf(owner);

        await this.balls.begin();

        const linkAfter = await this.link.balanceOf(owner);
        const ballsAfter = await this.balls.balanceOf(owner);

        await expectRevert(this.balls.begin(), "LottoBalls: INVALID");

        assert.equal(linkAfter.toString(), linkBefore.sub((new BN("1")).mul(Bone)).toString(), "wrong link balance");
        assert.equal(ballsAfter.toString(), ballsBefore.add( (new BN("100000")).mul(Bone) ).toString(), "wrong ball balance");


    })

    it("cannot call without balls", async () => {
        await expectRevert(this.balls.playWithBalls(makeBalls(), {from: player1}), "LottoBalls: You don't have enough Balls lol");
        
    })

    it("addLink", async () => {
        const linkBefore = await this.link.balanceOf(owner);
        const ballsBefore = await this.balls.balanceOf(owner);
        await this.balls.addLink();
        const ballsAfter = await this.balls.balanceOf(owner);
        const linkAfter = await this.link.balanceOf(owner);

        assert.equal(linkAfter.toString(), linkBefore.sub(Bone).toString(), "wrong LINK balance");
        assert.equal(ballsAfter.toString(), ballsBefore.add(linkReward).toString(), "wrong BALL reward");

    })

    it("change Link Reward", async () => {
        const linkBefore = await this.link.balanceOf(owner);
        const ballsBefore = await this.balls.balanceOf(owner);
        await expectRevert(this.balls.changeLinkReward(600), "LottoBalls: reward amount invalid")
        await expectRevert(this.balls.changeLinkReward(60001), "LottoBalls: reward amount invalid")
        await this.balls.changeLinkReward(1500)
        await this.balls.addLink();
        const ballsAfter = await this.balls.balanceOf(owner);
        const linkAfter = await this.link.balanceOf(owner);

        assert.equal(linkAfter.toString(), linkBefore.sub(Bone).toString(), "wrong LINK balance");
        assert.equal(ballsAfter.toString(), ballsBefore.add((new BN("1500")).mul(Bone)).toString(), "wrong BALL reward");
        await this.balls.changeLinkReward(10000)
    })

    it("constant adds", async () => {
        for (let i = 0; i < 48; i++) {
            await this.balls.addLink();
        }
        
    })

    

    it("cannot add over 50 LINK", async () => {
        await expectRevert(this.balls.addLink(), "Too much LINK");
        
    })

    it("external burn", async () => {
        await expectRevert(this.external.burnBalls(), "LottoBalls: this feature is locked");

        await expectRevert(this.balls.addSpender(this.external.address), "LottoBalls: Feature locked");
        await expectRevert(this.balls.removeSpender(this.external.address), "LottoBalls: Feature locked");
        await this.balls.unlock();
        await expectRevert(this.balls.unlock(), "LottoBalls: Feature locked");
        await expectRevert(this.external.burnBalls(), "LottoBalls: sender not approved");
        await expectRevert(this.external.mintBalls(), "LottoBalls: sender not approved");
        await expectRevert(this.balls.removeSpender(this.external.address), "Invalid");
        await expectRevert(this.balls.addSpender(this.balls.address), "Invalid");

        await this.balls.addSpender(this.external.address);
        
        await expectRevert(this.external.burnBalls({from: player3}), "ERC20: burn amount exceeds balance");
        
        const ballsBefore = await this.balls.balanceOf(owner);
        await this.external.burnBalls();
        const ballsAfter = await this.balls.balanceOf(owner);

        assert.equal(ballsAfter.toString(), ballsBefore.sub(Bone).toString())

        await this.external.mintBalls()
        const newBalls = await this.balls.balanceOf(owner);

        assert.equal(newBalls.toString(), ballsAfter.add(Bone).toString());

        await this.balls.removeSpender(this.external.address);
        await expectRevert(this.external.burnBalls(), "LottoBalls: sender not approved");

        
    })
    
    it("erc20 function", async () => {
        const balBeforeSender = await this.balls.balanceOf(owner);
        const balBeforeReceiver = await this.balls.balanceOf(player1);

        await expectRevert(this.balls.transferFrom(owner, player1, 1000, {from: player1}), "ERC20: transfer amount exceeds allowance");
        await this.balls.approve(player1, 1000);

        await this.balls.transferFrom(owner, player1, 1000, {from: player1});

        const balAfterSender = await this.balls.balanceOf(owner);
        const balAfterReceiver = await this.balls.balanceOf(player1);

        assert.equal(balAfterSender.toString(), balBeforeSender.sub(new BN("1000")).toString(), "wrong amount sent");
        assert.equal(balAfterReceiver.toString(), balBeforeReceiver.add(new BN("1000")).toString(), "wrong receive amount");
    })
    let balls = 0;
        for (let i = 0; i < 5; i++) {
            if ((i +1) % 45 == 0) {
                it(`play with balls - run #: ${count}`, async () => {
                    await playWithBalls();
                    count++
                    
                   
                })
            } else {
                it(`play with DAI - run #: ${count}`, async () => {
                    await playWithDAI()
                    count++;
                    
                })
            }

        }
        // 999999
        
   

    it("win?", async () => {
        if (END) {
            console.log("8/8 COMPLETE");
            console.log(`count is: ${count}`);
        } else {
            console.log("FAILED");
        }
    })

    const playWithDAI = async () => {
        const linkBefore = await this.link.balanceOf(this.balls.address);
        const DAIBefore = await this.DAI.balanceOf(owner);
        const DAIBeforePlayer = await this.DAI.balanceOf(player1);
        const DAIBeforeGam = await this.DAI.balanceOf(this.balls.address);
        const DAIBeforeGame = DAIBeforeGam.add(new BN("4500000000000000000"))
        const ballBefore = await this.balls.balanceOf(player1);
        const initTotalSupply = await this.balls.totalSupply();

        const roundNumInit = await this.balls.roundNumber();

        const playBalls = makeBalls()
        console.log(playBalls);
        await this.balls.playDAI(playBalls, {from: player1});

        const linkAfter = await this.link.balanceOf(this.balls.address);
        const DAIAfter = await this.DAI.balanceOf(owner);
        const DAIAfterPlayer = await this.DAI.balanceOf(player1);
        const DAIAfterGame = await this.DAI.balanceOf(this.balls.address);
        const ballAfter = await this.balls.balanceOf(player1);
        const afterTotalSupply = await this.balls.totalSupply();

        // const userGames = await this.balls.getUserGames(player1);
        const roundNumAft = await this.balls.roundNumber();
        // console.log(userGames.length)
        assert.equal(roundNumInit.toString(), roundNumAft.sub(new BN("1")).toString(), "wrong round assigned");
        // assert.equal(userGames.length, count, "wrong length");
        const data = await this.balls.getGameByIndex(roundNumAft.sub(new BN("1")).toString());

        // const altData = await this.balls.getGameWithReqID(data.reqId);

        // assert.equal(altData.player, data.player, "wrong data");


        assert.equal(data.playedNumbers.length, 8, "wrong length of playedNum");
        // assert.equal(data.drawnNumbers.length, 8, "wrong length of drawnNum");
        
        let playerCard = []
        let gameCard = []
        let matches = 0;
        let errors = 0;
        // console.log(data.randomNum)
        for(let i = 0; i < 8; i++) {
            playerCard.push(parseInt(data.playedNumbers[i]))
            const numb = web3.utils.toBN(web3.utils.soliditySha3(data.randomNum, i)).mod(new BN("7"))
            gameCard.push(numb.toString());
        }
        assert.equal(playerCard.length, 8, "wrong playCard");
        assert.equal(gameCard.length, 8, "wrong gamel ength");
        console.log(playerCard);
        console.log(gameCard)
        for (let k = 0; k <8; k++) {
            if(playerCard[k] == gameCard[k]) {
                matches++;
            }

            if(playerCard[k] > 7 || gameCard[k] > 7) {
                console.log("here1")
                errors++
            }
        }
        
        let DAIPrizes = new BN("0");
        let ballPrize = new BN("0");    
        
        // console.log(`matches: ${matches}`)
        if (parseInt(matches) === 0) {
            ballPrize = Bone.mul(new BN("4"));
        } else if (parseInt(matches) === 1) {
            ballPrize = Bone.mul(new BN("8"))
        } else if (parseInt(matches) === 2) {
            ballPrize = Bone.mul(new BN("20"))
        } else if (parseInt(matches) === 3) {
            ballPrize = Bone.mul(new BN("40"))
            
        } else if (parseInt(matches) === 4) {
            ballPrize = Bone.mul(new BN("400"))
            DAIPrizes = DAIBeforeGame.div(new BN("100000"));
        } else if (parseInt(matches) === 5) {
            ballPrize = Bone.mul(new BN("4000"))
            DAIPrizes = DAIBeforeGame.div(new BN("10000"));
            console.log("hits 5")
        } else if (parseInt(matches) === 6) {
            ballPrize = Bone.mul(new BN("40000"))
            DAIPrizes = DAIBeforeGame.div(new BN("1000"));
            console.log("hits 6")
        } else if (parseInt(matches) === 7) {
            ballPrize = Bone.mul(new BN("400000"))
            DAIPrizes = DAIBeforeGame.div(new BN("100"));
            console.log("hits 7")
        } else if (parseInt(matches) === 8) {
            DAIPrizes = DAIBeforeGame.div(new BN("10")).mul(new BN("9"));
            END = true;
            console.log("KURWA");
        } else {
            errors++;
        }

        if (roundNumInit <= 10) {
            ballPrize = ballPrize.mul(new BN("5"));
        }
        assert.equal(errors, 0, "errors present");

        // console.log(data.reqId.toString())
        // console.log(DAIPrizes)
        // assert.equal(data.DAIPrize.toString(), DAIPrizes.toString(), `wrong DAI Prize ${matches} matches`);
        assert.equal(data.LTBPrize.toString(), ballPrize.toString(), `wrong ball prize ${matches} matches`);
        
        assert.equal(DAIAfterGame.toString(), DAIBeforeGam.add(gamePrice.sub(devShare)).sub(DAIPrizes).toString(), `wrong prize deduction ${matches} matches`);
        assert.equal(ballAfter.toString(), ballBefore.add(ballPrize).toString(), `wrong ball prize ${matches} matches`)
        assert.equal(afterTotalSupply.toString(), initTotalSupply.add(ballPrize).toString(), "wrong total supply");

        assert.equal(linkAfter.toString(), linkBefore.sub(new BN("100000000000000")).toString(), "Bad link balance");
        assert.equal(DAIAfter.toString(), DAIBefore.add(devShare).toString(), "wrong DAI");
        assert.equal(DAIAfterPlayer.toString(), DAIBeforePlayer.sub(gamePrice).add(DAIPrizes).toString(), "wrong player DAI");
         
    }

    const playWithBalls = async () => {
        const linkBefore = await this.link.balanceOf(this.balls.address);
        const DAIBefore = await this.DAI.balanceOf(owner);
        const DAIBeforePlayer = await this.DAI.balanceOf(player1);
        const DAIBeforeGame = await this.DAI.balanceOf(this.balls.address);
        const ballBefore = await this.balls.balanceOf(player1);
        const initTotalSupply = await this.balls.totalSupply();

        const playBalls = makeBalls()
        await this.balls.playWithBalls(playBalls, {from: player1});

        const linkAfter = await this.link.balanceOf(this.balls.address);
        const DAIAfter = await this.DAI.balanceOf(owner);
        const DAIAfterPlayer = await this.DAI.balanceOf(player1);
        const DAIAfterGame = await this.DAI.balanceOf(this.balls.address);
        const ballAfter = await this.balls.balanceOf(player1);
        const afterTotalSupply = await this.balls.totalSupply();

        assert.equal(linkAfter.toString(), linkBefore.sub(new BN("100000000000000")).toString(), "Bad link balance");
        assert.equal(DAIAfter.toString(), DAIBefore.toString(), "wrong DAI");
        
        

        const data = await this.balls.getGameByIndex(count);


        assert.equal(data.playedNumbers.length, 8, "wrong length of playedNum");
        assert.equal(data.drawnNumbers.length, 8, "wrong length of drawnNum");

        let playerCard = []
        let gameCard = []
        let matches = 0;
        let errors = 0;
        for(let i = 0; i < 8; i++) {
            playerCard.push(parseInt(data.playedNumbers[i]))
            gameCard.push(parseInt(data.drawnNumbers[i]));
        }
        assert.equal(playerCard.length, 8, "wrong playCard");
        assert.equal(gameCard.length, 8, "wrong gamel ength");

        for (let k = 0; k <8; k++) {
            if(playerCard[k] == gameCard[k]) {
                matches++;
            }

            if(playerCard[k] > 7 || gameCard[k] > 7) {
                console.log("here1")
                errors++
            }
        }
        
        let DAIPrizes;
        let ballPrize;
        
        // console.log(`matches: ${matches}`)
        if (parseInt(matches) === 0) {
            ballPrize = Bone.mul(new BN("4"));
        } else if (parseInt(matches) === 1) {
            ballPrize = Bone.mul(new BN("8"));
        } else if (parseInt(matches) === 2) {
            ballPrize = Bone.mul(new BN("20"));
        } else if (parseInt(matches) === 3) {
            ballPrize = Bone.mul(new BN("40"));
        } else if (parseInt(matches) === 4) {
            ballPrize = Bone.mul(new BN("400"));
            DAIPrizes = DAIBeforeGame.div(new BN("100000"));
        } else if (parseInt(matches) === 5) {
            ballPrize = Bone.mul(new BN("4000"));
            DAIPrizes = DAIBeforeGame.div(new BN("10000"));
            console.log("hits 5")
        } else if (parseInt(matches) === 6) {
            ballPrize = Bone.mul(new BN("40000"));
            DAIPrizes = DAIBeforeGame.div(new BN("1000"));
            console.log("hits 6")
        } else if (parseInt(matches) === 7) {
            ballPrize = Bone.mul(new BN("400000"));
            DAIPrizes = DAIBeforeGame.div(new BN("100"));
            console.log("hits 7")
        } else if (parseInt(matches) === 8) {
            DAIPrizes = DAIBeforeGame.div(new BN("10")).mul(new BN("9"));
            END = true;
            console.log("KURWA");
        } else {
            errors++;
        }
        assert.equal(errors, 0, "errors present");

        if (roundNumInit <= 10) {
            ballPrize = ballPrize.mul(new BN("5"));
        }
        
        // console.log(data.reqId.toString())
        // console.log(DAIPrizes)
        // assert.equal(data.DAIPrize.toString(), DAIPrizes.toString(), `wrong DAI Prize ${matches} matches`);
        assert.equal(data.LTBPrize.toString(), ballPrize.toString(), `wrong ball prize ${matches} matches`);

        assert.equal(DAIAfterPlayer.toString(), DAIBeforePlayer.add(DAIPrizes).toString(), `wrong player DAI ${matches} matches ${DAIBeforePlayer.toString()} DAIBEFOREPLAYER`);
        
        assert.equal(DAIAfterGame.toString(), DAIBeforeGame.sub(DAIPrizes).toString(), "wrong prize deduction");
        assert.equal(ballAfter.toString(), ballBefore.sub(ballPrice).add(ballPrize).toString(), "wrong ball prize")
        assert.equal(afterTotalSupply.toString(), initTotalSupply.add(ballPrize).sub(ballPrice).toString(), "wrong total supply");

    }
  })

  // test from 0x0 address by calling from a constructor


//   describe('mining', async () => {

//   })
})
