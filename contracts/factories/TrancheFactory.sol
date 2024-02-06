// SPDX-License-Identifier: Apache-2.0

import "../Tranche.sol";
import "../interfaces/IWrappedPosition.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IInterestTokenFactory.sol";
import "../interfaces/IInterestToken.sol";

pragma solidity ^0.8.0;

/// @author Element Finance
/// @title Tranche Factory
contract TrancheFactory {
    /// @dev An event to track tranche creations
    /// @param trancheAddress the address of the tranche contract
    /// @param wpAddress the address of the wrapped position
    /// @param expiration the expiration time of the tranche
    event TrancheCreated(
        address indexed trancheAddress,
        uint256 indexed expiration,
        address indexed donationAddress, // YFG added this parameter
        address wpAddress // YFG removed `indexed` as there can only be three indexed parameters
    );

    IInterestTokenFactory internal immutable _interestTokenFactory;
    address internal _tempWpAddress;
    uint256 internal _tempExpiration;
    address internal _tempDonationAddress; // YFG added this line
    IInterestToken internal _tempInterestToken;
    bytes32 public constant TRANCHE_CREATION_HASH =
        keccak256(type(Tranche).creationCode);
    // The address of our date library
    address internal immutable _dateLibrary;

    /// @notice Create a new Tranche.
    /// @param _factory Address of the interest token factory.
    constructor(address _factory, address dateLibrary) {
        _interestTokenFactory = IInterestTokenFactory(_factory);
        _dateLibrary = dateLibrary;
    }

    /// @notice Deploy a new Tranche contract.
    /// @param _expiration The expiration timestamp for the tranche.
    /// @param _wpAddress Address of the Wrapped Position contract the tranche will use.
    /// @param _donationAddress The address of the organization to donate yield to
    /// @return The deployed Tranche contract.
    // YFG - added donation address as a parameter and are using it in the salt calculation for create2
    function deployTranche(
        uint256 _expiration,
        address _wpAddress,
        address _donationAddress //added donation address as a parameter
    ) public returns (Tranche) {
        _tempWpAddress = _wpAddress;
        _tempExpiration = _expiration;
        _tempDonationAddress = _donationAddress; // YFG - added this line

        IWrappedPosition wpContract = IWrappedPosition(_wpAddress);
        // YFG - added the donation address to the salt calc. Create2 should now create unique addresses for each tranche
        // based on the vault, expiration, and donation address
        bytes32 salt = keccak256(
            abi.encodePacked(_wpAddress, _expiration, _donationAddress) // YFG - added donation address
        );
        string memory wpSymbol = wpContract.symbol();
        IERC20 underlying = wpContract.token();
        uint8 underlyingDecimals = underlying.decimals();

        // derive the expected tranche address
        address predictedAddress = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            address(this),
                            salt,
                            TRANCHE_CREATION_HASH
                        )
                    )
                )
            )
        );

        _tempInterestToken = _interestTokenFactory.deployInterestToken(
            predictedAddress,
            wpSymbol,
            _expiration,
            underlyingDecimals
        );

        Tranche tranche = new Tranche{ salt: salt }();
        emit TrancheCreated(
            address(tranche),
            _expiration,
            _donationAddress,
            _wpAddress
        );
        require(
            address(tranche) == predictedAddress,
            "CREATE2 address mismatch"
        );

        // set back to 0-value for some gas savings
        delete _tempWpAddress;
        delete _tempExpiration;
        delete _tempInterestToken;
        delete _tempDonationAddress; // YFG - added this line

        return tranche;
    }

    /// @notice Callback function called by the Tranche.
    /// @dev This is called by the Tranche contract constructor.
    /// The return data is used for Tranche initialization. Using this, the Tranche avoids
    /// constructor arguments which can make the Tranche bytecode needed for create2 address
    /// derivation non-constant.
    /// @return Wrapped Position contract address, expiration timestamp, interest token contract, and donation address
    function getData()
        external
        view
        returns (
            address,
            uint256,
            IInterestToken,
            address,
            address
        )
    {
        return (
            _tempWpAddress,
            _tempExpiration,
            _tempInterestToken,
            _tempDonationAddress, // YFG - added this line
            _dateLibrary
        );
    }
}
