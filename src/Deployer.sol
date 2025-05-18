// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Test} from "../lib/forge-std/src/Test.sol";
import {
    IPoolAddressesProvider,
    PoolAddressesProvider
} from "../lib/aave-v3-core/contracts/protocol/configuration/PoolAddressesProvider.sol";
import {IACLManager, ACLManager} from "../lib/aave-v3-core/contracts/protocol/configuration/ACLManager.sol";
import {IPriceOracle} from "../lib/aave-v3-core/contracts/interfaces/IPriceOracle.sol";
import {IPriceOracleGetter} from "../lib/aave-v3-core/contracts/interfaces/IPriceOracleGetter.sol";
import {IPoolConfigurator, PoolConfigurator} from "../lib/aave-v3-core/contracts/protocol/pool/PoolConfigurator.sol";
// import {IPool, Pool} from "../lib/aave-v3-core/contracts/protocol/pool/Pool.sol";
// import {IL2Pool, L2Pool} from "../lib/aave-v3-core/contracts/protocol/pool/L2Pool.sol";
// import {AToken} from "../lib/aave-v3-core/contracts/protocol/tokenization/AToken.sol";
// import {StableDebtToken} from "../lib/aave-v3-core/contracts/protocol/tokenization/StableDebtToken.sol";
// import {VariableDebtToken} from "../lib/aave-v3-core/contracts/protocol/tokenization/VariableDebtToken.sol";
// import {IAaveIncentivesController} from "../lib/aave-v3-core/contracts/interfaces/IAaveIncentivesController.sol";
// import {DefaultReserveInterestRateStrategy} from
//     "../lib/aave-v3-core/contracts/protocol/pool/DefaultReserveInterestRateStrategy.sol";
// import {DataTypes} from "../lib/aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol";
// import {IERC20Detailed} from "../lib/aave-v3-core/contracts/dependencies/openzeppelin/contracts/IERC20Detailed.sol";
// import {ConfiguratorInputTypes} from "../lib/aave-v3-core/contracts/protocol/libraries/types/ConfiguratorInputTypes.sol";
// import {ReserveConfiguration} from
//     "../lib/aave-v3-core/contracts/protocol/libraries/configuration/ReserveConfiguration.sol";

struct AaaveV3CoreConfig {
    string marketId;
    bool useL2Pool;
    address oracleBaseCurrency; // e.g. USD address or address(0)
    uint256 oracleBaseCurrencyUnit; // e.g. 10**8 for USD
}

struct AaveV3CoreReserveInput {
    address assetAddress;
    string nameSuffix;
    uint256 initialPrice;
    // Default recommended config params
    uint256 ltv; // e.g., 7500 for 75%
    uint256 liquidationThreshold; // e.g., 8000 for 80%
    uint256 liquidationBonus; // e.g., 10500 for 5% bonus
    uint256 reserveFactor; // e.g., 1000 for 10%
    bool borrowingEnabled;
    bool stableBorrowRateEnabled;
    uint256 borrowCap; // 0 for no cap
    uint256 supplyCap; // 0 for no cap
}

contract AaveV3CorePriceOracle is IPriceOracle, IPriceOracleGetter {
    mapping(address => uint256) private _prices;
    address public immutable BASE_CURRENCY_MOCK;
    uint256 public immutable BASE_CURRENCY_UNIT_MOCK;

    constructor(address baseCurrencyAddress, uint256 baseCurrencyUnitAmount) {
        BASE_CURRENCY_MOCK = baseCurrencyAddress;
        BASE_CURRENCY_UNIT_MOCK = baseCurrencyUnitAmount;
    }

    function setAssetPrice(address asset, uint256 price) external override {
        _prices[asset] = price;
    }

    function getAssetPrice(address asset) external view override(IPriceOracle, IPriceOracleGetter) returns (uint256) {
        if (asset == BASE_CURRENCY_MOCK) {
            return BASE_CURRENCY_UNIT_MOCK;
        }
        uint256 price = _prices[asset];
        // Consider returning 0 or another indicator for unset prices if `require` is too strict for fuzzing
        require(price > 0, "MockPriceOracle: Price not set or zero");
        return price;
    }

    function BASE_CURRENCY() external view override returns (address) {
        return BASE_CURRENCY_MOCK;
    }

    function BASE_CURRENCY_UNIT() external view override returns (uint256) {
        return BASE_CURRENCY_UNIT_MOCK;
    }
}

// contract AaveV3CoreIncentivesController is IAaveIncentivesController {
//     function handleAction(address, uint256, uint256) external override {
//         // No-op
//     }
// }

contract AaveV3CoreDeployer is Test {
    address aaveV3CoreDeployer = makeAddr("aaveV3CoreDeployer");
    address aaveV3CoreTreasury = makeAddr("aaveV3CoreTreasury");

    IPoolAddressesProvider aaveV3PoolAddressesProvider;
    IACLManager aaveV3ACLManager;
    AaveV3CorePriceOracle aaveV3PriceOracle;
    IPoolConfigurator aaveV3PoolConfigurator;
    // IL2Pool aaveV3Pool;

    function deployPoolAddressesProvider(string memory marketId) private {
        aaveV3PoolAddressesProvider = new PoolAddressesProvider(marketId, aaveV3CoreDeployer);
        aaveV3PoolAddressesProvider.setACLAdmin(aaveV3CoreDeployer);
    }

    function deployACLManager() private {
        aaveV3ACLManager = new ACLManager(aaveV3PoolAddressesProvider);
        aaveV3PoolAddressesProvider.setACLManager(address(aaveV3ACLManager));
        aaveV3ACLManager.addPoolAdmin(aaveV3CoreDeployer);
        aaveV3ACLManager.addAssetListingAdmin(aaveV3CoreDeployer);
        aaveV3ACLManager.addEmergencyAdmin(aaveV3CoreDeployer);
        aaveV3ACLManager.addRiskAdmin(aaveV3CoreDeployer);
    }

    function deployPriceOracle(address baseCurrency, uint256 baseCurrencyUnit) private {
        aaveV3PriceOracle = new AaveV3CorePriceOracle(baseCurrency, baseCurrencyUnit);
    }

    function deployPoolConfigurator() private {
        PoolConfigurator configuratorLogic = new PoolConfigurator();
        aaveV3PoolAddressesProvider.setPoolConfiguratorImpl(address(configuratorLogic));
        aaveV3PoolConfigurator = PoolConfigurator(aaveV3PoolAddressesProvider.getPoolConfigurator());
    }

    // function deployL2Pool() private {
    //     L2Pool l2PoolLogic = new L2Pool(aaveV3PoolAddressesProvider);
    //     aaveV3PoolAddressesProvider.setPoolImpl(address(l2PoolLogic));
    //     aaveV3Pool = L2Pool(aaveV3PoolAddressesProvider.getPool());
    // }

    // function deployPool() private {
    //     Pool poolLogic = new Pool(aaveV3PoolAddressesProvider);
    //     aaveV3PoolAddressesProvider.setPoolImpl(address(poolLogic));
    //     address poolProxyAddress = aaveV3PoolAddressesProvider.getPool();
    //     aaveV3Pool = IPool(poolProxyAddress);
    // }

    function deployAndConfigureAaveV3Core(AaaveV3CoreConfig memory config, AaveV3CoreReserveInput[] memory reserves)
        internal
    {
        vm.startPrank(aaveV3CoreDeployer);

        // 1) Deploy PoolAddressesProvider
        deployPoolAddressesProvider(config.marketId);

        // 2) Deploy ACLManager
        deployACLManager();

        // 3) Deploy PriceOracle
        deployPriceOracle(config.oracleBaseCurrency, config.oracleBaseCurrencyUnit);

        // 4) Deploy PoolConfigurator
        deployPoolConfigurator();

        // 5) Deploy Pool or L2Pool
        // deployL2Pool();
        // if (config.useL2Pool) {
        // } else {
        //     deployPool();
        // }

        // // 6) Deploy default token implementations, strategy, and controller
        // address defaultATokenImpl = address(new AToken(aaveV3Pool));
        // address defaultStableDebtTokenImpl = address(new StableDebtToken(aaveV3Pool));
        // address defaultVariableDebtTokenImpl = address(new VariableDebtToken(aaveV3Pool));
        // address defaultIncentivesController = address(new AaveV3CoreIncentivesController());
        // address defaultStrategy = address(
        //     new DefaultReserveInterestRateStrategy(
        //         aaveV3PoolAddressesProvider,
        //         8000, // optimalUsageRatio: 80%
        //         0, // baseVariableBorrowRate: 0%
        //         400, // variableRateSlope1: 4%
        //         7500, // variableRateSlope2: 75%
        //         2000, // stableRateSlope1: 20%
        //         7500, // stableRateSlope2: 75%
        //         500, // baseStableRateOffset: 5%
        //         4000, // stableRateExcessOffset: 40%
        //         2000 // optimalStableToTotalDebtRatio: 20%
        //     )
        // );

        // for (uint256 i = 0; i < reserves.length; i++) {
        //     AaveV3CoreReserveInput memory cfg = reserves[i];
        //     addReserve(
        //         cfg.assetAddress,
        //         defaultATokenImpl,
        //         defaultStableDebtTokenImpl,
        //         defaultVariableDebtTokenImpl,
        //         defaultStrategy, // Use deployed default strategy
        //         msg.sender, // Treasury defaults to msg.sender
        //         defaultIncentivesController, // Use deployed default mock controller
        //         cfg.nameSuffix
        //     );
        //     configureReserve(cfg);
        // }

        vm.stopPrank();
    }

    // function addReserve(
    //     address asset,
    //     address aTokenImpl,
    //     address stableDebtTokenImpl,
    //     address variableDebtTokenImpl,
    //     address interestRateStrategyAddress,
    //     address treasury,
    //     address incentivesController,
    //     string memory nameSuffix
    // ) internal {
    //     require(address(aaveV3PoolConfigurator) != address(0), "aaveV3PoolConfigurator not set");

    //     uint8 assetDecimals = IERC20Detailed(asset).decimals();

    //     ConfiguratorInputTypes.InitReserveInput memory input = ConfiguratorInputTypes.InitReserveInput({
    //         aTokenImpl: aTokenImpl,
    //         stableDebtTokenImpl: stableDebtTokenImpl,
    //         variableDebtTokenImpl: variableDebtTokenImpl,
    //         underlyingAssetDecimals: assetDecimals,
    //         interestRateStrategyAddress: interestRateStrategyAddress,
    //         underlyingAsset: asset,
    //         treasury: treasury,
    //         incentivesController: incentivesController,
    //         aTokenName: string.concat("Aave ", nameSuffix),
    //         aTokenSymbol: string.concat("a", nameSuffix),
    //         variableDebtTokenName: string.concat("Aave  Variable Debt ", nameSuffix),
    //         variableDebtTokenSymbol: string.concat("vd", nameSuffix),
    //         stableDebtTokenName: string.concat("Aave Stable Debt ", nameSuffix),
    //         stableDebtTokenSymbol: string.concat("sd", nameSuffix),
    //         params: "0x10"
    //     });

    //     ConfiguratorInputTypes.InitReserveInput[] memory inputs = new ConfiguratorInputTypes.InitReserveInput[](1);
    //     inputs[0] = input;

    //     aaveV3PoolConfigurator.initReserves(inputs);
    // }

    // function configureReserve(AaveV3CoreReserveInput memory cfg) internal {
    //     aaveV3PoolConfigurator.configureReserveAsCollateral(
    //         cfg.assetAddress, cfg.ltv, cfg.liquidationThreshold, cfg.liquidationBonus
    //     );
    //     aaveV3PoolConfigurator.setReserveFactor(cfg.assetAddress, cfg.reserveFactor);
    //     aaveV3PoolConfigurator.setReserveBorrowing(cfg.assetAddress, cfg.borrowingEnabled);
    //     if (cfg.borrowingEnabled) {
    //         aaveV3PoolConfigurator.setReserveStableRateBorrowing(cfg.assetAddress, cfg.stableBorrowRateEnabled);
    //     } else {
    //         aaveV3PoolConfigurator.setReserveStableRateBorrowing(cfg.assetAddress, false); // Ensure it's off if borrowing is off
    //     }
    //     aaveV3PoolConfigurator.setBorrowCap(cfg.assetAddress, cfg.borrowCap);
    //     aaveV3PoolConfigurator.setSupplyCap(cfg.assetAddress, cfg.supplyCap);

    //     aaveV3PoolConfigurator.setReserveFlashLoaning(cfg.assetAddress, true);
    //     aaveV3PriceOracle.setAssetPrice(cfg.assetAddress, cfg.initialPrice);
    // }
}
