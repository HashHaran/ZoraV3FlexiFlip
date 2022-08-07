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

/// @title BarterOffersV1Test
/// @notice Unit Tests for BarterOffers v1.0
contract BarterOffersV1Test is DSTest {
    VM internal vm;

    ZoraRegistrar internal registrar;
    ZoraProtocolFeeSettings internal ZPFS;
    ZoraModuleManager internal ZMM;
    ERC20TransferHelper internal erc20TransferHelper;
    ERC721TransferHelper internal erc721TransferHelper;
    RoyaltyEngine internal royaltyEngine;

    BarterOffersV1 internal offers;
    TestERC721 internal token;
    WETH internal weth;

    Zorb internal maker;
    Zorb internal taker;
    Zorb internal finder;
    Zorb internal royaltyRecipient;

    //Test Variables
    address[] internal _offerTokenAddresses;
    bool[] internal _isNfts;
    uint256[] internal _offerTokenIds;
    uint256[] internal _amounts;

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
        maker = new Zorb(address(ZMM));
        taker = new Zorb(address(ZMM));
        finder = new Zorb(address(ZMM));
        royaltyRecipient = new Zorb(address(ZMM));

        // Deploy mocks
        royaltyEngine = new RoyaltyEngine(address(royaltyRecipient));
        token = new TestERC721();
        weth = new WETH();

        // Deploy Offers v1.0
        offers = new BarterOffersV1(
            address(erc20TransferHelper),
            address(erc721TransferHelper),
            address(royaltyEngine),
            address(ZPFS),
            address(weth)
        );
        registrar.registerModule(address(offers));

        // Set maker balance
        vm.deal(address(maker), 100 ether);

        // Mint taker token
        token.mint(address(taker), 0);

        //Mint maker token
        token.mint(address(maker), 1);
        token.mint(address(maker), 2);

        // Maker swap 50 ETH <> 50 WETH
        vm.prank(address(maker));
        weth.deposit{value: 50 ether}();

        // Users approve Offers module
        maker.setApprovalForModule(address(offers), true);
        taker.setApprovalForModule(address(offers), true);

        // Maker approve ERC20TransferHelper
        vm.startPrank(address(maker));
        weth.approve(address(erc20TransferHelper), 50 ether);
        token.setApprovalForAll(address(erc721TransferHelper), true);
        vm.stopPrank();

        // Taker approve ERC721TransferHelper
        vm.prank(address(taker));
        token.setApprovalForAll(address(erc721TransferHelper), true);

        _offerTokenAddresses.push(address(0));
        _offerTokenAddresses.push(address(token));

        _isNfts.push(false);
        _isNfts.push(true);

        _offerTokenIds.push(99);
        _offerTokenIds.push(1);

        _amounts.push(1 ether);
        _amounts.push(99);
    }

    /// ------------ CREATE NFT OFFER ------------ ///

    function testGas_CreateOffer() public {
        vm.prank(address(maker));
        offers.createOffer{value: 1 ether}(address(token), 0, _offerTokenAddresses, _isNfts, _offerTokenIds, _amounts, 1000);
    }

    function test_CreateOffer() public {
        vm.prank(address(maker));
        offers.createOffer{value: 1 ether}(address(token), 0, _offerTokenAddresses, _isNfts, _offerTokenIds, _amounts, 1000);

        (address offeror, ) = offers.offers(address(token), 0, 1);

        require(offeror == address(maker));
        require(token.ownerOf(1) == address(offers));
        require(address(offers).balance == 1 ether);
    }

    function testFail_CannotCreateOfferWithoutAttachingFunds() public {
        vm.prank(address(maker));
        offers.createOffer(address(token), 0, _offerTokenAddresses, _isNfts, _offerTokenIds, _amounts, 1000);
    }

    function testFail_CannotCreateOfferWithInvalidFindersFeeBps() public {
        vm.prank(address(maker));
        offers.createOffer(address(token), 0, _offerTokenAddresses, _isNfts, _offerTokenIds, _amounts, 10001);
    }

    /// ------------ SET NFT OFFER ------------ ///

    function test_IncreaseETHOfferAndChangeNft() public {
        vm.startPrank(address(maker));

        offers.createOffer{value: 1 ether}(address(token), 0, _offerTokenAddresses, _isNfts, _offerTokenIds, _amounts, 1000);

        vm.warp(1 hours);

        _offerTokenIds.pop();
        _offerTokenIds.pop();
        _offerTokenIds.push(99);
        _offerTokenIds.push(2);

        _amounts.pop();
        _amounts.pop();
        _amounts.push(2 ether);
        _amounts.push(99);

        offers.setOfferAmount{value: 1 ether}(address(token), 0, 1, _offerTokenAddresses, _offerTokenIds, _amounts);

        vm.stopPrank();

        (, , uint256 offerTokenId, , ) = offers.offerTokenOfferMap(1, address(token));
        (, , , uint256 amount, ) = offers.offerTokenOfferMap(1, address(0));

        require(amount == 2 ether);
        require(address(offers).balance == 2 ether);
        require(offerTokenId == 2);
        require(token.ownerOf(offerTokenId) == address(offers));
        require(token.ownerOf(1) == address(maker));
    }

    function test_DecreaseETHOffer() public {
        vm.startPrank(address(maker));

        offers.createOffer{value: 1 ether}(address(token), 0, _offerTokenAddresses, _isNfts, _offerTokenIds, _amounts, 1000);

        vm.warp(1 hours);

        _offerTokenIds.pop();
        _offerTokenIds.pop();
        _offerTokenIds.push(99);
        _offerTokenIds.push(2);

        _amounts.pop();
        _amounts.pop();
        _amounts.push(0.5 ether);
        _amounts.push(99);

        offers.setOfferAmount(address(token), 0, 1, _offerTokenAddresses, _offerTokenIds, _amounts);

        vm.stopPrank();

        (, , , uint256 amount, ) = offers.offerTokenOfferMap(1, address(0));

        require(amount == 0.5 ether);
        require(address(offers).balance == 0.5 ether);
    }

    function testRevert_CannotDecreaseETHOfferWithERC20() public {
        vm.startPrank(address(maker));

        offers.createOffer{value: 1 ether}(address(token), 0, _offerTokenAddresses, _isNfts, _offerTokenIds, _amounts, 1000);

        vm.warp(1 hours);

        _offerTokenAddresses.pop();
        _offerTokenAddresses.pop();
        _offerTokenAddresses.push(address(weth));
        _offerTokenAddresses.push(address(token));

        _amounts.pop();
        _amounts.pop();
        _amounts.push(0.5 ether);
        _amounts.push(99);

        vm.expectRevert("Initial set of tokens cannot be changed");
        offers.setOfferAmount(address(token), 0, 1, _offerTokenAddresses, _offerTokenIds, _amounts);

        vm.stopPrank();
    }

    function testRevert_OnlySellerCanUpdateOffer() public {
        vm.prank(address(maker));
        offers.createOffer{value: 1 ether}(address(token), 0, _offerTokenAddresses, _isNfts, _offerTokenIds, _amounts, 1000);

        vm.expectRevert("setOfferAmount must be maker");
        vm.prank(address(taker));
        offers.setOfferAmount(address(token), 0, 1, _offerTokenAddresses, _offerTokenIds, _amounts);
    }

    function testRevert_CannotIncreaseOfferWithoutAttachingFunds() public {
        vm.startPrank(address(maker));

        offers.createOffer{value: 1 ether}(address(token), 0, _offerTokenAddresses, _isNfts, _offerTokenIds, _amounts, 1000);

        vm.warp(1 hours);

        _offerTokenIds.pop();
        _offerTokenIds.pop();
        _offerTokenIds.push(99);
        _offerTokenIds.push(2);

        _amounts.pop();
        _amounts.pop();
        _amounts.push(2 ether);
        _amounts.push(99);

        vm.expectRevert("_handleIncomingTransfer msg value less than expected amount");
        offers.setOfferAmount(address(token), 0, 1, _offerTokenAddresses, _offerTokenIds, _amounts);

        vm.stopPrank();
    }

    function testRevert_UpdateOfferWithPreviousAmountandNewNft() public {
        vm.startPrank(address(maker));

        offers.createOffer{value: 1 ether}(address(token), 0, _offerTokenAddresses, _isNfts, _offerTokenIds, _amounts, 1000);

        vm.warp(1 hours);

        require(token.ownerOf(2) == address(maker));
        require(token.ownerOf(1) == address(offers));
        require(address(offers).balance == 1 ether);

        _offerTokenIds.pop();
        _offerTokenIds.pop();
        _offerTokenIds.push(99);
        _offerTokenIds.push(2);

        offers.setOfferAmount{value: 1 ether}(address(token), 0, 1, _offerTokenAddresses, _offerTokenIds, _amounts);

        vm.stopPrank();

        require(token.ownerOf(2) == address(offers));
        require(token.ownerOf(1) == address(maker));
        require(address(offers).balance == 2 ether);
    }

    function testRevert_UpdateOfferWithPreviousNftTokenIdAndNewAmount() public {
        vm.startPrank(address(maker));

        offers.createOffer{value: 1 ether}(address(token), 0, _offerTokenAddresses, _isNfts, _offerTokenIds, _amounts, 1000);

        vm.warp(1 hours);

        require(address(offers).balance == 1 ether);
        require(token.ownerOf(2) == address(maker));
        require(token.ownerOf(1) == address(offers));

        _amounts.pop();
        _amounts.pop();
        _amounts.push(2 ether);
        _amounts.push(99);

        vm.expectRevert("ERC721: transfer caller is not owner nor approved");
        offers.setOfferAmount{value: 1 ether}(address(token), 0, 1, _offerTokenAddresses, _offerTokenIds, _amounts);

        require(address(offers).balance == 2 ether);
        require(token.ownerOf(2) == address(maker));
        require(token.ownerOf(1) == address(offers));

        vm.stopPrank();
    }

    function testRevert_CannotUpdateWithoutAnyChangeInAmountAndTokenId() public {
        vm.startPrank(address(maker));

        offers.createOffer{value: 1 ether}(address(token), 0, _offerTokenAddresses, _isNfts, _offerTokenIds, _amounts, 1000);

        vm.warp(1 hours);

        vm.expectRevert("ERC721: transfer caller is not owner nor approved");
        offers.setOfferAmount{value: 1 ether}(address(token), 0, 1, _offerTokenAddresses, _offerTokenIds, _amounts);

        vm.stopPrank();
    }

    function testRevert_CannotUpdateWithZeroAmount() public {
        vm.startPrank(address(maker));

        offers.createOffer{value: 1 ether}(address(token), 0, _offerTokenAddresses, _isNfts, _offerTokenIds, _amounts, 1000);

        vm.warp(1 hours);

        _offerTokenIds.pop();
        _offerTokenIds.pop();
        _offerTokenIds.push(99);
        _offerTokenIds.push(2);

        _amounts.pop();
        _amounts.pop();
        _amounts.push(0);
        _amounts.push(99);

        vm.expectRevert("setOfferAmount invalid _amounts and _offerTokenIds");
        offers.setOfferAmount{value: 1 ether}(address(token), 0, 1, _offerTokenAddresses, _offerTokenIds, _amounts);

        vm.stopPrank();
    }

    function testRevert_CannotUpdateInactiveOffer() public {
        vm.prank(address(maker));
        offers.createOffer{value: 1 ether}(address(token), 0, _offerTokenAddresses, _isNfts, _offerTokenIds, _amounts, 1000);

        vm.prank(address(taker));
        offers.fillOffer(address(token), 0, 1, _offerTokenAddresses, _offerTokenIds, _amounts, address(finder));

        vm.prank(address(maker));
        vm.expectRevert("setOfferAmount must be maker");
        offers.setOfferAmount(address(token), 0, 1, _offerTokenAddresses, _offerTokenIds, _amounts);
    }

    /// ------------ CANCEL NFT OFFER ------------ ///

    function test_CancelNFTOffer() public {
        vm.startPrank(address(maker));

        offers.createOffer{value: 1 ether}(address(token), 0, _offerTokenAddresses, _isNfts, _offerTokenIds, _amounts, 1000);

        (, , uint256 beforeTokenId, uint256 beforeAmount, ) = offers.offerTokenOfferMap(1, address(token));
        require(beforeAmount == 1 ether);
        require(beforeTokenId == 1);

        offers.cancelOffer(address(token), 0, 1);

        (, , uint256 afterTokenId, uint256 afterAmount, ) = offers.offerTokenOfferMap(1, address(token));
        require(afterAmount == 0);
        require(afterTokenId == 0);

        vm.stopPrank();
    }

    function testRevert_CannotCancelInactiveOffer() public {
        vm.prank(address(maker));
        offers.createOffer{value: 1 ether}(address(token), 0, _offerTokenAddresses, _isNfts, _offerTokenIds, _amounts, 1000);

        vm.prank(address(taker));
        offers.fillOffer(address(token), 0, 1, _offerTokenAddresses, _offerTokenIds, _amounts, address(finder));

        vm.prank(address(maker));
        vm.expectRevert("cancelOffer must be maker");
        offers.cancelOffer(address(token), 0, 1);
    }

    function testRevert_OnlySellerCanCancelOffer() public {
        vm.prank(address(maker));
        offers.createOffer{value: 1 ether}(address(token), 0, _offerTokenAddresses, _isNfts, _offerTokenIds, _amounts, 1000);

        vm.expectRevert("cancelOffer must be maker");
        offers.cancelOffer(address(token), 0, 1);
    }

    /// ------------ FILL NFT OFFER ------------ ///

    function test_FillNFTOffer() public {
        vm.prank(address(maker));
        offers.createOffer{value: 1 ether}(address(token), 0, _offerTokenAddresses, _isNfts, _offerTokenIds, _amounts, 1000);

        address beforeTokenOwner = token.ownerOf(0);

        vm.prank(address(taker));
        offers.fillOffer(address(token), 0, 1, _offerTokenAddresses, _offerTokenIds, _amounts, address(finder));

        address afterTokenOwner = token.ownerOf(0);

        require(beforeTokenOwner == address(taker) && afterTokenOwner == address(maker));
    }

    function testRevert_OnlyTokenHolderCanFillOffer() public {
        vm.prank(address(maker));
        uint256 id = offers.createOffer{value: 1 ether}(address(token), 0, _offerTokenAddresses, _isNfts, _offerTokenIds, _amounts, 1000);

        vm.expectRevert("fillOffer must be token owner");
        offers.fillOffer(address(token), 0, 1, _offerTokenAddresses, _offerTokenIds, _amounts, address(finder));
    }

    function testRevert_CannotFillInactiveOffer() public {
        vm.prank(address(maker));
        uint256 id = offers.createOffer{value: 1 ether}(address(token), 0, _offerTokenAddresses, _isNfts, _offerTokenIds, _amounts, 1000);

        vm.prank(address(taker));
        offers.fillOffer(address(token), 0, 1, _offerTokenAddresses, _offerTokenIds, _amounts, address(finder));

        vm.prank(address(taker));
        vm.expectRevert("fillOffer must be active offer");
        offers.fillOffer(address(token), 0, 1, _offerTokenAddresses, _offerTokenIds, _amounts, address(finder));
    }

    function testRevert_AcceptCurrencyMustMatchOffer() public {
        vm.prank(address(maker));
        uint256 id = offers.createOffer{value: 1 ether}(address(token), 0, _offerTokenAddresses, _isNfts, _offerTokenIds, _amounts, 1000);

        vm.prank(address(taker));
        vm.expectRevert("fillOffer _offerTokenAddresses must match offer");

        _offerTokenAddresses.pop();
        _offerTokenAddresses.pop();
        _offerTokenAddresses.push(address(weth));
        _offerTokenAddresses.push(address(token));

        offers.fillOffer(address(token), 0, 1, _offerTokenAddresses, _offerTokenIds, _amounts, address(finder));
    }

    function testRevert_AcceptAmountMustMatchOffer() public {
        vm.prank(address(maker));
        uint256 id = offers.createOffer{value: 1 ether}(address(token), 0, _offerTokenAddresses, _isNfts, _offerTokenIds, _amounts, 1000);

        _amounts.pop();
        _amounts.pop();
        _amounts.push(0.5 ether);
        _amounts.push(99);

        vm.prank(address(taker));
        vm.expectRevert("fillOffer _amounts must match offer");
        offers.fillOffer(address(token), 0, 1, _offerTokenAddresses, _offerTokenIds, _amounts, address(finder));
    }

    function testRevert_AcceptTokenIdMustMatchOffer() public {
        vm.prank(address(maker));
        uint256 id = offers.createOffer{value: 1 ether}(address(token), 0, _offerTokenAddresses, _isNfts, _offerTokenIds, _amounts, 1000);

        _offerTokenIds.pop();
        _offerTokenIds.pop();
        _offerTokenIds.push(99);
        _offerTokenIds.push(2);

        vm.prank(address(taker));
        vm.expectRevert("fillOffer _offerTokenIds must match offer");
        offers.fillOffer(address(token), 0, 1, _offerTokenAddresses, _offerTokenIds, _amounts, address(finder));
    }
}
