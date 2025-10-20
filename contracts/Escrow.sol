// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract Escrow {
    // state vars
    address public job_manager; // contract address
    mapping(uint => uint) public job_funds;
    mapping(uint => address) public job_client;
    mapping(uint => bool) public released;
    mapping(uint => bool) public refunded;

    // events
    event Deposited(uint indexed job_id, address indexed client, uint amount);
    event Released(uint indexed job_id, address indexed freelancer, uint amount);
    event Refunded(uint indexed job_id, address indexed client, uint amount);

    modifier onlyJobManager() {
        require(msg.sender == job_manager, "Only job manager can call this function");
        _;
    }

    constructor(address _jobManager) {
        require(_jobManager != address(0), "Invalid JobManager address");
        job_manager = _jobManager;
    }

    // methods
    function deposit(uint job_id) external payable {
        require(msg.value > 0, "Deposit must be greater than 0");
        require(job_funds[job_id] == 0, "already deposited");
        
    }
}