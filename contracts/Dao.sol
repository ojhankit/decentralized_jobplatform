// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// This contract is responsible for dispute resolution, platform governance, and fund management within the DAO structure.

// Our platform will provide native token to facilitate governance and incentivize participation.

// Interfaces
interface IFLXToken {
    function balanceOfFLX(address account) external view returns (uint256);
    function totalSupplyFLX() external view returns (uint256);
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
}

contract Dao {
    // enums
    enum ProposalType {
        GeneralChange,
        DisputeResolution
    }

    enum ProposalStatus {
        Active,
        Executed,
        Rejected
    }
    // struct
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
    }

    // constructor
    constructor(address _token, address _jobManager, address _treasury) {
        require(_token != address(0), "Invalid token address");
        require(_jobManager != address(0), "Invalid JobManager");
        require(_treasury != address(0), "Invalid treasury");

        token = IFLXToken(_token);
        jobManager = IJobManager(_jobManager);
        treasury = _treasury;
    }

    // modifiers
    modifier onlyMember() {
        require(members[msg.sender], "Not a DAO member");
        _;
    }

    modifier onlyActive(uint proposalId) {
        Proposal storage p = proposals[proposalId];
        require(block.timestamp >= p.vote_start && block.timestamp <= p.vote_end, "Voting not active");
        _;
    }
    // state vars
    IFLXToken public token;
    IJobManager public jobManager;
    address public treasury;

    uint public proposal_count;
    mapping(uint => Proposal) public proposals;
    mapping(uint => mapping(address => bool)) public has_voted;
    mapping(address => bool) public members;

    uint public constant VOTING_PERIOD = 3 days;
    uint public quorum_percent = 10;

    // events
    event MemberJoined(address member);
    event ProposalCreated(uint indexed proposalId, address indexed proposer, string description);
    event Voted(uint indexed proposalId, address indexed voter, bool support, uint weight);
    event ProposalExecuted(uint indexed proposalId, bool success);
    event DisputeResolved(uint indexed jobId, bool freelancerWon);

    // methods

    // to join dao user should have a threshold flx tokens
    function joinDAO() external {
        require(!members[msg.sender], "Already member");
        require(token.balanceOfFLX(msg.sender) > 0, "Need FLX tokens to join");

        members[msg.sender] = true;
        emit MemberJoined(msg.sender);
    }
    // goverance methods -> create proposal, startvote, declare res
    function createProposal(string memory _desc, ProposalType _type) external onlyMember{
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
            status: ProposalStatus.Active
        });
        emit ProposalCreated(proposal_count, msg.sender, _desc);
    }

    function vote(uint _id, bool support) external onlyMember onlyActive(_id){
        require(!has_voted[_id][msg.sender], "Already voted");

        uint weight = token.balanceOfFLX(msg.sender);
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
        uint quorum = (token.totalSupplyFLX() * quorum_percent) / 100;

        require(totalVotes >= quorum, "Quorum not met");

        bool success = p.upvote > p.downvote;
        p.executed = true;
        p.status = success ? ProposalStatus.Executed : ProposalStatus.Rejected;

        emit ProposalExecuted(_id, success);
    }

}