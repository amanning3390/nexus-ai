// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title NexusStaking
 * @dev Stake $NEXUS and earn rewards
 */
contract NexusStaking is Ownable {
    using SafeERC20 for IERC20;
    
    IERC20 public nexusToken;
    
    // Staking info
    struct StakeInfo {
        uint256 amount;
        uint256 startTime;
        uint256 rewards;
        uint256 lastClaimTime;
    }
    
    mapping(address => StakeInfo[]) public stakes;
    mapping(address => uint256) public totalStaked;
    uint256 public totalStakedSupply;
    
    // Reward rates (per second, scaled by 1e18)
    // 100 NEXUS per year per 1 NEXUS staked = 100e18/31536000
    uint256 public rewardRate;
    
    // Duration
    uint256 public constant MIN_STAKE_DURATION = 7 days;
    uint256 public constant EARLY_WITHDRAWAL_PENALTY = 10; // 10%
    
    // Events
    event Staked(address indexed user, uint256 amount, uint256 stakeId);
    event Unstaked(address indexed user, uint256 amount, uint256 stakeId);
    event RewardClaimed(address indexed user, uint256 reward);
    event RewardRateUpdated(uint256 newRate);
    
    constructor(address _nexusToken) Ownable(msg.sender) {
        nexusToken = IERC20(_nexusToken);
        rewardRate = 31709791983765; // ~100e18/365days (wei per second)
    }
    
    /**
     * @dev Stake NEXUS tokens
     */
    function stake(uint256 amount) external {
        require(amount > 0, "Cannot stake 0");
        
        nexusToken.safeTransferFrom(msg.sender, address(this), amount);
        
        stakes[msg.sender].push(StakeInfo({
            amount: amount,
            startTime: block.timestamp,
            rewards: 0,
            lastClaimTime: block.timestamp
        }));
        
        totalStaked[msg.sender] += amount;
        totalStakedSupply += amount;
        
        emit Staked(msg.sender, amount, stakes[msg.sender].length - 1);
    }
    
    /**
     * @dev Claim pending rewards
     */
    function claimRewards() external {
        uint256 totalReward = 0;
        
        for (uint256 i = 0; i < stakes[msg.sender].length; i++) {
            StakeInfo storage stakeInfo = stakes[msg.sender][i];
            if (stakeInfo.amount == 0) continue;
            
            uint256 pending = calculatePendingReward(msg.sender, i);
            if (pending > 0) {
                stakeInfo.rewards += pending;
                stakeInfo.lastClaimTime = block.timestamp;
                totalReward += pending;
            }
        }
        
        require(totalReward > 0, "No rewards to claim");
        
        nexusToken.safeTransfer(msg.sender, totalReward);
        
        emit RewardClaimed(msg.sender, totalReward);
    }
    
    /**
     * @dev Unstake tokens (with penalty if early)
     */
    function unstake(uint256 stakeId) external {
        require(stakeId < stakes[msg.sender].length, "Invalid stake ID");
        
        StakeInfo storage stakeInfo = stakes[msg.sender][stakeId];
        require(stakeInfo.amount > 0, "Already unstaked");
        
        // Calculate pending rewards
        uint256 pending = calculatePendingReward(msg.sender, stakeId);
        uint256 amount = stakeInfo.amount;
        
        // Apply early withdrawal penalty if < min duration
        uint256 withdrawAmount = amount;
        if (block.timestamp - stakeInfo.startTime < MIN_STAKE_DURATION) {
            uint256 penalty = (amount * EARLY_WITHDRAWAL_PENALTY) / 100;
            withdrawAmount = amount - penalty;
            // Penalty goes to treasury
            totalStakedSupply -= penalty;
        }
        
        // Clear stake
        stakeInfo.amount = 0;
        
        // Update totals
        totalStaked[msg.sender] -= amount;
        totalStakedSupply -= amount;
        
        // Transfer tokens
        nexusToken.safeTransfer(msg.sender, withdrawAmount);
        
        // Transfer pending rewards
        if (pending > 0) {
            nexusToken.safeTransfer(msg.sender, pending);
            emit RewardClaimed(msg.sender, pending);
        }
        
        emit Unstaked(msg.sender, amount, stakeId);
    }
    
    /**
     * @dev Calculate pending rewards for a stake
     */
    function calculatePendingReward(address user, uint256 stakeId) public view returns (uint256) {
        StakeInfo storage stakeInfo = stakes[user][stakeId];
        if (stakeInfo.amount == 0) return 0;
        
        uint256 timeStaked = block.timestamp - stakeInfo.lastClaimTime;
        uint256 pending = (stakeInfo.amount * rewardRate * timeStaked) / (365 days * 1e18);
        
        return pending;
    }
    
    /**
     * @dev Get total pending rewards for a user
     */
    function getTotalPendingRewards(address user) external view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < stakes[user].length; i++) {
            total += calculatePendingReward(user, i);
        }
        return total;
    }
    
    /**
     * @dev Update reward rate (owner only)
     */
    function setRewardRate(uint256 newRate) external onlyOwner {
        rewardRate = newRate;
        emit RewardRateUpdated(newRate);
    }
    
    /**
     * @dev Get stake count for user
     */
    function getStakeCount(address user) external view returns (uint256) {
        return stakes[user].length;
    }
}
