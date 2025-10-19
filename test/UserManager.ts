import { expect } from "chai";
import { network } from "hardhat";

const { ethers } = await network.connect();

describe("UserManager", function () {
  it("Should emit UserRegistered when a user registers", async function () {
    const userManager = await ethers.deployContract("UserManager");
    const [owner, user] = await ethers.getSigners();

    await expect(
      userManager.connect(user).registerUser("freelancer", "ipfs://abc123")
    )
      .to.emit(userManager, "UserRegistered")
      .withArgs(user.address, "freelancer");

    const data = await userManager.getUser(user.address);
    expect(data.wallet).to.equal(user.address);
    expect(data.role).to.equal("freelancer");
    expect(data.profile_url).to.equal("ipfs://abc123");
  });

  it("Should revert if a user tries to register twice", async function () {
    const userManager = await ethers.deployContract("UserManager");
    const [_, user] = await ethers.getSigners();

    await userManager.connect(user).registerUser("freelancer", "ipfs://abc123");

    await expect(
      userManager.connect(user).registerUser("freelancer", "ipfs://xyz789")
    ).to.be.revertedWith("Already registered");
  });

  it("Should emit UserProfileUpdated when user updates their profile", async function () {
    const userManager = await ethers.deployContract("UserManager");
    const [_, user] = await ethers.getSigners();

    await userManager.connect(user).registerUser("freelancer", "ipfs://abc123");

    await expect(
      userManager.connect(user).updateProfile("ipfs://newCID")
    )
      .to.emit(userManager, "UserProfileUpdated")
      .withArgs(user.address, "ipfs://newCID");

    const updated = await userManager.getUser(user.address);
    expect(updated.profile_url).to.equal("ipfs://newCID");
  });

  it("Should revert when unregistered user tries to update profile", async function () {
    const userManager = await ethers.deployContract("UserManager");
    const [_, user] = await ethers.getSigners();

    await expect(
      userManager.connect(user).updateProfile("ipfs://fake")
    ).to.be.revertedWith("User not registered");
  });

  it("Should be able to query UserRegistered events", async function () {
    const userManager = await ethers.deployContract("UserManager");
    const [_, user1, user2] = await ethers.getSigners();

    const deploymentBlock = await ethers.provider.getBlockNumber();

    await userManager.connect(user1).registerUser("freelancer", "ipfs://abc123");
    await userManager.connect(user2).registerUser("employer", "ipfs://xyz456");

    const events = await userManager.queryFilter(
      userManager.filters.UserRegistered(),
      deploymentBlock,
      "latest"
    );

    expect(events.length).to.equal(2);
    expect(events[0].args.user).to.equal(user1.address);
    expect(events[0].args.role).to.equal("freelancer");
    expect(events[1].args.user).to.equal(user2.address);
    expect(events[1].args.role).to.equal("employer");
  });
});
