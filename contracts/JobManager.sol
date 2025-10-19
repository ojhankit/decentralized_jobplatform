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

    // event
    event JobCreated(uint indexed job_id, address indexed employer, string job_description);
    event JobAssigned(uint indexed job_id, address indexed worker);
    event JobCompleted(uint indexed job_id);
    event JobClosed(uint indexed job_id);
    event JobCancelled(uint indexed job_id);

    // methods
    /*
        1. createJob
        2. assignJob
        3. markJobComplete
        4. closeJob
        5. completeJob
        6. cancelJob
        7. getJobs
        8. getEmployerJob
        9. getFreelancerJob
    */
}