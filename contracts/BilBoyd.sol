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


    // Function to check if the car exists using ownerOf


    // Function to retrieve car details
    function getCarDetails(uint256 carId) public view returns (Car memory) {
        // Ensure the token exists by checking ownership
        require(_ownerOf(carId) != address(0), "Car does not exist");
        return cars[carId];
    }
}
