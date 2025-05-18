// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Test} from "../lib/forge-std/src/Test.sol";

import {AaveV3CoreDeployer, AaaveV3CoreConfig, AaveV3CoreReserveInput} from "../src/Deployer.sol";

import {AssetMock} from "./AssetMock.sol";

contract DeployerTest is Test, AaveV3CoreDeployer {
    //
    function setUp() external {
        AssetMock weth = new AssetMock("WETH", "WETH");

        AaaveV3CoreConfig memory config = AaaveV3CoreConfig({
            marketId: "Test",
            useL2Pool: true,
            oracleBaseCurrency: address(0), // e.g. USD address or address(0)
            oracleBaseCurrencyUnit: 10 ** 8 // e.g. 10**8 for USD
        });

        AaveV3CoreReserveInput[] memory reserves = new AaveV3CoreReserveInput[](1);
        reserves[0] = AaveV3CoreReserveInput({
            assetAddress: address(weth),
            nameSuffix: "ETH",
            initialPrice: 10 ** 8,
            // Default recommended config params
            ltv: 7500, // e.g., 7500 for 75%
            liquidationThreshold: 8000, // e.g., 8000 for 80%
            liquidationBonus: 10500, // e.g., 10500 for 5% bonus
            reserveFactor: 1000, // e.g., 1000 for 10%
            borrowingEnabled: true,
            stableBorrowRateEnabled: true,
            borrowCap: 0, // 0 for no cap
            supplyCap: 0 // 0 for no cap
        });
        //
        deployAndConfigureAaveV3Core(config, reserves);
    }

    function testPoolAddressesProvider() external view {
        assertEq(aaveV3PoolAddressesProvider.getACLAdmin(), aaveV3CoreDeployer, "pap: invalid acl admin");
    }
}
