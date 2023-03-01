const { expect } = require("chai");

describe("Rental", function () {

  // deploy Rental
  async function deployRental() {
    // Rental
    const Rental = await hre.ethers.getContractFactory("Rental");
    const rental = await Rental.deploy();
    await rental.deployed();
    const [owner] = await ethers.getSigners();
    return { rental , owner};
  }


  it("Set fee", async function () {
    const { rental } = await deployRental();

    // The 100 percent value is 10,000
    const fee = 100;

    await rental.setFee(fee);

    console.log("Rental contract address : " + rental.address);

    expect(await rental.fee()).to.equal(fee);

  });


  it("Set feeColllector", async function () {
    const { rental , owner} = await deployRental();
    let ownerAddress;
    await owner.getAddress().then((ret) => {
      ownerAddress = ret;
    });

    await rental.setFeeCollector(ownerAddress);
    expect(await rental.feeCollector()).to.equal(ownerAddress);
  });


  it("grantRole", async function () {
    const { rental , owner} = await deployRental();
    let ownerAddress;
    await owner.getAddress().then((ret) => {
      ownerAddress = ret;
    });

    let role = '0xf7db13299c8a9e501861f04c20f69a2444829a36a363cfad4b58864709c75560';
    await rental.grantRole(role, ownerAddress);
    expect(await rental.hasRole(role, ownerAddress)).to.equal(true);
  });


  it("supportsInterface", async function () {
    const { rental , owner} = await deployRental();
    expect(await rental.supportsInterface('0x7965db0b')).to.equal(true);
  });




  
});
