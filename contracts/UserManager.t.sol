pragma solidity ^0.8.28;

import {UserManager} from "./UserManager.sol";
import {Test} from "forge-std/Test.sol";

contract UserManagerTest is Test {
    UserManager userManager;
    address user1 = address(0x123);
    address user2 = address(0x456);

    function setUp() public {
        userManager = new UserManager();
    }

    function test_RegisterUser() public {
        vm.prank(user1);
        userManager.registerUser("Freelancer", "ipfs://profile1");

        UserManager.User memory user = userManager.getUser(user1);

        assertEq(user.wallet, user1);
        assertEq(user.role, "Freelancer");
        assertEq(user.profile_url, "ipfs://profile1");
    }

    function testFail_DoubleRegisterShouldRevert() public {
        vm.startPrank(user1);
        userManager.registerUser("Freelancer", "ipfs://profile1");
        userManager.registerUser("Employer", "ipfs://profile2");
        vm.stopPrank();
    }

    function test_UpdateProfile() public {
        vm.startPrank(user1);
        userManager.registerUser("Freelancer", "ipfs://profile1");
        userManager.updateProfile("ipfs://new_profile");
        vm.stopPrank();

        UserManager.User memory user = userManager.getUser(user1);
        assertEq(user.profile_url, "ipfs://new_profile");
    }

    function testFail_UpdateProfile_UnregisteredUser() public {
        vm.prank(user2);
        userManager.updateProfile("ipfs://profile_unreg");
    }

    function test_Events() public {
        vm.prank(user1);
        vm.expectEmit(true, false, false, true);
        emit UserManager.UserRegistered(user1, "Freelancer");
        userManager.registerUser("Freelancer", "ipfs://profile1");

        vm.prank(user1);
        vm.expectEmit(true, false, false, true);
        emit UserManager.UserProfileUpdated(user1, "ipfs://new");
        userManager.updateProfile("ipfs://new");
    }
}
