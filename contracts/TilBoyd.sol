// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Bilboyd_CarLeasing is ERC721, Ownable {

    struct Car {
        string model;
        string color;
        uint256 yearOfMatriculation;
        uint256 originalValue;
    }

    mapping(uint256 => Car) private carDetails;

    constructor() ERC721("BillyBoyCar", "BSAR") Ownable(msg.sender) {}

    function calculateMonthlyQuota(
        uint256 carId,
        uint256 currentMileage,
        uint256 driverExperienceYears,  // years of possession of a driving license, which affects the insurance cost
        uint256 mileageCap,
        uint256 contractDuration
    ) public view returns (uint256) {
        Car memory car = carDetails[carId];

        // Base quota calculation based on original value and contract duration
        uint256 baseQuota = car.originalValue / (10 + contractDuration);

        // Mileage factor - adding a penalty if current mileage exceeds the cap
        uint256 mileagePenalty = (currentMileage > mileageCap) ? 
            (currentMileage - mileageCap) / 10 : 0;

        // Experience discount - a small discount for experienced drivers
        uint256 experienceDiscount = (driverExperienceYears > 5) ? 10 : 0;

        // Final monthly quota calculation
        uint256 monthlyQuota = baseQuota + mileagePenalty - experienceDiscount;

        return monthlyQuota;
    }

    // struct for deal
    struct Deal {
        address driver;
        uint256 carId;
        uint256 amountLocked;
        bool isConfirmed;
    }

    mapping(uint256 => Deal) public deals;
    uint256 public nextDealId;

    function registerDeal(uint256 carId, uint256 monthlyQuota) public payable {
        require(carDetails[carId].originalValue > 0, "Car does not exist");
        require(msg.value == monthlyQuota * 4, "Incorrect payment amount"); // Ensures the driver sends the exact payment required (3 monthly quotas as a down payment + 1 monthly quota).

        deals[nextDealId] = Deal({
            driver: msg.sender,  // corrected from diver to driver
            carId: carId,
            amountLocked: msg.value,  // corrected from ammountLocked to amountLocked
            isConfirmed: false  // corrected from isconfirmed to isConfirmed
        });
        nextDealId++;
    }

    function confirmDeal(uint256 dealId) public {
        // Manually check if the caller is the owner
        require(msg.sender == owner(), "Caller is not the owner");
        
        Deal storage deal = deals[dealId];
        require(deal.driver != address(0), "Deal does not exist");
        require(!deal.isConfirmed, "Deal already confirmed");

        deal.isConfirmed = true;

        // Transfer the locked funds to BilBoyd
        payable(owner()).transfer(deal.amountLocked);
    }
}
