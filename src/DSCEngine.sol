// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
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

    mapping(address token => address priceFeed) private s_priceFeeds; //tokenToPriceFeed
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
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

    function mintDsc() external {}

    function burnDsc() external {}

    function liquidate() external {}

    function getHealthFactor() external view {}
}
