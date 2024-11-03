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

    // Function to check if the car exists using ownerOf


    // Function to retrieve car details
    function getCarDetails(uint256 carId) public view returns (Car memory) {
        // Ensure the token exists by checking ownership
        require(_ownerOf(carId) != address(0), "Car does not exist");
        return cars[carId];
    }
}
