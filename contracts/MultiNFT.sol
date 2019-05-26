pragma solidity ^0.5.8;

library Address {
    /**
     * Returns whether the target address is a contract
     * @dev This function will return false if invoked during the constructor of a contract,
     * as the code is not actually created until after the constructor finishes.
     * @param account address of the account to check
     * @return whether the target address is a contract
     */
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        // XXX Currently there is no better way to check if there is a contract in an address
        // than to check the size of the code at that address.
        // See https://ethereum.stackexchange.com/a/14016/36603
        // for more details about how this works.
        // TODO Check this again before the Serenity release, because all addresses will be
        // contracts then.
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
    }
}

library Strings {

    function lowerCase(string memory base) internal pure returns (string memory) {
        bytes memory baseBytes = bytes(base);
        for (uint i = 0; i < baseBytes.length; i++) {
            baseBytes[i] = _lowerCase(baseBytes[i]);
        }
        return string(baseBytes);
    }

    function _lowerCase(bytes1 _b1) private pure returns (bytes1) {
        if (_b1 >= 0x41 && _b1 <= 0x5A) {
            return bytes1(uint8(_b1)+32);
        }
        return _b1;
    }

    /**
     * Equals
     * 
     * Compares the characters of two strings, to ensure that they have an 
     * identical footprint. A more gas optimal implementation based on checking hashes instead of char by char comparison is possible 
     * 
     * @param _base When being used for a data type this is the extended object
     *               otherwise this is the string base to compare against
     * @param _value The string the base is being compared to
     * @return bool Simply notates if the two string have an equivalent
     */
    function equals(string memory _base, string memory _value) 
        internal
        pure
        returns (bool) {
        bytes memory _baseBytes = bytes(_base);
        bytes memory _valueBytes = bytes(_value);

        if (_baseBytes.length != _valueBytes.length) {
            return false;
        }

        for(uint i = 0; i < _baseBytes.length; i++) {
            if (_baseBytes[i] != _valueBytes[i]) {
                return false;
            }
        }

        return true;
    }
}

/**
 * @title Roles
 * @dev Library for managing addresses assigned to a Role.
 */
library Roles {
    struct Role {
        mapping (address => bool) bearer;
    }

    /**
     * @dev give an account access to this role
     */
    function add(Role storage role, address account) internal {
        require(account != address(0), "Account cannot be 0 address");
        require(!has(role, account), "Account already has this role");

        role.bearer[account] = true;
    }

    /**
     * @dev remove an account's access to this role
     */
    function remove(Role storage role, address account) internal {
        require(account != address(0), "Account cannot be 0 address");
        require(has(role, account), "Account does not have this role");

        role.bearer[account] = false;
    }

    /**
     * @dev check if an account has this role
     * @return bool
     */
    function has(Role storage role, address account) internal view returns (bool) {
        require(account != address(0), "Account cannot be zero address");
        return role.bearer[account];
    }
}


library SafeMath {
    /**
    * @dev Multiplies two unsigned integers, reverts on overflow.
    */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b);

        return c;
    }

    /**
    * @dev Integer division of two unsigned integers truncating the quotient, reverts on division by zero.
    */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
    * @dev Subtracts two unsigned integers, reverts on overflow (i.e. if subtrahend is greater than minuend).
    */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        uint256 c = a - b;

        return c;
    }

    /**
    * @dev Adds two unsigned integers, reverts on overflow.
    */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a);

        return c;
    }

    /**
    * @dev Divides two unsigned integers and returns the remainder (unsigned integer modulo),
    * reverts when dividing by zero.
    */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0);
        return a % b;
    }
}

/**
 * @title Initializable
 *
 * @dev Helper contract to support initializer functions. To use it, replace
 * the constructor with a function that has the `initializer` modifier.
 * WARNING: Unlike constructors, initializer functions must be manually
 * invoked. This applies both to deploying an Initializable contract, as well
 * as extending an Initializable contract via inheritance.
 * WARNING: When used with inheritance, manual care must be taken to not invoke
 * a parent initializer twice, or ensure that all initializers are idempotent,
 * because this is not dealt with automatically as with constructors.
 */
contract Initializable {

  /**
   * @dev Indicates that the contract has been initialized.
   */
  bool private initialized;

  /**
   * @dev Indicates that the contract is in the process of being initialized.
   */
  bool private initializing;

  /**
   * @dev Modifier to use in the initializer function of a contract.
   */
  modifier initializer() {
    require(initializing || isConstructor() || !initialized, "Contract instance has already been initialized");

    bool wasInitializing = initializing;
    initializing = true;
    initialized = true;

    _;

    initializing = wasInitializing;
  }

  /// @dev Returns true if and only if the function is running in the constructor
  function isConstructor() private view returns (bool) {
    // extcodesize checks the size of the code stored in an address, and
    // address returns the current address. Since the code is still not
    // deployed when running a constructor, any checks on its code size will
    // yield zero, making it an effective way to detect if a contract is
    // under construction or not.
    uint256 cs;
    assembly { cs := extcodesize(address) }
    return cs == 0;
  }

  // Reserved storage space to allow for layout changes in the future.
  uint256[50] private ______gap;
}

contract PauserRole is Initializable {
    using Roles for Roles.Role;

    event PauserAdded(address indexed account);
    event PauserRemoved(address indexed account);

    Roles.Role private _pausers;

    function _initialize(address sender) internal initializer {
        if (!isPauser(sender)) {
            _addPauser(sender);
        }
    }

    modifier onlyPauser() {
        require(isPauser(msg.sender), "Sender is not a pauser");
        _;
    }

    function isPauser(address account) public view returns (bool) {
        return _pausers.has(account);
    }

    function addPauser(address account) public onlyPauser {
        _addPauser(account);
    }

    function renouncePauser() public {
        _removePauser(msg.sender);
    }

    function _addPauser(address account) internal {
        _pausers.add(account);
        emit PauserAdded(account);
    }

    function _removePauser(address account) internal {
        _pausers.remove(account);
        emit PauserRemoved(account);
    }

    uint256[50] private ______gap;
}


contract Pausable is Initializable, PauserRole {
    event Paused(address account);
    event Unpaused(address account);

    bool private _paused;

    function _initialize(address sender) internal initializer {
        PauserRole._initialize(sender);

        _paused = false;
    }

    /**
     * @return true if the contract is paused, false otherwise.
     */
    function paused() public view returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     */
    modifier whenNotPaused() {
        require(!_paused, "Contract paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     */
    modifier whenPaused() {
        require(_paused, "Contract not paused");
        _;
    }

    /**
     * @dev called by the owner to pause, triggers stopped state
     */
    function pause() public onlyPauser whenNotPaused {
        _paused = true;
        emit Paused(msg.sender);
    }

    /**
     * @dev called by the owner to unpause, returns to normal state
     */
    function unpause() public onlyPauser whenPaused {
        _paused = false;
        emit Unpaused(msg.sender);
    }

    uint256[50] private ______gap;
}

interface IERC165 {
    /**
     * @notice Query if a contract implements an interface
     * @param interfaceId The interface identifier, as specified in ERC-165
     * @dev Interface identification is specified in ERC-165. This function
     * uses less than 30,000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

contract IERC721 is Initializable, IERC165 {
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    function balanceOf(address owner) public view returns (uint256 balance);
    function ownerOf(uint256 tokenId) public view returns (address owner);

    function approve(address to, uint256 tokenId) public;
    function getApproved(uint256 tokenId) public view returns (address operator);

    function setApprovalForAll(address operator, bool _approved) public;
    function isApprovedForAll(address owner, address operator) public view returns (bool);

    function transferFrom(address from, address to, uint256 tokenId) public;
    function safeTransferFrom(address from, address to, uint256 tokenId) public;

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public;
}

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
contract IERC721Receiver {
    /**
     * @notice Handle the receipt of an NFT
     * @dev The ERC721 smart contract calls this function on the recipient
     * after a `safeTransfer`. This function MUST return the function selector,
     * otherwise the caller will revert the transaction. The selector to be
     * returned can be obtained as `this.onERC721Received.selector`. This
     * function MAY throw to revert and reject the transfer.
     * Note: the ERC721 contract address is always the message sender.
     * @param operator The address which called `safeTransferFrom` function
     * @param from The address which previously owned the token
     * @param tokenId The NFT identifier which is being transferred
     * @param data Additional data with no specified format
     * @return `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`
     */
    function onERC721Received(address operator, address from, uint256 tokenId, bytes memory data)
    public returns (bytes4);
}

contract IERC721Enumerable is Initializable, IERC721 {
    function totalSupply() public view returns (uint256);
    function tokenOfOwnerByIndex(address owner, uint256 index) public view returns (uint256 tokenId);

    function tokenByIndex(uint256 index) public view returns (uint256);
}

contract IERC721Metadata is Initializable, IERC721 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

contract ERC165 is Initializable, IERC165 {
    bytes4 private constant _INTERFACE_ID_ERC165 = 0x01ffc9a7;
    /**
     * 0x01ffc9a7 ===
     *     bytes4(keccak256('supportsInterface(bytes4)'))
     */

    /**
     * @dev a mapping of interface id to whether or not it's supported
     */
    mapping(bytes4 => bool) private _supportedInterfaces;

    /**
     * @dev A contract implementing SupportsInterfaceWithLookup
     * implement ERC165 itself
     */
    function _initialize() internal initializer {
        _registerInterface(_INTERFACE_ID_ERC165);
    }

    /**
     * @dev implement supportsInterface(bytes4) using a lookup table
     */
    function supportsInterface(bytes4 interfaceId) public view returns (bool) {
        return _supportedInterfaces[interfaceId];
    }

    /**
     * @dev internal method for registering an interface
     */
    function _registerInterface(bytes4 interfaceId) internal {
        require(interfaceId != 0xffffffff);
        _supportedInterfaces[interfaceId] = true;
    }

    uint256[50] private ______gap;
}

contract ERC721 is Initializable, ERC165, IERC721 {
    using SafeMath for uint256;
    using Address for address;

    // Equals to `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`
    // which can be also obtained as `IERC721Receiver(0).onERC721Received.selector`
    bytes4 private constant _ERC721_RECEIVED = 0x150b7a02;

    // Mapping from token ID to owner
    mapping (uint256 => address) private _tokenOwner;

    // Mapping from token ID to approved address
    mapping (uint256 => address) private _tokenApprovals;

    // Mapping from owner to number of owned token
    mapping (address => uint256) private _ownedTokensCount;

    // Mapping from owner to operator approvals
    mapping (address => mapping (address => bool)) private _operatorApprovals;

    bytes4 private constant _INTERFACE_ID_ERC721 = 0x80ac58cd;
    /*
     * 0x80ac58cd ===
     *     bytes4(keccak256('balanceOf(address)')) ^
     *     bytes4(keccak256('ownerOf(uint256)')) ^
     *     bytes4(keccak256('approve(address,uint256)')) ^
     *     bytes4(keccak256('getApproved(uint256)')) ^
     *     bytes4(keccak256('setApprovalForAll(address,bool)')) ^
     *     bytes4(keccak256('isApprovedForAll(address,address)')) ^
     *     bytes4(keccak256('transferFrom(address,address,uint256)')) ^
     *     bytes4(keccak256('safeTransferFrom(address,address,uint256)')) ^
     *     bytes4(keccak256('safeTransferFrom(address,address,uint256,bytes)'))
     */

    function _initialize() internal initializer {
        ERC165._initialize();

        // register the supported interfaces to conform to ERC721 via ERC165
        _registerInterface(_INTERFACE_ID_ERC721);
    }

    function _hasBeenInitialized() internal view returns (bool) {
        return supportsInterface(_INTERFACE_ID_ERC721);
    }

    /**
     * @dev Gets the balance of the specified address
     * @param owner address to query the balance of
     * @return uint256 representing the amount owned by the passed address
     */
    function balanceOf(address owner) public view returns (uint256) {
        require(owner != address(0));
        return _ownedTokensCount[owner];
    }

    /**
     * @dev Gets the owner of the specified token ID
     * @param tokenId uint256 ID of the token to query the owner of
     * @return owner address currently marked as the owner of the given token ID
     */
    function ownerOf(uint256 tokenId) public view returns (address) {
        address owner = _tokenOwner[tokenId];
        require(owner != address(0));
        return owner;
    }

    /**
     * @dev Approves another address to transfer the given token ID
     * The zero address indicates there is no approved address.
     * There can only be one approved address per token at a given time.
     * Can only be called by the token owner or an approved operator.
     * @param to address to be approved for the given token ID
     * @param tokenId uint256 ID of the token to be approved
     */
    function approve(address to, uint256 tokenId) public {
        address owner = ownerOf(tokenId);
        require(to != owner, "Cannot approve owner");
        require(msg.sender == owner || isApprovedForAll(owner, msg.sender), "Sender is not owner or not approved by owner");

        _tokenApprovals[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

    /**
     * @dev Gets the approved address for a token ID, or zero if no address set
     * Reverts if the token ID does not exist.
     * @param tokenId uint256 ID of the token to query the approval of
     * @return address currently approved for the given token ID
     */
    function getApproved(uint256 tokenId) public view returns (address) {
        require(_exists(tokenId), "Token does not exist");
        return _tokenApprovals[tokenId];
    }

    /**
     * @dev Sets or unsets the approval of a given operator
     * An operator is allowed to transfer all tokens of the sender on their behalf
     * @param to operator address to set the approval
     * @param approved representing the status of the approval to be set
     */
    function setApprovalForAll(address to, bool approved) public {
        require(to != msg.sender, "Cannot approve self");
        _operatorApprovals[msg.sender][to] = approved;
        emit ApprovalForAll(msg.sender, to, approved);
    }

    /**
     * @dev Tells whether an operator is approved by a given owner
     * @param owner owner address which you want to query the approval of
     * @param operator operator address which you want to query the approval of
     * @return bool whether the given operator is approved by the given owner
     */
    function isApprovedForAll(address owner, address operator) public view returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev Transfers the ownership of a given token ID to another address
     * Usage of this method is discouraged, use `safeTransferFrom` whenever possible
     * Requires the msg sender to be the owner, approved, or operator
     * @param from current owner of the token
     * @param to address to receive the ownership of the given token ID
     * @param tokenId uint256 ID of the token to be transferred
    */
    function transferFrom(address from, address to, uint256 tokenId) public {
        require(_isApprovedOrOwner(msg.sender, tokenId), "Sender is neither the owner or an approved address");

        _transferFrom(from, to, tokenId);
    }

    /**
     * @dev Safely transfers the ownership of a given token ID to another address
     * If the target address is a contract, it must implement `onERC721Received`,
     * which is called upon a safe transfer, and return the magic value
     * `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`; otherwise,
     * the transfer is reverted.
     *
     * Requires the msg sender to be the owner, approved, or operator
     * @param from current owner of the token
     * @param to address to receive the ownership of the given token ID
     * @param tokenId uint256 ID of the token to be transferred
    */
    function safeTransferFrom(address from, address to, uint256 tokenId) public {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev Safely transfers the ownership of a given token ID to another address
     * If the target address is a contract, it must implement `onERC721Received`,
     * which is called upon a safe transfer, and return the magic value
     * `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`; otherwise,
     * the transfer is reverted.
     * Requires the msg sender to be the owner, approved, or operator
     * @param from current owner of the token
     * @param to address to receive the ownership of the given token ID
     * @param tokenId uint256 ID of the token to be transferred
     * @param _data bytes data to send along with a safe transfer check
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) public {
        transferFrom(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721 received message not returned");
    }

    /**
     * @dev Returns whether the specified token exists
     * @param tokenId uint256 ID of the token to query the existence of
     * @return whether the token exists
     */
    function _exists(uint256 tokenId) internal view returns (bool) {
        address owner = _tokenOwner[tokenId];
        return owner != address(0);
    }

    /**
     * @dev Returns whether the given spender can transfer a given token ID
     * @param spender address of the spender to query
     * @param tokenId uint256 ID of the token to be transferred
     * @return bool whether the msg.sender is approved for the given token ID,
     *    is an operator of the owner, or is the owner of the token
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        address owner = ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    }

    /**
     * @dev Internal function to mint a new token
     * Reverts if the given token ID already exists
     * @param to The address that will own the minted token
     * @param tokenId uint256 ID of the token to be minted
     */
    function _mint(address to, uint256 tokenId) internal {
        require(to != address(0));
        require(!_exists(tokenId), "Token already exists");

        _tokenOwner[tokenId] = to;
        _ownedTokensCount[to] = _ownedTokensCount[to].add(1);

        emit Transfer(address(0), to, tokenId);
    }

    /**
     * @dev Internal function to burn a specific token
     * Reverts if the token does not exist
     * Deprecated, use _burn(uint256) instead.
     * @param sender sender of the token to burn
     * @param tokenId uint256 ID of the token being burned
     */
    function _burn(address sender, uint256 tokenId) internal {
        require(ownerOf(tokenId) == sender, "Burner is not owner");

        _clearApproval(tokenId);

        _ownedTokensCount[sender] = _ownedTokensCount[sender].sub(1);
        _tokenOwner[tokenId] = address(0);

        emit Transfer(sender, address(0), tokenId);
    }

    /**
     * @dev Internal function to burn a specific token
     * Reverts if the token does not exist
     * @param tokenId uint256 ID of the token being burned
     */
    function _burn(uint256 tokenId) internal {
        _burn(ownerOf(tokenId), tokenId);
    }

    /**
     * @dev Internal function to transfer ownership of a given token ID to another address.
     * As opposed to transferFrom, this imposes no restrictions on msg.sender.
     * @param from current owner of the token
     * @param to address to receive the ownership of the given token ID
     * @param tokenId uint256 ID of the token to be transferred
    */
    function _transferFrom(address from, address to, uint256 tokenId) internal {
        require(ownerOf(tokenId) == from, "Cannot send token from non owner");
        require(to != address(0));

        _clearApproval(tokenId);

        _ownedTokensCount[from] = _ownedTokensCount[from].sub(1);
        _ownedTokensCount[to] = _ownedTokensCount[to].add(1);

        _tokenOwner[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    /**
     * @dev Internal function to invoke `onERC721Received` on a target address
     * The call is not executed if the target address is not a contract
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param _data bytes optional data to send along with the call
     * @return whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory _data)
        internal returns (bool)
    {
        if (!to.isContract()) {
            return true;
        }

        bytes4 retval = IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, _data);
        return (retval == _ERC721_RECEIVED);
    }

    /**
     * @dev Private function to clear current approval of a given token ID
     * @param tokenId uint256 ID of the token to be transferred
     */
    function _clearApproval(uint256 tokenId) private {
        if (_tokenApprovals[tokenId] != address(0)) {
            _tokenApprovals[tokenId] = address(0);
        }
    }

    uint256[50] private ______gap;
}

contract ERC721Pausable is Initializable, ERC721, Pausable {
    function _initialize(address sender) internal initializer {
        require(ERC721._hasBeenInitialized());
        Pausable._initialize(sender);
    }

    function approve(address to, uint256 tokenId) public whenNotPaused {
        super.approve(to, tokenId);
    }

    function setApprovalForAll(address to, bool approved) public whenNotPaused {
        super.setApprovalForAll(to, approved);
    }

    function transferFrom(address from, address to, uint256 tokenId) public whenNotPaused {
        super.transferFrom(from, to, tokenId);
    }

    uint256[50] private ______gap;
}

contract ERC721Metadata is Initializable, ERC165, ERC721, IERC721Metadata {
    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Optional mapping for token URIs
    mapping(uint256 => string) private _tokenURIs;

    bytes4 private constant _INTERFACE_ID_ERC721_METADATA = 0x5b5e139f;
    /**
     * 0x5b5e139f ===
     *     bytes4(keccak256('name()')) ^
     *     bytes4(keccak256('symbol()')) ^
     *     bytes4(keccak256('tokenURI(uint256)'))
     */

    /**
     * @dev Constructor function
     */
    function _initialize(string memory name, string memory symbol) internal initializer {
        require(ERC721._hasBeenInitialized());

        _name = name;
        _symbol = symbol;

        // register the supported interfaces to conform to ERC721 via ERC165
        _registerInterface(_INTERFACE_ID_ERC721_METADATA);
    }

    function _hasBeenInitialized() internal view returns (bool) {
        return supportsInterface(_INTERFACE_ID_ERC721_METADATA);
    }
    /**
     * @dev Gets the token name
     * @return string representing the token name
     */
    function name() external view returns (string memory) {
        return _name;
    }

    /**
     * @dev Gets the token symbol
     * @return string representing the token symbol
     */
    function symbol() external view returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns an URI for a given token ID
     * Throws if the token ID does not exist. May return an empty string.
     * @param tokenId uint256 ID of the token to query
     */
    function tokenURI(uint256 tokenId) external view returns (string memory) {
        require(_exists(tokenId), "Token does not exist");
        return _tokenURIs[tokenId];
    }

    /**
     * @dev Internal function to set the token URI for a given token
     * Reverts if the token ID does not exist
     * @param tokenId uint256 ID of the token to set its URI
     * @param uri string URI to assign
     */
    function _setTokenURI(uint256 tokenId, string memory uri) internal {
        // the require here is redundant
        //require(_exists(tokenId), "Token does not exist");
        // decision to let the owner change token URI can have interesting consequences, but until ipfs based addressing becomes a reality,
        // we cannot rely on web links that can break
        //require(bytes(_tokenURIs[tokenId]).length == 0, "URI already set");
        _tokenURIs[tokenId] = uri;
    }

    /**
     * @dev Internal function to burn a specific token
     * Reverts if the token does not exist
     * Deprecated, use _burn(uint256) instead
     * @param owner owner of the token to burn
     * @param tokenId uint256 ID of the token being burned by the msg.sender
     */
    function _burn(address owner, uint256 tokenId) internal {
        super._burn(owner, tokenId);

        // Clear metadata (if any)
        if (bytes(_tokenURIs[tokenId]).length != 0) {
            delete _tokenURIs[tokenId];
        }
    }

    uint256[50] private ______gap;
}

contract ERC721MultiMetadata is ERC721Metadata {

    using Strings for string;

    uint256 constant _TYPE_MASK = uint256(uint128(~0)) << 128;
    // Token type to name mapping
    mapping(uint256 => string) private _names;

    // Token type to symbol mapping
    mapping(uint256 => string) private _symbols;

    // name to type mapping
    mapping(string => uint256) private _nameToType;

    mapping(string => uint256) private _symbolToType;

    /**
     * @dev Gets the token name of the given tokenId
     * @return string representing the token name
     */
    function name(uint256 tokenId) external view returns (string memory) {
        uint256 tokenType = tokenId & _TYPE_MASK;
        return _names[tokenType];
    }

    /**
     * @dev Gets the token symbol
     * @return string representing the token symbol
     */
    function symbol(uint256 tokenId) external view returns (string memory) {
        uint256 tokenType = tokenId & _TYPE_MASK;
        return _symbols[tokenType];
    }

    /**
     * @dev Sets name for the token type
     * @return string representing the token symbol
     */
    function _setName(uint256 tokenType, string memory tokenName) internal {
        require(bytes(_names[tokenType]).length == 0 && bytes(tokenName).length != 0, "Name is already set or supplied name is empty");
        _names[tokenType] = tokenName;
        _nameToType[tokenName.lowerCase()] = tokenType;
    }

    /**
     * @dev Sets name for the token type
     * @return string representing the token symbol
     */
    function _setSymbol(uint256 tokenType, string memory tokenSymbol) internal {
        require(bytes(_symbols[tokenType]).length == 0 && bytes(tokenSymbol).length != 0, "Symbol is already set or supplied symbol is empty");
        _symbols[tokenType] = tokenSymbol;
        _symbolToType[tokenSymbol.lowerCase()] = tokenType;
    }

    function nameExists(string memory tokenName) public view returns (bool) {
        return _nameToType[tokenName.lowerCase()] > 0;
    }

    function symbolExists(string memory tokenSymbol) public view returns (bool) {
        return _symbolToType[tokenSymbol.lowerCase()] > 0;
    }

    function tokenTypeOfName(string memory tokenName) public view returns (uint256) {
        return _nameToType[tokenName.lowerCase()];
    }

    function tokenTypeOfSymbol(string memory tokenSymbol) public view returns (uint256) {
        return _symbolToType[tokenSymbol.lowerCase()];
    }

    uint256[50] private ______gap;
}

contract ERC721Enumerable is Initializable, ERC165, ERC721, IERC721Enumerable {
    // Mapping from owner to list of owned token IDs
    mapping(address => uint256[]) private _ownedTokens;

    // Mapping from token ID to index of the owner tokens list
    mapping(uint256 => uint256) private _ownedTokensIndex;

    // Array with all token ids, used for enumeration
    uint256[] private _allTokens;

    // Mapping from token id to position in the allTokens array
    mapping(uint256 => uint256) private _allTokensIndex;

    bytes4 private constant _INTERFACE_ID_ERC721_ENUMERABLE = 0x780e9d63;
    /**
     * 0x780e9d63 ===
     *     bytes4(keccak256('totalSupply()')) ^
     *     bytes4(keccak256('tokenOfOwnerByIndex(address,uint256)')) ^
     *     bytes4(keccak256('tokenByIndex(uint256)'))
     */

    /**
     * @dev Constructor function
     */
    function _initialize() internal initializer {
        require(ERC721._hasBeenInitialized());

        // register the supported interface to conform to ERC721 via ERC165
        _registerInterface(_INTERFACE_ID_ERC721_ENUMERABLE);
    }

    function _hasBeenInitialized() internal view returns (bool) {
        return supportsInterface(_INTERFACE_ID_ERC721_ENUMERABLE);
    }

    /**
     * @dev Gets the token ID at a given index of the tokens list of the requested owner
     * @param owner address owning the tokens list to be accessed
     * @param index uint256 representing the index to be accessed of the requested tokens list
     * @return uint256 token ID at the given index of the tokens list owned by the requested address
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) public view returns (uint256) {
        require(index < balanceOf(owner), "Index must be less than balance");
        return _ownedTokens[owner][index];
    }

    /**
     * @dev Gets the total amount of tokens stored by the contract
     * @return uint256 representing the total amount of tokens
     */
    function totalSupply() public view returns (uint256) {
        return _allTokens.length;
    }

    /**
     * @dev Gets the token ID at a given index of all the tokens in this contract
     * Reverts if the index is greater or equal to the total number of tokens
     * @param index uint256 representing the index to be accessed of the tokens list
     * @return uint256 token ID at the given index of the tokens list
     */
    function tokenByIndex(uint256 index) public view returns (uint256) {
        require(index < totalSupply(), "Index must be less than total supply");
        return _allTokens[index];
    }

    /**
     * @dev Internal function to transfer ownership of a given token ID to another address.
     * As opposed to transferFrom, this imposes no restrictions on msg.sender.
     * @param from current owner of the token
     * @param to address to receive the ownership of the given token ID
     * @param tokenId uint256 ID of the token to be transferred
    */
    function _transferFrom(address from, address to, uint256 tokenId) internal {
        super._transferFrom(from, to, tokenId);

        _removeTokenFromOwnerEnumeration(from, tokenId);

        _addTokenToOwnerEnumeration(to, tokenId);
    }

    /**
     * @dev Internal function to mint a new token
     * Reverts if the given token ID already exists
     * @param to address the beneficiary that will own the minted token
     * @param tokenId uint256 ID of the token to be minted
     */
    function _mint(address to, uint256 tokenId) internal {
        super._mint(to, tokenId);

        _addTokenToOwnerEnumeration(to, tokenId);

        _addTokenToAllTokensEnumeration(tokenId);
    }

    /**
     * @dev Internal function to burn a specific token
     * Reverts if the token does not exist
     * Deprecated, use _burn(uint256) instead
     * @param owner owner of the token to burn
     * @param tokenId uint256 ID of the token being burned
     */
    function _burn(address owner, uint256 tokenId) internal {
        super._burn(owner, tokenId);

        _removeTokenFromOwnerEnumeration(owner, tokenId);
        // Since tokenId will be deleted, we can clear its slot in _ownedTokensIndex to trigger a gas refund
        _ownedTokensIndex[tokenId] = 0;

        _removeTokenFromAllTokensEnumeration(tokenId);
    }

    /**
     * @dev Gets the list of token IDs of the requested owner
     * @param owner address owning the tokens
     * @return uint256[] List of token IDs owned by the requested address
     */
    function _tokensOfOwner(address owner) internal view returns (uint256[] storage) {
        return _ownedTokens[owner];
    }

    /**
     * @dev Private function to add a token to this extension's ownership-tracking data structures.
     * @param to address representing the new owner of the given token ID
     * @param tokenId uint256 ID of the token to be added to the tokens list of the given address
     */
    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        _ownedTokensIndex[tokenId] = _ownedTokens[to].length;
        _ownedTokens[to].push(tokenId);
    }

    /**
     * @dev Private function to add a token to this extension's token tracking data structures.
     * @param tokenId uint256 ID of the token to be added to the tokens list
     */
    function _addTokenToAllTokensEnumeration(uint256 tokenId) private {
        _allTokensIndex[tokenId] = _allTokens.length;
        _allTokens.push(tokenId);
    }

    /**
     * @dev Private function to remove a token from this extension's ownership-tracking data structures. Note that
     * while the token is not assigned a new owner, the _ownedTokensIndex mapping is _not_ updated: this allows for
     * gas optimizations e.g. when performing a transfer operation (avoiding double writes).
     * This has O(1) time complexity, but alters the order of the _ownedTokens array.
     * @param from address representing the previous owner of the given token ID
     * @param tokenId uint256 ID of the token to be removed from the tokens list of the given address
     */
    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId) private {
        // To prevent a gap in from's tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = _ownedTokens[from].length.sub(1);
        uint256 tokenIndex = _ownedTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _ownedTokens[from][lastTokenIndex];

            _ownedTokens[from][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
            _ownedTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index
        }

        // This also deletes the contents at the last position of the array
        _ownedTokens[from].length--;

        // Note that _ownedTokensIndex[tokenId] hasn't been cleared: it still points to the old slot (now occcupied by
        // lasTokenId, or just over the end of the array if the token was the last one).
    }

    /**
     * @dev Private function to remove a token from this extension's token tracking data structures.
     * This has O(1) time complexity, but alters the order of the _allTokens array.
     * @param tokenId uint256 ID of the token to be removed from the tokens list
     */
    function _removeTokenFromAllTokensEnumeration(uint256 tokenId) private {
        // To prevent a gap in the tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = _allTokens.length.sub(1);
        uint256 tokenIndex = _allTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary. However, since this occurs so
        // rarely (when the last minted token is burnt) that we still do the swap here to avoid the gas cost of adding
        // an 'if' statement (like in _removeTokenFromOwnerEnumeration)
        uint256 lastTokenId = _allTokens[lastTokenIndex];

        _allTokens[tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
        _allTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index

        // This also deletes the contents at the last position of the array
        _allTokens.length--;
        _allTokensIndex[tokenId] = 0;
    }

    uint256[50] private ______gap;
}

/**
 * @title Multi ERC721 token
 *
 */
contract MultiNFT is Initializable, ERC721, ERC721Enumerable, ERC721MultiMetadata, ERC721Pausable {

    // Use a split bit implementation.
    // Store the type in the upper 128 bits
    uint256 constant _TYPE_MASK = uint256(uint128(~0)) << 128;
    // and the non-fungible index in the lower 128
    uint256 constant _INDEX_MASK = uint128(~0);

    uint256 _numTypesCreated;

    // type => (owner => balance)
    mapping (uint256 => mapping(address => uint256)) private _typeBalances;

    // tyoe => creator
    mapping (uint256 => address) private _typeCreators;

    // type => maxIndex of type
    mapping (uint256 => uint256) private _maxIndexOfType;

    // dev fee for token actions, if exists; type => fee
    mapping (uint256 => uint256) private _devFee;

    mapping (uint256 => string) private _webTypeCreators;

    mapping (uint256 => string) private _webOwners;

    mapping (address => bool) private _webApprovers;
    

    modifier creatorOnly(uint256 tokenType) {
        require(_typeCreators[tokenType] == msg.sender, "Only token type creators can perform this operation");
        _;
    }

    modifier webApprovedOnly() {
        require(_webApprovers[msg.sender] == true, "Only web approvers can perform this operation");
        _;
    }

    event CreateType(string name, string symbol, string uri, address indexed creator);
    event SetUri(uint256 indexed tokenId, string uri);
    event WebCreateType(string name, string symbol, string uri, string owner, address indexed operator);
    event WebMint(string tokenName, string uri, uint256 count, string owner);
    event WebClaimType(string tokenName, string oldOwner, address indexed newOwner);
    event WebTransfer(address indexed to, uint256 indexed tokenId, string owner);

    function initialize(string memory name, string memory symbol, address[] memory pausers, address[] memory webApprovers) public initializer {
        ERC721._initialize();
        ERC721Enumerable._initialize();
        ERC721Metadata._initialize(name, symbol);

        // Initialize the pauser roles, and renounce them
        ERC721Pausable._initialize(address(this));
        _removePauser(address(this));

        // Add the requested pausers (this can be done after renouncing since this is an internal call)
        for (uint256 i = 0; i < pausers.length; ++i) {
            _addPauser(pausers[i]);
        }

        for (uint256 i = 0; i < webApprovers.length; ++i) {
            addWebApprover(webApprovers[i]);
        }
    }

    function getTypeBalance(uint256 tokenType, address owner) public view returns (uint256) {
        return _typeBalances[tokenType][owner];
    }

    function getCreator(uint256 tokenType) public view returns (address) {
        return _typeCreators[tokenType];
    }

    function getMaxIndex(uint256 tokenType) public view returns (uint256) {
        return _maxIndexOfType[tokenType];
    }

    function numTypesCreated() public view returns (uint256) {
        return _numTypesCreated;
    }

    // returns index of the given tokenId of this type
    function getIndex(uint256 tokenId) public pure returns (uint256) {
        return tokenId & _INDEX_MASK;
    }

    // returns the type of this tokenId
    function getType(uint256 tokenId) public pure returns (uint256) {
        return tokenId & _TYPE_MASK;
    }

    // This function only creates the type.
    function createType(string calldata name, string calldata symbol, string calldata uri) external whenNotPaused returns (uint256) {
        require(_numTypesCreated < _TYPE_MASK, "Limit of max number of types reached. This is the end of the world.");
        require(!nameExists(name), "Name already exists");
        require(!symbolExists(symbol), "Symbol already exists");

        // Store the type in the upper 128 bits
        _numTypesCreated = _numTypesCreated.add(1);
        uint256 tokenType = (_numTypesCreated << 128);

        // This will allow restricted access to creators.
        _typeCreators[tokenType] = msg.sender;

        _setName(tokenType, name);
        _setSymbol(tokenType, symbol);

        // mint the first token of this type with index 0 and send to type creator
        _mintWithTokenURI(msg.sender, tokenType, uri);
        _typeBalances[tokenType][msg.sender] = _typeBalances[tokenType][msg.sender].add(1);

        emit CreateType(name, symbol, uri, msg.sender);

        return tokenType;
    }

    function _mint(uint256 tokenType, address[] memory to, string memory uri) internal whenNotPaused creatorOnly(tokenType) {
        require(_maxIndexOfType[tokenType].add(to.length) < _INDEX_MASK, "Limit of max number of tokens of this type reached and the world ends now.");

        uint256 index = _maxIndexOfType[tokenType].add(1);

        for (uint256 i = 0; i < to.length; ++i) {
            address dest = to[i];
            uint256 tokenId  = tokenType | index.add(i);
            _mintWithTokenURI(dest, tokenId, uri);
            _typeBalances[tokenType][dest] = _typeBalances[tokenType][dest].add(1);
        }

        _maxIndexOfType[tokenType] = to.length.add(_maxIndexOfType[tokenType]);
    }

    function mint(string calldata tokenName, address[] calldata to, string calldata uri) external {
        _mint(tokenTypeOfName(tokenName), to, uri);
    }

    function _mintWithTokenURI(address to, uint256 tokenId, string memory tokenURI) internal returns (bool) {
        _mint(to, tokenId);
        _setTokenURI(tokenId, tokenURI);
        return true;
    }

    function _transferFrom(address from, address to, uint256 tokenId) internal {
        super._transferFrom(from, to, tokenId);
        uint256 tokenType = getType(tokenId);
        _typeBalances[tokenType][from] = _typeBalances[tokenType][from].sub(1);
        _typeBalances[tokenType][to] = _typeBalances[tokenType][to].add(1);
    }

    // sets only when eixsting URI is blank
    function setTokenURI(uint256 tokenId, string calldata uri) external whenNotPaused {
        require(bytes(uri).length != 0, "URI cannot be empty");
        require(ownerOf(tokenId) == msg.sender, "Only owner can set uri");
        _setTokenURI(tokenId, uri);

        emit SetUri(tokenId, uri);
    }

    function addWebApprover(address approver) public whenNotPaused webApprovedOnly {
        _webApprovers[approver] = true;
    }

    function removeWebApprover(address approver) public whenNotPaused webApprovedOnly {
        delete _webApprovers[approver];
    }

    function webCreateType(string calldata name, string calldata symbol, string calldata uri, string calldata owner) external whenNotPaused webApprovedOnly returns (uint256) {
        require(_numTypesCreated < _TYPE_MASK, "Limit of max number of types reached. This is the end of the world.");
        require(!nameExists(name), "Name already exists");
        require(!symbolExists(symbol), "Symbol already exists");

        // Store the type in the upper 128 bits
        _numTypesCreated = _numTypesCreated.add(1);
        uint256 tokenType = (_numTypesCreated << 128);
        require(!_exists(tokenType), "Token type already exists"); // may be redundant

        _webTypeCreators[tokenType] = owner;
        _setName(tokenType, name);
        _setSymbol(tokenType, symbol);
        _setTokenURI(tokenType, uri);
        _webOwners[tokenType] = owner;

        emit WebCreateType(name, symbol, uri, owner, msg.sender);
        return tokenType;
    }

    function webClaimType(string calldata tokenName, string calldata oldOwner, address newOwner) external whenNotPaused webApprovedOnly returns (bool) {
        uint256 tokenType = tokenTypeOfName(tokenName);
        require(_webTypeCreators[tokenType].equals(oldOwner), "Only owner can claim type");
        _typeCreators[tokenType] = newOwner;
        delete _webTypeCreators[tokenType];
        emit WebClaimType(tokenName, oldOwner, newOwner);
        return true;
    }

    function webMint(string calldata tokenName, string calldata uri, uint256 count, string calldata owner) external whenNotPaused webApprovedOnly {
        require(count < 20, "Cannot mint more than 20 tokens at a time"); //arbitrarily set to 20
        uint256 tokenType = tokenTypeOfName(tokenName);
        require(_maxIndexOfType[tokenType].add(count) < _INDEX_MASK, "Limit of max number of tokens of this type reached and the world ends now.");

        uint256 index = _maxIndexOfType[tokenType].add(1);

        for (uint256 i = 0; i < count; ++i) {
            uint256 tokenId  = tokenType | index.add(i);
            _setTokenURI(tokenId, uri);
            _webOwners[tokenId] = owner;
        }

        _maxIndexOfType[tokenType] = count.add(_maxIndexOfType[tokenType]);

        emit WebMint(tokenName, uri, count, owner);
    }

    function webTransfer(address to, uint256 tokenId, string calldata owner) external whenNotPaused webApprovedOnly {
        require(_webOwners[tokenId].equals(owner), "Only owner can transfer");
        _mint(to, tokenId);
        uint256 tokenType = getType(tokenId);
        _typeBalances[tokenType][to] = _typeBalances[tokenType][to].add(1);
        delete _webOwners[tokenId];
        emit WebTransfer(to, tokenId, owner);
    }

    function webSetTokenURI(uint256 tokenId, string calldata uri, string calldata owner) external whenNotPaused webApprovedOnly {
        require(bytes(uri).length != 0, "URI cannot be empty");
        require(_webOwners[tokenId].equals(owner), "Only owner can set uri");
        _setTokenURI(tokenId, uri);
        emit SetUri(tokenId, uri);
    }

    /**
     * @dev Burns a specific ERC721 token.
     * @param tokenId uint256 id of the ERC721 token to be burned.
     */
    function burn(uint256 tokenId) external whenNotPaused {
        uint256 tokenType = getType(tokenId);
        _burn(msg.sender, tokenId);
        _typeBalances[tokenType][msg.sender] = _typeBalances[tokenType][msg.sender].sub(1);
    }

    uint256[50] private ______gap;
}