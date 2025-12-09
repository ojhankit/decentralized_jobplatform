// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// ---------------------------------------------------------------------------
/// USER MANAGER INTERFACE (UPDATED FOR DID + CREDENTIALS)
/// ---------------------------------------------------------------------------
interface IUserManager {
    struct User {
        address wallet;
        string profile_url; 
        string role;
        string did;
        bool did_verified;
    }

    function getUser(address _user) external view returns (User memory);

    function hasValidCredential(address _user, string memory _type)
        external
        view
        returns (bool);
}

/// ---------------------------------------------------------------------------
/// ESCROW INTERFACE
/// ---------------------------------------------------------------------------
interface IEscrow {
    function deposit(uint job_id, address client) external payable;
    function releasePayment(uint job_id, address payable freelancer) external;
    function refund(uint job_id) external;
}

/// ---------------------------------------------------------------------------
/// JOB MANAGER CONTRACT
/// ---------------------------------------------------------------------------
contract JobManager is ReentrancyGuard {
    enum JobStatus {
        Open,
        Taken,
        Completed,
        Closed,
        Cancelled,
        Disputed
    }

    struct Job {
        uint32 job_id;
        address job_owner;
        address job_worker;
        uint256 created_at;
        string job_description; 
        JobStatus status;
        uint256 payment_amount;
    }

    // ----------------------------------------------------------------------------------------

    mapping(address => uint[]) public employer_jobs;
    mapping(address => uint[]) public freelancer_jobs;
    mapping(uint => Job) public jobs;

    uint32 public job_count;

    IUserManager public userManager;
    IEscrow public escrow;
    address public owner;
    address public daoAddress;

    // ----------------------------------------------------------------------------------------

    event JobCreated(uint indexed job_id, address indexed employer, string job_description, uint256 amount);
    event JobAssigned(uint indexed job_id, address indexed worker);
    event JobCompleted(uint indexed job_id);
    event JobClosed(uint indexed job_id);
    event JobCancelled(uint indexed job_id);
    event DisputeInitiated(uint indexed job_id, address indexed initiator);

    // ----------------------------------------------------------------------------------------

    constructor(address _userManager, address _escrow) {
        require(_userManager != address(0), "Invalid UserManager address");
        require(_escrow != address(0), "Invalid Escrow address");

        userManager = IUserManager(_userManager);
        escrow = IEscrow(_escrow);
        owner = msg.sender;
    }

    // ----------------------------------------------------------------------------------------
    // SETTERS
    // ----------------------------------------------------------------------------------------

    function setEscrow(address _escrow) external {
        require(msg.sender == owner, "Only owner");
        require(_escrow != address(0), "Invalid escrow");
        escrow = IEscrow(_escrow);
    }

    function setDAO(address _dao) external {
        require(msg.sender == owner, "Only owner");
        require(_dao != address(0), "Invalid DAO");
        daoAddress = _dao;
    }

    // ----------------------------------------------------------------------------------------
    // JOB CREATION
    // ----------------------------------------------------------------------------------------

    function createJob(string memory _job_description) public {
        IUserManager.User memory user = userManager.getUser(msg.sender);

        require(user.wallet != address(0), "User not registered");
        require(user.did_verified, "Employer DID not verified");

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
            status: JobStatus.Open,
            payment_amount: 0
        });

        employer_jobs[msg.sender].push(job_count);

        emit JobCreated(job_count, msg.sender, _job_description, 0);
    }

    // ----------------------------------------------------------------------------------------
    // ESCROW DEPOSIT
    // ----------------------------------------------------------------------------------------

    function depositToEscrow(uint _job_id) external payable nonReentrant {
        Job storage job = jobs[_job_id];

        require(job.job_owner == msg.sender, "Not job owner");
        require(job.status == JobStatus.Open, "Job not open");
        require(msg.value > 0, "Funds required");
        require(job.payment_amount == 0, "Already funded");

        job.payment_amount = msg.value;

        (bool success, ) = address(escrow).call{value: msg.value}(
            abi.encodeWithSignature("deposit(uint256,address)", _job_id, msg.sender)
        );

        require(success, "Escrow deposit failed");
    }

    // ----------------------------------------------------------------------------------------
    // ASSIGN JOB
    // ----------------------------------------------------------------------------------------

    function assignJob(uint _job_id, address _worker) public {
        Job storage job = jobs[_job_id];

        require(job.job_owner == msg.sender, "Not job owner");
        require(job.status == JobStatus.Open, "Job not open");
        require(job.payment_amount > 0, "Escrow not funded");

        IUserManager.User memory workerUser = userManager.getUser(_worker);

        require(workerUser.wallet != address(0), "Worker not registered");
        require(workerUser.did_verified, "Worker DID not verified");

        require(
            keccak256(bytes(workerUser.role)) == keccak256(bytes("Freelancer")),
            "Worker is not a freelancer"
        );

        // OPTIONAL: enforce skill credential
        // require(userManager.hasValidCredential(_worker, "SkillCertification"), "Missing skill credential");

        job.job_worker = _worker;
        job.status = JobStatus.Taken;

        freelancer_jobs[_worker].push(_job_id);

        emit JobAssigned(_job_id, _worker);
    }

    // ----------------------------------------------------------------------------------------
    // COMPLETE A JOB
    // ----------------------------------------------------------------------------------------

    function markJobComplete(uint _job_id) public {
        Job storage job = jobs[_job_id];

        require(job.job_worker == msg.sender, "Not assigned worker");
        require(job.status == JobStatus.Taken, "Not taken");

        job.status = JobStatus.Completed;

        emit JobCompleted(_job_id);
    }

    // ----------------------------------------------------------------------------------------
    // CLOSE JOB AFTER COMPLETION
    // ----------------------------------------------------------------------------------------

    function closeJob(uint _job_id) public nonReentrant {
        Job storage job = jobs[_job_id];

        require(job.job_owner == msg.sender, "Not job owner");
        require(job.status == JobStatus.Completed, "Job not completed");

        job.status = JobStatus.Closed;

        escrow.releasePayment(_job_id, payable(job.job_worker));

        emit JobClosed(_job_id);
    }

    // ----------------------------------------------------------------------------------------
    // CANCEL JOB
    // ----------------------------------------------------------------------------------------

    function cancelJob(uint _job_id) public nonReentrant {
        Job storage job = jobs[_job_id];

        require(job.job_owner == msg.sender, "Not job owner");
        require(job.status == JobStatus.Open, "Cannot cancel");

        job.status = JobStatus.Cancelled;

        if (job.payment_amount > 0) {
            escrow.refund(_job_id);
        }

        emit JobCancelled(_job_id);
    }

    // ----------------------------------------------------------------------------------------
    // DISPUTES
    // ----------------------------------------------------------------------------------------

    function initiateDispute(uint _job_id) external {
        Job storage job = jobs[_job_id];

        require(
            msg.sender == job.job_owner || msg.sender == job.job_worker,
            "Not allowed"
        );

        require(
            job.status == JobStatus.Taken || job.status == JobStatus.Completed,
            "Invalid dispute status"
        );

        job.status = JobStatus.Disputed;

        emit DisputeInitiated(_job_id, msg.sender);
    }

    function resolveDispute(uint _job_id, bool favorFreelancer) external {
        require(msg.sender == daoAddress, "Only DAO");

        Job storage job = jobs[_job_id];

        require(job.status == JobStatus.Disputed, "Not disputed");

        job.status = JobStatus.Closed;

        if (favorFreelancer) {
            escrow.releasePayment(_job_id, payable(job.job_worker));
        } else {
            escrow.refund(_job_id);
        }
    }

    // ----------------------------------------------------------------------------------------
    // VIEW FUNCTIONS
    // ----------------------------------------------------------------------------------------

    function getJob(uint jobId)
        external
        view
        returns (
            uint32 job_id,
            address job_owner,
            address job_worker,
            uint256 created_at,
            string memory job_description,
            uint8 status
        )
    {
        Job memory job = jobs[jobId];

        return (
            job.job_id,
            job.job_owner,
            job.job_worker,
            job.created_at,
            job.job_description,
            uint8(job.status)
        );
    }

    function getEmployerJobs(address _employer) public view returns (uint[] memory) {
        return employer_jobs[_employer];
    }

    function getFreelancerJobs(address _freelancer) public view returns (uint[] memory) {
        return freelancer_jobs[_freelancer];
    }
}
