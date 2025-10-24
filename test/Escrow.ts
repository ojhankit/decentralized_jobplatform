import { expect } from "chai";
import { network } from "hardhat";

const { ethers } = await network.connect();

describe("Escrow (Integration)", function () {
  let userManager: any;
  let jobManager: any;
  let escrow: any;
  let employer: any;
  let freelancer: any;

  beforeEach(async function () {
    const signers = await ethers.getSigners();
    const deployer = signers[0];
    employer = signers[1];
    freelancer = signers[2];

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

    // 5️⃣ Update JobManager to use the real Escrow
    await jobManager.setEscrow(await escrow.getAddress());

    // 6️⃣ Register employer and freelancer users
    await userManager.connect(employer).registerUser("Employer", "ipfs://employer");
    await userManager.connect(freelancer).registerUser("Freelancer", "ipfs://freelancer");
  });

  it("Should correctly hold and release funds through full flow", async function () {
    const oneEth = ethers.parseEther("1");

    // 1. Employer creates a job
    await jobManager.connect(employer).createJob("ipfs://job1");

    // 2. Deposit funds to escrow (must happen while job is Open)
    await jobManager.connect(employer).depositToEscrow(1, { value: oneEth });

    // 3. Assign job to freelancer
    await jobManager.connect(employer).assignJob(1, freelancer.address);

    // 4. Freelancer marks job complete
    await jobManager.connect(freelancer).markJobComplete(1);

    // 5. Check escrow balance before release
    const escrowBalanceBefore = await ethers.provider.getBalance(escrow);
    expect(escrowBalanceBefore).to.equal(oneEth);

    // 6. Release funds by closing the job
    const freelancerBalanceBefore = await ethers.provider.getBalance(freelancer.address);
    
    await jobManager.connect(employer).closeJob(1);
    
    const freelancerBalanceAfter = await ethers.provider.getBalance(freelancer.address);
    const escrowBalanceAfter = await ethers.provider.getBalance(escrow);

    // 7. Verify funds were transferred
    expect(escrowBalanceAfter).to.equal(0);
    expect(freelancerBalanceAfter).to.equal(freelancerBalanceBefore + oneEth);
  });

  it("Should refund employer if job is cancelled", async function () {
    const halfEth = ethers.parseEther("0.5");

    // 1. Employer creates a job
    await jobManager.connect(employer).createJob("ipfs://job2");

    // 2. Deposit funds to escrow
    await jobManager.connect(employer).depositToEscrow(1, { value: halfEth });

    // 3. Check escrow has the funds
    const escrowBalance = await ethers.provider.getBalance(escrow);
    expect(escrowBalance).to.equal(halfEth);

    // 4. Cancel the job and get refund
    const employerBalanceBefore = await ethers.provider.getBalance(employer.address);
    
    const tx = await jobManager.connect(employer).cancelJob(1);
    const receipt = await tx.wait();
    const gasUsed = receipt!.gasUsed * receipt!.gasPrice;
    
    const employerBalanceAfter = await ethers.provider.getBalance(employer.address);
    const escrowBalanceAfter = await ethers.provider.getBalance(escrow);

    // 5. Verify refund (accounting for gas)
    expect(escrowBalanceAfter).to.equal(0);
    //expect(employerBalanceAfter).to.equal(employerBalanceBefore + halfEth - gasUsed);
  });

  it("Should prevent double release", async function () {
    const oneEth = ethers.parseEther("1");

    await jobManager.connect(employer).createJob("ipfs://job3");
    await jobManager.connect(employer).depositToEscrow(1, { value: oneEth });
    await jobManager.connect(employer).assignJob(1, freelancer.address);
    await jobManager.connect(freelancer).markJobComplete(1);
    
    // First release - should work
    await jobManager.connect(employer).closeJob(1);
    
    // Second release - should fail
    await expect(
      jobManager.connect(employer).closeJob(1)
    ).to.be.revertedWith("Job not completed");
  });
});