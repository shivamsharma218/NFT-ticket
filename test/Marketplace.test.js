
const { expect } = require("chai");
const { ethers } = require("hardhat");


beforeEach(async function () {

    [owner, organizer, buyer] =
        await ethers.getSigners();

    const FanToken =
        await ethers.getContractFactory("FanToken");

    fanToken =
        await FanToken.deploy(owner.address);

    const TicketNFT =
        await ethers.getContractFactory("TicketNFT");

    ticketNFT =
        await TicketNFT.deploy(
            "Ticket",
            "TKT",
            owner.address
        );

    const EventManager =
        await ethers.getContractFactory("EventManager");

    eventManager =
        await EventManager.deploy(
            await ticketNFT.getAddress(),
            await fanToken.getAddress(),
            owner.address
        );

    const Marketplace =
        await ethers.getContractFactory("Marketplace");

    marketplace =
        await Marketplace.deploy(
            await ticketNFT.getAddress(),
            await eventManager.getAddress(),
            owner.address
        );

    await ticketNFT
        .connect(owner)
        .setEventManager(
            await eventManager.getAddress()
        );

});

describe("List ticket",function(){
    beforeEach(async function () {
        await eventManager.connect(organizer)
        .createEvent(
            "Football final",
            "ipfs//metadata",
            ethers.parseEther("1"),
            100,
            Math.floor(Date.now()/1000)+100,
            500
        );

        await eventManager.connect(buyer).buyTicket(1,{
            value: ethers.parseEther("1")
        });
        
    });







    it("should list ticket sucessfully",async function () {
        await ticketNFT.connect(buyer)
        .approve(await marketplace.getAddress(),1);

        await expect(
            marketplace.connect(buyer).listTicket(
                1,
                ethers.parseEther("2")
            )
        )
        .to.emit(marketplace,"TicketListed")
        .withArgs(
            1,
            buyer.address,
            ethers.parseEther("2")
        );

        const listing = await marketplace.getListing(1);

        expect (listing.seller).to.equal(buyer.address);
        expect(listing.price).to.equal(ethers.parseEther("2"));
        expect(listing.active).to.equal(true);
        
    });





    it("should revert if caller is not owner",async function () {
        await expect(
            marketplace.connect(owner).listTicket(
                1,ethers.parseEther("2")
            )

        )
        .to.be.revertedWithCustomError(
            marketplace,
            "NotOwner"
        );
        
    });





    it("should revert if price is zero",async function() {

        await ticketNFT
        .connect(buyer)
        .approve(await marketplace.getAddress(),1);
        await expect(marketplace.connect(buyer).listTicket(1,0))
        .to.be.revertedWithCustomError(
            marketplace,
            "InvalidPrice"
        );
        
    });




    it("should revert if ticket is already used",async function () {

        await ticketNFT.connect(buyer).
        approve(
            await marketplace.getAddress(),1
        );

        await marketplace.connect(buyer).listTicket(
            1,ethers.parseEther("2")
        );

        

        await expect(
            marketplace.connect(buyer).listTicket(
                1,ethers.parseEther("4")
            )
        )
        .to.be.revertedWithCustomError(
            marketplace,
            "AlreadyListed"
        );

        
        
    });




    it("should revert if marketplace is not approved",async function () {
        await expect(
            marketplace.connect(buyer).listTicket(
                1,ethers.parseEther("2")
            )
        )
        .to.be.revertedWithCustomError(
            marketplace,
            "NotApproved"
        );
        
    });





    it("should revert if ticket is already used",async function() {
        
    })






})