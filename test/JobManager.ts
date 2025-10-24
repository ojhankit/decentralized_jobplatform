import { expect } from "chai";
import { network } from "hardhat";
//import "@nomicfoundation/hardhat-chai-matchers";
const { ethers } = await network.connect();

describe("JobManager (Integration)", function () {
  let userManager: any;
  let escrow: any;
  let jobManager: any;
  let employer: any;
  let freelancer: any;
  let outsider: any;

  beforeEach(async function () {
  const signers = await ethers.getSigners();
  const deployer = signers[0];
  employer = signers[1];
  freelancer = signers[2];
  outsider = signers[3];

  // 1️⃣ Deploy UserManager
  userManager = await ethers.deployContract("UserManager");

  // 2️⃣ Get factories
  const EscrowFactory = await ethers.getContractFactory("Escrow");
  const JobManagerFactory = await ethers.getContractFactory("JobManager");

  // 3️⃣ Deploy JobManager with deployer as temporary escrow
  jobManager = await JobManagerFactory.deploy(
    await userManager.getAddress(),
    deployer.address  // Temporary placeholder
  );

  // 4️⃣ Deploy Escrow with the real JobManager address
  escrow = await EscrowFactory.deploy(await jobManager.getAddress());

  // 5️⃣ ✅ Update JobManager to use the real Escrow
  await jobManager.setEscrow(await escrow.getAddress());

  // 6️⃣ Register Employer and Freelancer
  await userManager.connect(employer).registerUser("Employer", "ipfs://employer");
  await userManager.connect(freelancer).registerUser("Freelancer", "ipfs://freelancer");
});

  it("Should let employer create a job", async function () {
    await expect(jobManager.connect(employer).createJob("ipfs://job1"))
      .to.emit(jobManager, "JobCreated")
      .withArgs(1, employer.address, "ipfs://job1");

    const job = await jobManager.jobs(1);
    expect(job.job_owner).to.equal(employer.address);
    expect(job.status).to.equal(0); // Open
  });

  it("Should revert if non-employer creates job", async function () {
    await expect(jobManager.connect(freelancer).createJob("ipfs://job1"))
      .to.be.revertedWith("Only employers can create jobs");
  });

  it("Should allow employer to assign job to freelancer", async function () {
    await jobManager.connect(employer).createJob("ipfs://job1");

    await expect(jobManager.connect(employer).assignJob(1, freelancer.address))
      .to.emit(jobManager, "JobAssigned")
      .withArgs(1, freelancer.address);

    const job = await jobManager.jobs(1);
    expect(job.job_worker).to.equal(freelancer.address);
    expect(job.status).to.equal(1); // Taken
  });

  it("Should let freelancer mark job complete", async function () {
    await jobManager.connect(employer).createJob("ipfs://job1");
    await jobManager.connect(employer).assignJob(1, freelancer.address);

    await expect(jobManager.connect(freelancer).markJobComplete(1))
      .to.emit(jobManager, "JobCompleted")
      .withArgs(1);

    const job = await jobManager.jobs(1);
    expect(job.status).to.equal(2); // Completed
  });

  it("Should let employer close job and release payment through escrow", async function () {
    const oneEth = ethers.parseEther("1");
    
    // 1. Create job
    await jobManager.connect(employer).createJob("ipfs://job1");
    
    // 2. Deposit first (while job is still Open)
    await jobManager.connect(employer).depositToEscrow(1, { value: oneEth });
    
    // 3. Then assign job (changes status from Open to Taken)
    await jobManager.connect(employer).assignJob(1, freelancer.address);
    
    // 4. Freelancer marks job complete (changes status to Completed)
    await jobManager.connect(freelancer).markJobComplete(1);
    
    // 5. Get balances before
    const escrowBalanceBefore = await ethers.provider.getBalance(escrow);
    const freelancerBalanceBefore = await ethers.provider.getBalance(freelancer);
    
    // 6. Close job
    await expect(jobManager.connect(employer).closeJob(1))
      .to.emit(jobManager, "JobClosed")
      .withArgs(1);
    
    // 7. Check balances after
    const escrowBalanceAfter = await ethers.provider.getBalance(escrow);
    const freelancerBalanceAfter = await ethers.provider.getBalance(freelancer);
    
    expect(escrowBalanceAfter).to.equal(escrowBalanceBefore - oneEth);
    expect(freelancerBalanceAfter).to.equal(freelancerBalanceBefore + oneEth);

    // 8. Verify final status
    const job = await jobManager.jobs(1);
    expect(job.status).to.equal(3); // Closed
});
  it("Should allow employer to cancel an open job and refund via escrow", async function () {
    await jobManager.connect(employer).createJob("ipfs://job1");

    // Deposit into escrow first
    await jobManager.connect(employer).depositToEscrow(1, {
      value: ethers.parseEther("0.5"),
    });

    await expect(jobManager.connect(employer).cancelJob(1))
      .to.emit(jobManager, "JobCancelled")
      .withArgs(1);

    const job = await jobManager.jobs(1);
    expect(job.status).to.equal(4); // Cancelled
  });
});
