// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./RewardNft.sol";

contract AnimalRehab {
    uint256 counterId = 1;
    address _owner;
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
    mapping(uint256 => uint256) private idToBalance;

    modifier onlyOwner() {
        require(msg.sender == _owner, "Not the owner!");
        _;
    }

    // constructor
    constructor() RewardNft() {
        _owner = msg.sender; //owner is the rehabilitator
    }

    //functions
    function createRescueRequest(string calldata _animalType) external payable {
        idToRequest[counterId] = RescueRequest(
            counterId,
            msg.sender,
            _animalType,
            msg.value
        );
        require(
            msg.sender.balance > msg.value,
            "Not enough ETH in you account"
        );
        require(msg.value > 0, "Not ETH sent!");
        idToBalance[counterId] = msg.value;
        emit NewRequest(msg.sender, counterId, _animalType, msg.value);
        counterId++;
    }

    function approveIntake(uint256 _id) external onlyOwner {
        //rehabilitator approves animal intake.  Partial fund transfer to the rehabilitator
        uint256 initialSum = idToRequest[_id].donationAmount / 2;
        idToBalance[_id] -= initialSum;
        internalTransfer(initialSum);
        activeRescues.push(idToRequest[_id]);
        emit RequestApproved(_id, idToRequest[_id].donorAddress);
    }

    function internalTransfer(uint256 _sum) private {
        (bool success, ) = payable(_owner).call{value: _sum}("");
        require(success, "first transfer failed");
    }

    function rescueComplete(RewardNft _nftContract, uint256 _id)
        external
        onlyOwner
    {

        uint256 remainingBalance = idToBalance[_id];
        idToBalance[_id] = 0;
        internalTransfer(remainingBalance);
        _nftContract.awardItem(idToRequest[_id].donorAddress, Token_URI); //RewardNft
    }

    function viewActiveRescues() public view returns (RescueRequest[] memory) {
        return activeRescues;
    }

    function viewOwner() public view returns (address) {
        return _owner;
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
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
