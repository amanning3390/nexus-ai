// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title NexusFaucet
 * @dev Testnet faucet for $NEXUS tokens
 */
contract NexusFaucet is Ownable {
    IERC20 public nexusToken;
    
    // Faucet settings
    uint256 public dripAmount = 100e18; // 100 NEXUS per drip
    uint256 public cooldownPeriod = 24 hours;
    
    mapping(address => uint256) public lastDripTime;
    mapping(address => uint256) public totalDripped;
    
    // Events
    event Dripped(address indexed recipient, uint256 amount);
    
    constructor(address _nexusToken) Ownable(msg.sender) {
        nexusToken = IERC20(_nexusToken);
    }
    
    /**
     * @dev Claim tokens from faucet
     */
    function drip() external {
        require(
            block.timestamp >= lastDripTime[msg.sender] + cooldownPeriod,
            "Cooldown not elapsed"
        );
        
        require(
            nexusToken.balanceOf(address(this)) >= dripAmount,
            "Faucet empty"
        );
        
        lastDripTime[msg.sender] = block.timestamp;
        totalDripped[msg.sender] += dripAmount;
        
        nexusToken.transfer(msg.sender, dripAmount);
        
        emit Dripped(msg.sender, dripAmount);
    }
    
    /**
     * @dev Get remaining cooldown for an address
     */
    function getCooldown(address user) external view returns (uint256) {
        if (lastDripTime[user] == 0) return 0;
        
        uint256 nextDrip = lastDripTime[user] + cooldownPeriod;
        if (block.timestamp >= nextDrip) return 0;
        
        return nextDrip - block.timestamp;
    }
    
    /**
     * @dev Owner: Refill faucet
     */
    function refill() external onlyOwner {
        // Owner can send more tokens to faucet
    }
    
    /**
     * @dev Owner: Set drip amount
     */
    function setDripAmount(uint256 amount) external onlyOwner {
        dripAmount = amount;
    }
    
    /**
     * @dev Owner: Set cooldown period
     */
    function setCooldownPeriod(uint256 period) external onlyOwner {
        cooldownPeriod = period;
    }
    
    /**
     * @dev Owner: Withdraw remaining tokens
     */
    function withdraw() external onlyOwner {
        uint256 balance = nexusToken.balanceOf(address(this));
        nexusToken.transfer(msg.sender, balance);
    }
}
