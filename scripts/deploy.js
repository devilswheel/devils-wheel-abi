async function main() {
  const [deployer] = await ethers.getSigners();

  console.log('Deploying contracts with the account:', deployer.address);

  console.log('Account balance:', (await deployer.getBalance()).toString());

  const DevilsWheel = await ethers.getContractFactory('DevilsWheel');
  const devilswheel = await DevilsWheel.deploy();

  console.log('DevilsWheel address:', devilswheel.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
