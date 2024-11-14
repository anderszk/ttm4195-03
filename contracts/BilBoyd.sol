// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Importing necessary OpenZeppelin contracts for ERC721 (NFT) and ownership functionality
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// The main contract for CarLeasingNFT inheriting ERC721 functionality and ownership control
contract CarLeasingNFT is ERC721, Ownable {

    // Structure to store details of each car
    struct Car {
        string model;  // Car model (e.g., 'Tesla Model 3')
        string color;  // Car color (e.g., 'Red')
        uint256 yearOfMatriculation;  // Year when the car was registered
        uint256 originalValue;  // Original value of the car
    }

    // Mapping to associate each car token ID with its details
    mapping(uint256 => Car) public cars;

    // Structure to track leasing deals for each car
    struct Deal {
        uint256 tokenId;  // Token ID representing the car
        address lessee;  // Address of the lessee (person leasing the car)
        uint256 driverExpierience;  // Driver's years of experience
        uint256 totalPaid;  // Total amount paid by the lessee so far
        bool confirmedByBilBoyd;  // Whether the deal has been confirmed by the contract owner
        uint256 monthlyQuota;  // Monthly payment for the lease
        uint256 nextPaymentDue;  // Timestamp for the next payment due
        uint256 contractEndDate;  // Timestamp for when the lease ends
        uint256 contractDuration;  // Duration of the lease in months
    }

    // Mapping to associate each car token ID with its leasing deal
    mapping(uint256 => Deal) public deals;
    uint256 private _currentTokenId;  // Counter to track the latest token ID

    // Constructor to initialize the contract, inheriting ERC721 and Ownable functionality
    constructor() ERC721("BilBoydCarLease", "BBCAR") Ownable(msg.sender) {}

    // Function to create a new Car NFT with details and mint it
    function createCarNFT(
        string memory _model,
        string memory _color,
        uint256 _yearOfMatriculation,
        uint256 _originalValue
    ) public onlyOwner returns (uint256) {
        _currentTokenId++;  // Increment the token ID counter
        uint256 newCarId = _currentTokenId;

        // Mint the NFT representing the car, assigning it to the owner of the contract
        _mint(msg.sender, newCarId);

        // Store the car details in the mapping
        cars[newCarId] = Car({
            model: _model,
            color: _color,
            yearOfMatriculation: _yearOfMatriculation,
            originalValue: _originalValue
        });

        return newCarId;
    }

    // Function to compute the monthly leasing quota based on various factors
    function computeMonthlyQuotaForProposal(
        uint256 tokenId,
        uint256 driverExperience,
        uint256 mileageCap,
        uint256 contractDuration,
        uint256 estimatedMileage // New parameter: Estimated mileage over the lease term
    ) public view returns (uint256) {
        require(_ownerOf(tokenId) != address(0), "Token ID does not exist");

        Car memory car = getCarDetails(tokenId);

        // Base monthly quota is calculated as 1% of the car's original value
        uint256 baseQuota = car.originalValue / 100;

        // Define a cost per mile over the mileage cap
        uint256 costPerMileOverCap = 0.1 ether; // Example: 0.1 ether per mile over the mileage cap

        // Calculate the additional cost if the estimated mileage exceeds the mileage cap
        uint256 mileageCost = 0;
        if (estimatedMileage > mileageCap) {
            uint256 excessMileage = estimatedMileage - mileageCap;
            mileageCost = excessMileage * costPerMileOverCap;
        }

        // Discount based on driver's experience (1% discount per year)
        uint256 experienceDiscount = (driverExperience * baseQuota) / 100;

        // Discount based on the duration of the lease contract (e.g., 5% for leases >= 36 months)
        uint256 durationDiscount = 0;
        if (contractDuration >= 36) {
            durationDiscount = (baseQuota * 5) / 100;
        } else if (contractDuration >= 24) {
            durationDiscount = (baseQuota * 3) / 100;
        }

        // Final monthly quota considering the base value, mileage, experience discount, and duration discount
        uint256 monthlyQuota = baseQuota + mileageCost - experienceDiscount - durationDiscount;

        return monthlyQuota;
    }

    // Function to register a leasing deal for a specific car
    function registerDeal(
        uint256 tokenId,
        uint256 driverExperience,
        uint256 mileageCap,
        uint256 contractDuration,
        uint256 estimatedMileage
    ) public payable {
        require(msg.value > 0, "Payment must be greater than zero");

        // Ensure the car exists and is available for leasing
        require(ownerOf(tokenId) != address(0), "Token ID does not exist");
        Deal storage currentDeal = deals[tokenId];
        require(currentDeal.lessee == address(0), "Deal already exists!");

        // Calculate the monthly leasing quota based on the provided details
        uint256 monthlyQuota = computeMonthlyQuotaForProposal(tokenId, driverExperience, mileageCap, contractDuration, estimatedMileage);

        // Calculate down payment (3 months' quota + first month)
        uint256 downPayment = monthlyQuota * 3;

        // Ensure sufficient payment for down payment and first month's quota
        require(msg.value >= downPayment + monthlyQuota, "Insufficient payment for down payment and first month");

        // Register the leasing deal
        deals[tokenId] = Deal({
            tokenId: tokenId,
            lessee: msg.sender,  // The lessee is the sender of the transaction
            driverExpierience: driverExperience,
            totalPaid: msg.value,
            confirmedByBilBoyd: false,  // Deal is not yet confirmed
            monthlyQuota: monthlyQuota,
            nextPaymentDue: block.timestamp + 30 days,  // Next payment due in 30 days
            contractEndDate: block.timestamp + (contractDuration * 30 days),  // Contract end date
            contractDuration: contractDuration
        });
    }

    // Function for BilBoyd (the contract owner) to confirm the leasing deal
    function confirmDeal(uint256 tokenId) public onlyOwner {
        require(deals[tokenId].lessee != address(0), "No deal registered for this token");
        
        deals[tokenId].confirmedByBilBoyd = true;
    }

    // Function to allow the contract owner to withdraw the funds after the deal is confirmed
    function withdrawFunds(uint256 tokenId) public onlyOwner {
        require(deals[tokenId].confirmedByBilBoyd, "Deal not confirmed by BilBoyd");
        require(deals[tokenId].totalPaid > 0, "No funds to withdraw");

        uint256 amountToWithdraw = deals[tokenId].totalPaid;
        deals[tokenId].totalPaid = 0;  // Reset the total paid after withdrawal

        payable(owner()).transfer(amountToWithdraw);  // Transfer funds to the contract owner
    }

    // Function for lessee to make monthly payments
    function makeMonthlyPayment(uint256 tokenId) public payable {
        Deal storage deal = deals[tokenId];
        require(deal.lessee == msg.sender, "Only the lessee can make the payment");
        require(deal.confirmedByBilBoyd, "Deal not confirmed by BilBoyd");
        require(msg.value == deal.monthlyQuota, "Incorrect payment amount");
        require(block.timestamp <= deal.nextPaymentDue + 7 days, "Payment overdue");

        deal.totalPaid += msg.value;
        deal.nextPaymentDue += 30 days;  // Set next payment due date to a month later
    }

    // Function to check for overdue payments and return the car if overdue
    function checkOverdue(uint256 tokenId) public {
        Deal storage deal = deals[tokenId];
        require(deal.confirmedByBilBoyd, "Deal not confirmed by BilBoyd");
        if (block.timestamp > deal.nextPaymentDue + 7 days) {
            deal.lessee = address(0);  // Return the car to the contract owner
            _transfer(owner(), ownerOf(tokenId), tokenId);
        }
    }

    // Function for lessee to terminate the lease after the lease period is completed
    function terminateLease(uint256 tokenId) public {
        Deal storage deal = deals[tokenId];
        require(deal.lessee == msg.sender, "Only the lessee can terminate the lease");
        require(block.timestamp >= deal.contractEndDate, "Lease period not yet completed");

        // Clear lessee details and reset ownership to contract owner
        deal.lessee = address(0);
        _transfer(owner(), ownerOf(tokenId), tokenId);  // Return car to contract owner
    }

    // Function to extend the lease for one more year, recalculating the quota
    function extendLease(uint256 tokenId, uint256 estimatedMileage, uint256 mileageCap) public {
        Deal storage deal = deals[tokenId];
        require(deal.lessee == msg.sender, "Only the lessee can extend the lease");
        require(deal.confirmedByBilBoyd,"Contract is not confirmed");

        // Recompute monthly quota for the extended period
        uint256 newMonthlyQuota = computeMonthlyQuotaForProposal(tokenId, deal.driverExpierience, mileageCap, deal.contractDuration + 12, estimatedMileage);

        // Extend lease and update quota
        deal.monthlyQuota = newMonthlyQuota;
        deal.contractDuration += 12;  // Add 12 months to the lease
        deal.contractEndDate += 12 * 30 days;  // Extend contract end date by 12 months
    }

    // Helper function to retrieve car details for a given token ID
    function getCarDetails(uint256 tokenId) public view returns (Car memory) {
        return cars[tokenId];
    }
}
