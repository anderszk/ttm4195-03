// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CarLeasingNFT is ERC721, Ownable {

    struct Car {
        string model;
        string color;
        uint256 yearOfMatriculation;
        uint256 originalValue;
    }

    // Mapping from token ID to Car details
    mapping(uint256 => Car) public cars;

    // Deal structure to keep track of the leasing deal
    struct Deal {
        uint256 tokenId;
        address lessee;
        uint256 driverExpierience;
        uint256 totalPaid;
        bool confirmedByBilBoyd;
        uint256 monthlyQuota;
        uint256 nextPaymentDue;
        uint256 contractEndDate; // New: End date of the lease contract
        uint256 contractDuration;
    }

    mapping(uint256 => Deal) public deals; // Mapping of token ID to Deal
    uint256 private _currentTokenId;

    // Constructor for the CarLeasingNFT contract
    constructor() ERC721("BilBoydCarLease", "BBCAR") Ownable(msg.sender) {}

    function createCarNFT(
        string memory _model,
        string memory _color,
        uint256 _yearOfMatriculation,
        uint256 _originalValue
    ) public onlyOwner returns (uint256) {
        _currentTokenId++;
        uint256 newCarId = _currentTokenId;

        // Mint the NFT for the car
        _mint(msg.sender, newCarId);

        // Store the car details
        cars[newCarId] = Car({
            model: _model,
            color: _color,
            yearOfMatriculation: _yearOfMatriculation,
            originalValue: _originalValue
        });

        return newCarId;
    }

    function computeMonthlyQuotaForProposal(
        uint256 tokenId,
        uint256 driverExperience,
        uint256 mileageCap,
        uint256 contractDuration,
        uint256 estimatedMileage // New parameter to estimate the mileage for the contract
    ) public view returns (uint256) {
        require(_ownerOf(tokenId) != address(0), "Token ID does not exist");

        Car memory car = getCarDetails(tokenId);

        // Base monthly quota is a percentage of the original car value
        uint256 baseQuota = car.originalValue / 100; // 1% of original value

        // Define a cost per mile over the mileage cap
        uint256 costPerMileOverCap = 0.1 ether; // Example: 0.1 ether per mile over the cap

        // Calculate mileage cost if the estimated mileage exceeds the mileage cap
        uint256 mileageCost = 0;
        if (estimatedMileage > mileageCap) {
            uint256 excessMileage = estimatedMileage - mileageCap;
            mileageCost = excessMileage * costPerMileOverCap; // Total cost for exceeding mileage
        }

        // Discount based on driver's experience
        uint256 experienceDiscount = (driverExperience * baseQuota) / 100; // 1% discount per year

        // Adjustment based on contract duration
        uint256 durationDiscount = 0;
        if (contractDuration >= 36) {
            durationDiscount = (baseQuota * 5) / 100; // 5% discount
        } else if (contractDuration >= 24) {
            durationDiscount = (baseQuota * 3) / 100; // 3% discount
        }

        // Calculate the final monthly quota
        uint256 monthlyQuota = baseQuota + mileageCost - experienceDiscount - durationDiscount;

        return monthlyQuota;
    }

    // Function to register a leasing deal
// Function to register a leasing deal
 function registerDeal(
        uint256 tokenId,
        uint256 driverExperience,
        uint256 mileageCap,
        uint256 contractDuration,
        uint256 estimatedMileage
    ) public payable {
        require(msg.value > 0, "Payment must be greater than zero");
        require(ownerOf(tokenId) != address(0), "Token ID does not exist");

        uint256 monthlyQuota = computeMonthlyQuotaForProposal(tokenId, driverExperience, mileageCap, contractDuration, estimatedMileage);
        uint256 downPayment = monthlyQuota * 3;
        require(msg.value >= downPayment + monthlyQuota, "Insufficient payment for down payment and first month");

        deals[tokenId] = Deal({
            tokenId: tokenId,
            lessee: msg.sender,
            driverExpierience: driverExperience,
            totalPaid: msg.value,
            confirmedByBilBoyd: false,
            monthlyQuota: monthlyQuota,
            nextPaymentDue: block.timestamp + 30 days,
            contractEndDate: block.timestamp + (contractDuration * 30 days), // Set end date based on contract duration
            contractDuration: contractDuration
        });
    }



    // Function for BilBoyd to confirm the deal
    function confirmDeal(uint256 tokenId) public onlyOwner {
        require(deals[tokenId].lessee != address(0), "No deal registered for this token");
        
        deals[tokenId].confirmedByBilBoyd = true;
    }
    event FundsWithdrawn(uint256 tokenId, uint256 amount, address to);
    // Function for the owner to withdraw the funds after confirmation
    function withdrawFunds(uint256 tokenId) public onlyOwner {
        require(deals[tokenId].confirmedByBilBoyd, "Deal not confirmed by BilBoyd");
        require(deals[tokenId].totalPaid > 0, "No funds to withdraw");

        uint256 amountToWithdraw = deals[tokenId].totalPaid;
        deals[tokenId].totalPaid = 0; // Reset total paid after withdrawal

        payable(owner()).transfer(amountToWithdraw);

        emit FundsWithdrawn(tokenId, amountToWithdraw, owner());
    }

    function makeMonthlyPayment(uint256 tokenId) public payable {
        Deal storage deal = deals[tokenId];
        require(deal.lessee == msg.sender, "Only the lessee can make the payment");
        require(deal.confirmedByBilBoyd, "Deal not confirmed by BilBoyd");
        require(msg.value == deal.monthlyQuota, "Incorrect payment amount");
        require(block.timestamp <= deal.nextPaymentDue + 7 days, "Payment overdue");

        deal.totalPaid += msg.value;
        deal.nextPaymentDue += 30 days; // Set the next due date to a month later
    }

    function checkOverdue(uint256 tokenId) public {
        Deal storage deal = deals[tokenId];
        require(deal.confirmedByBilBoyd, "Deal not confirmed by BilBoyd");
        if (block.timestamp > deal.nextPaymentDue + 7 days) {
            deal.lessee = address(0);
            _transfer(owner(), ownerOf(tokenId), tokenId);
        }
    }

    function isContractEnded(uint256 tokenId) public view returns (bool) {
    Deal storage deal = deals[tokenId];
    require(deal.confirmedByBilBoyd, "Deal not confirmed by BilBoyd");
    require(deal.lessee != address(0), "No active lease for this token");

    return block.timestamp >= deal.contractEndDate;
}


        function terminateLease(uint256 tokenId) public {
        Deal storage deal = deals[tokenId];
        require(deal.lessee == msg.sender, "Only the lessee can terminate the lease");
        require(block.timestamp >= deal.contractEndDate, "Lease period not yet completed");

        // Clear lessee details and reset ownership to contract owner
        deal.lessee = address(0);
        _transfer(owner(), ownerOf(tokenId), tokenId);
    }

    function extendLease(uint256 tokenId, uint256 estimatedMileage, uint256 mileageCap) public {
        Deal storage deal = deals[tokenId];
        require(deal.lessee == msg.sender, "Only the lessee can extend the lease");
        require(block.timestamp >= deal.contractEndDate, "Lease period not yet completed");

        // Recompute monthly quota for extension
        uint256 newExpierience = deal.driverExpierience + deal.contractDuration;
        uint256 newMonthlyQuota = computeMonthlyQuotaForProposal(tokenId, newExpierience, mileageCap, 12, estimatedMileage);
        deal.monthlyQuota = newMonthlyQuota;
        deal.contractEndDate += 365 days; // Extend by 1 year
    }

    function signNewLease(uint256 oldTokenId, uint256 newTokenId, uint256 newDriverExperience, uint256 newMileageCap, uint256 newContractDuration, uint256 newEstimatedMileage) public payable {
        Deal storage oldDeal = deals[oldTokenId];
        require(oldDeal.lessee == msg.sender, "Only the lessee can sign a new lease");
        require(block.timestamp >= oldDeal.contractEndDate, "Old lease period not yet completed");

        // Terminate old lease
        oldDeal.lessee = address(0);
        _transfer(owner(), ownerOf(oldTokenId), oldTokenId);

        // Register new deal
        registerDeal(newTokenId, newDriverExperience, newMileageCap, newContractDuration, newEstimatedMileage);
    }


    // Function to retrieve car details
    function getCarDetails(uint256 carId) public view returns (Car memory) {
        // Ensure the token exists by checking ownership
        require(_ownerOf(carId) != address(0), "Car does not exist");
        return cars[carId];
    }
}
