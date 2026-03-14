// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {NexusToken} from "../token/NexusToken.sol";

contract NexusTokenTest is Test {
    NexusToken public token;
    
    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    
    uint256 public constant INITIAL_SUPPLY = 1000e18;
    
    function setUp() public {
        vm.prank(owner);
        token = new NexusToken();
    }
    
    function testTokenMetadata() public view {
        assertEq(token.name(), "Nexus AI");
        assertEq(token.symbol(), "NEXUS");
        assertEq(token.decimals(), 18);
    }
    
    function testInitialSupply() public view {
        assertEq(token.totalSupply(), 0);
    }
    
    function testMint() public {
        vm.prank(owner);
        token.mint(user1, INITIAL_SUPPLY);
        
        assertEq(token.balanceOf(user1), INITIAL_SUPPLY);
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
    }
    
    function testMintOnlyMinter() public {
        vm.prank(user1);
        vm.expectRevert();
        token.mint(user1, INITIAL_SUPPLY);
    }
    
    function testBurn() public {
        vm.prank(owner);
        token.mint(user1, INITIAL_SUPPLY);
        
        vm.prank(user1);
        token.burn(INITIAL_SUPPLY / 2);
        
        assertEq(token.balanceOf(user1), INITIAL_SUPPLY / 2);
    }
    
    function testTransfer() public {
        vm.prank(owner);
        token.mint(user1, INITIAL_SUPPLY);
        
        vm.prank(user1);
        token.transfer(user2, 100e18);
        
        assertEq(token.balanceOf(user1), INITIAL_SUPPLY - 100e18);
        assertEq(token.balanceOf(user2), 100e18);
    }
    
    function testAllowance() public {
        vm.prank(owner);
        token.mint(user1, INITIAL_SUPPLY);
        
        vm.prank(user1);
        token.approve(user2, 500e18);
        
        assertEq(token.allowance(user1, user2), 500e18);
    }
    
    function testTransferFrom() public {
        vm.prank(owner);
        token.mint(user1, INITIAL_SUPPLY);
        
        vm.prank(user1);
        token.approve(address(this), 500e18);
        
        token.transferFrom(user1, user2, 500e18);
        
        assertEq(token.balanceOf(user2), 500e18);
    }
    
    function testSnapshot() public {
        vm.prank(owner);
        token.mint(user1, INITIAL_SUPPLY);
        
        vm.prank(owner);
        uint256 snapshotId = token.snapshot();
        
        assertEq(snapshotId, 1);
    }
    
    function testVestingCreation() public {
        vm.prank(owner);
        token.createVesting(user1, 1000e18, 365 days, 1460 days);
        
        (uint256 total, uint256 start, uint256 cliff, uint256 duration, uint256 released) = 
            token.vestingSchedules(user1);
        
        assertEq(total, 1000e18);
        assertEq(cliff, 365 days);
        assertEq(duration, 1460 days);
    }
    
    function testVestingReleaseAfterCliff() public {
        vm.prank(owner);
        token.mint(owner, 1000e18);
        
        vm.prank(owner);
        token.createVesting(user1, 1000e18, 0, 100 days);
        
        // Warp past cliff
        vm.warp(block.timestamp + 101 days);
        
        vm.prank(user1);
        token.releaseVesting(user1);
        
        // Should have received all tokens
        assertEq(token.balanceOf(user1), 1000e18);
    }
    
    function testInitialAllocations() public {
        vm.prank(owner);
        token.mintInitialAllocations(user1, user2, address(0x4));
        
        assertEq(token.balanceOf(user1), 400_000_000e18); // 40% community
        assertEq(token.balanceOf(user2), 50_000_000e18);  // 5% airdrop
    }
    
    function testMaxSupply() public {
        uint256 maxSupply = token.MAX_SUPPLY();
        
        vm.prank(owner);
        vm.expectRevert();
        token.mint(user1, maxSupply + 1);
    }
}
