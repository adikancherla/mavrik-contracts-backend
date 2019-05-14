pragma solidity ^0.5.0;

import "./ERC1155MixedFungible.sol";

/**
    @dev Mintable form of ERC1155
    Shows how easy it is to mint new items
*/
contract ERC1155MixedFungibleMintableBurnable is ERC1155MixedFungible {

    uint256 nonce;
    mapping (uint256 => address) public creators;
    mapping (uint256 => uint256) public maxIndex;

    modifier creatorOnly(uint256 _id) {
        require(creators[_id] == msg.sender);
        _;
    }

    modifier fungibleCreatorsOnly(uint256[] memory _ids) {
        for (uint256 i = 0; i < _ids.length; i++) {
            require(creators[_ids[i]] == msg.sender);
            require(isFungible(_ids[i]));
        }
        _;
    }

    modifier nonFungibleCreatorsOnly(uint256[] memory _types) {
        for (uint256 i = 0; i < _types.length; i++) {
            require(creators[_types[i]] == msg.sender);
            require(isNonFungible(_types[i]));
        }
        _;
    }

    // This function only creates the type.
    function create(string calldata _uri, bool   _isNF) external returns(uint256 _type) {

        // Store the type in the upper 128 bits
        // todo: what happens to types and index in each type when nonce number is greater than 128 bits?
        _type = (++nonce << 128);

        // Set a flag if this is an NFI.
        if (_isNF)
          _type = _type | TYPE_NF_BIT;

        // This will allow restricted access to creators.
        creators[_type] = msg.sender;

        // emit a Transfer event with Create semantic to help with discovery.
        emit TransferSingle(msg.sender, address(0x0), address(0x0), _type, 0);

        if (bytes(_uri).length > 0)
            emit URI(_uri, _type);
    }

    function mintNonFungible(uint256 _type, address[] calldata _to) external creatorOnly(_type) {

        // creatorOnly() will only let a valid type pass through.
        require(isNonFungible(_type));

        // Index are 1-based.
        uint256 index = maxIndex[_type] + 1;

        for (uint256 i = 0; i < _to.length; ++i) {
            address dst = _to[i];
            uint256 id  = _type | index + i;

            if (dst.isContract()) {
                require(IERC1155TokenReceiver(dst).onERC1155Received(msg.sender, msg.sender, id, 1, '') == ERC1155_RECEIVED);
            }

            nfOwners[id] = dst;

            // You could use base-type id to store NF type balances if you wish.
            balances[_type][dst] = balances[_type][dst].add(1);

            emit TransferSingle(msg.sender, address(0x0), dst, id, 1);
        }

        maxIndex[_type] = _to.length.add(maxIndex[_type]);
    }

    function mintFungible(uint256 _id, address[] calldata _to, uint256[] calldata _quantities) external creatorOnly(_id) {

        require(isFungible(_id));
        require(_to.length == _quantities.length, "Array lengths must match");

        for (uint256 i = 0; i < _to.length; ++i) {

            address to = _to[i];
            uint256 quantity = _quantities[i];

            if (to.isContract()) {
                require(IERC1155TokenReceiver(to).onERC1155Received(msg.sender, msg.sender, _id, quantity, '') == ERC1155_RECEIVED);
            }

            // Grant the items to the caller
            balances[_id][to] = quantity.add(balances[_id][to]);

            // Emit the Transfer/Mint event.
            // the 0x0 source address implies a mint
            // It will also provide the circulating supply info.
            emit TransferSingle(msg.sender, address(0x0), to, _id, quantity);
        }
    }

    // Batch mint tokens of different non fungible types. Assign directly to _to.
    function batchMintNonFungibles(address _to, uint256[] calldata _types) external nonFungibleCreatorsOnly(_types) {

        uint256[] memory ones;

        if (_to.isContract()) {
            require(IERC1155TokenReceiver(_to).onERC1155BatchReceived(msg.sender, address(0x0), _types, ones, '') == ERC1155_BATCH_RECEIVED, "Receiver contract did not accept the transfer.");
        }

        for (uint256 i = 0; i < _types.length; ++i) {
            uint256 tokenType = _types[i];
            // Index are 1-based
            uint256 index = maxIndex[tokenType] + 1;
            uint256 id  = tokenType | index + i;

            nfOwners[id] = _to;

            // You could use base-type id to store NF type balances if you wish.
            balances[tokenType][_to] = balances[tokenType][_to].add(1);
            maxIndex[tokenType] = maxIndex[tokenType].add(1);

        }

        // Emit batch mint event
        emit TransferBatch(msg.sender, address(0x0), _to, _types, ones);
    }

    // Batch mint tokens of different fungible types. Assign directly to _to.
    function batchMintFungibles(address _to, uint256[] calldata _ids, uint256[] calldata _amounts) external fungibleCreatorsOnly(_ids) {

        require(_ids.length == _amounts.length, "Array lengths must match");

        if (_to.isContract()) {
            require(IERC1155TokenReceiver(_to).onERC1155BatchReceived(msg.sender, address(0x0), _ids, _amounts, '') == ERC1155_BATCH_RECEIVED, "Receiver contract did not accept the transfer.");
        }

         // Executing all minting
        for (uint256 i = 0; i < _ids.length; i++) {
          // Update storage balance
          balances[_ids[i]][_to] = balances[_ids[i]][_to].add(_amounts[i]);
        }

        // Emit batch mint event
        emit TransferBatch(msg.sender, address(0x0), _to, _ids, _amounts);
    }

    /**
   * @notice Burn _amount of tokens of a given token id 
   * @param _from    The address to burn tokens from
   * @param _id      Token id to burn
   * @param _amount  The amount to be burned
   */
  function burnFungible(address _from, uint256 _id, uint256 _amount) external {    
    //Substract _amount
    balances[_id][_from] = balances[_id][_from].sub(_amount);

    // Emit event
    emit TransferSingle(msg.sender, _from, address(0x0), _id, _amount);
  }

  /**
   * @notice Burn tokens of given token id for each (_ids[i], _amounts[i]) pair 
   * @param _from     The address to burn tokens from
   * @param _ids      Array of token ids to burn
   * @param _amounts  Array of the amount to be burned
   */
  function batchBurnFungible(address _from, uint256[] calldata _ids, uint256[] calldata _amounts) external {
    require(_ids.length == _amounts.length, "id and amount array lengths must match");

     // Executing all minting
    for (uint256 i = 0; i < _ids.length; i++) {
      // Update storage balance
      balances[_ids[i]][_from] = balances[_ids[i]][_from].sub(_amounts[i]);
    }

    // Emit batch mint event
    emit TransferBatch(msg.sender, _from, address(0x0), _ids, _amounts);
  }

  function burnNonFungible(address _from, uint256 _id) external {
    // get base type and subtract balance
    uint256 baseType = getNonFungibleBaseType(_id);
    balances[baseType][_from] = balances[baseType][_from].sub(1);

    nfOwners[_id] = address(0x0);

    // Emit event
    emit TransferSingle(msg.sender, _from, address(0x0), _id, 1);
  }

  function batchBurnNonFungible(address _from, uint256[] calldata _ids) external {
    // get base type and subtract balance
    for (uint256 i = 0; i < _ids.length; i++) {
        uint256 baseType = getNonFungibleBaseType(_ids[i]);
        balances[baseType][_from] = balances[baseType][_from].sub(1);
        nfOwners[_ids[i]] = address(0x0);
    }

    uint256[] memory ones;
    // Emit event
    emit TransferBatch(msg.sender, _from, address(0x0), _ids, ones);
  }
}
