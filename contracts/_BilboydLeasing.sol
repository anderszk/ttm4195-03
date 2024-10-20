// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract BilBoydCarLeasing is ERC721, Ownable {

    struct Car {
        string model;
        string color;
        uint16 yearOfMatriculation;
        uint256 originalValue;
    }

    mapping(uint256 => Car) public cars;

    constructor() ERC721("BilBoydCar", "BBC") Ownable(msg.sender) {}

}