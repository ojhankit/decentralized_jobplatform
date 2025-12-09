// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IFLXToken {
    // Fixed: Use standard ERC20 function names
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

interface IJobManager {
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
        );

    function resolveDispute(uint job_id, bool favorFreelancer) external;
}

contract Dao {
    enum ProposalType {
        GeneralChange,
        DisputeResolution
    }

    enum ProposalStatus {
        Active,
        Executed,
        Rejected
    }

    struct Proposal {
        uint proposal_id;
        address proposer;
        string description;
        ProposalType proposal_type;
        uint vote_start;
        uint vote_end;
        uint upvote;
        uint downvote;
        bool executed;
        ProposalStatus status;
        uint job_id;
        bool favor_freelancer;
    }

    IFLXToken public token;
    IJobManager public jobManager;
    address public treasury;
    address public owner;

    uint public proposal_count;
    mapping(uint => Proposal) public proposals;
    mapping(uint => mapping(address => bool)) public has_voted;
    mapping(address => bool) public members;

    uint public constant VOTING_PERIOD = 3 days;
    uint public quorum_percent = 10;

    event MemberJoined(address member);
    event MemberLeft(address member);
    event ProposalCreated(uint indexed proposalId, address indexed proposer, string description);
    event Voted(uint indexed proposalId, address indexed voter, bool support, uint weight);
    event ProposalExecuted(uint indexed proposalId, bool success);
    event DisputeResolved(uint indexed jobId, bool freelancerWon);
    event QuorumUpdated(uint oldQuorum, uint newQuorum);
    event OwnerTransferred(address indexed oldOwner, address indexed newOwner);

    modifier onlyMember() {
        require(members[msg.sender], "Not a DAO member");
        _;
    }

    modifier onlyActive(uint proposalId) {
        Proposal storage p = proposals[proposalId];
        require(block.timestamp >= p.vote_start && block.timestamp <= p.vote_end, "Voting not active");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    constructor(address _token, address _jobManager, address _treasury) {
        require(_token != address(0), "Invalid token address");
        require(_jobManager != address(0), "Invalid JobManager");
        require(_treasury != address(0), "Invalid treasury");

        token = IFLXToken(_token);
        jobManager = IJobManager(_jobManager);
        treasury = _treasury;
        owner = msg.sender;
    }

    function joinDAO() external {
        require(!members[msg.sender], "Already member");

        // Fixed: Use standard balanceOf
        uint256 bal = token.balanceOf(msg.sender);
        require(bal > 0, "Need FLX tokens to join");

        members[msg.sender] = true;
        emit MemberJoined(msg.sender);
    }

    function leaveDAO() external onlyMember {
        members[msg.sender] = false;
        emit MemberLeft(msg.sender);
    }

    function createProposal(string memory _desc, ProposalType _type) external onlyMember {
        proposal_count += 1;
        proposals[proposal_count] = Proposal({
            proposal_id: proposal_count,
            proposer: msg.sender,
            description: _desc,
            proposal_type: _type,
            vote_start: block.timestamp,
            vote_end: block.timestamp + VOTING_PERIOD,
            upvote: 0,
            downvote: 0,
            executed: false,
            status: ProposalStatus.Active,
            job_id: 0,
            favor_freelancer: false
        });
        emit ProposalCreated(proposal_count, msg.sender, _desc);
    }

    function createDisputeProposal(
        uint _job_id,
        string memory _desc,
        bool _favorFreelancer
    ) external onlyMember {
        (uint32 job_id, , , , , uint8 status) = jobManager.getJob(_job_id);
        require(job_id > 0, "Job doesn't exist");
        require(status == 5, "Job not in disputed status");

        proposal_count += 1;
        proposals[proposal_count] = Proposal({
            proposal_id: proposal_count,
            proposer: msg.sender,
            description: _desc,
            proposal_type: ProposalType.DisputeResolution,
            vote_start: block.timestamp,
            vote_end: block.timestamp + VOTING_PERIOD,
            upvote: 0,
            downvote: 0,
            executed: false,
            status: ProposalStatus.Active,
            job_id: _job_id,
            favor_freelancer: _favorFreelancer
        });

        emit ProposalCreated(proposal_count, msg.sender, _desc);
    }

    function vote(uint _id, bool support) external onlyMember onlyActive(_id) {
        require(!has_voted[_id][msg.sender], "Already voted");

        // Fixed: Use standard balanceOf
        uint weight = token.balanceOf(msg.sender);
        require(weight > 0, "No voting power");

        Proposal storage p = proposals[_id];
        if (support) p.upvote += weight;
        else p.downvote += weight;

        has_voted[_id][msg.sender] = true;
        emit Voted(_id, msg.sender, support, weight);
    }

    function executeProposal(uint _id) external onlyMember {
        Proposal storage p = proposals[_id];
        require(block.timestamp > p.vote_end, "Voting still ongoing");
        require(!p.executed, "Already executed");

        uint totalVotes = p.upvote + p.downvote;
        // Fixed: Use standard totalSupply
        uint totalSupply = token.totalSupply();
        require(totalSupply > 0, "Token total supply is zero");

        uint quorum = (totalSupply * quorum_percent) / 100;
        require(totalVotes >= quorum, "Quorum not met");

        bool success = p.upvote > p.downvote;
        p.executed = true;
        p.status = success ? ProposalStatus.Executed : ProposalStatus.Rejected;

        if (success && p.proposal_type == ProposalType.DisputeResolution) {
            jobManager.resolveDispute(p.job_id, p.favor_freelancer);
            emit DisputeResolved(p.job_id, p.favor_freelancer);
        }

        emit ProposalExecuted(_id, success);
    }

    function getProposal(uint _id) external view returns (
        uint proposal_id,
        address proposer,
        string memory description,
        ProposalType proposal_type,
        uint vote_start,
        uint vote_end,
        uint upvote,
        uint downvote,
        bool executed,
        ProposalStatus status,
        uint job_id,
        bool favor_freelancer
    ) {
        Proposal memory p = proposals[_id];
        return (
            p.proposal_id,
            p.proposer,
            p.description,
            p.proposal_type,
            p.vote_start,
            p.vote_end,
            p.upvote,
            p.downvote,
            p.executed,
            p.status,
            p.job_id,
            p.favor_freelancer
        );
    }

    function setQuorumPercent(uint _newQuorum) external onlyOwner {
        require(_newQuorum > 0 && _newQuorum <= 100, "Quorum must be 1-100");
        uint old = quorum_percent;
        quorum_percent = _newQuorum;
        emit QuorumUpdated(old, _newQuorum);
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "Invalid owner");
        address old = owner;
        owner = _newOwner;
        emit OwnerTransferred(old, _newOwner);
    }
}