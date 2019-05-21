pragma solidity ^0.5.8;

import "zos-lib/contracts/Initializable.sol";
import "openzeppelin-eth/contracts/token/ERC721/ERC721.sol";
import "openzeppelin-eth/contracts/token/ERC721/ERC721Enumerable.sol";
import "openzeppelin-eth/contracts/token/ERC721/ERC721Metadata.sol";
import "openzeppelin-eth/contracts/token/ERC721/ERC721Pausable.sol";

/**
 * @title Multi ERC721 token
 *
 */
contract MavrikNFTs is Initializable, ERC721, ERC721Enumerable, ERC721Metadata, ERC721Pausable {

    // Use a split bit implementation.
    // Store the type in the upper 128 bits
    uint256 constant _TYPE_MASK = uint256(uint128(~0)) << 128;
    // and the non-fungible index in the lower 128
    uint256 constant _INDEX_MASK = uint128(~0);

    // token type
    uint256 _tokenType;

    // type => (owner => balance)
    mapping (uint256 => mapping(address => uint256)) private _typeBalances;

    // tyoe => creator
    mapping (uint256 => address) private _typeCreators;

    // type => maxIndex of type
    mapping (uint256 => uint256) private _maxIndexOfType;

    // dev fee for token actions, if exists; type => fee
    mapping (uint256 => uint256) private _devFee;

    modifier creatorOnly(uint256 tokenType) {
        require(_typeCreators[tokenType] == msg.sender);
        _;
    }

    function initialize(string memory name, string memory symbol, address[] memory pausers) public initializer {
        ERC721.initialize();
        ERC721Enumerable.initialize();
        ERC721Metadata.initialize(name, symbol);

        // Initialize the pauser roles, and renounce them
        ERC721Pausable.initialize(address(this));
        _removePauser(address(this));

        // Add the requested pausers (this can be done after renouncing since
        // this is an internal calls)
        for (uint256 i = 0; i < pausers.length; ++i) {
            _addPauser(pausers[i]);
        }
    }

    // returns index of the given tokenId of this type
    function getIndex(uint256 tokenId) public pure returns(uint256) {
        return tokenId & _INDEX_MASK;
    }

    // returns the type of this tokenId
    function getType(uint256 tokenId) public pure returns(uint256) {
        return tokenId & _TYPE_MASK;
    }

    // This function only creates the type.
    function createType(string calldata uri) external returns(uint256) {
        require(_tokenType < _TYPE_MASK);
        // Store the type in the upper 128 bits
        _tokenType = _tokenType.add(1);

        // This will allow restricted access to creators.
        _typeCreators[_tokenType] = msg.sender;

        // mint the first token of this type with index 0 and send to type creator
        uint256 tokenId = _tokenType << 128;
        _mintWithTokenURI(msg.sender, tokenId, uri);
        _typeBalances[_tokenType][msg.sender] = _typeBalances[_tokenType][msg.sender].add(1);
        return _tokenType;
    }

    function mint(uint256 tokenType, address[] calldata to, string calldata uri) external creatorOnly(tokenType) {
        require(_maxIndexOfType[tokenType].add(to.length) < _INDEX_MASK);

        uint256 index = _maxIndexOfType[tokenType].add(1);

        for (uint256 i = 0; i < to.length; ++i) {
            address dest = to[i];
            uint256 tokenId  = tokenType | index.add(i);
            _mintWithTokenURI(dest, tokenId, uri);
            _typeBalances[tokenType][dest] = _typeBalances[tokenType][dest].add(1);
        }

        _maxIndexOfType[tokenType] = to.length.add(_maxIndexOfType[tokenType]);
    }

    function _mintWithTokenURI(address to, uint256 tokenId, string memory tokenURI) internal returns (bool) {
        _mint(to, tokenId);
        _setTokenURI(tokenId, tokenURI);
        return true;
    }

    /**
     * @dev Burns a specific ERC721 token.
     * @param tokenId uint256 id of the ERC721 token to be burned.
     */
    function burn(uint256 tokenId) external {
        address owner = ownerOf(tokenId);
        uint256 tokenType = getType(tokenId);
        _burn(owner, tokenId);
        _typeBalances[tokenType][owner] = _typeBalances[tokenType][owner].sub(1);
    }

    uint256[50] private ______gap;
}