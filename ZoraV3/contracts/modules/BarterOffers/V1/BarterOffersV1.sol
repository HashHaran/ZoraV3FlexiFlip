// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.10;

/// ------------ IMPORTS ------------

import {ReentrancyGuard} from "@rari-capital/solmate/src/utils/ReentrancyGuard.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC721TransferHelper} from "../../../transferHelpers/ERC721TransferHelper.sol";
import {UniversalExchangeEventV1} from "../../../common/UniversalExchangeEvent/V1/UniversalExchangeEventV1.sol";
import {IncomingTransferSupportV1} from "../../../common/IncomingTransferSupport/V1/IncomingTransferSupportV1.sol";
import {FeePayoutSupportV1} from "../../../common/FeePayoutSupport/FeePayoutSupportV1.sol";
import {IncomingNftTransferSupportV1} from "../../../common/IncomingTransferSupport/V1/IncomingNftTransferSupportV1.sol";
import {OutgoingNftTransferSupportV1} from "../../../common/OutgoingTransferSupport/V1/OutgoingNftTransferSupportV1.sol";
import {ModuleNamingSupportV1} from "../../../common/ModuleNamingSupport/ModuleNamingSupportV1.sol";

/// @title Offers V1
/// @author kulkarohan <rohan@zora.co>
/// @notice This module allows users to make ETH/ERC-20 offers for any ERC-721 token
contract BarterOffersV1 is
    ReentrancyGuard,
    UniversalExchangeEventV1,
    IncomingTransferSupportV1,
    FeePayoutSupportV1,
    IncomingNftTransferSupportV1,
    OutgoingNftTransferSupportV1,
    ModuleNamingSupportV1
{
    /// @dev The indicator to pass all remaining gas when paying out royalties
    uint256 private constant USE_ALL_GAS_FLAG = 0;

    /// @dev All methods are reentrant locked, an adversary can deploy arbitrary number of ERC20 tokens and make the for loop go on and on causing Denial of Service attack
    uint8 private constant MAX_NUMBER_OF_TOKENS = 5;

    modifier noMoreThanMaxTokens(address[] memory tokenAddresses) {
        require(tokenAddresses.length <= MAX_NUMBER_OF_TOKENS, "Offer made on more tokens than allowed");
        _;
    }

    /// @notice The total number of offers made
    uint256 public offerCount;

    struct TokenOffer {
        bool isPresent;
        bool isNft;
        uint256 tokenId;
        uint256 amount;
        address tokenAddress;
    }

    /// @notice The metadata of an offer
    /// @param maker The address of the user who made the offer
    /// @param tokenAddresses The addresses of the ERC-721s and ERC-20s offered. address(0) for ETH offered
    /// @param tokenIds The token ids of the ERC-721 token ids offered. 0 for ETH and other ERC-20s
    /// @param findersFeeBps The fee to the referrer of the offer
    /// @param amounts The amounts of ERC-721/ETH/ERC-20 tokens offered
    struct Offer {
        address maker;
        address[] tokenAddresses;
        uint16 findersFeeBps;
    }

    /// ------------ STORAGE ------------

    /// @notice The metadata for a given offer
    /// @dev ERC-721 token address => ERC-721 token ID => Offer ID => Offer
    mapping(address => mapping(uint256 => mapping(uint256 => Offer))) public offers;

    mapping(uint256 => mapping(address => TokenOffer)) offerTokenOfferMap;

    /// @notice The offers for a given NFT
    /// @dev ERC-721 token address => ERC-721 token ID => Offer IDs
    mapping(address => mapping(uint256 => uint256[])) public offersForNFT;

    /// ------------ EVENTS ------------

    /// @notice Emitted when an offer is created
    /// @param tokenContract The ERC-721 token address of the created offer
    /// @param tokenId The ERC-721 token ID of the created offer
    /// @param id The ID of the created offer
    /// @param offer The metadata of the created offer
    event BarterOfferCreated(address indexed tokenContract, uint256 indexed tokenId, uint256 indexed id, Offer offer);

    /// @notice Emitted when an offer is updated
    /// @param tokenContract The ERC-721 token address of the updated offer
    /// @param tokenId The ERC-721 token ID of the updated offer
    /// @param id The ID of the updated offer
    /// @param offer The metadata of the updated offer
    event BarterOfferUpdated(address indexed tokenContract, uint256 indexed tokenId, uint256 indexed id, Offer offer);

    /// @notice Emitted when an offer is canceled
    /// @param tokenContract The ERC-721 token address of the canceled offer
    /// @param tokenId The ERC-721 token ID of the canceled offer
    /// @param id The ID of the canceled offer
    /// @param offer The metadata of the canceled offer
    event BarterOfferCanceled(address indexed tokenContract, uint256 indexed tokenId, uint256 indexed id, Offer offer);

    /// @notice Emitted when an offer is filled
    /// @param tokenContract The ERC-721 token address of the filled offer
    /// @param tokenId The ERC-721 token ID of the filled offer
    /// @param id The ID of the filled offer
    /// @param taker The address of the taker who filled the offer
    /// @param finder The address of the finder who referred the offer
    /// @param offer The metadata of the filled offer
    event BarterOfferFilled(address indexed tokenContract, uint256 indexed tokenId, uint256 indexed id, address taker, address finder, Offer offer);

    /// ------------ CONSTRUCTOR ------------

    /// @param _erc20TransferHelper The ZORA ERC-20 Transfer Helper address
    /// @param _erc721TransferHelper The ZORA ERC-721 Transfer Helper address
    /// @param _royaltyEngine The Manifold Royalty Engine address
    /// @param _protocolFeeSettings The ZoraProtocolFeeSettingsV1 address
    /// @param _wethAddress The WETH token address
    constructor(
        address _erc20TransferHelper,
        address _erc721TransferHelper,
        address _royaltyEngine,
        address _protocolFeeSettings,
        address _wethAddress
    )
        IncomingTransferSupportV1(_erc20TransferHelper)
        FeePayoutSupportV1(_royaltyEngine, _protocolFeeSettings, _wethAddress, ERC721TransferHelper(_erc721TransferHelper).ZMM().registrar())
        IncomingNftTransferSupportV1(_erc721TransferHelper)
        OutgoingNftTransferSupportV1()
        ModuleNamingSupportV1("BarterOffers: v1.0")
    {}

    /// ------------ MAKER FUNCTIONS ------------

    //     ,-.
    //     `-'
    //     /|\
    //      |             ,--------.               ,-------------------.
    //     / \            |OffersV1|               |ERC20TransferHelper|
    //   Caller           `---+----'               `---------+---------'
    //     |   createOffer()  |                              |
    //     | ----------------->                              |
    //     |                  |                              |
    //     |                  |        transferFrom()        |
    //     |                  | ----------------------------->
    //     |                  |                              |
    //     |                  |                              |----.
    //     |                  |                              |    | transfer tokens into escrow
    //     |                  |                              |<---'
    //     |                  |                              |
    //     |                  |----.                         |
    //     |                  |    | ++offerCount            |
    //     |                  |<---'                         |
    //     |                  |                              |
    //     |                  |----.                         |
    //     |                  |    | create offer            |
    //     |                  |<---'                         |
    //     |                  |                              |
    //     |                  |----.
    //     |                  |    | offersFor[NFT].append(id)
    //     |                  |<---'
    //     |                  |                              |
    //     |                  |----.                         |
    //     |                  |    | emit OfferCreated()     |
    //     |                  |<---'                         |
    //     |                  |                              |
    //     |        id        |                              |
    //     | <-----------------                              |
    //   Caller           ,---+----.               ,---------+---------.
    //     ,-.            |OffersV1|               |ERC20TransferHelper|
    //     `-'            `--------'               `-------------------'
    //     /|\
    //      |
    //     / \
    /// @notice Creates an offer for an NFT
    /// @param _targetTokenContract The address of the desired ERC-721 token
    /// @param _targetTokenId The ID of the desired ERC-721 token
    /// @param _offerTokenAddresses The addresses of the ERC-721, ERC-20 token offering, or address(0) for ETH
    /// @param _isNfts True if the
    /// @param _offerTokenIds The amount offering
    /// @param _amounts The amount offering
    /// @param _findersFeeBps The bps of the amount (post-royalties) to send to a referrer of the sale
    /// @return The ID of the created offer
    function createOffer(
        address _targetTokenContract,
        uint256 _targetTokenId,
        address[] memory _offerTokenAddresses,
        bool[] memory _isNfts,
        uint256[] memory _offerTokenIds,
        uint256[] memory _amounts,
        uint16 _findersFeeBps
    ) external payable nonReentrant noMoreThanMaxTokens(_offerTokenAddresses) returns (uint256) {
        require(_findersFeeBps <= 10000, "createOffer finders fee bps must be less than or equal to 10000");

        //All array parameters should be of same length
        require(_offerTokenAddresses.length == _offerTokenIds.length, "Unequal lengths for parameters");
        require(_offerTokenIds.length == _amounts.length, "Unequal lengths for parameters");
        require(_amounts.length == _isNfts.length, "Unequal lengths for parameters");

        // Validate offers and take custody
        for (uint256 i = 0; i < _isNfts.length; i++) {
            if (_isNfts[i]) {
                _handleIncomingNftTransfer(_offerTokenIds[i], _offerTokenAddresses[i]);
            } else {
                require(_amounts[i] != 0, "Invalid amount for ERC20");
                _handleIncomingTransfer(_amounts[i], _offerTokenAddresses[i]);
            }
        }

        // "the sun will devour the earth before it could ever overflow" - @transmissions11
        // offerCount++ --> unchecked { offerCount++ }

        // "Although the increment part is cheaper with unchecked, the opcodes after become more expensive for some reason" - @joshieDo
        // unchecked { offerCount++ } --> offerCount++

        // "Earlier today while reviewing c4rena findings I learned that doing ++offerCount would save 5 gas per increment here" - @devtooligan
        // offerCount++ --> ++offerCount

        // TLDR;           unchecked       checked
        // non-optimized   130,037 gas  <  130,149 gas
        // optimized       127,932 gas  >  *127,298 gas*

        ++offerCount;

        offers[_targetTokenContract][_targetTokenId][offerCount] = Offer({
            maker: msg.sender,
            tokenAddresses: _offerTokenAddresses,
            findersFeeBps: _findersFeeBps
        });

        for (uint256 i = 0; i < _offerTokenAddresses.length; i++) {
            offerTokenOfferMap[offerCount][_offerTokenAddresses[i]] = TokenOffer({
                isPresent: true,
                isNft: _isNfts[i],
                tokenId: _offerTokenIds[i],
                amount: _amounts[i],
                tokenAddress: _offerTokenAddresses[i]
            });
        }

        offersForNFT[_targetTokenContract][_targetTokenId].push(offerCount);

        emit BarterOfferCreated(_targetTokenContract, _targetTokenId, offerCount, offers[_targetTokenContract][_targetTokenId][offerCount]);

        return offerCount;
    }

    struct OwedToken {
        int256 netAmount;
        bool isNft;
    }

    //     ,-.
    //     `-'
    //     /|\
    //      |             ,--------.                     ,-------------------.
    //     / \            |OffersV1|                     |ERC20TransferHelper|
    //   Caller           `---+----'                     `---------+---------'
    //     | setOfferAmount() |                                    |
    //     | ----------------->                                    |
    //     |                  |                                    |
    //     |                  |                                    |
    //     |    _______________________________________________________________________
    //     |    ! ALT  /  same token?                              |                   !
    //     |    !_____/       |                                    |                   !
    //     |    !             | retrieve increase / refund decrease|                   !
    //     |    !             | ----------------------------------->                   !
    //     |    !~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!
    //     |    ! [different token]                                |                   !
    //     |    !             |        refund previous offer       |                   !
    //     |    !             | ----------------------------------->                   !
    //     |    !             |                                    |                   !
    //     |    !             |         retrieve new offer         |                   !
    //     |    !             | ----------------------------------->                   !
    //     |    !~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!
    //     |                  |                                    |
    //     |                  |----.                               |
    //     |                  |    | emit OfferUpdated()           |
    //     |                  |<---'                               |
    //   Caller           ,---+----.                     ,---------+---------.
    //     ,-.            |OffersV1|                     |ERC20TransferHelper|
    //     `-'            `--------'                     `-------------------'
    //     /|\
    //      |
    //     / \
    /// @notice Updates the given offer for an NFT
    /// @param _targetTokenContract The address of the offer ERC-721 token
    /// @param _targetTokenId The ID of the offer ERC-721 token
    /// @param _offerId The ID of the offer
    /// @param _offerTokenAddresses The address of the ERC-20 token offering, or address(0) for ETH
    /// @param _amounts The new amount offering
    /// @dev The method cannot change the initial set of ERC20/ERC721 addresses, only token id and amount can be changed in case of ERC721 and ERC20 respectively
    function setOfferAmount(
        address _targetTokenContract,
        uint256 _targetTokenId,
        uint256 _offerId,
        address[] calldata _offerTokenAddresses,
        uint256[] calldata _offerTokenIds,
        uint256[] calldata _amounts
    ) external payable nonReentrant noMoreThanMaxTokens(_offerTokenAddresses) {
        Offer storage offer = offers[_targetTokenContract][_targetTokenId][_offerId];

        require(offer.maker == msg.sender, "setOfferAmount must be maker");
        require(_offerTokenAddresses.length == _offerTokenIds.length, "Unequal lengths for parameters");
        require(_offerTokenIds.length == _amounts.length, "Unequal lengths for parameters");

        for (uint256 i = 0; i < _offerTokenAddresses.length; i++) {
            require(!offerTokenOfferMap[_offerId][_offerTokenAddresses[i]].isPresent, "Initial set of tokens cannot be changed");
            // Get initial amount
            uint256 prevAmount = offerTokenOfferMap[_offerId][_offerTokenAddresses[i]].amount;
            // Ensure valid update
            require(_amounts[i] > 0 && _amounts[i] != prevAmount, "setOfferAmount invalid _amount");

            // If offer increase --
            if (_amounts[i] > prevAmount) {
                unchecked {
                    // Get delta
                    uint256 increaseAmount = _amounts[i] - prevAmount;
                    // Custody increase
                    _handleIncomingTransfer(increaseAmount, _offerTokenAddresses[i]);
                    // Update storage
                    offerTokenOfferMap[_offerId][_offerTokenAddresses[i]].amount += increaseAmount;
                }
                // Else offer decrease --
            } else {
                unchecked {
                    // Get delta
                    uint256 decreaseAmount = prevAmount - _amounts[i];
                    // Refund difference
                    _handleOutgoingTransfer(offer.maker, decreaseAmount, _offerTokenAddresses[i], USE_ALL_GAS_FLAG);
                    // Update storage
                    offerTokenOfferMap[_offerId][_offerTokenAddresses[i]].amount -= decreaseAmount;
                }
            }
            // Else other currency --
        }

        emit BarterOfferUpdated(_targetTokenContract, _targetTokenId, _offerId, offer);
    }

    //     ,-.
    //     `-'
    //     /|\
    //      |             ,--------.          ,-------------------.
    //     / \            |OffersV1|          |ERC20TransferHelper|
    //   Caller           `---+----'          `---------+---------'
    //     |   cancelOffer()  |                         |
    //     | ----------------->                         |
    //     |                  |                         |
    //     |                  |      transferFrom()     |
    //     |                  | ------------------------>
    //     |                  |                         |
    //     |                  |                         |----.
    //     |                  |                         |    | refund tokens from escrow
    //     |                  |                         |<---'
    //     |                  |                         |
    //     |                  |----.
    //     |                  |    | emit OfferCanceled()
    //     |                  |<---'
    //     |                  |                         |
    //     |                  |----.                    |
    //     |                  |    | delete offer       |
    //     |                  |<---'                    |
    //   Caller           ,---+----.          ,---------+---------.
    //     ,-.            |OffersV1|          |ERC20TransferHelper|
    //     `-'            `--------'          `-------------------'
    //     /|\
    //      |
    //     / \
    /// @notice Cancels and refunds the given offer for an NFT
    /// @param _targetTokenContract The ERC-721 token address of the offer
    /// @param _targetTokenId The ERC-721 token ID of the offer
    /// @param _offerId The ID of the offer
    function cancelOffer(
        address _targetTokenContract,
        uint256 _targetTokenId,
        uint256 _offerId
    ) external nonReentrant {
        Offer memory offer = offers[_targetTokenContract][_targetTokenId][_offerId];

        require(offer.maker == msg.sender, "cancelOffer must be maker");

        // Refund offer
        for (uint256 i = 0; i < offer.tokenAddresses.length; i++) {
            _handleOutgoingTransfer(
                offer.maker,
                offerTokenOfferMap[_offerId][offer.tokenAddresses[i]].amount,
                offer.tokenAddresses[i],
                USE_ALL_GAS_FLAG
            );
        }

        emit BarterOfferCanceled(_targetTokenContract, _targetTokenId, _offerId, offer);

        delete offers[_targetTokenContract][_targetTokenId][_offerId];
    }

    /// ------------ TAKER FUNCTIONS ------------

    //     ,-.
    //     `-'
    //     /|\
    //      |             ,--------.                ,--------------------.
    //     / \            |OffersV1|                |ERC721TransferHelper|
    //   Caller           `---+----'                `---------+----------'
    //     |    fillOffer()   |                               |
    //     | ----------------->                               |
    //     |                  |                               |
    //     |                  |----.                          |
    //     |                  |    | validate token owner     |
    //     |                  |<---'                          |
    //     |                  |                               |
    //     |                  |----.                          |
    //     |                  |    | handle royalty payouts   |
    //     |                  |<---'                          |
    //     |                  |                               |
    //     |                  |                               |
    //     |    __________________________________________________
    //     |    ! ALT  /  finders fee configured for this offer?  !
    //     |    !_____/       |                               |   !
    //     |    !             |----.                          |   !
    //     |    !             |    | handle finders fee payout|   !
    //     |    !             |<---'                          |   !
    //     |    !~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!
    //     |    !~[noop]~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!
    //     |                  |                               |
    //     |                  |         transferFrom()        |
    //     |                  | ------------------------------>
    //     |                  |                               |
    //     |                  |                               |----.
    //     |                  |                               |    | transfer NFT from taker to maker
    //     |                  |                               |<---'
    //     |                  |                               |
    //     |                  |----.                          |
    //     |                  |    | emit ExchangeExecuted()  |
    //     |                  |<---'                          |
    //     |                  |                               |
    //     |                  |----.                          |
    //     |                  |    | emit OfferFilled()       |
    //     |                  |<---'                          |
    //     |                  |                               |
    //     |                  |----.
    //     |                  |    | delete offer from contract
    //     |                  |<---'
    //   Caller           ,---+----.                ,---------+----------.
    //     ,-.            |OffersV1|                |ERC721TransferHelper|
    //     `-'            `--------'                `--------------------'
    //     /|\
    //      |
    //     / \
    /// @notice Fills a given offer for an owned NFT, in exchange for ETH/ERC-20 tokens
    /// @param _targetTokenContract The address of the ERC-721 token to transfer
    /// @param _targetTokenId The ID of the ERC-721 token to transfer
    /// @param _offerId The ID of the offer to fill
    /// @param _offerTokenAddresses The address of the ERC-20 to take, or address(0) for ETH
    /// @param _amounts The amount to take
    /// @param _finder The address of the offer referrer
    function fillOffer(
        address _targetTokenContract,
        uint256 _targetTokenId,
        uint256 _offerId,
        address[] calldata _offerTokenAddresses,
        uint256[] calldata _amounts,
        address _finder
    ) external nonReentrant noMoreThanMaxTokens(_offerTokenAddresses) {
        Offer memory offer = offers[_targetTokenContract][_targetTokenId][_offerId];

        require(offer.maker != address(0), "fillOffer must be active offer");
        require(IERC721(_targetTokenContract).ownerOf(_targetTokenId) == msg.sender, "fillOffer must be token owner");
        require(offer.tokenAddresses.length == _offerTokenAddresses.length, "Offer tokens length should match");
        for (uint256 i = 0; i < _offerTokenAddresses.length; i++) {
            require(
                !offerTokenOfferMap[_offerId][_offerTokenAddresses[i]].isPresent &&
                    offerTokenOfferMap[_offerId][_offerTokenAddresses[i]].amount == _amounts[i],
                "fillOffer _offerTokenAddresses & _amounts must match offer"
            );
        }

        for (uint256 i = 0; i < _offerTokenAddresses.length; i++) {
            // Payout respective parties, ensuring royalties are honored
            uint256 remainingProfit;
            if (!offerTokenOfferMap[_offerId][_offerTokenAddresses[i]].isNft) {
                (remainingProfit, ) = _handleRoyaltyPayout(
                    _targetTokenContract,
                    _targetTokenId,
                    offerTokenOfferMap[_offerId][_offerTokenAddresses[i]].amount,
                    _offerTokenAddresses[i],
                    USE_ALL_GAS_FLAG
                );

                // Payout optional protocol fee
                remainingProfit = _handleProtocolFeePayout(remainingProfit, _offerTokenAddresses[i]);

                // Payout optional finders fee
                if (_finder != address(0)) {
                    uint256 findersFee = (remainingProfit * offer.findersFeeBps) / 10000;
                    _handleOutgoingTransfer(_finder, findersFee, _offerTokenAddresses[i], USE_ALL_GAS_FLAG);

                    remainingProfit -= findersFee;
                }

                // Transfer remaining ETH/ERC-20 tokens to offer taker
                _handleOutgoingTransfer(msg.sender, remainingProfit, _offerTokenAddresses[i], USE_ALL_GAS_FLAG);
            } else {
                _handleOutgoingNftTransfer(msg.sender, offerTokenOfferMap[_offerId][_offerTokenAddresses[i]].tokenId, _offerTokenAddresses[i]);
            }
        }
        // Transfer NFT to offer maker
        erc721TransferHelper.transferFrom(_targetTokenContract, msg.sender, offer.maker, _targetTokenId);

        emit BarterOfferFilled(_targetTokenContract, _targetTokenId, _offerId, msg.sender, _finder, offer);

        delete offers[_targetTokenContract][_targetTokenId][_offerId];
    }
}
