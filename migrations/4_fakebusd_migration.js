const BUSD = artifacts.require("../Fakes/FakeBUSD.sol");

module.exports = async function (deployer) {
  await deployer.deploy(BUSD);




}   