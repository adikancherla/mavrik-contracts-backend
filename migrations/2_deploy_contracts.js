const SimpleStorage = artifacts.require("SimpleStorage");
const ERC1155 = artifacts.require("ERC1155");
const ERC1155Mintable = artifacts.require("ERC1155Mintable");
const ERC1155MixedFungible = artifacts.require("ERC1155MixedFungible");
const ERC1155MixedFungibleMintable = artifacts.require(
	"ERC1155MixedFungibleMintable"
);
const ERC1155MockReceiver = artifacts.require("ERC1155MockReceiver");

module.exports = function(deployer) {
	deployer.deploy(SimpleStorage);
	deployer.deploy(ERC1155);
	deployer.deploy(ERC1155Mintable);
	deployer.deploy(ERC1155MixedFungible);
	deployer.deploy(ERC1155MixedFungibleMintable);
	deployer.deploy(ERC1155MockReceiver);
};
