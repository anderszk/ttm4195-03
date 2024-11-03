// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Import OpenZeppelin libraries
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract CarLeaseNFT is ERC721, Ownable, ReentrancyGuard {
    // Lease deal structure
    struct LeaseDeal {
        address lessee;
        uint256 downPayment;
        uint256 monthlyQuota;
        uint256 totalAmountDeposited;
        bool lesseeRegistered;
        bool lesseeConfirmed;
        bool bilBoydConfirmed;
        bool fundsReleased;
    }

    // Mapping from lease ID to LeaseDeal
    mapping(uint256 => LeaseDeal) public leaseDeals;

    // Constructor to initialize the NFT with a name and symbol
    constructor() ERC721("CarLeaseNFT", "CLNFT") {}

    /**
     * @dev Lessee registers a deal by depositing the down payment and first monthly quota.
     * The funds are locked in the contract until both parties confirm the deal.
     * @param leaseId Unique identifier for the lease NFT.
     * @param downPayment Amount required as a down payment.
     * @param monthlyQuota Amount of the monthly payment.
     */
    function registerDeal(
        uint256 leaseId,
        uint256 downPayment,
        uint256 monthlyQuota
    ) external payable {
        require(
            msg.value == downPayment + monthlyQuota,
            "Incorrect payment amount"
        );
        require(
            leaseDeals[leaseId].lessee == address(0),
            "Lease ID already registered"
        );

        // Store the lease deal details
        leaseDeals[leaseId] = LeaseDeal({
            lessee: msg.sender,
            downPayment: downPayment,
            monthlyQuota: monthlyQuota,
            totalAmountDeposited: msg.value,
            lesseeRegistered: true,
            lesseeConfirmed: false,
            bilBoydConfirmed: false,
            fundsReleased: false
        });
    }

    /**
     * @dev Lessee confirms the deal.
     * @param leaseId Unique identifier for the lease NFT.
     */
    function lesseeConfirm(uint256 leaseId) external {
        LeaseDeal storage deal = leaseDeals[leaseId];
        require(deal.lesseeRegistered, "Deal not registered");
        require(msg.sender == deal.lessee, "Only lessee can confirm");
        require(!deal.lesseeConfirmed, "Lessee already confirmed");

        deal.lesseeConfirmed = true;

        // If both parties have confirmed, finalize the deal
        if (deal.bilBoydConfirmed) {
            _finalizeDeal(leaseId);
        }
    }

    /**
     * @dev BilBoyd confirms the deal.
     * @param leaseId Unique identifier for the lease NFT.
     */
    function bilBoydConfirm(uint256 leaseId) external onlyOwner {
        LeaseDeal storage deal = leaseDeals[leaseId];
        require(deal.lesseeRegistered, "Deal not registered");
        require(!deal.bilBoydConfirmed, "BilBoyd already confirmed");

        deal.bilBoydConfirmed = true;

        // If both parties have confirmed, finalize the deal
        if (deal.lesseeConfirmed) {
            _finalizeDeal(leaseId);
        }
    }

    /**
     * @dev Finalizes the deal by transferring funds and minting the NFT.
     * Internal function to prevent external calls.
     * @param leaseId Unique identifier for the lease NFT.
     */
    function _finalizeDeal(uint256 leaseId) internal nonReentrant {
        LeaseDeal storage deal = leaseDeals[leaseId];
        require(deal.lesseeConfirmed, "Lessee has not confirmed");
        require(deal.bilBoydConfirmed, "BilBoyd has not confirmed");
        require(!deal.fundsReleased, "Funds already released");

        deal.fundsReleased = true;

        // Mint the lease NFT to the lessee
        _mint(deal.lessee, leaseId);

        // Release funds to BilBoyd
        (bool success, ) = owner().call{value: deal.totalAmountDeposited}("");
        require(success, "Transfer to BilBoyd failed");
    }

    /**
     * @dev Lessee can cancel the deal and withdraw funds if BilBoyd has not confirmed yet.
     * @param leaseId Unique identifier for the lease NFT.
     */
    function cancelDeal(uint256 leaseId) external nonReentrant {
        LeaseDeal storage deal = leaseDeals[leaseId];
        require(deal.lesseeRegistered, "Deal not registered");
        require(msg.sender == deal.lessee, "Only lessee can cancel");
        require(!deal.bilBoydConfirmed, "Cannot cancel after BilBoyd confirms");
        require(!deal.fundsReleased, "Funds already released");

        uint256 refundAmount = deal.totalAmountDeposited;

        // Delete the deal
        delete leaseDeals[leaseId];

        // Refund the lessee
        (bool success, ) = payable(msg.sender).call{value: refundAmount}("");
        require(success, "Refund failed");
    }
}
