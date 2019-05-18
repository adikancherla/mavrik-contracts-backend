pragma solidity ^0.5.0;

import "zos-lib/contracts/Initializable.sol";
import "openzeppelin-eth/contracts/math/SafeMath.sol";
import "openzeppelin-eth/contracts/utils/Address.sol";
import "openzeppelin-eth/contracts/introspection/IERC165.sol";
import "./IERC1155TokenReceiver.sol";
import "./IERC1155.sol";
import "openzeppelin-eth/contracts/ownership/Ownable.sol";
import "openzeppelin-eth/contracts/lifecycle/Pausable.sol";

contract Mavrik is IERC1155, IERC165, Pausable, Ownable {

	using SafeMath for uint256;
    using Address for address;

    // Use a split bit implementation.
    // Store the type in the upper 128 bits..
    uint256 constant TYPE_MASK = uint256(uint128(~0)) << 128;
    // ..and the non-fungible index in the lower 128
    uint256 constant NF_INDEX_MASK = uint128(~0);
    // The top bit is a flag to tell if this is a NFI.
    uint256 constant TYPE_NF_BIT = 1 << 255;

    // bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))
    bytes4 constant public ERC1155_RECEIVED = 0xf23a6e61;
    //bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))
    bytes4 constant public ERC1155_BATCH_RECEIVED = 0xbc197c81;

    /////////////////////////////////////////// ERC165 //////////////////////////////////////////////

    /*
        bytes4(keccak256('supportsInterface(bytes4)'));
    */
    bytes4 constant public INTERFACE_SIGNATURE_ERC165 = 0x01ffc9a7;

    /*
        bytes4(keccak256("safeTransferFrom(address,address,uint256,uint256,bytes)")) ^
        bytes4(keccak256("safeBatchTransferFrom(address,address,uint256[],uint256[],bytes)")) ^
        bytes4(keccak256("balanceOf(address,uint256)")) ^
        bytes4(keccak256("balanceOfBatch(address[],uint256[])")) ^
        bytes4(keccak256("setApprovalForAll(address,bool)")) ^
        bytes4(keccak256("isApprovedForAll(address,address)"));
    */
    bytes4 constant public INTERFACE_SIGNATURE_ERC1155 = 0xd9b67a26;

	// metadata
    string public name;
    string public symbol;
    string public version;

    uint256 nonce;

    // id => (owner => balance)
    mapping (uint256 => mapping(address => uint256)) internal balances;
    mapping (uint256 => address) nfOwners;
    // owner => (operator => approved)
    mapping (address => mapping(address => bool)) internal operatorApproval;
    mapping (uint256 => address) public creators;
    mapping (uint256 => uint256) public maxIndex;

    // num of token types created
    uint256 numTypes;

    // dev fee for token actions, if exists
    mapping (uint256 => uint256) public devFee;

    modifier senderOrApprovedOnly(address _from) {
        require(_from == msg.sender || operatorApproval[_from][msg.sender] == true, "Need operator approval for 3rd party transfers");
        _;
    }

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

    function initialize(address _from) initializer public senderOrApprovedOnly(_from) {
    	Pausable.initialize(_from);
    	Ownable.initialize(_from);
        name = "Mavrik";
    	symbol = "MAV";
    	version = "1.0.2";
    }

    function supportsInterface(bytes4 _interfaceId)
    public
    view
    returns (bool) {
         if (_interfaceId == INTERFACE_SIGNATURE_ERC165 ||
             _interfaceId == INTERFACE_SIGNATURE_ERC1155) {
            return true;
         }

         return false;
    }

    // todo: Are these functions pure or view
    function isNonFungible(uint256 _id) public pure returns(bool) {
        return _id & TYPE_NF_BIT == TYPE_NF_BIT;
    }
    function isFungible(uint256 _id) public pure returns(bool) {
        return _id & TYPE_NF_BIT == 0;
    }
    function getNonFungibleIndex(uint256 _id) public pure returns(uint256) {
        return _id & NF_INDEX_MASK;
    }
    function getNonFungibleBaseType(uint256 _id) public pure returns(uint256) {
        return _id & TYPE_MASK;
    }
    function isNonFungibleBaseType(uint256 _id) public pure returns(bool) {
        // A base type has the NF bit but does not have an index.
        return (_id & TYPE_NF_BIT == TYPE_NF_BIT) && (_id & NF_INDEX_MASK == 0);
    }
    function isNonFungibleItem(uint256 _id) public pure returns(bool) {
        // A base type has the NF bit but does has an index.
        return (_id & TYPE_NF_BIT == TYPE_NF_BIT) && (_id & NF_INDEX_MASK != 0);
    }
    function ownerOf(uint256 _id) public view returns (address) {
        return nfOwners[_id];
    }

    // overide
    function safeTransferFrom(address _from, address _to, uint256 _id, uint256 _value, bytes calldata _data) external senderOrApprovedOnly(_from) {

        require(_to != address(0x0), "cannot send to zero address");
        if (_to.isContract()) {
            require(IERC1155TokenReceiver(_to).onERC1155Received(msg.sender, _from, _id, _value, _data) == ERC1155_RECEIVED);
        }

        if (isNonFungible(_id)) {
            require(nfOwners[_id] == _from);
            nfOwners[_id] = _to;
            // You could keep balance of NF type in base type id like so:
            uint256 baseType = getNonFungibleBaseType(_id);
            balances[baseType][_from] = balances[baseType][_from].sub(_value);
            balances[baseType][_to]   = balances[baseType][_to].add(_value);
        } else {
            balances[_id][_from] = balances[_id][_from].sub(_value);
            balances[_id][_to]   = balances[_id][_to].add(_value);
        }

        emit TransferSingle(msg.sender, _from, _to, _id, _value);
    }

    // overide
    function safeBatchTransferFrom(address _from, address _to, uint256[] calldata _ids, uint256[] calldata _values, bytes calldata _data) external senderOrApprovedOnly(_from) {

        require(_to != address(0x0), "cannot send to zero address");
        require(_ids.length == _values.length, "Array length must match");
        if (_to.isContract()) {
            require(IERC1155TokenReceiver(_to).onERC1155BatchReceived(msg.sender, _from, _ids, _values, _data) == ERC1155_BATCH_RECEIVED);
        }

        for (uint256 i = 0; i < _ids.length; ++i) {
            // Cache value to local variable to reduce read costs.
            uint256 id = _ids[i];

            if (isNonFungible(id)) {
                require(nfOwners[id] == _from);
                nfOwners[id] = _to;
                // You could keep balance of NF type in base type id like so:
                uint256 baseType = getNonFungibleBaseType(id);
                balances[baseType][_from] = balances[baseType][_from].sub(_values[i]);
                balances[baseType][_to]   = balances[baseType][_to].add(_values[i]);
            } else {
                balances[id][_from] = balances[id][_from].sub(_values[i]);
                balances[id][_to]   = _values[i].add(balances[id][_to]);
            }
        }

        emit TransferBatch(msg.sender, _from, _to, _ids, _values);
    }

    function balanceOf(address _owner, uint256 _id) external view returns (uint256) {
        if (isNonFungibleItem(_id))
            return nfOwners[_id] == _owner ? 1 : 0;
        return balances[_id][_owner];
    }

    function balanceOfBatch(address[] calldata _owners, uint256[] calldata _ids) external view returns (uint256[] memory) {

        require(_owners.length == _ids.length);

        uint256[] memory balances_ = new uint256[](_owners.length);

        for (uint256 i = 0; i < _owners.length; ++i) {
            uint256 id = _ids[i];
            if (isNonFungibleItem(id)) {
                balances_[i] = nfOwners[id] == _owners[i] ? 1 : 0;
            } else {
                balances_[i] = balances[id][_owners[i]];
            }
        }

        return balances_;
    }

     /**
        @notice Enable or disable approval for a third party ("operator") to manage all of the caller's tokens.
        @dev MUST emit the ApprovalForAll event on success.
        @param _operator  Address to add to the set of authorized operators
        @param _approved  True if the operator is approved, false to revoke approval
    */
    function setApprovalForAll(address _operator, bool _approved) external {
        operatorApproval[msg.sender][_operator] = _approved;
        emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    /**
        @notice Queries the approval status of an operator for a given owner.
        @param _owner     The owner of the Tokens
        @param _operator  Address of authorized operator
        @return           True if the operator is approved, false if not
    */
    function isApprovedForAll(address _owner, address _operator) external view returns (bool) {
        return operatorApproval[_owner][_operator];
    }

    // This function only creates the type.
    function create(string calldata _uri, bool _isNF) external returns(uint256 _type) {

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
	function burnFungible(address _from, uint256 _id, uint256 _amount) external senderOrApprovedOnly(_from) {    
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
	function batchBurnFungible(address _from, uint256[] calldata _ids, uint256[] calldata _amounts) external senderOrApprovedOnly(_from) {
	    require(_ids.length == _amounts.length, "id and amount array lengths must match");

	     // Executing all minting
	    for (uint256 i = 0; i < _ids.length; i++) {
	      // Update storage balance
	      balances[_ids[i]][_from] = balances[_ids[i]][_from].sub(_amounts[i]);
	    }

	    // Emit batch mint event
	    emit TransferBatch(msg.sender, _from, address(0x0), _ids, _amounts);
	}

	function burnNonFungible(address _from, uint256 _id) external senderOrApprovedOnly(_from) {
	    // get base type and subtract balance
	    uint256 baseType = getNonFungibleBaseType(_id);
	    balances[baseType][_from] = balances[baseType][_from].sub(1);

	    nfOwners[_id] = address(0x0);

	    // Emit event
	    emit TransferSingle(msg.sender, _from, address(0x0), _id, 1);
	}

	function batchBurnNonFungible(address _from, uint256[] calldata _ids) external senderOrApprovedOnly(_from) {
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