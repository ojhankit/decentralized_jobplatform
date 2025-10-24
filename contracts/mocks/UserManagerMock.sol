// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract UserManagerMock {
    struct User {
        address wallet;
        string profile_url;
        string role;
    }

    mapping(address => User) public users;

    event UserRegistered(address indexed user, string role);

    function registerUser(string memory _role, string memory _url) external {
        require(users[msg.sender].wallet == address(0), "Already registered");
        users[msg.sender] = User(msg.sender, _url, _role);
        emit UserRegistered(msg.sender, _role);
    }

    function getUser(address _user) external view returns (User memory) {
        return users[_user];
    }
}
