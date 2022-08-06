// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.10;

import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/// @title OutgoingNftTransferSupportV1
/// @author HashHaran
/// @notice This contract extension supports paying out NFTs to an external recipient
contract OutgoingNftTransferSupportV1 is ERC721Holder {
    /// @notice Handle an outgoing NFT transfer
    /// @param _dest The destination for the NFT transfer
    /// @param _tokenId The token id to be sent
    /// @param _tokenAddress The address of the ERC721 contract
    function _handleOutgoingNftTransfer(
        address _dest,
        uint256 _tokenId,
        address _tokenAddress
    ) internal {
        require(_tokenAddress != address(0), "ERC721 token adress(0)");
        IERC721(_tokenAddress).safeTransferFrom(address(this), _dest, _tokenId);
    }
}
