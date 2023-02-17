// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./RentalStorage.sol";

/**
 * @dev Rental.
 */
contract Rental is Ownable , AccessControl , EIP712 , RentalStorage {

    constructor() EIP712("rental", "1"){
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(CLAIM_ROLE, _msgSender());
        feeCollector = msg.sender;
    }
    

    /**
     * @dev Transfer ownership.
     */ 
    function transferOwnership(address _newOwner) public override onlyOwner {
        require(_newOwner != address(0), "Rental: zero address");
        _transferOwnership(_newOwner);
    
        // Set the permissions.
        _grantRole(DEFAULT_ADMIN_ROLE, _newOwner);
        _grantRole(CLAIM_ROLE, _newOwner);
    
        // Revoke permissions.
        _revokeRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _revokeRole(CLAIM_ROLE, _msgSender());
    }


    /**
     * @dev Set the address of the fee collector.
     */    
    function setFeeCollector(address _feeCollector) external onlyOwner {
        emit FeeCollectorUpdated(feeCollector , feeCollector = _feeCollector , msg.sender);
    }
    

    /**
     * @dev Set the fee for rentals.
     */    
    function setFee(uint256 _fee) external onlyOwner {
        require(_fee <= 10000 , "Rental: HIGHER_THAN_10000");
        emit FeeUpdated(fee , fee = _fee , msg.sender);
    }
    

    /**
     * @dev Set the ERC20 token used by tenants to pay rent.
     */    
    function setToken(IERC20 _token) external onlyOwner {
        emit TokenUpdated(token , token = _token , msg.sender);
    }


    /**
     * @dev Receive NFT, the contract only allows safe transfers by itself made by the rent function.
     */    
    function onERC721Received(
        address operator,
        address ,
        uint256 ,
        bytes calldata
    ) external view returns (bytes4) {
        require(operator == address(this), "Rental: ONLY_ACCEPT_TRANSFERS_FROM_THIS_CONTRACT");
        return type(IERC721Receiver).interfaceId;
    }


    /**
     * @dev Accept a rental listing created by the owner of an asset.
     */   
    function acceptListing(Listing calldata _listing, address _operator, uint256 _index, uint256 _rentalDays) external {
        require(isListing(_listing) , "Rental: SIGNATURE_MISSMATCH");

        // Verify that the caller and the signer are not the same address.
        address lessor = _listing.signer;
        address tenant = _msgSender();     
        require(tenant != lessor, "Rental: CALLER_CANNOT_BE_SIGNER");
        
        // Verify that pricePerDay, maxDays and minDays have the same length.
        require(_listing.pricePerDay.length == _listing.maxDays.length, "Rental:  MAX_DAYS_LENGTH_MISSMATCH");
        require(_listing.pricePerDay.length == _listing.minDays.length, "Rental:  MIN_DAYS_LENGTH_MISSMATCH");

        // Verify that the provided index is not out of bounds of the listing conditions.
        require(_index < _listing.pricePerDay.length, "Rental: INDEX_OUT_OF_BOUNDS");

        // Verify that the listing is not already expired.
        require(_listing.expiration > block.timestamp, "Rental: EXPIRED_SIGNATURE");

        // Verify that minDays and maxDays have valid values.
        require(_listing.minDays[_index] <= _listing.maxDays[_index], "Rental: MAX_DAYS_LOWER_THAN_MIN_DAYS");
        require(_listing.minDays[_index] > 0, "Rental: MIN_DAYS_IS_ZERO");

        // Verify that the provided rental days is between min and max days range.
        require(_rentalDays >= _listing.minDays[_index] && _rentalDays <= _listing.maxDays[_index], "Rental: DAYS_NOT_IN_RANGE");
 
        _rent(lessor, tenant, _listing.contractAddress, _listing.tokenId, _listing.pricePerDay[_index], _rentalDays, _operator);
    }


    /**
     * @dev Verify that the signer provided in the listing is the one that signed it.
     */    
    function isListing(Listing calldata voucher) public view returns (bool) {
        bytes32 _hash = _hashTypedDataV4(keccak256(abi.encode(
                    LISTING_TYPE_HASH,
                    voucher.signer,
                    voucher.contractAddress,
                    voucher.tokenId,
                    voucher.expiration,
                    voucher.nonce,
                    keccak256(abi.encodePacked(voucher.pricePerDay)),
                    keccak256(abi.encodePacked(voucher.minDays)),
                    keccak256(abi.encodePacked(voucher.maxDays))
                )));

        return ECDSA.recover(_hash, voucher.signature) == voucher.signer;
    }


    /**
     * @dev Accept an offer for rent of an asset owned by the caller.
     */    
    function acceptOffer(Offer calldata _offer) external {
        require(isOffer(_offer), "Rental: SIGNATURE_MISSMATCH");

        // Verify that the caller and the signer are not the same address.
        address lessor = _msgSender();
        address tenant = _offer.signer;
        require(lessor != tenant, "Rental: CALLER_CANNOT_BE_SIGNER");

        // Verify that the offer is not already expired.
        require(_offer.expiration > block.timestamp, "Rental: EXPIRED_SIGNATURE");

        // Verify that the rental days provided in the offer are valid.
        require(_offer.rentalDays > 0, "Rental: RENTAL_DAYS_IS_ZERO");

        _rent(lessor, tenant, _offer.contractAddress, _offer.tokenId, _offer.pricePerDay, _offer.rentalDays, _offer.operator);
    }


    /**
     * @dev Verify that the signer provided in the offer is the one that signed it.
     */    
    function isOffer(Offer calldata voucher) public view returns (bool) {
        bytes32 _hash = _hashTypedDataV4(keccak256(abi.encode(
                    OFFER_TYPE_HASH,
                    voucher.signer,
                    voucher.contractAddress,
                    voucher.tokenId,
                    voucher.expiration,
                    voucher.nonce,
                    voucher.pricePerDay,
                    voucher.rentalDays,
                    voucher.operator
                )));

        return ECDSA.recover(_hash, voucher.signature) == voucher.signer;
    }


    function _rent(
        address _lessor,
        address _tenant,
        address _contractAddress,
        uint256 _tokenId,
        uint256 _pricePerDay,
        uint256 _rentalDays,
        address _operator
    ) private {

        // Verify that the asset is not already rented.
        require(!isRented(_contractAddress, _tokenId), "Rental: CURRENTLY_RENTED");

        IERC721Operable asset = IERC721Operable(_contractAddress);
        Rental storage rental = rentals[_contractAddress][_tokenId];
        address tokenOwner = asset.ownerOf(_tokenId);

        // Verify that the owner of the asset is _lessor.
        if(tokenOwner == address(this)){
            require(rental.lessor == _lessor , "Rental: NOT_ORIGINAL_OWNER");
        }else{
            require(tokenOwner == _lessor , "Rental: The owner of the token is not the Lessor");    
        }

        // Pay ERC20 token.
        if (_pricePerDay > 0) {
            _handleTokenTransfers(_lessor, _tenant, _pricePerDay, _rentalDays);
        }

        if(tokenOwner != address(this)){
            asset.safeTransferFrom(_lessor, address(this), _tokenId);
        }


        rental.lessor = _lessor;
        rental.tenant = _tenant;
        rental.endDate = block.timestamp + _rentalDays * (1 days);

        asset.setUpdateOperator(_tokenId, _operator);

        emit RentalStarted(_contractAddress, _tokenId, _lessor, _tenant, _operator, _rentalDays, _pricePerDay, _msgSender());
    }


    /**
     * @dev Whether the asset is being rented.
     */    
    function isRented(address _contractAddress, uint256 _tokenId) public view returns (bool) {
        return block.timestamp <= rentals[_contractAddress][_tokenId].endDate;
    }


    /**
     * @dev Transfer the erc20 tokens required to start a rent from the tenant to the lessor and the fee collector.
     */    
    function _handleTokenTransfers(address _lessor, address _tenant, uint256 _pricePerDay, uint256 _rentalDays) private {
        uint256 totalPrice = _pricePerDay * _rentalDays;
        uint256 forCollector = (totalPrice * fee) / 10000;

        // transfer the ERC20 tokens to the lessor.
        token.transferFrom(_tenant, _lessor, totalPrice - forCollector);

        // transfer the erc20 tokens to the fee collector.
        token.transferFrom(_tenant, feeCollector, forCollector);
    }


    /**
     * @dev Set the operator of a tokenId.
     */    
    function setOperator(address _contractAddress, uint256 _tokenId, address _operator) external {
        IERC721Operable asset = IERC721Operable(_contractAddress);
        Rental memory rental = rentals[_contractAddress][_tokenId];
        bool rented = isRented(_contractAddress, _tokenId);

        // If rented, only the tenant can change the operator, Otherwise only the original owner can.
        bool canSetOperator = (rented && rental.tenant == msg.sender) || (!rented && rental.lessor == msg.sender);
        require(canSetOperator, "Rental: CANNOT_UPDATE_OPERATOR");

        // Update the operator. 
        asset.setUpdateOperator(_tokenId, _operator);

        emit OperatorUpdated(_contractAddress, _tokenId, _operator , msg.sender);
    }


    /**
     * @dev Claim asset.
     */    
    function claim(address _contractAddress , uint256 _tokenId) external {
        // Verify that the rent has finished.
        require(!isRented(_contractAddress , _tokenId) , "Rental: CURRENTLY_RENTED");

        bool isLessor = rentals[_contractAddress][_tokenId].lessor == msg.sender;
        bool hasRole = hasRole(CLAIM_ROLE, msg.sender);
        
        require(isLessor || hasRole , "Rental: Caller unauthorized");

        delete rentals[_contractAddress][_tokenId];

        IERC721Operable asset = IERC721Operable(_contractAddress);
        asset.safeTransferFrom(address(this) , msg.sender , _tokenId);

        emit AssetClaimed(_contractAddress , _tokenId , msg.sender);
    }


    function _isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }

}
