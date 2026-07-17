// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

interface IEventManager{
    function isResaleAllowed(uint256 eventId)
    external 
    view 
    returns(bool);
}

interface ITicketNFT is IERC721{
    function royaltyInfo(
        uint256 tokenId,
        uint256 salePrice
    )external
    view
    returns(address , uint256);

    function getTicketInfo(uint256 tokenId)
    external
    view
    returns(
        uint256 , bool, bool
    );

    function getApproved(uint256 tokenId)
    external 
    view
    returns(address);

    function isApprovedForAll(address owner, address operator)
    external view 
    returns(bool);
}


contract Marketplace is Ownable, ReentrancyGuard, Pausable, ERC721Holder {
ITicketNFT public immutable ticketNFT;
IEventManager public immutable eventManager;
uint96 public constant MAX_MARKETPLACE_FEE = 1000; // 10%
uint96 public constant FEE_DENOMINATOR = 10_000;
uint96 public marketplaceFee = 250; // 2.5%


struct Listing {
    address seller;
    uint256 price;
    bool active;
}


mapping(uint256 => Listing)public listings;


//errors
error InvalidAddress();
error IncorrectPayment();
error AlreadyListed();

error ListingInactive();
error NotOwner();
error NotApproved();
error TransferFailed();
error ResaleNotAllowed();
error InvalidMarketplaceFee();
error InvalidPrice();
error CannotBuyOwnListing();
error NothingToWithdraw();




//EventS
event TicketListed(
    uint256 indexed tokenId,
    address indexed seller,
    uint256 price
);

event ListingCancelled(
    uint256 indexed tokenId
);

event ListingPriceUpdated(
    uint256 indexed tokenId,
    uint256 newPrice
);

event TicketSold(
    uint256 indexed tokenId,
    address indexed seller,
    address indexed buyer,
    uint256 price
);

event MarketplaceFeeUpdated(
    uint96 newFee
);

constructor(
    address _ticketNFT,
    address _eventManager,
    address _owner
)Ownable(_owner){
    if(_ticketNFT == address(0)) revert InvalidAddress();
    if(_eventManager == address(0)) revert InvalidAddress();

    ticketNFT = ITicketNFT(_ticketNFT);
    eventManager = IEventManager(_eventManager);
}


//list ticket
function listTicket(
    uint256 tokenId,
    uint256 price
)
    external
    whenNotPaused
{
    if (price == 0)
        revert InvalidPrice();

    if (ticketNFT.ownerOf(tokenId) != msg.sender)
        revert NotOwner();

    if (listings[tokenId].active)
        revert AlreadyListed();

    (uint256 eventId, bool used,) =
        ticketNFT.getTicketInfo(tokenId);

    if (used)
        revert ResaleNotAllowed();

    if (!eventManager.isResaleAllowed(eventId))
        revert ResaleNotAllowed();

    if (
        ticketNFT.getApproved(tokenId) != address(this) &&
        !ticketNFT.isApprovedForAll(msg.sender, address(this))
    ) {
        revert NotApproved();
    }

    listings[tokenId] = Listing({
        seller: msg.sender,
        price: price,
        active: true
    });

    emit TicketListed(
        tokenId,
        msg.sender,
        price
    );
}


//cancel listing

function cancelListing(uint256 tokenId)
    external
    whenNotPaused
{
    Listing memory listing = listings[tokenId];

    if (!listing.active)
        revert ListingInactive();

    if (listing.seller != msg.sender)
        revert NotOwner();

    if (ticketNFT.ownerOf(tokenId) != msg.sender) {
        delete listings[tokenId];
        revert ListingInactive();
    }

    delete listings[tokenId];

    emit ListingCancelled(tokenId);
}


//update listing price

function updateListingPrice(
    uint256 tokenId,
    uint256 newPrice
)
    external
    whenNotPaused
{
    if (newPrice == 0)
        revert InvalidPrice();

    Listing storage listing = listings[tokenId];

    if (!listing.active)
        revert ListingInactive();

    if (listing.seller != msg.sender)
        revert NotOwner();

    if (ticketNFT.ownerOf(tokenId) != msg.sender) {
        delete listings[tokenId];
        revert ListingInactive();
    }

    listing.price = newPrice;

    emit ListingPriceUpdated(
        tokenId,
        newPrice
    );
}


//update fee
function updateMarketplaceFee(
    uint96 newFee
)
    external
    onlyOwner
{
    if (newFee > MAX_MARKETPLACE_FEE)
    revert InvalidMarketplaceFee();

    marketplaceFee = newFee;

    emit MarketplaceFeeUpdated(
        newFee
    );
}


function pause()
    external
    onlyOwner
{
    _pause();
}

function unpause()
    external
    onlyOwner
{
    _unpause();
}

function getListing(uint256 tokenId)
    external
    view
    returns (Listing memory)
{
    return listings[tokenId];
}





//buy ticket
function buyTicket(uint256 tokenId)
    external
    payable
    nonReentrant
    whenNotPaused
{
    

    Listing memory listing = listings[tokenId];

    if (!listing.active)
        revert ListingInactive();

    if (listing.seller == msg.sender)
        revert CannotBuyOwnListing();

    if (msg.value != listing.price)
        revert IncorrectPayment();

    if (ticketNFT.ownerOf(tokenId) != listing.seller) {
        delete listings[tokenId];
        revert ListingInactive();
    }

    (uint256 eventId, bool used,) =
        ticketNFT.getTicketInfo(tokenId);

    if (used)
        revert ResaleNotAllowed();

    if (!eventManager.isResaleAllowed(eventId))
        revert ResaleNotAllowed();

    if (
        ticketNFT.getApproved(tokenId) != address(this) &&
        !ticketNFT.isApprovedForAll(
            listing.seller,
            address(this)
        )
    ) {
        delete listings[tokenId];
        revert NotApproved();
    }

    (
        address royaltyReceiver,
        uint256 royaltyAmount
    ) = ticketNFT.royaltyInfo(
        tokenId,
        msg.value
    );

    uint256 marketplaceAmount =
        (msg.value * marketplaceFee) /
        FEE_DENOMINATOR;

    uint256 sellerAmount =
        msg.value -
        royaltyAmount -
        marketplaceAmount;

    address seller = listing.seller;
    uint256 price = listing.price;

    

    delete listings[tokenId];

   

    ticketNFT.safeTransferFrom(
        seller,
        msg.sender,
        tokenId
    );

    if (royaltyAmount > 0) {
        (bool success,) = payable(
            royaltyReceiver
        ).call{value: royaltyAmount}("");

        if (!success)
            revert TransferFailed();
    }

    (bool feeSuccess,) = payable(owner()).call{
        value: marketplaceAmount
    }("");

    if (!feeSuccess)
        revert TransferFailed();

    (bool sellerSuccess,) = payable(seller).call{
        value: sellerAmount
    }("");

    if (!sellerSuccess)
        revert TransferFailed();

    emit TicketSold(
        tokenId,
        seller,
        msg.sender,
        price
    );
}

function withdrawStuckETH()
    external
    onlyOwner
{
    uint256 balance = address(this).balance;

    if (balance == 0)
        revert NothingToWithdraw();

    (bool success,) = payable(owner()).call{value: balance}("");

    if (!success)
        revert TransferFailed();
}

receive() external payable {
    revert();
}






}

