const CakeBTDStrategy = artifacts.require("../contracts/Bolt/CakeBTDStrategy.sol");
const BoltMaster = artifacts.require("../contracts/Bolt/BoltMaster.sol");
const FakeSmartChef = artifacts.require("../contracts/Fakes/FakeSmartChef.sol");
const FakeCake = artifacts.require("../contracts/Fakes/FakeCake.sol");
const FakeEPS = artifacts.require("../contracts/Fakes/FakeEPS.sol");
const FakeBTD = artifacts.require("../contracts/Fakes/FakeBTD.sol");
const FakeBUSD = artifacts.require("../contracts/Fakes/FakeBUSD.sol");

module.exports = async function (deployer) {

      
    let boltMaster = await BoltMaster.deployed();
    let fakeSmartChef = await FakeSmartChef.deployed();
    let fakeCake = await FakeCake.deployed();
    let fakeEPS = await FakeEPS.deployed();
    let fakeBtd = await FakeBTD.deployed();
    let fakeBUSD = await FakeBUSD.deployed();

    await deployer.deploy(CakeBTDStrategy, boltMaster.address, 
        fakeSmartChef.address, 0, fakeCake.address, 
        fakeEPS.address, fakeBtd.address, 
        fakeBUSD.address, 
        "0xD99D1c33F9fC3444f8101754aBC46c52416550D1", // Router address
        "0x0000000000000000000000000000000000000000", // treasury address
        "0x0000000000000000000000000000000000000000");// dev address


};

