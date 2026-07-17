const { expect } = require("chai");
const { ethers } = require("hardhat");


describe("TicketNFT", function () {

    let ticketNFT;
    let owner;
    let eventManager;
    let user;
    let organizer;
    let attacker;


    beforeEach(async function () {

        [
            owner,
            eventManager,
            user,
            organizer,
            attacker
        ] = await ethers.getSigners();


        const TicketNFT =
            await ethers.getContractFactory("TicketNFT");


        ticketNFT =
            await TicketNFT.deploy(
                "Event Ticket",
                "TICKET",
                owner.address
            );


        await ticketNFT.waitForDeployment();


        // set manager

        await ticketNFT
            .connect(owner)
            .setEventManager(eventManager.address);

    });



    describe("Deployment", function () {


        it("should set correct owner", async function(){

            expect(
                await ticketNFT.owner()
            )
            .to.equal(owner.address);

        });


        it("should have event manager", async function(){

            expect(
                await ticketNFT.eventManager()
            )
            .to.equal(eventManager.address);

        });


    });



    describe("Event Manager", function(){


        it("owner can update event manager", async function(){

            await ticketNFT
            .connect(owner)
            .setEventManager(user.address);


            expect(
                await ticketNFT.eventManager()
            )
            .to.equal(user.address);

        });



        it("non owner cannot update manager", async function(){

            await expect(
                ticketNFT
                .connect(attacker)
                .setEventManager(user.address)
            )
            .to.be.reverted;

        });



        it("reject zero address", async function(){

            await expect(
                ticketNFT
                .connect(owner)
                .setEventManager(
                    ethers.ZeroAddress
                )
            )
            .to.be.revertedWithCustomError(
                ticketNFT,
                "InvalidAddress"
            );

        });


    });




    describe("Mint Ticket", function(){


        it("should mint ticket", async function(){


            await ticketNFT
            .connect(eventManager)
            .mintTicket(
                user.address,
                1,
                "ipfs://ticket.json",
                organizer.address,
                500
            );


            expect(
                await ticketNFT.ownerOf(1)
            )
            .to.equal(user.address);


        });



        it("should store ticket information", async function(){


            await ticketNFT
            .connect(eventManager)
            .mintTicket(
                user.address,
                10,
                "ipfs://ticket.json",
                organizer.address,
                500
            );


            const info =
            await ticketNFT.getTicketInfo(1);



            expect(info.eventId)
            .to.equal(10);


            expect(info.used)
            .to.equal(false);


            expect(info.rewardClaimed)
            .to.equal(false);


        });




        it("only manager can mint", async function(){


            await expect(
                ticketNFT
                .connect(attacker)
                .mintTicket(
                    user.address,
                    1,
                    "ipfs://ticket",
                    organizer.address,
                    500
                )
            )
            .to.be.revertedWithCustomError(
                ticketNFT,
                "Unauthorized"
            );


        });



        it("reject zero user address", async function(){


            await expect(
                ticketNFT
                .connect(eventManager)
                .mintTicket(
                    ethers.ZeroAddress,
                    1,
                    "ipfs",
                    organizer.address,
                    500
                )
            )
            .to.be.revertedWithCustomError(
                ticketNFT,
                "InvalidAddress"
            );


        });



        it("reject royalty above 100%", async function(){


            await expect(
                ticketNFT
                .connect(eventManager)
                .mintTicket(
                    user.address,
                    1,
                    "ipfs",
                    organizer.address,
                    10001
                )
            )
            .to.be.revertedWithCustomError(
                ticketNFT,
                "InvalidRoyaltyFee"
            );


        });


    });




    describe("Ticket Usage", function(){


        beforeEach(async function(){


            await ticketNFT
            .connect(eventManager)
            .mintTicket(
                user.address,
                1,
                "ipfs",
                organizer.address,
                500
            );


        });



        it("manager can mark used", async function(){


            await ticketNFT
            .connect(eventManager)
            .markTicketUsed(1);


            const info =
            await ticketNFT.getTicketInfo(1);


            expect(info.used)
            .to.equal(true);


        });



        it("cannot use ticket twice", async function(){


            await ticketNFT
            .connect(eventManager)
            .markTicketUsed(1);



            await expect(
                ticketNFT
                .connect(eventManager)
                .markTicketUsed(1)
            )
            .to.be.revertedWithCustomError(
                ticketNFT,
                "TicketAlreadyUsed"
            );


        });



    });





    describe("Rewards", function(){


        beforeEach(async function(){


            await ticketNFT
            .connect(eventManager)
            .mintTicket(
                user.address,
                1,
                "ipfs",
                organizer.address,
                500
            );


        });



        it("cannot claim before using ticket", async function(){


            await expect(
                ticketNFT
                .connect(eventManager)
                .markRewardClaimed(1)
            )
            .to.be.revertedWithCustomError(
                ticketNFT,
                "TicketNotUsed"
            );


        });



        it("manager can mark reward claimed", async function(){


            await ticketNFT
            .connect(eventManager)
            .markTicketUsed(1);



            await ticketNFT
            .connect(eventManager)
            .markRewardClaimed(1);



            const info =
            await ticketNFT.getTicketInfo(1);


            expect(info.rewardClaimed)
            .to.equal(true);


        });



    });




    describe("Burn", function(){


        it("manager can burn ticket", async function(){


            await ticketNFT
            .connect(eventManager)
            .mintTicket(
                user.address,
                1,
                "ipfs",
                organizer.address,
                500
            );



            await ticketNFT
            .connect(eventManager)
            .burn(1);



            await expect(
                ticketNFT.ownerOf(1)
            )
            .to.be.reverted;


        });


    });




    describe("Pause", function(){


        it("owner can pause", async function(){

            await ticketNFT
            .connect(owner)
            .pause();


            expect(
                await ticketNFT.paused()
            )
            .to.equal(true);

        });



        it("cannot mint when paused", async function(){


            await ticketNFT
            .connect(owner)
            .pause();



            await expect(
                ticketNFT
                .connect(eventManager)
                .mintTicket(
                    user.address,
                    1,
                    "ipfs",
                    organizer.address,
                    500
                )
            )
            .to.be.reverted;


        });


    });


});