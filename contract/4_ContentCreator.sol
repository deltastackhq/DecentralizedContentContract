// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DecentralizedContentContract is Ownable {

    using SafeMath for uint256;

    bool private locked;
    bool public emergencyStop;

    // Contract owner
    // address public  owner;

    // Counter for tracking content items
    uint256 public contentCount;

    // Array to store addresses of governance members
    address[] public governanceMembers;

    // Structure to represent content
    struct Content {
        uint256 id;
        address creator;
        string contentHash;
        string title;
        string[] tags;
        uint256 price;
        uint256 views;
        uint256 totalRating;
        uint256 totalReviews;
        mapping(address => uint256) userRatings;
    }

    // Struct to represent a governance proposal
    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        uint256 votes;
        bool executed;
        mapping(address => bool) voters;
    }

    // Array to store governance proposals
    Proposal[] public proposals;
    

    // Mapping to store content by ID
    mapping(uint256 => Content) public contentById;

    // // Mapping for decentralized governance
    // mapping(address => bool) public governanceMembers;

    // Event emitted when content is published
    event ContentPublished(uint256 id, address indexed creator, string title);

    // Event emitted when content is rated
    event ContentRated(uint256 id, address indexed rater, uint256 rating);

    // Event emitted when a new proposal is created
    event ProposalCreated(uint256 id, address indexed proposer, string description);

    // Event emitted when a proposal is voted on
    event Voted(uint256 indexed proposalId, address indexed voter);

    // Event emitted when a proposal is executed
    event ProposalExecuted(uint256 indexed proposalId);

    // Modifier to restrict access to the contract owner
    // modifier onlyOwner() override {
    //     require(msg.sender == owner(), "Only the contract owner can call this function");
    //     _;
    // }

    modifier onlyGovernance() {
        require(isGovernanceMember(msg.sender), "Only governance members can call this function");
        _;
    }

    modifier reentrancyGuard() {
        require(!locked, "Reentrancy detected");
        locked = true;
        _;
        locked = false;
    }

    modifier onlyUnpaused() {
        require(!emergencyStop, "Contract is in emergency stop mode");
        _;
    }


    // Contract constructor, sets the owner to the deployer
    constructor() Ownable(msg.sender) {
        // owner = msg.sender;

    }

    // accessing the owner
    function getOwner() external view returns (address) {
        return owner();
    }

    // Function to publish new content
    function publishContent(
        string memory _contentHash, 
        string memory _title, 
        string[] memory _tags, 
        uint256 _price) external onlyUnpaused reentrancyGuard {
        // Input validation
        require(bytes(_contentHash).length > 0, "Content hash cannot be empty");
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(_price > 0, "Price must be greater than zero");

        // Increment content count
        contentCount++;

        // Create a new content item
        Content storage newContent = contentById[contentCount];
        newContent.id = contentCount;
        newContent.creator = msg.sender;
        newContent.contentHash = _contentHash;
        newContent.title = _title;
        newContent.tags = _tags;
        newContent.price = _price;

        // Emit event to signify content publication
        emit ContentPublished(contentCount, msg.sender, _title);
    }

    // Function to view and pay for content
    function viewContent(uint256 _contentId) external payable onlyUnpaused reentrancyGuard {
        // Retrieve content
        Content storage content = contentById[_contentId];

        // Validate content existence and sufficient funds
        require(content.id > 0, "Content not found");
        require(msg.value >= content.price, "Insufficient funds");

        // Increment content views
        content.views++;

        // Transfer payment to content creator
        payable(content.creator).transfer(msg.value);
    }

    // Function to rate content
    function rateContent(uint256 _contentId, uint256 _rating) external onlyUnpaused reentrancyGuard {
        // Validate rating
        require(_rating >= 1 && _rating <= 5, "Invalid rating value");

        // Retrieve content
        Content storage content = contentById[_contentId];

        // Ensure content exists
        require(content.id > 0, "Content not found");

        // Ensure the user has not rated the content before
        require(content.userRatings[msg.sender] == 0, "User has already rated this content");

        // Update content rating information
        content.totalRating += _rating;
        content.totalReviews++;
        content.userRatings[msg.sender] = _rating;

        // Emit event to signify content rating
        emit ContentRated(_contentId, msg.sender, _rating);
    }

    // Function to get average content rating
    function getAverageRating(uint256 _contentId) external view returns (uint256) {
        // Retrieve content
        Content storage content = contentById[_contentId];

        // Ensure content exists
        require(content.id > 0, "Content not found");

        // Calculate and return average rating
        if (content.totalReviews > 0) {
            return content.totalRating / content.totalReviews;
        } else {
            return 0;
        }
    }

    // Function to check if an address is a governance member
    function isGovernanceMember(address _member) public view returns (bool) {
        for (uint256 i = 0; i < governanceMembers.length; i++) {
            if (governanceMembers[i] == _member) {
                return true;
            }
        }
        return false;
    }

    // Function to add a new governance member
    function addGovernanceMember(address _newMember) external onlyOwner {
        require(_newMember != address(0), "Invalid member address");
        governanceMembers.push(_newMember);
    }

    // Function to create a new proposal
    function createProposal(string memory _description) external onlyGovernance {
        require(bytes(_description).length > 0, "Proposal description cannot be empty");

        uint256 proposalId = proposals.length + 1;

        Proposal storage newProposal = proposals.push();
        newProposal.id = proposalId;
        newProposal.proposer = msg.sender;
        newProposal.description = _description;

        emit ProposalCreated(proposalId, msg.sender, _description);
    }

    // Function to vote on a proposal
    function vote(uint256 _proposalId) external onlyUnpaused {
        Proposal storage proposal = proposals[_proposalId - 1];

        require(proposal.id > 0, "Proposal not found");
        require(!proposal.voters[msg.sender], "You have already voted on this proposal");

        proposal.voters[msg.sender] = true;
        proposal.votes++;

        emit Voted(_proposalId, msg.sender);
    }

    // Function to execute a proposal if it has enough votes
    function executeProposal(uint256 _proposalId) external onlyGovernance onlyUnpaused reentrancyGuard {
        Proposal storage proposal = proposals[_proposalId - 1];

        require(proposal.id > 0, "Proposal not found");
        require(!proposal.executed, "Proposal has already been executed");

        // Set proposal as executed if it has enough votes
        if (proposal.votes >= (governanceMembers.length / 2)) {
            proposal.executed = true;

            // TODO: Add logic to execute the proposal (e.g., modify contract state)

            emit ProposalExecuted(_proposalId);
        }
    }

    function emergencyStopToggle() external onlyOwner {
        emergencyStop = !emergencyStop;
    }


    // TODO: Implement content licensing and permissions
    // Define a separate contract for content licensing and permissions

    // TODO: Implement tokenization and dynamic pricing
    // Define a separate contract for tokenization and dynamic pricing

}
