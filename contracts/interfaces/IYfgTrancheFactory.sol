// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "../InterestToken.sol";
import "../libraries/DateString.sol";

/**
 * @title ITrancheFactory
 * @author
 * @notice Removed InterestToken and added donationAddress
 */
interface IYfgTrancheFactory {
    function getData()
        external
        returns (
            address,
            uint256,
            address, // yfg added this line for donationAddress
            address
        );
}
