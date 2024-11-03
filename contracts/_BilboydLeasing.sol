// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CarLeasingNFT {
    // ERC721 Implementation

    // Event declarations as per ERC721 standard
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    // Mapping from token ID to owner
    mapping(uint256 => address) private _owners;

    // Mapping owner address to token count (balance)
    mapping(address => uint256) private _balances;

    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals (for all tokens)
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    // Token name and symbol
    string private _name;
    string private _symbol;

    // Token counter
    uint256 private _tokenIds;

    // Car struct
    struct Car {
        string model;
        string color;
        uint256 yearOfMatriculation;
        uint256 originalValue;
        uint256 currentMileage;
    }

    // Mapping from token ID to Car details
    mapping(uint256 => Car) private _carDetails;

    // LeaseAgreement struct
    struct LeaseAgreement {
        uint256 tokenId;
        address lessee;
        uint256 driverExperience; // in years
        uint256 mileageCap;
        uint256 contractDuration; // in months
        bool isActive;            // Indicates if the lease is active
        uint256 deposit;          // Deposit held in the contract
        uint256 lastPaymentTime;  // Timestamp of the last payment
        uint256 paymentDueDate;   // Next payment due date
        uint256 monthlyQuota;     // Monthly payment amount
    }

    // Mapping from token ID to LeaseAgreement
    mapping(uint256 => LeaseAgreement) private _leaseAgreements;

    // Contract owner (for access control)
    address private _owner;

    // Modifier to restrict functions to contract owner
    modifier onlyOwner() {
        require(msg.sender == _owner, "Caller is not the owner");
        _;
    }

    constructor() {
        _name = "BilBoydCar";
        _symbol = "BBC";
        _owner = msg.sender;
    }

    // Public function to check if a token exists
    function exists(uint256 tokenId) public view returns (bool) {
        return _owners[tokenId] != address(0);
    }

    // Function to get the token name
    function name() public view returns (string memory) {
        return _name;
    }

    // Function to get the token symbol
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    // Function to get the token balance of an owner
    function balanceOf(address ownerAddress) public view returns (uint256) {
        require(ownerAddress != address(0), "Invalid address");
        return _balances[ownerAddress];
    }

    // Function to get the owner of a token ID
    function ownerOf(uint256 tokenId) public view returns (address) {
        address ownerAddress = _owners[tokenId];
        require(ownerAddress != address(0), "Token ID does not exist");
        return ownerAddress;
    }

    // Function to approve another address to transfer the given token ID
    function approve(address to, uint256 tokenId) public {
        address ownerAddress = ownerOf(tokenId);
        require(to != ownerAddress, "Approval to current owner");

        require(
            msg.sender == ownerAddress || isApprovedForAll(ownerAddress, msg.sender),
            "Caller is not owner nor approved for all"
        );

        _tokenApprovals[tokenId] = to;

        emit Approval(ownerAddress, to, tokenId);
    }

    // Function to get the approved address for a token ID
    function getApproved(uint256 tokenId) public view returns (address) {
        require(exists(tokenId), "Token ID does not exist");

        return _tokenApprovals[tokenId];
    }

    // Function to set or unset approval for an operator to manage all tokens of the caller
    function setApprovalForAll(address operator, bool approved) public {
        require(operator != msg.sender, "Cannot approve to caller");

        _operatorApprovals[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    // Function to check if an operator is approved for all tokens of an owner
    function isApprovedForAll(address ownerAddress, address operator) public view returns (bool) {
        return _operatorApprovals[ownerAddress][operator];
    }

    // Function to transfer ownership of a token ID to another address
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public {
        require(_isApprovedOrOwner(msg.sender, tokenId), "Caller is not owner nor approved");

        _transfer(from, to, tokenId);
    }

    // Internal function to transfer ownership of a token ID to another address
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal {
        require(ownerOf(tokenId) == from, "From address is not owner");
        require(to != address(0), "Transfer to zero address");

        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    // Internal function to check if an address is the owner or approved for a token ID
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        require(exists(tokenId), "Token ID does not exist");
        address ownerAddress = ownerOf(tokenId);
        return (spender == ownerAddress ||
            getApproved(tokenId) == spender ||
            isApprovedForAll(ownerAddress, spender));
    }

    // Internal function to approve an address for a token ID
    function _approve(address to, uint256 tokenId) internal {
        _tokenApprovals[tokenId] = to;
        emit Approval(ownerOf(tokenId), to, tokenId);
    }

    // Mint a new car NFT (owned by the dealership initially)
    function mintCar(
        string memory model,
        string memory color,
        uint256 yearOfMatriculation,
        uint256 originalValue,
        uint256 currentMileage
    ) public onlyOwner returns (uint256) {
        require(_owner != address(0), "Mint to zero address");

        _tokenIds += 1;
        uint256 newCarId = _tokenIds;

        _balances[_owner] += 1;
        _owners[newCarId] = _owner;

        _carDetails[newCarId] = Car({
            model: model,
            color: color,
            yearOfMatriculation: yearOfMatriculation,
            originalValue: originalValue,
            currentMileage: currentMileage
        });

        emit Transfer(address(0), _owner, newCarId);

        return newCarId;
    }

    // Alice proposes a lease by sending the down payment and first monthly quota
    function proposeLease(
        uint256 tokenId,
        uint256 driverExperience, // in years
        uint256 mileageCap,
        uint256 contractDuration // in months
    ) public payable {
        require(exists(tokenId), "Token ID does not exist");
        require(_leaseAgreements[tokenId].lessee == address(0), "Lease already exists for this token");

        // Validate inputs
        require(
            mileageCap == 10000 || mileageCap == 15000 || mileageCap == 20000,
            "Invalid mileage cap"
        );
        require(
            contractDuration == 12 || contractDuration == 24 || contractDuration == 36,
            "Invalid contract duration"
        );

        // Compute monthly quota
        uint256 monthlyQuota = computeMonthlyQuotaForProposal(
            tokenId,
            driverExperience,
            mileageCap,
            contractDuration
        );

        // Compute required initial payment (3 monthly quotas as down payment + first monthly quota)
        uint256 requiredPayment = monthlyQuota * 4;

        // Check that the sender sent the correct amount
        require(msg.value == requiredPayment, "Incorrect payment amount");

        // Store the proposal
        _leaseAgreements[tokenId] = LeaseAgreement({
            tokenId: tokenId,
            lessee: msg.sender,
            driverExperience: driverExperience,
            mileageCap: mileageCap,
            contractDuration: contractDuration,
            isActive: false,
            deposit: monthlyQuota * 3, // Hold the down payment as deposit
            lastPaymentTime: block.timestamp,
            paymentDueDate: block.timestamp + 30 days, // Next payment due in 30 days
            monthlyQuota: monthlyQuota
        });

        // Funds are locked in the contract until BilBoyd confirms
    }

    // BilBoyd confirms the lease, activating it and receiving the first monthly quota
    function confirmLease(uint256 tokenId) public onlyOwner {
        LeaseAgreement storage lease = _leaseAgreements[tokenId];
        require(lease.lessee != address(0), "No lease proposal found");
        require(!lease.isActive, "Lease already active");

        // Transfer the first monthly quota to BilBoyd
        uint256 firstMonthlyQuota = lease.monthlyQuota;
        uint256 amountToTransfer = firstMonthlyQuota;

        // Adjust deposit to only hold the down payment
        lease.deposit = lease.deposit - firstMonthlyQuota;

        // Transfer the first monthly quota to BilBoyd
        (bool sent, ) = _owner.call{value: amountToTransfer}("");
        require(sent, "Failed to send Ether");

        // Mark the lease as active
        lease.isActive = true;

        // Transfer the NFT to the lessee
        _transfer(_owner, lease.lessee, tokenId);
    }

    // Compute the monthly quota for a proposed lease
    function computeMonthlyQuotaForProposal(
        uint256 tokenId,
        uint256 driverExperience,
        uint256 mileageCap,
        uint256 contractDuration
    ) public view returns (uint256) {
        require(exists(tokenId), "Token ID does not exist");

        Car memory car = _carDetails[tokenId];

        // Base monthly quota is a percentage of the original car value
        uint256 baseQuota = car.originalValue / 100; // 1% of original value

        // No additional mileage cost at proposal time
        uint256 mileageCost = 0;

        // Discount based on driver's experience
        uint256 experienceDiscount = (driverExperience * baseQuota) / 100; // 1% discount per year

        // Adjustment based on contract duration
        uint256 durationDiscount = 0;
        if (contractDuration >= 36) {
            durationDiscount = (baseQuota * 5) / 100; // 5% discount
        } else if (contractDuration >= 24) {
            durationDiscount = (baseQuota * 3) / 100; // 3% discount
        }

        uint256 monthlyQuota = baseQuota + mileageCost - experienceDiscount - durationDiscount;

        return monthlyQuota;
    }

    // Lessee makes a monthly payment
    function makeMonthlyPayment(uint256 tokenId) public payable {
        LeaseAgreement storage lease = _leaseAgreements[tokenId];
        require(lease.lessee == msg.sender, "Only lessee can make payments");
        require(lease.isActive, "Lease is not active");
        require(msg.value == lease.monthlyQuota, "Incorrect payment amount");
        require(block.timestamp <= lease.paymentDueDate + 5 days, "Payment is overdue");

        // Update payment information
        lease.lastPaymentTime = block.timestamp;
        lease.paymentDueDate += 30 days;

        // Transfer payment to BilBoyd
        (bool sent, ) = _owner.call{value: msg.value}("");
        require(sent, "Failed to send Ether");
    }

    // BilBoyd can repossess the car if payments are overdue
    function repossessCar(uint256 tokenId) public onlyOwner {
        LeaseAgreement storage lease = _leaseAgreements[tokenId];
        require(lease.isActive, "Lease is not active");
        require(block.timestamp > lease.paymentDueDate + 5 days, "Payment is not overdue");

        // Transfer the NFT back to BilBoyd
        _transfer(lease.lessee, _owner, tokenId);

        // Mark the lease as inactive
        lease.isActive = false;

        // Forfeit the deposit
        lease.deposit = 0;
    }

    // Lessee can cancel the lease proposal and get a refund if BilBoyd hasn't confirmed yet
    function cancelLeaseProposal(uint256 tokenId) public {
        LeaseAgreement storage lease = _leaseAgreements[tokenId];
        require(lease.lessee == msg.sender, "Only lessee can cancel");
        require(!lease.isActive, "Lease is already active");

        uint256 refundAmount = lease.deposit + lease.monthlyQuota;

        // Reset the lease agreement
        delete _leaseAgreements[tokenId];

        // Refund the funds
        (bool sent, ) = msg.sender.call{value: refundAmount}("");
        require(sent, "Failed to send Ether");
    }

    // Retrieve car details
    function getCarDetails(uint256 tokenId) public view returns (Car memory) {
        require(exists(tokenId), "Token ID does not exist");
        return _carDetails[tokenId];
    }

    // Retrieve lease agreement details
    function getLeaseDetails(uint256 tokenId) public view returns (LeaseAgreement memory) {
        require(exists(tokenId), "Token ID does not exist");
        return _leaseAgreements[tokenId];
    }

    // Update car's current mileage
    function updateMileage(uint256 tokenId, uint256 newMileage) public {
        require(exists(tokenId), "Token ID does not exist");
        // Only the owner or lessee can update the mileage
        LeaseAgreement memory lease = _leaseAgreements[tokenId];
        require(
            msg.sender == ownerOf(tokenId) || msg.sender == lease.lessee,
            "Caller is not owner nor lessee"
        );
        _carDetails[tokenId].currentMileage = newMileage;
    }
}
