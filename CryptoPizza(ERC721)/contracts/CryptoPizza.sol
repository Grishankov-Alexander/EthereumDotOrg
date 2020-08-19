pragma solidity ^0.5.10;

import "../node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "../node_modules/@openzeppelin/contracts/introspection/ERC165.sol";
import "../node_modules/@openzeppelin/contracts/math/SafeMath.sol";

contract CryptoPizza is IERC721, ERC165 {
    
    using SafeMath for uint256;
    
    uint256 constant dnaDigits = 10;
    uint256 constant dnaModulus = 10 ** dnaDigits;
    bytes4 private constant _ERC721_RECEIVED = 0x150b7a02;
    
    struct Pizza {
        string name;
        uint256 dna;
    }
    
    Pizza[] public pizzas;
    mapping(uint256 => address) public pizzaToOwner;
    mapping(address => uint256) public ownerPizzaCount;
    mapping(uint256 => address) pizzaApprovals;
    mapping(address => mapping(address => bool)) private operatorApprovals;
    
    function _createPizza(string memory _name, uint256 _dna)
        internal _isUnique(_name, _dna)
    {
        uint256 id = SafeMath.sub(pizzas.push(Pizza(_name, _dna)), 1);
        assert(pizzaToOwner[id] == address(0));
        pizzaToOwner[id] = msg.sender;
        ownerPizzaCount[msg.sender] = SafeMath.add(
            ownerPizzaCount[msg.sender], 1
        );
    }
    
    function createRandomPizza(string memory _name) public
    {
        uint256 randDna = generateRandomDna(_name, msg.sender);
        _createPizza(_name, randDna);
    }
    
    function generateRandomDna(string memory _str, address _owner)
        public pure returns (uint256)
    {
        uint256 rand = uint256(keccak256(abi.encodePacked(_str)))
            + uint256(_owner);
        rand = SafeMath.mod(rand, dnaModulus);    
        return rand;
    }
    
    function getPizzasByOwner(address _owner)
        public view returns (uint256[] memory)
    {
        uint256[] memory result = new uint256[](ownerPizzaCount[_owner]);
        uint256 counter = 0;
        for (uint256 i = 0; i < pizzas.length; ++i) {
            if (pizzaToOwner[i] == _owner) {
                result[counter] = i;
                counter++;
            }
        }
        return result;
    }
    
    function transferFrom(address _from, address _to, uint256 _pizzaId)
        public
    {
        require(_from != address(0) && _to != address(0), "Invalid address");
        require(_from != _to, "Cannot transfer to the same address");
        require(_exists(_pizzaId), "Pizza doesn't exist");
        require(_isApprovedOrOwner(_from, _pizzaId), "Address is not approved");
        
        ownerPizzaCount[_from] = SafeMath.sub(ownerPizzaCount[_from], 1);
        ownerPizzaCount[_to] = SafeMath.add(ownerPizzaCount[_to], 1);
        pizzaToOwner[_pizzaId] = _to;
        
        emit Transfer(_from, _to, _pizzaId);
        _clearApproval(_to, _pizzaId);
    }
    
    function safeTransferFrom(address _from, address _to, uint256 _pizzaId)
        public
    {
        this.safeTransferFrom(_from, _to, _pizzaId, "");
    }
    
    function safeTransferFrom(
        address _from, address _to,
        uint256 _pizzaId, bytes memory _data
        )
        public
    {
        this.transferFrom(_from, _to, _pizzaId);
        require(_checkOnERC721Received(_from, _to, _pizzaId, _data),
            "Must implement onERC721Received");
    }
    
    function _checkOnERC721Received(
        address _from, address _to,
        uint256 _pizzaId, bytes memory _data
        ) internal returns (bool)
    {
        if (!isContract(_to)) {
            return true;
        }
        bytes4 retval = IERC721Receiver(_to).onERC721Received(
            msg.sender, _from, _pizzaId, _data);
        return (retval == _ERC721_RECEIVED);
    }
    
    function burn(uint256 _pizzaId) external {
        require(msg.sender != address(0), "Invalid address.");
        require(_exists(_pizzaId), "Pizza does not exist");
        require(_isApprovedOrOwner(msg.sender, _pizzaId),
            "Address is not approved");
        
        ownerPizzaCount[msg.sender] = SafeMath.sub(
            ownerPizzaCount[msg.sender], 1);
        pizzaToOwner[_pizzaId] = address(0);
    }
    
    function balanceOf(address _owner) public view returns (uint256)
    {
        return ownerPizzaCount[_owner];
    }
    
    function ownerOf(uint256 _pizzaId) public view returns (address)
    {
        address owner = pizzaToOwner[_pizzaId];
        require(owner != address(0), "Invalid pizza ID");
        return owner;
    }
    
    function approve(address _to, uint256 _pizzaId) public
    {
        require(msg.sender == pizzaToOwner[_pizzaId], "Must be the pizza owner");
        pizzaApprovals[_pizzaId] = _to;
        emit Approval(msg.sender, _to, _pizzaId);
    }
    
    function getApproved(uint256 _pizzaId)
        public view returns (address _operator)
    {
        require(_exists(_pizzaId), "Pizza does not exist");
        return pizzaApprovals[_pizzaId];
    }
    
    function _clearApproval(address _owner, uint256 _pizzaId)
        private
    {
        require(pizzaToOwner[_pizzaId] == _owner, "Must be a pizza owner");
        require(_exists(_pizzaId), "Pizza does not exist");
        if (pizzaApprovals[_pizzaId] != address(0)) {
            pizzaApprovals[_pizzaId] = address(0);
        }
    }
    
    function setApprovalForAll(address _to, bool _approved) public
    {
        require(_to != msg.sender, "Cannot approve own address");
        operatorApprovals[msg.sender][_to] = _approved;
        emit ApprovalForAll(msg.sender, _to, _approved);
    }
    
    function isApprovedForAll(address _owner, address _operator)
        public view returns (bool approved)
    {
        return operatorApprovals[_owner][_operator];    
    }
    
    function takeOwnership(uint256 _pizzaId)
        public
    {
        require(_isApprovedOrOwner(msg.sender, _pizzaId), "Address is not approved");
        address owner = this.ownerOf(_pizzaId);
        this.transferFrom(owner, msg.sender, _pizzaId);
    }
    
    function _exists(uint256 _pizzaId) internal view returns (bool)
    {
        address owner = pizzaToOwner[_pizzaId];
        return (owner != address(0));
    }
    
    function _isApprovedOrOwner(address _spender, uint256 _pizzaId)
        internal view returns (bool approved)
    {
        address owner = pizzaToOwner[_pizzaId];
        return (_spender == owner
            || this.isApprovedForAll(owner, _spender)
            || this.getApproved(_pizzaId) == _spender);
    }
    
    modifier _isUnique(string memory _name, uint256 _dna)
    {
        bool result = true;
        for (uint256 i = 0; i < pizzas.length; i++) {
            if (
                keccak256(abi.encodePacked(_name))
                == keccak256(abi.encodePacked(pizzas[i].name))
                && pizzas[i].dna == _dna
            ) {
                result = false;
            }
        }
        require(result, "Pizza with such name already exists");
        _;
    }
    
    function isContract(address _account) internal view returns (bool)
    {
        uint256 size;
        assembly {
            size := extcodesize(_account)
        }
        return size > 0;
    }
    
}
