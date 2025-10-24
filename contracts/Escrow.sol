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
    function deposit(uint job_id, address client) external payable {
    require(msg.value > 0, "Deposit must be greater than 0");
    require(job_funds[job_id] == 0, "already deposited");
    require(!refunded[job_id] && !released[job_id], "Job already processed");

    job_funds[job_id] = msg.value;
    job_client[job_id] = client;  // ✅ Use the passed client address

    emit Deposited(job_id, client, msg.value);
}

    // called by jobmanager when job is closed / completed
    function releasePayment(uint job_id, address payable freelancer) external onlyJobManager{
        require(!released[job_id], "Already released");
         require(!refunded[job_id], "Already refunded");
        require(job_funds[job_id] > 0, "No funds for this job");

        uint amount = job_funds[job_id];
        released[job_id] = true;
        job_funds[job_id] = 0;

        (bool success, ) = freelancer.call{value: amount}("");
        require(success, "Transfer failed");

        emit Released(job_id, freelancer, amount);
    }

    // refund client if job is cancelled
    function refund(uint job_id) external onlyJobManager {
        require(!refunded[job_id], "Already refunded");
        require(!released[job_id], "Already released");
        require(job_funds[job_id] > 0, "No funds for this job");

        uint amount = job_funds[job_id];
        refunded[job_id] = true;
        job_funds[job_id] = 0;

        address payable client = payable(job_client[job_id]);
        (bool success, ) = client.call{value: amount}("");
        require(success, "Refund failed");

        emit Refunded(job_id, client, amount);
    }

    // optional method to check escrow balance
    function getEscrowBalance(uint job_id) external view returns (uint) {
        return job_funds[job_id];
    }
}