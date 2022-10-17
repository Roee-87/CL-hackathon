// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./RewardNft.sol";

contract AnimalRehab {
    uint256 counterId = 1;
    address _owner; //wildlife rescue rehabilitator is the contract owner
    string public constant Token_URI =
        '{"description": "Rescued Animal", "image": "ipfs://QmTnUzjqVK31r7LLSp399QJpd3YAL8AZD5b1kYv4LcKpPF", "name": "Wildlife Rescue NFT"}';

    struct RescueRequest {
        uint256 id;
        address donorAddress;
        string animalType;
        uint256 donationAmount;
    }

    RescueRequest[] public activeRescues;

    event NewRequest(
        address donor,
        uint256 indexed requestId,
        string indexed animal,
        uint256 indexed donatedAmount
    );

    event RequestApproved(
        uint256 indexed requestId,
        address indexed donorAddress
    );

    // mappings
    mapping(uint256 => RescueRequest) private idToRequest;
    mapping(uint256 => uint256) private idToTime;

    modifier onlyOwner() {
        require(msg.sender == _owner, "Not the owner!");
        _;
    }

    // constructor
    constructor() {
        _owner = msg.sender; //owner is the rehabilitator
    }

    //donor creates a new request.  Inputs animal type, amount to donate.
    //Donor's balance is updated (he may have multiple simultaneous requests)
    function createRescueRequest(string calldata _animalType) external payable {
        require(msg.value > 0, "No ETH sent!");
        require(
            msg.sender.balance > msg.value,
            "Not enough ETH in you account"
        );
        idToRequest[counterId] = RescueRequest(
            counterId,
            msg.sender,
            _animalType,
            msg.value
        );
        emit NewRequest(msg.sender, counterId, _animalType, msg.value);
        counterId++;
    }

    //rehabilitator approves animal intake.  Partial fund transfer to the rehabilitator
    function approveIntake(uint256 _id) external onlyOwner {
        uint256 initialSum = idToRequest[_id].donationAmount / 2;
        idToRequest[_id].donationAmount -= initialSum;
        internalTransferToOwner(initialSum);
        activeRescues.push(idToRequest[_id]);
        emit RequestApproved(_id, idToRequest[_id].donorAddress);
    }

    //rehabilitator rejects the intake.  Donated funds are returned to the donor.  Rescue request is deleted (struct params set to zero), donor balance reduced by donated sum
    function rejectIntake(uint256 _id) external onlyOwner {
        uint256 sum = idToRequest[_id].donationAmount;
        address donor = idToRequest[_id].donorAddress;
        delete idToRequest[_id]; // is this the correct way to delete a struct (set values to zero) from a mapping?
        internalTransferToDonor(sum, donor);
    }

    function internalTransferToOwner(uint256 _sum) private {
        (bool success, ) = payable(_owner).call{value: _sum}("");
        require(success, "transfer to owner failed");
    }

    function internalTransferToDonor(uint256 _sum, address _donor) private {
        (bool success, ) = payable(_donor).call{value: _sum}("");
        require(success, "transfer to donor failed");
    }

    //rehabilitator completes
    function rescueComplete(RewardNft _nftContract, uint256 _id)
        external
        onlyOwner
    {
        uint256 remainingDonation = idToRequest[_id].donationAmount;
        idToRequest[_id].donationAmount = 0;
        internalTransferToOwner(remainingDonation);
        _nftContract.awardItem(idToRequest[_id].donorAddress, Token_URI);
        //need to remove idToRequest[_id] item from the activeRescues array.  How do I do this without the index of the itme?
        //Eventually I need to have chainlink fetch Token_URI from IPFS after the rehabilitator has uploaded the photo.  Maybe use a CL websocket?
    }

    function viewActiveRescues()
        public
        view
        onlyOwner
        returns (RescueRequest[] memory)
    {
        return activeRescues;
    }

    fallback() external payable {
        // donations go directly to the rehabilitator director
        payable(_owner).transfer(msg.value);
    }

    receive() external payable {
        // donations go directly to the rehabilitator director
        payable(_owner).transfer(msg.value);
    }
}
