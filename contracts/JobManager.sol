// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// UserManager interface
interface IUserManager{
    struct User{
        address wallet;
        string profile_url;
        string role;
    }

    function getUser(address _user) external view returns (User memory);
}

// Escrow interface
interface IEscrow {
    function deposit(uint job_id, address client) external payable;  // ✅ Add client parameter
    function releasePayment(uint job_id, address payable freelancer) external;
    function refund(uint job_id) external;
}


contract JobManager {
    /* job struct will require 
        1. jobid
        2. job owner
        3. job worker
        4. posted date
        5. status // taken or not taken or closed
        6. job description hash
    */
    enum JobStatus {
        Open, // Open to accept proposals
        Taken, // freelancer alloted
        Completed, // freelancer marked work done still waiting for employer approval 
        Closed, // employer verified the work
        Cancelled // Cancelled by employer
    }

    struct Job {
        uint32 job_id;
        address job_owner;
        address job_worker;
        uint256 created_at;
        string job_description;
        JobStatus status;
    }

    // state vars
    mapping(address => uint[]) public employer_jobs;
    mapping(address => uint[]) public freelancer_jobs;
    mapping(uint => Job) public jobs;
    uint32 public job_count;

    IUserManager public userManager;
    IEscrow public escrow;
    address public owner;  // ✅ ADD THIS

    // event
    event JobCreated(uint indexed job_id, address indexed employer, string job_description);
    event JobAssigned(uint indexed job_id, address indexed worker);
    event JobCompleted(uint indexed job_id);
    event JobClosed(uint indexed job_id);
    event JobCancelled(uint indexed job_id);

    // constructor to set UserManager contract
    constructor(address _userManager, address _escrow) {
        require(_userManager != address(0), "Invalid UserManager address");
        require(_escrow != address(0), "Invalid Escrow address");
        userManager = IUserManager(_userManager);
        escrow = IEscrow(_escrow);
        owner = msg.sender;  // ✅ ADD THIS
    }

    // ✅ ADD THIS FUNCTION after the constructor
    function setEscrow(address _escrow) external {
        require(msg.sender == owner, "Only owner can set escrow");
        require(_escrow != address(0), "Invalid escrow address");
        escrow = IEscrow(_escrow);
    }

    // methods
    /*
        1. createJob
        2. assignJob
        3. markJobComplete
        4. closeJob
        5. cancelJob
        6. getJobs
        7. getEmployerJob
        8. getFreelancerJob
        9. depositToEscrow <new>
    */

    // deposit to escrow when job is created
    function depositToEscrow(uint _job_id) external payable{
        Job storage job = jobs[_job_id];

        // only job owner can deposit
        require(job.job_owner == msg.sender, "Not job owner");
        require(job.status == JobStatus.Open, "Job not open");
        require(msg.value > 0, "Must send funds");

        // forward funds to escrow
        // ✅ NEW CODE - pass the employer address
        (bool success, ) = address(escrow).call{value: msg.value}(
            abi.encodeWithSignature("deposit(uint256,address)", _job_id, msg.sender)
    );
        require(success, "Escrow deposit failed");
    }

    function createJob(string memory _job_description) public {
        // check caller is a registered employer
        IUserManager.User memory user = userManager.getUser(msg.sender);
        require(user.wallet != address(0), "User not registered");
        require(
            keccak256(bytes(user.role)) == keccak256(bytes("Employer")),
            "Only employers can create jobs"
        );

        job_count += 1;
        jobs[job_count] = Job({
            job_id: job_count,
            job_owner: msg.sender,
            job_worker: address(0),
            created_at: block.timestamp,
            job_description: _job_description,
            status: JobStatus.Open
        });

        employer_jobs[msg.sender].push(job_count);

        emit JobCreated(job_count, msg.sender, _job_description);
    }

    function assignJob(uint _job_id, address _worker) public {
        Job storage job = jobs[_job_id];

        // only job owner can assign
        require(job.job_owner == msg.sender, "Not job owner");
        require(job.status == JobStatus.Open, "Job not open");

        // check worker is registered freelancer
        IUserManager.User memory workerUser = userManager.getUser(_worker);
        require(workerUser.wallet != address(0), "Worker not registered");
        require(
            keccak256(bytes(workerUser.role)) == keccak256(bytes("Freelancer")),
            "Only freelancers can be assigned"
        );

        job.job_worker = _worker;
        job.status = JobStatus.Taken;

        freelancer_jobs[_worker].push(_job_id);

        emit JobAssigned(_job_id, _worker);
    }

    function markJobComplete(uint _job_id) public {
        Job storage job = jobs[_job_id];

        // only assigned freelancer can mark complete
        require(job.job_worker == msg.sender, "Not assigned worker");

        IUserManager.User memory user = userManager.getUser(msg.sender);
        require(
            keccak256(bytes(user.role)) == keccak256(bytes("Freelancer")),
            "Only freelancer can mark job complete"
        );

        require(job.status == JobStatus.Taken, "Job not in Taken status");

        job.status = JobStatus.Completed;

        emit JobCompleted(_job_id);
    }

    function closeJob(uint _job_id) public {
        Job storage job = jobs[_job_id];

        // only job owner can close
        require(job.job_owner == msg.sender, "Not job owner");
        require(job.status == JobStatus.Completed, "Job not completed");

        job.status = JobStatus.Closed;

        // after status is closed, release payment from escrow to freelancer
        escrow.releasePayment(_job_id, payable(job.job_worker));

        emit JobClosed(_job_id);
    }

    function cancelJob(uint _job_id) public {
        Job storage job = jobs[_job_id];

        // only job owner can cancel
        require(job.job_owner == msg.sender, "Not job owner");
        require(job.status == JobStatus.Open, "Job not open");

        job.status = JobStatus.Cancelled;

        // after status is cancelled, refund payment from escrow to employer
        escrow.refund(_job_id);
        emit JobCancelled(_job_id);
    }

    function getEmployerJobs(address _employer) public view returns (uint[] memory) {
        return employer_jobs[_employer];
    }

    function getFreelancerJobs(address _freelancer) public view returns (uint[] memory) {
        return freelancer_jobs[_freelancer];
    }

}
