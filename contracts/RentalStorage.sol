// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @dev Operable.
 */
interface IERC721Operable is IERC721 {
    function setUpdateOperator(uint256, address) external;
}


/**
 * @dev Rental storage.
 */
contract RentalStorage {

    // An advertisement for a lessor, EIP712 type hashes for recovering the signer from a signature.
    bytes32 internal constant LISTING_TYPE_HASH = keccak256("Listing(address signer,address contractAddress,uint256 tokenId,uint256 expiration,uint256 nonce,uint256[] pricePerDay,uint256[] minDays,uint256[] maxDays)");

    // The offer from the tenant.
    bytes32 internal constant OFFER_TYPE_HASH =keccak256("Offer(address signer,address contractAddress,uint256 tokenId,uint256 expiration,uint256 nonce,uint256 pricePerDay,uint256 rentalDays,address operator)");

    // Claim role.
    bytes32 public constant CLAIM_ROLE = keccak256("CLAIM_ROLE");

    // ERC20 token used to pay for rent and fees.
    IERC20 public token;

    // Address that will receive ERC20 tokens collected as rental fees.
    address public feeCollector;

    // Rate, 100% equal 10000.
    uint256 public fee;

    // The struct of rental information.
    struct Rental {
        address lessor;
        address tenant;
        uint256 endDate;
    }

    // Mapping from nft to rental, schema(contract address -> token id -> rental information).
    mapping(address => mapping(uint256 => Rental)) public rentals;

    /**
     * Struct received as a parameter in `acceptListing` containing all information about
     * listing conditions and values required to verify the signature was created by the signer.
     */    
    struct Listing {
        address signer;
        address contractAddress;
        uint256 tokenId;
        uint256 expiration;
        uint256 nonce;
        uint256[] pricePerDay;
        uint256[] minDays;
        uint256[] maxDays;
        bytes signature;
    }

    /**
     * Struct received as a parameter in `acceptOffer` containing all information about
     * offer conditions and values required to verify the signature was created by the signer.
     */
    struct Offer {
        address signer;
        address contractAddress;
        uint256 tokenId;
        uint256 expiration;
        uint256 nonce;
        uint256 pricePerDay;
        uint256 rentalDays;
        address operator;
        bytes signature;
    }

    /**
     * @dev Emitted when set the feeCollector.
     */    
    event FeeCollectorUpdated(address _from, address _to, address _sender);
    
    /**
     * @dev Emitted when set the fee.
     */    
    event FeeUpdated(uint256 _from, uint256 _to, address _sender);

    /**
     * @dev Emitted when set the token.
     */    
    event TokenUpdated(IERC20 _from, IERC20 _to, address _sender);
      
    event AssetClaimed(address _contractAddress, uint256 _tokenId, address _sender);
    
    event OperatorUpdated(address _contractAddress, uint256 _tokenId, address _to, address _sender);
    
    event RentalStarted(
        address _contractAddress,
        uint256 _tokenId,
        address _lessor,
        address _tenant,
        address _operator,
        uint256 _rentalDays,
        uint256 _pricePerDay,
        address _sender
    );


    
}
