// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.10;

import {DSTest} from "ds-test/test.sol";

import {BarterOffersV1} from "../../../../modules/BarterOffers/V1/BarterOffersV1.sol";
import {Zorb} from "../../../utils/users/Zorb.sol";
import {ZoraRegistrar} from "../../../utils/users/ZoraRegistrar.sol";
import {ZoraModuleManager} from "../../../../ZoraModuleManager.sol";
import {ZoraProtocolFeeSettings} from "../../../../auxiliary/ZoraProtocolFeeSettings/ZoraProtocolFeeSettings.sol";
import {ERC20TransferHelper} from "../../../../transferHelpers/ERC20TransferHelper.sol";
import {ERC721TransferHelper} from "../../../../transferHelpers/ERC721TransferHelper.sol";
import {RoyaltyEngine} from "../../../utils/modules/RoyaltyEngine.sol";

import {TestERC721} from "../../../utils/tokens/TestERC721.sol";
import {WETH} from "../../../utils/tokens/WETH.sol";
import {VM} from "../../../utils/VM.sol";

/// @title OffersV1IntegrationTest
/// @notice Integration Tests for Offers v1.0
contract BarterOffersV1IntegrationTest is DSTest {
    VM internal vm;

    ZoraRegistrar internal registrar;
    ZoraProtocolFeeSettings internal ZPFS;
    ZoraModuleManager internal ZMM;
    ERC20TransferHelper internal erc20TransferHelper;
    ERC721TransferHelper internal erc721TransferHelper;
    RoyaltyEngine internal royaltyEngine;

    BarterOffersV1 internal barterOffers;
    TestERC721 internal token;
    WETH internal weth;

    Zorb internal seller;
    Zorb internal buyer;
    Zorb internal finder;
    Zorb internal royaltyRecipient;

    //Test Variables
    address[] internal _offerTokenAddresses;
    bool[] internal _isNfts;
    uint256[] internal _amounts;
    uint256[] internal _offerTokenIds;

    function setUp() public {
        // Cheatcodes
        vm = VM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

        // Deploy V3
        registrar = new ZoraRegistrar();
        ZPFS = new ZoraProtocolFeeSettings();
        ZMM = new ZoraModuleManager(address(registrar), address(ZPFS));
        erc20TransferHelper = new ERC20TransferHelper(address(ZMM));
        erc721TransferHelper = new ERC721TransferHelper(address(ZMM));

        // Init V3
        registrar.init(ZMM);
        ZPFS.init(address(ZMM), address(0));

        // Create users
        seller = new Zorb(address(ZMM));
        buyer = new Zorb(address(ZMM));
        finder = new Zorb(address(ZMM));
        royaltyRecipient = new Zorb(address(ZMM));

        // Deploy mocks
        royaltyEngine = new RoyaltyEngine(address(royaltyRecipient));
        token = new TestERC721();
        weth = new WETH();

        // Deploy Offers v1.0
        barterOffers = new BarterOffersV1(
            address(erc20TransferHelper),
            address(erc721TransferHelper),
            address(royaltyEngine),
            address(ZPFS),
            address(weth)
        );
        registrar.registerModule(address(barterOffers));

        // Set seller balance
        vm.deal(address(seller), 100 ether);

        // Mint buyer token
        token.mint(address(buyer), 0);

        //Mint seller token to bid it
        token.mint(address(seller), 1);
        // Seller swap 50 ETH <> 50 WETH
        vm.prank(address(seller));
        weth.deposit{value: 50 ether}();

        // Users approve barterOffers module
        seller.setApprovalForModule(address(barterOffers), true);
        buyer.setApprovalForModule(address(barterOffers), true);

        // Seller approve ERC20TransferHelper
        vm.prank(address(seller));
        weth.approve(address(erc20TransferHelper), 50 ether);
        token.setApprovalForAll(address(barterOffers), true);

        // Buyer approve BarterOffers
        vm.prank(address(buyer));
        token.setApprovalForAll(address(barterOffers), true);
    }

    /// ------------ ETH Offer ------------ ///

    function runETH() public {
        vm.prank(address(seller));
        _offerTokenAddresses.push(address(0));
        _offerTokenAddresses.push(address(token));
        _isNfts.push(false);
        _isNfts.push(true);
        _offerTokenIds.push(99);
        _offerTokenIds.push(1);
        _amounts.push(1 ether);
        _amounts.push(99);
        uint256 id = barterOffers.createOffer{value: 1 ether}(address(token), 0, _offerTokenAddresses, _isNfts, _offerTokenIds, _amounts, 1000);

        vm.prank(address(buyer));
        barterOffers.fillOffer(address(token), 0, id, _offerTokenAddresses, _offerTokenIds, _amounts, address(finder));
    }

    function test_ETHIntegration() public {
        uint256 beforeSellerBalance = address(seller).balance;
        uint256 beforeBuyerBalance = address(buyer).balance;
        uint256 beforeRoyaltyRecipientBalance = address(royaltyRecipient).balance;
        uint256 beforeFinderBalance = address(finder).balance;
        address beforeTargetNftTokenOwner = token.ownerOf(0);
        address beforeOfferNftTokenOwner = token.ownerOf(1);

        runETH();

        uint256 afterSellerBalance = address(seller).balance;
        uint256 afterBuyerBalance = address(buyer).balance;
        uint256 afterRoyaltyRecipientBalance = address(royaltyRecipient).balance;
        uint256 afterFinderBalance = address(finder).balance;
        address afterTargetNftTokenOwner = token.ownerOf(0);
        address afterOfferNftTokenOwner = token.ownerOf(1);

        // 1 ETH withdrawn from seller
        require((beforeSellerBalance - afterSellerBalance) == 1 ether);
        // 0.05 ETH creator royalty
        require((afterRoyaltyRecipientBalance - beforeRoyaltyRecipientBalance) == 0.05 ether);
        // 1000 bps finders fee (Remaining 0.95 ETH * 10% finders fee = 0.095 ETH)
        require((afterFinderBalance - beforeFinderBalance) == 0.095 ether);
        // Remaining 0.855 ETH paid to buyer
        require((afterBuyerBalance - beforeBuyerBalance) == 0.855 ether);
        // Target NFT transferred to seller
        require((beforeTargetNftTokenOwner == address(buyer)) && afterTargetNftTokenOwner == address(seller));
        // Offer NFT transferred to buyer
        require((beforeOfferNftTokenOwner == address(seller)) && afterOfferNftTokenOwner == address(buyer));
    }

    /// ------------ ERC-20 Offer ------------ ///

    function runERC20() public {
        vm.prank(address(seller));
        _offerTokenAddresses.push(address(weth));
        _offerTokenAddresses.push(address(token));
        _isNfts.push(false);
        _isNfts.push(true);
        _offerTokenIds.push(99);
        _offerTokenIds.push(1);
        _amounts.push(1 ether);
        _amounts.push(99);
        uint256 id = barterOffers.createOffer(address(token), 0, _offerTokenAddresses, _isNfts, _offerTokenIds, _amounts, 1000);

        vm.prank(address(buyer));
        barterOffers.fillOffer(address(token), 0, id, _offerTokenAddresses, _offerTokenIds, _amounts, address(finder));
    }

    function test_ERC20Integration() public {
        uint256 beforeSellerBalance = weth.balanceOf(address(seller));
        uint256 beforeBuyerBalance = weth.balanceOf(address(buyer));
        uint256 beforeRoyaltyRecipientBalance = weth.balanceOf(address(royaltyRecipient));
        uint256 beforeFinderBalance = weth.balanceOf(address(finder));
        address beforeTokenOwner = token.ownerOf(0);
        address beforeOfferNftTokenOwner = token.ownerOf(1);

        runERC20();

        uint256 afterSellerBalance = weth.balanceOf(address(seller));
        uint256 afterBuyerBalance = weth.balanceOf(address(buyer));
        uint256 afterRoyaltyRecipientBalance = weth.balanceOf(address(royaltyRecipient));
        uint256 afterFinderBalance = weth.balanceOf(address(finder));
        address afterTokenOwner = token.ownerOf(0);
        address afterOfferNftTokenOwner = token.ownerOf(1);

        // 1 WETH withdrawn from seller
        require((beforeSellerBalance - afterSellerBalance) == 1 ether);
        // 0.05 WETH creator royalty
        require((afterRoyaltyRecipientBalance - beforeRoyaltyRecipientBalance) == 0.05 ether);
        // 0.095 WETH finders fee (0.95 WETH * 10% finders fee)
        require((afterFinderBalance - beforeFinderBalance) == 0.095 ether);
        // Remaining 0.855 WETH paid to buyer
        require((afterBuyerBalance - beforeBuyerBalance) == 0.855 ether);
        // NFT transferred to seller
        require((beforeTokenOwner == address(buyer)) && afterTokenOwner == address(seller));
        // Offer NFT transferred to buyer
        require((beforeOfferNftTokenOwner == address(seller)) && afterOfferNftTokenOwner == address(buyer));
    }
}
