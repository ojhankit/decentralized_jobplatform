// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract UserManager {
    /* user's data which will be stored on-chain are
        1. wallet address; 
        2. profile url // IPFS 
        3. role // Freelancer or Employer 
    */
    struct User {
        //uint user_id;
        address wallet;
        string profile_url;
        string role;
    }

    // state variable
    mapping(address => User) public users;

    // events 
    event UserRegistered(address indexed user, string role);
    event UserProfileUpdated(address indexed user, string new_profile_url);

    // methods 
    function registerUser(string memory _role, string memory _profile_url) public {
        require(users[msg.sender].wallet == address(0), "Already registered");

        users[msg.sender] = User({
            wallet: msg.sender,
            role: _role,
            profile_url: _profile_url
        });

        emit UserRegistered(msg.sender, _role);
    }

    function updateProfile(string memory _new_profile_url) public {
        require(users[msg.sender].wallet != address(0), "User not registered");

        users[msg.sender].profile_url = _new_profile_url;

        emit UserProfileUpdated(msg.sender, _new_profile_url);
    }

    function getUser(address _user) public view returns (User memory) {
        return users[_user];
    }
}
