// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title NexusGovernor
 * @dev On-chain governance for Nexus AI
 */
contract NexusGovernor is Ownable {
    using SafeERC20 for IERC20;
    
    IERC20 public nexusToken;
    
    // Governance parameters
    uint256 public proposalThreshold = 10_000_000e18; // 10M NEXUS to propose
    uint256 public quorumThreshold = 50_000_000e18;   // 50M NEXUS for quorum
    uint256 public votingDelay = 1 days;
    uint256 public votingPeriod = 5 days;
    
    // Proposal state
    enum ProposalState { Pending, Active, Canceled, Defeated, Succeeded, Executed }
    
    struct Proposal {
        address proposer;
        string description;
        address target;
        bytes data;
        uint256 voteStart;
        uint256 voteEnd;
        uint256 forVotes;
        uint256 againstVotes;
        bool executed;
        bool canceled;
    }
    
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    uint256 public proposalCount;
    
    // Events
    event ProposalCreated(uint256 indexed id, address proposer, string description);
    event VoteCast(uint256 indexed id, address voter, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed id);
    event ProposalCanceled(uint256 indexed id);
    
    constructor(address _nexusToken) Ownable(msg.sender) {
        nexusToken = IERC20(_nexusToken);
    }
    
    /**
     * @dev Create a new proposal
     */
    function propose(
        string memory description,
        address target,
        bytes memory data
    ) external returns (uint256) {
        require(
            nexusToken.balanceOf(msg.sender) >= proposalThreshold,
            "Below proposal threshold"
        );
        
        proposalCount++;
        uint256 id = proposalCount;
        
        Proposal storage proposal = proposals[id];
        proposal.proposer = msg.sender;
        proposal.description = description;
        proposal.target = target;
        proposal.data = data;
        proposal.voteStart = block.timestamp + votingDelay;
        proposal.voteEnd = proposal.voteStart + votingPeriod;
        
        emit ProposalCreated(id, msg.sender, description);
        
        return id;
    }
    
    /**
     * @dev Cast a vote on a proposal
     */
    function castVote(uint256 proposalId, bool support) external {
        require(proposalId <= proposalCount, "Invalid proposal");
        
        Proposal storage proposal = proposals[proposalId];
        require(
            block.timestamp >= proposal.voteStart && 
            block.timestamp < proposal.voteEnd,
            "Voting not active"
        );
        require(!hasVoted[proposalId][msg.sender], "Already voted");
        
        uint256 weight = nexusToken.balanceOf(msg.sender);
        require(weight > 0, "No voting power");
        
        hasVoted[proposalId][msg.sender] = true;
        
        if (support) {
            proposal.forVotes += weight;
        } else {
            proposal.againstVotes += weight;
        }
        
        emit VoteCast(proposalId, msg.sender, support, weight);
    }
    
    /**
     * @dev Execute a proposal if it passed
     */
    function execute(uint256 proposalId) external {
        require(proposalId <= proposalCount, "Invalid proposal");
        
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp >= proposal.voteEnd, "Voting not ended");
        require(!proposal.executed, "Already executed");
        require(!proposal.canceled, "Canceled");
        
        // Check quorum
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes;
        require(totalVotes >= quorumThreshold, "Quorum not reached");
        require(proposal.forVotes > proposal.againstVotes, "Proposal defeated");
        
        proposal.executed = true;
        
        // Execute the proposal data
        if (proposal.target != address(0) && proposal.data.length > 0) {
            (bool success, ) = proposal.target.call(proposal.data);
            require(success, "Execution failed");
        }
        
        emit ProposalExecuted(proposalId);
    }
    
    /**
     * @dev Cancel a proposal (only proposer)
     */
    function cancel(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(msg.sender == proposal.proposer, "Not proposer");
        require(!proposal.executed, "Already executed");
        
        proposal.canceled = true;
        
        emit ProposalCanceled(proposalId);
    }
    
    /**
     * @dev Get proposal state
     */
    function state(uint256 proposalId) external view returns (ProposalState) {
        require(proposalId <= proposalCount, "Invalid proposal");
        
        Proposal storage proposal = proposals[proposalId];
        
        if (proposal.canceled) return ProposalState.Canceled;
        if (proposal.executed) return ProposalState.Executed;
        if (block.timestamp < proposal.voteStart) return ProposalState.Pending;
        if (block.timestamp < proposal.voteEnd) return ProposalState.Active;
        
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes;
        if (totalVotes < quorumThreshold || proposal.forVotes <= proposal.againstVotes) {
            return ProposalState.Defeated;
        }
        
        return ProposalState.Succeeded;
    }
    
    /**
     * @dev Update governance parameters
     */
    function setProposalThreshold(uint256 threshold) external onlyOwner {
        proposalThreshold = threshold;
    }
    
    function setQuorumThreshold(uint256 threshold) external onlyOwner {
        quorumThreshold = threshold;
    }
    
    function setVotingDelay(uint256 delay) external onlyOwner {
        votingDelay = delay;
    }
    
    function setVotingPeriod(uint256 period) external onlyOwner {
        votingPeriod = period;
    }
}
