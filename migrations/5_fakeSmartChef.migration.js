const FakeSmartChef = artifacts.require("../contracts/Fakes/FakeSmartChef.sol");
const FakeCake = artifacts.require("../contracts/Fakes/FakeCake.sol");
const FakeEPS = artifacts.require("../contracts/Fakes/FakeEPS.sol");

module.exports = async function (deployer) {

    let fakeCake = await FakeCake.deployed();
    let fakeEPS = await FakeEPS.deployed();
    await deployer.deploy(FakeSmartChef, fakeCake.address, fakeEPS.address);
};
