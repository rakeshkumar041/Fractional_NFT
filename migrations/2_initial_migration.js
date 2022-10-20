const FNFT = artifacts.require("FractionalNFT");

module.exports = function (deployer) {
  deployer.deploy(FNFT);
};
