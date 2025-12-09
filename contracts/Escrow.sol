// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Escrow is ReentrancyGuard {
    address public job_manager;
    address public owner;

    mapping(uint => uint) public job_funds;
    mapping(uint => address) public job_client;
    mapping(uint => bool) public released;
    mapping(uint => bool) public refunded;

    event Deposited(uint indexed job_id, address indexed client, uint amount);
    event Released(uint indexed job_id, address indexed freelancer, uint amount);
    event Refunded(uint indexed job_id, address indexed client, uint amount);
    event JobManagerUpdated(address indexed oldManager, address indexed newManager);
    event OwnerTransferred(address indexed oldOwner, address indexed newOwner);

    modifier onlyJobManager() {
        require(msg.sender == job_manager, "Only job manager can call");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    constructor(address _jobManager) {
        require(_jobManager != address(0), "Invalid JobManager address");
        job_manager = _jobManager;
        owner = msg.sender;
    }

    /**
     * @notice Allows owner to change job manager (in case of upgrade)
     */
    function setJobManager(address _jobManager) external onlyOwner {
        require(_jobManager != address(0), "Invalid address");
        address old = job_manager;
        job_manager = _jobManager;
        emit JobManagerUpdated(old, _jobManager);
    }

    /**
     * @notice Transfer contract ownership
     */
    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "Invalid owner");
        address old = owner;
        owner = _newOwner;
        emit OwnerTransferred(old, _newOwner);
    }

    /**
     * @notice Deposit funds for a job. Can only be called by the JobManager.
     * @dev JobManager must call this function and forward ETH in the call.
     */
    function deposit(uint job_id, address client) external payable onlyJobManager {
        require(msg.value > 0, "Deposit must be > 0");
        require(job_funds[job_id] == 0, "Already deposited");
        require(!refunded[job_id] && !released[job_id], "Job already processed");
        require(client != address(0), "Invalid client");

        job_funds[job_id] = msg.value;
        job_client[job_id] = client;

        emit Deposited(job_id, client, msg.value);
    }

    /**
     * @notice Release funds to the freelancer. Only JobManager can trigger.
     * State changes are done before external call to minimize reentrancy risk.
     */
    function releasePayment(uint job_id, address payable freelancer) external onlyJobManager nonReentrant {
        require(!released[job_id], "Already released");
        require(!refunded[job_id], "Already refunded");
        uint amount = job_funds[job_id];
        require(amount > 0, "No funds for this job");
        require(freelancer != address(0), "Invalid freelancer");

        // update state first
        released[job_id] = true;
        job_funds[job_id] = 0;

        (bool success, ) = freelancer.call{value: amount}("");
        require(success, "Transfer failed");

        emit Released(job_id, freelancer, amount);
    }

    /**
     * @notice Refund deposited funds back to client. Only JobManager can trigger.
     */
    function refund(uint job_id) external onlyJobManager nonReentrant {
        require(!refunded[job_id], "Already refunded");
        require(!released[job_id], "Already released");
        uint amount = job_funds[job_id];
        require(amount > 0, "No funds for this job");

        address payable client = payable(job_client[job_id]);
        require(client != address(0), "Client not set");

        // update state first
        refunded[job_id] = true;
        job_funds[job_id] = 0;

        (bool success, ) = client.call{value: amount}("");
        require(success, "Refund failed");

        emit Refunded(job_id, client, amount);
    }

    /**
     * @notice Helper to read escrowed funds for a job
     */
    function getEscrowBalance(uint job_id) external view returns (uint) {
        return job_funds[job_id];
    }
}
