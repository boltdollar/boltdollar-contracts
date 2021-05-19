const BoltMaster = artifacts.require("../contracts/Bolt/BoltMaster.sol");
const CAKE2 = artifacts.require("../Fakes/FakeCake.sol");
const BTD = artifacts.require("../Fakes/FakeBTD.sol");
const EPS = artifacts.require("../Fakes/FakeEPS.sol");

module.exports = async function (deployer) {
  let fakeCake = (await CAKE2.deployed()).address; 
  let fakeBTD = (await BTD.deployed()).address; 
  let fakeEPS = (await EPS.deployed()).address; 
  await deployer.deploy(BoltMaster, fakeCake, fakeBTD);
  

};

