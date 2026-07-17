const { expect } = require("chai");
const { ethers } = require("hardhat");


describe("EventManager", function () {

    let owner;
    let organizer;
    let buyer;
    let attacker;

    let fanToken;
    let ticketNFT;
    let eventManager;


    const price = ethers.parseEther("1");


    beforeEach(async function () {

        [
            owner,
            organizer,
            buyer,
            attacker
        ] = await ethers.getSigners();


        const FanToken =
            await ethers.getContractFactory("FanToken");

        fanToken =
            await FanToken.deploy(
                owner.address
            );


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


        await ticketNFT
            .connect(owner)
            .setEventManager(
                await eventManager.getAddress()
            );


        await fanToken
            .connect(owner)
            .transfer(
                await eventManager.getAddress(),
                ethers.parseEther("10000")
            );

    });



    describe("Deployment", function () {


        it("should set correct addresses", async function () {

            expect(
                await eventManager.ticketNFT()
            )
            .to.equal(
                await ticketNFT.getAddress()
            );


            expect(
                await eventManager.fanToken()
            )
            .to.equal(
                await fanToken.getAddress()
            );

        });


    });




    describe("Create Event", function () {


        it("should create event", async function () {


            await eventManager
                .connect(organizer)
                .createEvent(
                    "Concert",
                    "ipfs://metadata",
                    price,
                    100,
                    Math.floor(Date.now()/1000)+100,
                    500
                );


            let event =
                await eventManager.events(1);



            expect(event.name)
                .to.equal("Concert");


            expect(event.organizer)
                .to.equal(
                    organizer.address
                );


            expect(event.ticketPrice)
                .to.equal(price);


            expect(event.status)
                .to.equal(0);

        });



        it("reject empty metadata", async function () {


            await expect(
                eventManager
                .connect(organizer)
                .createEvent(
                    "Concert",
                    "",
                    price,
                    100,
                    Math.floor(Date.now()/1000)+100,
                    500
                )
            )
            .to.be.revertedWithCustomError(
                eventManager,
                "InvalidMetadataURL"
            );


        });



        it("reject zero tickets", async function () {


            await expect(
                eventManager
                .connect(organizer)
                .createEvent(
                    "Concert",
                    "ipfs",
                    price,
                    0,
                    Math.floor(Date.now()/1000)+100,
                    500
                )
            )
            .to.be.revertedWithCustomError(
                eventManager,
                "InvalidEvent"
            );

        });



        it("reject invalid royalty", async function () {


            await expect(
                eventManager
                .connect(organizer)
                .createEvent(
                    "Concert",
                    "ipfs",
                    price,
                    100,
                    Math.floor(Date.now()/1000)+100,
                    10001
                )
            )
            .to.be.revertedWithCustomError(
                eventManager,
                "InvalidRoyaltyFee"
            );


        });


    });





    describe("Buy Ticket", function () {


        beforeEach(async function () {

            await eventManager
                .connect(organizer)
                .createEvent(
                    "Concert",
                    "ipfs",
                    price,
                    2,
                    Math.floor(Date.now()/1000)+100,
                    500
                );

        });



        it("buyer can purchase ticket", async function () {


            await eventManager
                .connect(buyer)
                .buyTicket(
                    1,
                    {
                        value:price
                    }
                );


            expect(
                await ticketNFT.ownerOf(1)
            )
            .to.equal(
                buyer.address
            );



            let event =
                await eventManager.events(1);


            expect(event.ticketsSold)
                .to.equal(1);


        });



        it("reject wrong payment", async function () {


            await expect(
                eventManager
                .connect(buyer)
                .buyTicket(
                    1,
                    {
                        value:
                        ethers.parseEther("0.5")
                    }
                )
            )
            .to.be.revertedWithCustomError(
                eventManager,
                "IncorrectPayment"
            );


        });



        it("reject when sold out", async function () {


            await eventManager
                .connect(buyer)
                .buyTicket(
                    1,
                    {
                        value:price
                    }
                );


            await eventManager
                .connect(attacker)
                .buyTicket(
                    1,
                    {
                        value:price
                    }
                );



            await expect(
                eventManager
                .connect(owner)
                .buyTicket(
                    1,
                    {
                        value:price
                    }
                )
            )
            .to.be.revertedWithCustomError(
                eventManager,
                "EventFull"
            );


        });






         it("should not start event before timestamp", async function () {


        await expect(
            eventManager
            .connect(organizer)
            .startEvent(1)
        )
        .to.be.reverted;



    });



    it("organizer can start event after timestamp", async function () {


        await ethers.provider.send(
            "evm_increaseTime",
            [60]
        );


        await ethers.provider.send(
            "evm_mine"
        );



        await eventManager
            .connect(organizer)
            .startEvent(1);



        let event =
            await eventManager.events(1);



        expect(event.status)
            .to.equal(1);


    });



    


    


});


    });

