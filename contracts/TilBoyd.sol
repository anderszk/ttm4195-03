// SPDX-Licence-Identifier: GPL-3.0

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

    mapping{uint256 => Car} private carDetails;

    constructor() ERC721("BillyBoyCar", "BSAR") Ownable(msg.sender) {}
}



