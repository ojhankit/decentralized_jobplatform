import { expect } from "chai";
import { network } from "hardhat";

const { ethers } = await network.connect();


describe("JobManager", function () {
  it("Should emit JobPosted when a job is posted", async function () {
    const jobManager = await ethers.deployContract("JobManager");
    const [owner, client] = await ethers.getSigners();

    await expect(
      jobManager.connect(client).postJob("Build a website", "ipfs://jobDesc123", 1000)
    )
      .to.emit(jobManager, "JobPosted")
      .withArgs(1, client.address, "Build a website", 1000);

    const job = await jobManager.getJob(1);
    expect(job.id).to.equal(1);
    expect(job.client).to.equal(client.address);
    expect(job.title).to.equal("Build a website");
    expect(job.description_url).to.equal("ipfs://jobDesc123");
    expect(job.budget).to.equal(1000);
  });

});