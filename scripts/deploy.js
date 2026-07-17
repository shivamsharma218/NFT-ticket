const hre = require("hardhat");

async function main() {
    const [deployer] = await hre.ethers.getSigners();

    console.log("Deployer:", deployer.address);

    // --------------------------------------------------
    // Deploy FanToken
    // --------------------------------------------------
    const FanToken = await hre.ethers.getContractFactory("FanToken");

    const fanToken = await FanToken.deploy(
        deployer.address
    );

    await fanToken.waitForDeployment();

    const fanTokenAddress = await fanToken.getAddress();

    console.log("FanToken:", fanTokenAddress);

    // --------------------------------------------------
    // Deploy TicketNFT
    // --------------------------------------------------
    const TicketNFT = await hre.ethers.getContractFactory("TicketNFT");

    const ticketNFT = await TicketNFT.deploy(
        "Sports Ticket",
        "STIX",
        deployer.address
    );

    await ticketNFT.waitForDeployment();

    const ticketNFTAddress = await ticketNFT.getAddress();

    console.log("TicketNFT:", ticketNFTAddress);

    // --------------------------------------------------
    // Deploy EventManager
    // --------------------------------------------------
    const EventManager = await hre.ethers.getContractFactory("EventManager");

    const eventManager = await EventManager.deploy(
        ticketNFTAddress,
        fanTokenAddress,
        deployer.address
    );

    await eventManager.waitForDeployment();

    const eventManagerAddress = await eventManager.getAddress();

    console.log("EventManager:", eventManagerAddress);

    // --------------------------------------------------
    // Configure TicketNFT
    // --------------------------------------------------
    let tx = await ticketNFT.setEventManager(
        eventManagerAddress
    );
    await tx.wait();

    console.log("EventManager configured in TicketNFT");

    // --------------------------------------------------
    // Fund EventManager
    // --------------------------------------------------
    tx = await fanToken.transfer(
        eventManagerAddress,
        hre.ethers.parseEther("100000")
    );

    await tx.wait();

    console.log("Transferred 100000 FAN tokens to EventManager");

    // --------------------------------------------------
    // Deploy Marketplace
    // --------------------------------------------------
    const Marketplace = await hre.ethers.getContractFactory("Marketplace");

    const marketplace = await Marketplace.deploy(
        ticketNFTAddress,
        eventManagerAddress,
        deployer.address
    );

    await marketplace.waitForDeployment();

    const marketplaceAddress =
        await marketplace.getAddress();

    console.log("Marketplace:", marketplaceAddress);

    // --------------------------------------------------
    // Deployment Summary
    // --------------------------------------------------
    console.log("\n========== Deployment Complete ==========\n");

    console.table({
        FanToken: fanTokenAddress,
        TicketNFT: ticketNFTAddress,
        EventManager: eventManagerAddress,
        Marketplace: marketplaceAddress,
    });
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});