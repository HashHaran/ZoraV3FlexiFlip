// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.10;

/// @title UniversalExchangeEvent V1
/// @author HashHaran
/// @notice This module generalizes indexing token exchanges across all of V3
contract UniversalFlexiBarterExchangeEventV1 {
    /// @notice The metadata of a token exchange
    /// @param currencyTokenContract The address of the currency token contract
    /// @param nftTokenContract The address of the NFT token contract
    /// @param tokenId The id of the token
    /// @param amount The number of tokens sent
    struct FlexiBarterExchangeDetails {
        address currencyTokenContract;
        address nftTokenContract;
        uint256 tokenId;
        uint256 amount;
    }

    /// @notice Emitted when a token exchange is executed
    /// @param userA The address of user A
    /// @param userB The address of a user B
    /// @param a The metadata of user A's exchange
    /// @param b The metadata of user B's exchange
    event FlexiBarterExchangeExecuted(address indexed userA, address indexed userB, FlexiBarterExchangeDetails a, FlexiBarterExchangeDetails b);
}
