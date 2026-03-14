// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title NexusToken
 * @dev $NEXUS - Community-Owned AGI Token
 */
contract NexusToken is ERC20, ERC20Burnable, Ownable, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 1e18; // 1 Billion
    uint256 public mintedSupply;
    
    // Vesting schedules
    mapping(address => VestingSchedule) public vestingSchedules;
    
    struct VestingSchedule {
        uint256 totalAmount;
        uint256 startTime;
        uint256 cliffDuration;
        uint256 duration;
        uint256 releasedAmount;
    }
    
    // Tokenomics
    uint256 public communityAllocation = 400_000_000 * 1e18;  // 40%
    uint256 public teamAllocation = 200_000_000 * 1e18;      // 20%
    uint256 public investorAllocation = 150_000_000 * 1e18;  // 15%
    uint256 public treasuryAllocation = 150_000_000 * 1e18;   // 15%
    uint256 public airdropAllocation = 50_000_000 * 1e18;    // 5%
    uint256 public liquidityAllocation = 50_000_000 * 1e18;   // 5%
    
    // Tracks which allocations have been minted
    bool public communityMinted;
    bool public teamMinted;
    bool public investorsMinted;
    bool public treasuryMinted;
    bool public airdropMinted;
    bool public liquidityMinted;
    
    // Treasury multi-sig (placeholder)
    address public treasury = 0x1234567890123456789012345678901234567890;
    
    event VestingCreated(address indexed beneficiary, uint256 amount);
    event VestingReleased(address indexed beneficiary, uint256 amount);
    event TreasuryUpdated(address indexed newTreasury);

    constructor() ERC20("Nexus AI", "NEXUS") Ownable(msg.sender) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }

    /**
     * @dev Mint tokens to an address
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        require(mintedSupply + amount <= MAX_SUPPLY, "Max supply exceeded");
        mintedSupply += amount;
        _mint(to, amount);
    }

    /**
     * @dev Create a vesting schedule for a beneficiary
     */
    function createVesting(
        address beneficiary,
        uint256 amount,
        uint256 cliffDuration,
        uint256 duration
    ) external onlyOwner {
        require(vestingSchedules[beneficiary].totalAmount == 0, "Vesting exists");
        
        vestingSchedules[beneficiary] = VestingSchedule({
            totalAmount: amount,
            startTime: block.timestamp,
            cliffDuration: cliffDuration,
            duration: duration,
            releasedAmount: 0
        });
        
        emit VestingCreated(beneficiary, amount);
    }

    /**
     * @dev Release vested tokens for a beneficiary
     */
    function releaseVesting(address beneficiary) external {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        require(schedule.totalAmount > 0, "No vesting");
        
        uint256 releasable = _computeReleasable(schedule);
        require(releasable > 0, "No tokens due");
        
        schedule.releasedAmount += releasable;
        _mint(beneficiary, releasable);
        
        emit VestingReleased(beneficiary, releasable);
    }

    /**
     * @dev Calculate releasable amount for a vesting schedule
     */
    function _computeReleasable(VestingSchedule storage schedule) internal view returns (uint256) {
        if (block.timestamp < schedule.startTime + schedule.cliffDuration) {
            return 0;
        }
        if (block.timestamp >= schedule.startTime + schedule.duration) {
            return schedule.totalAmount - schedule.releasedAmount;
        }
        uint256 timeFromStart = block.timestamp - schedule.startTime;
        uint256 vestedAmount = (schedule.totalAmount * timeFromStart) / schedule.duration;
        return vestedAmount - schedule.releasedAmount;
    }

    /**
     * @dev Get releasable amount for a beneficiary
     */
    function getReleasableAmount(address beneficiary) external view returns (uint256) {
        return _computeReleasable(vestingSchedules[beneficiary]);
    }

    /**
     * @dev Update treasury address
     */
    function setTreasury(address newTreasury) external onlyOwner {
        require(newTreasury != address(0), "Invalid treasury");
        treasury = newTreasury;
        emit TreasuryUpdated(newTreasury);
    }

    /**
     * @dev Batch mint for initial allocations (only owner, one-time)
     */
    function mintInitialAllocations(
        address communityRecipient,
        address airdropRecipient,
        address liquidityRecipient
    ) external onlyOwner {
        // Community rewards (40%)
        if (!communityMinted) {
            _mint(communityRecipient, communityAllocation);
            communityMinted = true;
        }
        
        // Airdrop (5%)
        if (!airdropMinted) {
            _mint(airdropRecipient, airdropAllocation);
            airdropMinted = true;
        }
        
        // Liquidity (5%)
        if (!liquidityMinted) {
            _mint(liquidityRecipient, liquidityAllocation);
            liquidityMinted = true;
        }
    }

    /**
     * @dev Batch create team vesting (called once)
     */
    function batchCreateTeamVesting(address[] calldata beneficiaries, uint256[] calldata amounts) external onlyOwner {
        require(beneficiaries.length == amounts.length, "Length mismatch");
        
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            // 4 year vesting, 1 year cliff
            this.createVesting(beneficiaries[i], amounts[i], 365 days, 1460 days);
        }
        teamMinted = true;
    }

    /**
     * @dev Batch create investor vesting (called once)
     */
    function batchCreateInvestorVesting(address[] calldata beneficiaries, uint256[] calldata amounts) external onlyOwner {
        require(beneficiaries.length == amounts.length, "Length mismatch");
        
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            // 2 year vesting, 6 month cliff
            this.createVesting(beneficiaries[i], amounts[i], 180 days, 730 days);
        }
        investorsMinted = true;
    }

    /**
     * @dev Batch create treasury vesting (called once)
     */
    function batchCreateTreasuryVesting(address[] calldata beneficiaries, uint256[] calldata amounts) external onlyOwner {
        require(beneficiaries.length == amounts.length, "Length mismatch");
        
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            // 3 year vesting, no cliff
            this.createVesting(beneficiaries[i], amounts[i], 0, 1095 days);
        }
        treasuryMinted = true;
    }

    // The following functions are overrides required by Solidity.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
