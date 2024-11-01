// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.2 < 0.9.0;

contract CarLeasingNFT {
    // Event declarations as per ERC721 standard
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    // Mappings
    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;


    // Token name and symbol and counter
    string private tokenName;
    string private tokenSymbol;
    uint256 private tokenIdCount;

    // Car struct
    struct Car {
        string model;
        string color;
        uint256 registrationYear;
        uint256 originalValue;
        uint256 currentMileage;
    }

    // Mapping from token ID to Car details
    mapping(uint256 => Car) private _carDetails;

    // Contract owner
    address private _owner;

    // Modifier to restrict functions to contract owner
    modifier onlyOwner() {
        require(msg.sender == _owner, "Caller is not the contract owner");
        _;
    }

    constructor() {
        tokenName = "BilBoydCar";
        tokenSymbol = "BBC";
        _owner = msg.sender;
    }

    /// @notice Public function to check if a token exists
    /// @return true if exists, else dfalse
    function exists(uint256 tokenId) public view returns (bool) {
        return _owners[tokenId] != address(0);
    }

    /// @notice Function to get the token name
    /// @return the token name
    function name() public view returns (string memory) {return tokenName;}

    /// @notice Function to get the token symbol
    /// @return the token symbol
    function symbol() public view returns (string memory) {return tokenSymbol;}

    /// @notice Function to get the balance of a given address
    /// @param ownerAddress - The address to be checked
    /// @return balance of the address
    function balanceOf(address ownerAddress) public view returns (uint256) {
        require(ownerAddress != address(0), "Invalid address");
        return _balances[ownerAddress];
    }

    /// @notice Function to get the owner of a token ID
    /// @param tokenId - The token ID the address is to be found
    /// @return ownerAddres of the given input
    function ownerOf(uint256 tokenId) public view returns (address) {
        address ownerAddress = _owners[tokenId];
        require(ownerAddress != address(0), "Token ID does not exist");
        return ownerAddress;
    }

    /// @notice Mint a new car NFT (only callable by the contract owner)
    /// @param to - The address th car is to be minted
    /// @param model - The car model
    /// @param color - The color of the car
    /// @param registrationYear - The year the car was registrered
    /// @param originalValue - The original car value at production
    /// @param currentMileage - The current milage of the car
    /// @return A quota calculated from the input params
    function mintCar(
        address to,
        string memory model,
        string memory color,
        uint256 registrationYear,
        uint256 originalValue,
        uint256 currentMileage
    ) public onlyOwner returns (uint256) {
        require(to != address(0), "Mint to zero address");

        tokenIdCount += 1;
        uint256 newCarId = tokenIdCount;

        _balances[to] += 1;
        _owners[newCarId] = to;

        _carDetails[newCarId] = Car({
            model: model,
            color: color,
            registrationYear: registrationYear,
            originalValue: originalValue,
            currentMileage: currentMileage
        });

        emit Transfer(address(0), to, newCarId);

        return newCarId;
    }


    /// @notice Gets cardetails from a tokenID
    /// @param tokenId - The token ID the car details are to be fetched from
    function getCarDetails(uint256 tokenId) public view returns (
        string memory model,
        string memory color,
        uint256 registrationYear,
        uint256 originalValue,
        uint256 currentMileage
    ) {
        require(exists(tokenId), "Token ID does not exist");
        Car memory car = _carDetails[tokenId];
        return (
            car.model,
            car.color,
            car.registrationYear,
            car.originalValue,
            car.currentMileage
        );
    }

    /// @notice Calculates baseQuota equalling to 2% of original car value 
    /// @param driverExperienceYears - the years of driving experience of the leaser in years
    /// @param mileageCap - the milage cap specified in the contract 
    /// @param contractDurationMonths - the duration of the contract in months
    /// @return A quota calculated from the input params
    function computeMonthlyQuota(
        uint256 tokenId,
        uint256 driverExperienceYears,
        uint256 mileageCap,
        uint256 contractDurationMonths
    ) public view returns (uint256) {
        require(exists(tokenId), "Token ID does not exist");

        Car memory car = _carDetails[tokenId];

        /// @notice Calculates baseQuota equalling to 2% of original car value
        uint256 baseQuota = car.originalValue / 50; 

        // Additional cost based on current mileage vs. mileage cap
        uint256 mileageCost = 0;
        if (car.currentMileage > mileageCap) {
            mileageCost = (car.currentMileage - mileageCap) * 10; // Example overage fee per mile
        }

        /// @notice Calculate discount given - 2% for each year of drivers experience
        uint256 experienceDiscount = (driverExperienceYears * baseQuota) / 50; // 2% discount per year

        /// @notice Calculating the discount based on how many years (or months) the contract is
        uint256 durationDiscount = 0;
        if (contractDurationMonths >= 36) {
            durationDiscount = (baseQuota * 10) / 100; // 10% discount for contracts >= 3 years
        } else if (contractDurationMonths >= 24) {
            durationDiscount = (baseQuota * 5) / 100; // 5% discount for contracts >= 2 years
        } else if (contractDurationMonths >= 12) {
            durationDiscount = (baseQuota * 3) / 100; // 3% discount for contracts >= 1 year
        }

        /// @notice Calculates and returns the monthly quota based on the calculations above
        uint256 monthlyQuota = baseQuota + mileageCost - experienceDiscount - durationDiscount;
        return monthlyQuota;
    }
}
