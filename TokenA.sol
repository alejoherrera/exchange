// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenA is ERC20, Ownable {
    uint256 public constant INITIAL_SUPPLY = 1000000 * 10**18; // 1 millón de tokens
    
    constructor() ERC20("Token A", "TKA") Ownable(msg.sender) {
        _mint(msg.sender, INITIAL_SUPPLY);
    }
    
    // Función para mintear más tokens (útil para testing)
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
    
    // Función para quemar tokens
    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }
    
    // Función para que el owner pueda transferir tokens a usuarios para testing
    function distributeTokens(address[] memory recipients, uint256 amount) public onlyOwner {
        for (uint256 i = 0; i < recipients.length; i++) {
            _transfer(msg.sender, recipients[i], amount);
        }
    }
}