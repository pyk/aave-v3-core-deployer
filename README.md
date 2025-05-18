# Aave V3 Core Deployer

My personal utility contract to deploy Aave V3 Core.

## Install

```shell
forge install pyk/aave-v3-core-deployer
```

## Usage

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {AaveV3Deployer} from "aave-v3-core-deployer/Deployer.sol";

contract SomeTest is Test, AaveV3Deployer {
    function setUp() external {
        deployAaveCoreContracts();
    }
}
```
