// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract EscrowMock {
    struct ReleasedInfo {
        uint jobId;
        address freelancer;
    }

    ReleasedInfo public released;
    uint public refundedJobId;
    uint public depositedJobId;

    function deposit(uint job_id) external payable {
        depositedJobId = job_id;
    }

    function releasePayment(uint job_id, address payable freelancer) external {
        released = ReleasedInfo(job_id, freelancer);
    }

    function refund(uint job_id) external {
        refundedJobId = job_id;
    }
}
