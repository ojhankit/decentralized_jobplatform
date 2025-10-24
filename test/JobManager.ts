import { expect } from "chai";
import { Contract, Signer } from "ethers";
import { network } from "hardhat";

const { ethers } = await network.connect();

/* 
1. setup & deployment
2. job creation
3. assigning job
4. deposit flow
5. job completion
6. job close
7. job cancel
8. access ctrl
*/

describe("JobManager", function () {
  let userManager: Contract;
  let jobManager: Contract;
  let escrow: Contract;

  let employer: Signer;
  let freelancer: Signer;

  beforeEach(async function () {
    [ employer, freelancer ] = await ethers.getSigners();

    // deploy mock user manager
  })
});