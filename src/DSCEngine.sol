// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from
    "lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
/**
 * @title DSCEngine
 * @author Jamiu Garba
 *
 * This system is designed to be as minimal as possible, and have tokens maintain a 1 token == $1 peg.
 * This stablecoin has the  properties:
 * - Exogenous collateral
 * - Dollar pegged
 * - Algorithmically stable
 *
 * It is similar to DAI if DAI had no governance, no fees and was only backed by WETH and WBTC.
 *
 * Our DSC system should always be "overcollecteralized". At no point should the value of all collecteral <= the $ backed value of all the DSC. i.e we should always have more collateral than DSC token
 *
 * @notice This contract is the core of the DSC system. It handles all the logic for minting and redeeming DSC, as well as depositing & withdrawing collateral.
 * @notice This contract is very loosely based on the MAKERDAO DSS (DAI) system.
 */

contract DSCEngine is ReentrancyGuard {
    ////////////////
    // ERRORS     //
    ///////////////

    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeTheSameLength();
    error DSCEngine__NotAllowedToken();
    error DSCEngine_TransferFailed();

    /////////////////////////
    // STATE VARIABLES     //
    ////////////////////////
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;

    mapping(address token => address priceFeed) private s_priceFeeds; //tokenToPriceFeed
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256 amountDscMint) private s_DscMinted;
    address[] private s_collateralTokens;

    DecentralizedStableCoin private immutable i_dsc;

    ////////////////
    // EVENTS  //
    ///////////////

    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);

    ////////////////
    // MODIFIERS  //
    ///////////////

    modifier moreThanZero(uint256 amount) {
        if (amount == 0) revert DSCEngine__NeedsMoreThanZero();
        _;
    }

    modifier isAllowToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert DSCEngine__NotAllowedToken();
        }

        _;
    }

    ///////////////////
    // CONSTRUCTOR  //
    //////////////////

    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address dscAddress) {
        // To get the priceFeed , we will use the USD price feeds
        // For example ETH/USD, BTC/USD
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeTheSameLength();
        }

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }

        // Note: Now to know which tokens are allowed , we just need to check if they have a priceFeed .
        // If they have a price feed, they are allowed if not they are not allowed

        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    /////////////////////////
    // EXTERNAL FUNCTIONS  //
    ////////////////////////

    function depositCollateralAndMintDsc() external {}

    /**
     * @notice follows CEI (Checks, Effects, Interactions) pattern
     * @param tokenCollateralAddress The address token to deposit as collateral
     * @param amountCollateral The amount of collateral to deposit
     */
    function depositcollateral(address tokenCollateralAddress, uint256 amountCollateral)
        external
        moreThanZero(amountCollateral)
        isAllowToken(tokenCollateralAddress)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        (bool success) = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) revert DSCEngine_TransferFailed();
    }

    function redeemCollateralForDsc() external {}

    function redeeemCollateral() external {}

    // To mint dsc -> Check if the collateral value is greater than the dsc amount
    /**
     * @notice Follows CEI
     * @param amountDscToMint The amount of decentralized stable coin to mint
     * @notice They must have more collateral value than the minimum threshold
     */
    function mintDsc(uint256 amountDscToMint) external moreThanZero(amountDscToMint) {
        s_DscMinted[msg.sender] += amountDscToMint;
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function burnDsc() external {}

    function liquidate() external {}

    function getHealthFactor() external view {}

    ////////////////////////////////////////
    // PRIVATE & INTERNAL VIEW FUNCTIONS  //
    ///////////////////////////////////////

    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        totalDscMinted = s_DscMinted[user];
        collateralValueInUsd = getAccountCollateralValue(user);
    }

    /**
     * Returns how close to liquidation a user is
     * If a user goes below 1, then they can get liquidated
     */
    function _healthFactor(address user) private view returns (uint256) {
        // 1. Total DSC minted
        // 2. Total collateral value

        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);
    }

    function _revertIfHealthFactorIsBroken(address user) internal view {
        // 1. Check health factor (Do they have enough collateral ?)
        // 2. revert if they don't have a good health factor
    }

    ////////////////////////////////////////
    // PUBLIC & EXTERNAL VIEW FUNCTIONS  //
    ///////////////////////////////////////

    function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueInUsd) {
        // Loop through each collateral token, get the amount they have deposited, and map it to
        // the price, to get the USD value

        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUsd += getUsdvalue(token, amount);
        }

        return totalCollateralValueInUsd;
    }

    function getUsdvalue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        // If 1 ETH = $1000
        // The returned value(price) from chainlink will be 1000 * 1e8 because it has 8 decimals
        // But the amount will be in wei which is 18 decimals 1e18 , so we have to make the 2 have the same decimals
        return (uint256((price * ADDITIONAL_FEED_PRECISION) * amount)) / PRECISION; // -> (1000 * 1e8 * 1e10) * 1 * 1e18
    }
}
