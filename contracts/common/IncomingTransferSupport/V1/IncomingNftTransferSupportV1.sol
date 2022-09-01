// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.10;

import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ERC721TransferHelper} from "../../../transferHelpers/ERC721TransferHelper.sol";

/// @title IncomingNftTransferSupportV1
/// @author HashHaran
/// @notice This contract extension supports receiving NFTs from an external user
contract IncomingNftTransferSupportV1 is ERC721Holder {
    /// @notice The ZORA ERC-721 Transfer Helper
    ERC721TransferHelper public immutable erc721TransferHelper;

    constructor(address _erc721TransferHelper) {
        erc721TransferHelper = ERC721TransferHelper(_erc721TransferHelper);
    }

    /// @notice Handle an incoming NFT transfer, the user should have approved the module conract to transfer the NFT on their behalf
    /// @param _tokenId The token id of the NFT in it's ERC721 contract
    /// @param _tokenAddress The address of the ERC721 contract
    function _handleIncomingNftTransfer(uint256 _tokenId, address _tokenAddress) internal {
        require(_tokenAddress != address(0), "ERC721 token adress(0)");
        erc721TransferHelper.safeTransferFrom(_tokenAddress, msg.sender, address(this), _tokenId);
    }
}
