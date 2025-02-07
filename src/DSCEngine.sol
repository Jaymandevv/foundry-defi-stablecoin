// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

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
contract DSCEngine {
    function depositCollateralAndMintDsc() external {}

    function depositcollateral() external {}

    function redeemCollateralForDsc() external {}

    function redeeemCollateral() external {}

    function mintDsc() external {}

    function burnDsc() external {}

    function liquidate() external {}

    function getHealthFactor() external view {}
}
