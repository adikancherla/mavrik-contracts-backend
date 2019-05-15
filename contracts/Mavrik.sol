pragma solidity ^0.5.0;

import "./ERC1155MixedFungibleMintableBurnable.sol";

contract Mavrik is ERC1155MixedFungibleMintableBurnable {
	// metadata
    string public constant name = "Mavrik";
    string public constant symbol = "MAV";
    string public version = "1.0.0";

    // num of token types created
    uint256 numTypes;

    // dev fee for token actions, if exists
    mapping (uint256 => uint256) public devFee;

}