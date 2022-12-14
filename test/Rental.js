const { expect } = require("chai");

describe("Rental", function () {

  // deploy Rental
  async function deployRental() {
    // Rental
    const Rental = await hre.ethers.getContractFactory("Rental");
    const rental = await Rental.deploy();
    await rental.deployed();

    return { rental };
  }


  it("Set fee", async function () {
    const { rental } = await deployRental();

    // The 100 percent value is 10,000
    const fee = 100;

    await rental.setFee(fee);

    console.log("Rental contract address : " + rental.address);

    expect(await rental.fee()).to.equal(fee);

  });

});
