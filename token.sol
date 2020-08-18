pragma solidity 0.5.10;

// This is a Token tutorial from ethereum.org

contract Token {
    address public owner;
    mapping (address => uint) public balances;
    
    event Transfer(address from, address to, uint amount);
    
    constructor() public {
        owner = msg.sender;
    }
    
    function mint(address receiver, uint amount) public {
        require(msg.sender == owner, "You are not the owner!");
        require(amount < 1e60, "Maximum issuance succeeded");
        balances[receiver] += amount;
    }
    
    function transfer(address receiver, uint amount) public {
        require(amount <= balances[msg.sender], "You don't have enough tokens");
        balances[receiver] += amount;
        balances[msg.sender] -= amount;
        emit Transfer(msg.sender, receiver, amount);
    }
}
