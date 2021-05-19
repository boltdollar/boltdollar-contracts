const CAKE2 = artifacts.require("../Fakes/FakeCake.sol");
const BTD = artifacts.require("../Fakes/FakeBTD.sol");
const EPS = artifacts.require("../Fakes/FakeEPS.sol");

module.exports = async function (deployer) {
  await deployer.deploy(CAKE2);
  await deployer.deploy(BTD);
  await deployer.deploy(EPS);
}   