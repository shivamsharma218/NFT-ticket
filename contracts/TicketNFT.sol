// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract TicketNFT is ERC721URIStorage, Ownable, Pausable, ERC2981{

    struct TicketInfo {
        uint256 eventId;
        bool used;
        bool rewardClaimed;
        

    }
    mapping(uint256 => TicketInfo) public ticketInfo;

    uint256 public nextTokenId;
    address public eventManager;

    constructor(
        string memory name_,
        string memory symbol_,
        address _owner
    )
        ERC721(name_, symbol_)
        Ownable(_owner)
    {}

    // errors
    error InvalidAddress();
    error Unauthorized();
    error InvalidToken();
    error TicketAlreadyUsed();
    error RewardAlreadyClaimed();
    error TicketNotUsed();
    error InvalidRoyaltyFee();


    // events
    event EventManagerUpdated(address indexed manager);
    event TicketMinted(
        address indexed to,
        uint256 indexed tokenId,
        uint256 indexed eventId
    );
    event TicketUsed(uint256 indexed tokenId);
    event RewardClaimed(uint256 indexed tokenId);

    modifier onlyEventManager() {
        if (msg.sender != eventManager) revert Unauthorized();
        _;
    }

    // set event manager
    function setEventManager(address manager) external onlyOwner {
        if (manager == address(0)) revert InvalidAddress();
        eventManager = manager;
        emit EventManagerUpdated(manager);
    }

    // mint ticket
    function mintTicket(
        address to,
        uint256 eventId,
        string calldata metadataURL,
        address organizer,
        uint96 royaltyFee
    )
        external
        onlyEventManager
        whenNotPaused
        returns (uint256)
    {
        if (to == address(0)) revert InvalidAddress();
        if (organizer == address(0)) revert InvalidAddress();

       if (royaltyFee > 10_000)
       revert InvalidRoyaltyFee();

        nextTokenId++;
        uint256 tokenId = nextTokenId;

        
        ticketInfo[tokenId] = TicketInfo({eventId: eventId, used: false, rewardClaimed : false});

        _safeMint(to, tokenId);
        _setTokenRoyalty(tokenId,organizer,royaltyFee);
        _setTokenURI(tokenId, metadataURL);

        emit TicketMinted(to, tokenId, eventId);
        return tokenId;
    }

    function markTicketUsed(uint256 tokenId)
        external
        onlyEventManager
        whenNotPaused
    {
        if (_ownerOf(tokenId) == address(0)) revert InvalidToken();
        if (ticketInfo[tokenId].used) revert TicketAlreadyUsed();

        ticketInfo[tokenId].used = true;

        emit TicketUsed(tokenId);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // get ticket info
   function getTicketInfo(uint256 tokenId)
    external
    view
    returns (
        uint256 eventId,
        bool used,
        bool rewardClaimed
    )
{
    if (_ownerOf(tokenId) == address(0))
        revert InvalidToken();

    TicketInfo memory ticket = ticketInfo[tokenId];

    return (
        ticket.eventId,
        ticket.used,
        ticket.rewardClaimed
    );
}

//mark rewardClaimed
function  markRewardClaimed(uint256 tokenId)
external
onlyEventManager{
    if(_ownerOf(tokenId)==address(0))
    revert InvalidToken();
    
    if (!ticketInfo[tokenId].used)
    revert TicketNotUsed();
    if (ticketInfo[tokenId].rewardClaimed)
    revert RewardAlreadyClaimed();
    ticketInfo[tokenId].rewardClaimed = true;
    emit RewardClaimed(tokenId);

}

function burn(uint256 tokenId) external onlyEventManager {
    
    _resetTokenRoyalty(tokenId);
    _burn(tokenId);
}


function supportsInterface(bytes4 interfaceId)
public 
view
override(ERC721URIStorage, ERC2981)
returns(bool){
    return super.supportsInterface(interfaceId);
}
}