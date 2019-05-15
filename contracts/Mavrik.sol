pragma solidity ^0.5.0;

import "./ERC1155MixedFungibleMintableBurnable.sol";
import "zos-lib/contracts/Initializable.sol";

contract Mavrik is ERC1155MixedFungibleMintableBurnable, Initializable {
	// metadata
    string public name;
    string public symbol;
    string public version;

    // num of token types created
    uint256 numTypes;

    // dev fee for token actions, if exists
    mapping (uint256 => uint256) public devFee;

    function initialize() initializer public {
        name = "Mavrik";
    	symbol = "MAV";
    	version = "1.0.0";
    }

}