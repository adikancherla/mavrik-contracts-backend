pragma solidity ^0.5.8;

import "zos-lib/contracts/Initializable.sol";
import "openzeppelin-eth/contracts/token/ERC721/ERC721.sol";
import "openzeppelin-eth/contracts/token/ERC721/ERC721Enumerable.sol";
import "openzeppelin-eth/contracts/token/ERC721/ERC721Metadata.sol";
import "openzeppelin-eth/contracts/token/ERC721/ERC721MetadataMintable.sol";
import "openzeppelin-eth/contracts/token/ERC721/ERC721Pausable.sol";

/**
 * @title Multi ERC721 token
 *
 */
contract MavrikNFTs is Initializable, ERC721, ERC721Enumerable, ERC721Metadata, ERC721MetadataMintable, ERC721Pausable {

    function initialize(string memory name, string memory symbol, address[] memory minters, address[] memory pausers) public initializer {
        ERC721.initialize();
        ERC721Enumerable.initialize();
        ERC721Metadata.initialize(name, symbol);

        // Initialize the minter and pauser roles, and renounce them
        ERC721MetadataMintable.initialize(address(this));
        _removeMinter(address(this));

        ERC721Pausable.initialize(address(this));
        _removePauser(address(this));

        // Add the requested minters and pausers (this can be done after renouncing since
        // these are the internal calls)
        for (uint256 i = 0; i < minters.length; ++i) {
            _addMinter(minters[i]);
        }

        for (uint256 i = 0; i < pausers.length; ++i) {
            _addPauser(pausers[i]);
        }
    }

    /**
     * @dev Burns a specific ERC721 token.
     * @param tokenId uint256 id of the ERC721 token to be burned.
     */
    function burn(uint256 tokenId) public {
        _burn(ownerOf(tokenId), tokenId);
    }

    uint256[50] private ______gap;
}