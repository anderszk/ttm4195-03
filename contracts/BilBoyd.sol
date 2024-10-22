// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

// Import all exports under a single name
import "@openzeppelin/contracts/token/ERC721/ERC721.sol" as ERC721Contract;
import "@openzeppelin/contracts/access/Ownable.sol" as OwnableContract;

contract Bilboyd_CarLeasing is ERC721Contract.ERC721, OwnableContract.Ownable {
    struct Car {
        bytes32 model; // Changed to bytes32 to limit size
        bytes32 colour; // Changed to bytes32 to limit size
        uint256 yearOfMatriculation;
        uint256 originalValue;
        uint256 currentMileage;
    }

    struct LeasingDeal {
        uint256 carTokenId;
        uint256 downPayment;
        uint256 monthlyQuota;
        uint256 leaseEndTime;
        address leasingContractor;
        uint256 driverExperienceYears;
        uint256 mileageCap;
        uint256 contractDuration;
    }

    mapping(uint256 => Car) private _carDetails; // Mapping from token ID to Car details
    mapping(uint256 => LeasingDeal) private leasingDeals; // Mapping from deal ID to Leasing Deal details
    mapping(address => uint256) private currentDeals; // Mapping from lessee address to their current deal ID

    // Adjusted constructor for ERC721 and Ownable
    constructor() 
        ERC721Contract.ERC721("BilBoydCar", "BCAR") // Pass name and symbol to ERC721 constructor
        OwnableContract.Ownable(msg.sender) // Pass the initial owner to Ownable constructor
    {}

    // Function to check if a token exists
    function _exists(uint256 tokenId) internal view returns (bool) {
        return _carDetails[tokenId].yearOfMatriculation != 0; // Check if the car details are initialized
    }

    // Function to register a new car
    function registerCar(
        uint256 tokenId,
        bytes32 model,
        bytes32 colour,
        uint256 yearOfMatriculation,
        uint256 originalValue,
        uint256 currentMileage
    ) external onlyOwner {
        require(!_exists(tokenId), "Car already registered"); // Ensure the car is not already registered
        _carDetails[tokenId] = Car(model, colour, yearOfMatriculation, originalValue, currentMileage);
        _mint(msg.sender, tokenId); // Mint the token to the owner
    }

    // Function to compute monthly quota based on parameters
    function computeMonthlyQuota(
        uint256 originalValue,
        uint256 currentMileage,
        uint256 driverExperienceYears,
        uint256 mileageCap,
        uint256 contractDuration
    ) public pure returns (uint256) {
        uint256 baseQuota = originalValue / 100; // Base quota calculation
        uint256 experienceDiscount = (driverExperienceYears > 1) ? baseQuota / 10 : 0; // Discount for experience
        uint256 adjustedQuota = baseQuota - experienceDiscount;

        if (currentMileage > mileageCap) {
            adjustedQuota += (currentMileage - mileageCap) / 100; // Adjust for mileage over the cap
        }

        adjustedQuota *= contractDuration; // Multiply by contract duration for total quota

        return adjustedQuota; // Return the calculated monthly quota
    }

    // Function to register a leasing deal
    function registerLeasingDeal(
        uint256 carTokenId,
        uint256 driverExperienceYears,
        uint256 mileageCap,
        uint256 contractDuration
    ) public payable {
        require(carExists(carTokenId), "Car does not exist"); // Ensure the car exists
        uint256 originalValue = _carDetails[carTokenId].originalValue;
        uint256 currentMileage = _carDetails[carTokenId].currentMileage;

        uint256 monthlyQuota = computeMonthlyQuota(originalValue, currentMileage, driverExperienceYears, mileageCap, contractDuration);
        uint256 dealId = uint256(keccak256(abi.encodePacked(carTokenId, msg.sender, block.number))); // Unique deal ID

        uint256 downPayment = monthlyQuota * 3; // Down payment is three times the monthly quota

        require(msg.value >= downPayment + monthlyQuota, "Insufficient payment for lease"); // Check payment

        leasingDeals[dealId] = LeasingDeal({
            carTokenId: carTokenId,
            downPayment: downPayment,
            monthlyQuota: monthlyQuota,
            leaseEndTime: block.number + (contractDuration * 30 days), // Set lease end time based on duration in days
            leasingContractor: msg.sender,
            driverExperienceYears: driverExperienceYears,
            mileageCap: mileageCap,
            contractDuration: contractDuration
        });

        currentDeals[msg.sender] = dealId; // Store the current deal for the leasing contractor
    }

    // Function to check if a car exists based on token ID
    function carExists(uint256 carTokenId) internal view returns (bool) {
    return _carDetails[carTokenId].model != bytes32(0); // Checks if the car has been registered by checking if the model is not the default value
}

    // Function to terminate the leasing contract
    function terminateContract(uint256 dealId) public {
        LeasingDeal storage deal = leasingDeals[dealId];

        require(msg.sender == deal.leasingContractor, "Only the leasing contractor can terminate the contract"); // Only the contractor can terminate
        require(block.number >= deal.leaseEndTime, "Lease is still active"); // Ensure lease is ended

        delete leasingDeals[dealId]; // Remove the leasing deal
    }

    // Function to sign lease for a new vehicle
    function signLeaseForNewVehicle(
        uint256 newCarTokenId,
        uint256 driverExperienceYears,
        uint256 mileageCap,
        uint256 contractDuration
    ) external payable {
        uint256 currentDealId = currentDeals[msg.sender]; // Get the current deal ID
        terminateContract(currentDealId); // Terminate the current contract

        // Register a new leasing deal for the new car
        registerLeasingDeal(newCarTokenId, driverExperienceYears, mileageCap, contractDuration);
    }
}
