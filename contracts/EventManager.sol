// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./FanToken.sol";

interface ITicketNFT {
    function mintTicket(
    address to,
    uint256 eventId,
    string calldata metadataURL,
    address organizer,
    uint96 royaltyFee
) external returns (uint256);

    function markTicketUsed(uint256 tokenId) external;

    function markRewardClaimed(uint256 tokenId) external;

    function getTicketInfo(uint256 tokenId)
        external
        view
        returns (
            uint256 eventId,
            bool used,
            bool rewardClaimed
        );
        function burn(uint256 tokenId) external;

    function ownerOf(uint256 tokenId)
        external
        view
        returns (address);
}


contract EventManager is Ownable, ReentrancyGuard, Pausable {
    ITicketNFT public immutable ticketNFT;
    FanToken public immutable fanToken;
    uint256 public rewardAmount =100*1e18;


    constructor(
    address _ticketNFT,
    address _fanToken,
    address _owner
) Ownable(_owner) {
    require(_ticketNFT != address(0), "invalid address");
    require(_fanToken != address(0), "invalid address");

    ticketNFT = ITicketNFT(_ticketNFT);
    fanToken = FanToken(_fanToken);
}

  enum EventStatus {
    Upcoming,
    Live,
    Finished,
    Cancelled
}

struct EventDetails {
    string name;
    string metadataURL;
    address organizer;
    uint96 royaltyFee;
    uint256 ticketPrice;
    uint256 maxTickets;
    uint256 ticketsSold;
    uint256 eventTimestamp;
    EventStatus status;
    bool exists;
}

    uint256 public nextEventId;
    mapping(uint256=> EventDetails) public events;
    mapping(uint256 => uint256)public organizerBalance;
    uint256 public totalOrganizerBalance;


    error InvalidAddress();
    error InvalidEvent();
    error EventNotActive();
    error EventCancelled();
    error EventFull();
    error IncorrectPayment();
    error Unauthorized();
    error EventAlreadyStarted();
    error TransferFailed();
    error NothingToWithdraw();
    error NotTicketOwner();
    error AlreadyUsed();
    error AlreadyRefunded();
    error NotCancelled();
    error InvalidRoyaltyFee();
    error InvalidMetadataURL();



mapping(uint256 => uint256) public ticketPricePaid;
mapping(uint256 => bool) public ticketRefunded;




//event
event EventCreated(
    uint256 indexed eventId,
    address indexed organizer,
    string name,
    uint256 ticketPrice,
    uint96 royaltyFee
);

event TicketPurchased(
    uint256 indexed eventId,
    uint256 indexed tokenId,
    address indexed buyer,
    uint256 pricePaid
);
event TicketCheckedIn(uint256 indexed eventId, uint256 indexed tokenId);
event OrganizerWithdraw(uint256 indexed eventId, address indexed organizer, uint256 amount);
event EventCancelledEvent(uint256 indexed eventId);
event TicketRefunded(uint256 indexed eventId, uint256 indexed tokenId, address indexed buyer, uint256 amount);
event EventStarted(uint256 indexed eventId);
event RewardClaimed(
    uint256 indexed eventId,
    uint256 indexed tokenId,
    address indexed user,
    uint256 amount
);

modifier onlyOrganizer(uint256 eventId) {
    if (msg.sender != events[eventId].organizer) revert Unauthorized();
    _;
}




modifier eventExists(uint256 eventId) {
    if (!events[eventId].exists) revert InvalidEvent();
    _;
}

//functions
//create event
function createEvent(
    string calldata name,
    string calldata metadataURL,
    uint256 ticketPrice,
    uint256 maxTickets,
    uint256 eventTimestamp,
    uint96 royaltyFee
)external whenNotPaused returns(uint256){
        if (maxTickets == 0)revert InvalidEvent();
        if (eventTimestamp<=block.timestamp)revert InvalidEvent();
        if (bytes(metadataURL).length == 0)
    revert InvalidMetadataURL();
    if(bytes(name).length == 0)
    revert InvalidEvent();
    if (ticketPrice == 0)
    revert InvalidEvent();
        if (royaltyFee > 10_000)
    revert InvalidRoyaltyFee();
        nextEventId++;
        uint256 eventId = nextEventId;

        events[eventId]= EventDetails({
            name : name,
            metadataURL : metadataURL,
            organizer : msg.sender,
            royaltyFee : royaltyFee,
            ticketPrice: ticketPrice,
            maxTickets : maxTickets,
            ticketsSold : 0,
            eventTimestamp : eventTimestamp,
            status: EventStatus.Upcoming,
            exists: true 
        });
        emit EventCreated(
    eventId,
    msg.sender,
    name,
    ticketPrice,
    royaltyFee
);
        return eventId;
}

//buy ticket
function buyTicket(uint256 eventId)
external
payable
nonReentrant
whenNotPaused
eventExists(eventId)
returns(uint256 tokenId){
    EventDetails storage evt = events[eventId];
    if (evt.status == EventStatus.Cancelled)
    revert EventCancelled();

if (evt.status != EventStatus.Upcoming)
    revert EventNotActive();
    if (block.timestamp >= evt.eventTimestamp)
    revert EventNotActive();
    if(evt.ticketsSold  >= evt.maxTickets)revert EventFull();
    if(msg.value !=evt.ticketPrice)revert IncorrectPayment();
    evt.ticketsSold++;
    organizerBalance[eventId] += msg.value;
    totalOrganizerBalance += msg.value;
    tokenId = ticketNFT.mintTicket(
    msg.sender,
    eventId,
    evt.metadataURL,
    evt.organizer,
    evt.royaltyFee
);
ticketPricePaid[tokenId] = msg.value;
emit TicketPurchased(eventId,tokenId,msg.sender,msg.value);

}


//CheckedIn ticket
function checkInTicket(uint256  eventId,uint256  tokenId)
external
eventExists(eventId){
    EventDetails storage evt = events[eventId];
    if (evt.status != EventStatus.Live)
    revert EventNotActive();
    if(msg.sender!=evt.organizer && msg.sender != owner())
    revert Unauthorized();

    (uint256 ticketEventId, , ) = ticketNFT.getTicketInfo(tokenId);
    if(ticketEventId != eventId)revert InvalidEvent();
    ticketNFT.markTicketUsed(tokenId);
    emit TicketCheckedIn(eventId,tokenId);

}
//wtd org fund
function withdrawOrganizerFunds(uint256 eventId)
external
nonReentrant
eventExists(eventId)
onlyOrganizer(eventId){
    uint256 amount = organizerBalance[eventId];
    if(amount==0)revert NothingToWithdraw();
    organizerBalance[eventId]= 0;
    totalOrganizerBalance -=  amount;
    (bool success,)= payable(msg.sender).call{value:amount}("");
    if(!success) revert TransferFailed();
    emit OrganizerWithdraw(eventId, msg.sender,amount);
}

//cancel event
function cancelEvent(uint256 eventId)
    external
    eventExists(eventId)
{
    EventDetails storage evt = events[eventId];

    if (msg.sender != evt.organizer && msg.sender != owner())
        revert Unauthorized();

    if (evt.status == EventStatus.Cancelled)
        revert EventCancelled();

    if (evt.status != EventStatus.Upcoming)
        revert EventAlreadyStarted();

    evt.status = EventStatus.Cancelled;

    emit EventCancelledEvent(eventId);
}
//start event


function startEvent(uint256 eventId)
    external
    eventExists(eventId)
    onlyOrganizer(eventId)
{
    EventDetails storage evt = events[eventId];

    require(evt.status == EventStatus.Upcoming, "Invalid state");
    require(block.timestamp >= evt.eventTimestamp, "Too early");

    evt.status = EventStatus.Live;

    emit EventStarted(eventId);
}
//finish event
event EventFinished(uint256 indexed eventId);

function finishEvent(uint256 eventId)
    external
    eventExists(eventId)
    onlyOrganizer(eventId)
{
    EventDetails storage evt = events[eventId];

    require(evt.status == EventStatus.Live, "Event not live");

    evt.status = EventStatus.Finished;

    emit EventFinished(eventId);
}


function claimRefund(uint256 eventId, uint256 tokenId)
    external
    nonReentrant
    eventExists(eventId)
{
    EventDetails storage evt = events[eventId];
    if (evt.status != EventStatus.Cancelled)
    revert NotCancelled();
    if (ticketNFT.ownerOf(tokenId) != msg.sender) revert NotTicketOwner();
    if (ticketRefunded[tokenId]) revert AlreadyRefunded();

    (uint256 ticketEventId, bool used, ) =
    ticketNFT.getTicketInfo(tokenId);
    if (ticketEventId != eventId) revert InvalidEvent();
    if (used) revert AlreadyUsed();

    uint256 amount = ticketPricePaid[tokenId];
    ticketRefunded[tokenId] = true;
    organizerBalance[eventId] -= amount; 
    totalOrganizerBalance -= amount;
    ticketNFT.burn(tokenId);

    (bool success, ) = payable(msg.sender).call{value: amount}("");
    if (!success) revert TransferFailed();

    emit TicketRefunded(eventId, tokenId, msg.sender, amount);
}
function claimReward(uint256 eventId, uint256 tokenId)
    external
    nonReentrant
    eventExists(eventId)
{
    EventDetails storage evt = events[eventId];

    require(evt.status == EventStatus.Finished, "Match not finished");
    require(ticketNFT.ownerOf(tokenId) == msg.sender, "Not owner");

    (uint256 ticketEventId, bool used, bool rewardClaimed) =
        ticketNFT.getTicketInfo(tokenId);

    require(ticketEventId == eventId, "Invalid ticket");
    require(used, "Ticket not used");
    require(!rewardClaimed, "Reward already claimed");

    ticketNFT.markRewardClaimed(tokenId);

    fanToken.transfer(msg.sender, rewardAmount);
    emit RewardClaimed(
    eventId,
    tokenId,
    msg.sender,
    rewardAmount
);
}

//resale
function isResaleAllowed(uint256 eventId)
external 
view
eventExists(eventId)
returns(bool){
    EventDetails memory evt = events[eventId];
    return
    evt.status == EventStatus.Upcoming && 
    block.timestamp < evt.eventTimestamp;
}







function pause() external onlyOwner {
    _pause();
}

function unpause() external onlyOwner {
    _unpause();
}


function withdrawStuckETH()external onlyOwner{
    uint256 withdrawable= 
    address(this).balance - totalOrganizerBalance;

    require(withdrawable > 0,"NothingToWithdraw");
    (bool success,) = payable(owner()).call{
        value: withdrawable

    }("");
    require(success,"transfer failed");
}

function getEvent(uint256 eventId)
    external
    view
    eventExists(eventId)
    returns (EventDetails memory)
{
    return events[eventId];
}
}