// import { ethers } from 'hardhat'
const { smockit } = require('@eth-optimism/smock');
const { expect } = require("chai");
const { ethers } = require('hardhat');

describe("Cake Strategy", function() {
    let pancakeRouter02;
    let cakeERC;
    let epsERC;
    let btdERC;
    let boltMasterContractWallet;
    let pancakeswapFarm;
    let cakeBTDStrategy;
    let mockPancakeRouter02;
    let mockCake;

	beforeEach(async () => {
        boltMasterContractWallet = ethers.Wallet.createRandom();
        

		const pancakeRouter02Factory = await ethers.getContractFactory("PancakeRouter");
		pancakeRouter02 = await pancakeRouter02Factory.deploy();
		await pancakeRouter02.deployed();


        const cakeErcFactory = await ethers.getContractFactory("ERC20");
        cakeERC = await cakeErcFactory.deploy("CAKE", "CAKE");
        await cakeERC.deployed();
        mockCake = await smockit(cakeERC);

        const epsERCFactory = await ethers.getContractFactory("ERC20");
        epsERC = await epsERCFactory.deploy("EPS", "EPS");
        await epsERC.deployed();

        const btdERCFactory = await ethers.getContractFactory("ERC20");
        btdERC = await btdERCFactory.deploy("BTD", "BTD");
        await btdERC.deployed();

        const pancakeswapFarmFactory = await ethers.getContractFactory("PancakeswapFarm");
        pancakeswapFarm = await pancakeswapFarmFactory.deploy();
        await pancakeswapFarm.deployed();

        mockPancakeRouter02 = await smockit(pancakeRouter02);
        const cakeBTDStrategyFactory = await ethers.getContractFactory("CakeBTDStrategy");
        cakeBTDStrategy = await cakeBTDStrategyFactory.deploy(boltMasterContractWallet.address,
            pancakeswapFarm.address,
            mockCake.address,
            epsERC.address,
            btdERC.address,
            mockPancakeRouter02.address)
        await cakeBTDStrategy.deployed();
	});

  it("Depositing should deposit to cake pool", async function() {



    
    mockCake.smocked.balanceOf.will.return(100000000);


    

        
  });
  });