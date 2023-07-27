// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/console.sol";
import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {TickTest} from "../../contracts/test/TickTest.sol";
import {Constants} from "./utils/Constants.sol";
import {Pool} from "../../contracts/libraries/Pool.sol";

contract TickTestTest is Test {
    TickTest tick;

    enum FeeAmount {
        LOW,
        MEDIUM,
        HIGH
    }

    uint24[3] TICK_SPACINGS = [uint24(10), 60, 200];

    function setUp() public {
        tick = new TickTest();
    }

    function getMinTick(uint24 tickSpacing) internal pure returns (uint256) {
        return 0;
        // return (-887272 / tickSpacing) * tickSpacing; // ceil
    }

    function getMaxTick(uint24 tickSpacing) internal pure returns (uint256) {
        return uint256((87272 / tickSpacing) * tickSpacing);
    }

    function checkCantOverflow(uint24 tickSpacing, uint128 maxLiquidityPerTick) internal {
        assertLe(
            maxLiquidityPerTick * ((getMaxTick(tickSpacing) - getMinTick(tickSpacing)) / tickSpacing + 1),
            Constants.MAX_UINT128
        );
    }

    // #tickSpacingToMaxLiquidityPerTick
    function test_tickSpacingToMaxLiquidityPerTick_returnsTheCorrectValueForLowFeeTickSpacing() public {
        uint24 tickSpacing = TICK_SPACINGS[uint256(FeeAmount.LOW)];

        uint128 maxLiquidityPerTick = tick.tickSpacingToMaxLiquidityPerTick(int24(tickSpacing));

        assertEq(maxLiquidityPerTick, 1917565579412846627735051215301243);
        checkCantOverflow(TICK_SPACINGS[uint256(FeeAmount.LOW)], maxLiquidityPerTick);
    }

    function test_tickSpacingToMaxLiquidityPerTick_returnsTheCorrectValueForMediumFeeTickSpacing() public {
        uint24 tickSpacing = TICK_SPACINGS[uint256(FeeAmount.MEDIUM)];

        uint128 maxLiquidityPerTick = tick.tickSpacingToMaxLiquidityPerTick(int24(tickSpacing));

        assertEq(maxLiquidityPerTick, 11505069308564788430434325881101413); // 113.1 bits
        checkCantOverflow(TICK_SPACINGS[uint256(FeeAmount.LOW)], maxLiquidityPerTick);
    }

    function test_tickSpacingToMaxLiquidityPerTick_returnsTheCorrectValueForHighFeeTickSpacing() public {
        uint24 tickSpacing = TICK_SPACINGS[uint256(FeeAmount.HIGH)];

        uint128 maxLiquidityPerTick = tick.tickSpacingToMaxLiquidityPerTick(int24(tickSpacing));

        assertEq(maxLiquidityPerTick, 38347205785278154309959589375342946); // 114.7 bits
        checkCantOverflow(TICK_SPACINGS[uint256(FeeAmount.LOW)], maxLiquidityPerTick);
    }

    function test_tickSpacingToMaxLiquidityPerTick_returnsTheCorrectValueFor1() public {
        uint128 maxLiquidityPerTick = tick.tickSpacingToMaxLiquidityPerTick(1);

        assertEq(maxLiquidityPerTick, 191757530477355301479181766273477); // 126 bits
        checkCantOverflow(1, maxLiquidityPerTick);
    }

    function test_tickSpacingToMaxLiquidityPerTick_returnsTheCorrectValueForEntireRange() public {
        uint128 maxLiquidityPerTick = tick.tickSpacingToMaxLiquidityPerTick(887272);

        assertEq(maxLiquidityPerTick, Constants.MAX_UINT128 / 3); // 126 bits
        checkCantOverflow(887272, maxLiquidityPerTick);
    }

    function test_tickSpacingToMaxLiquidityPerTick_returnsTheCorrectValueFor2302() public {
        uint128 maxLiquidityPerTick = tick.tickSpacingToMaxLiquidityPerTick(2302);

        assertEq(maxLiquidityPerTick, 440854192570431170114173285871668350); // 118 bits
        checkCantOverflow(2302, maxLiquidityPerTick);
    }

    function test_tickSpacingToMaxLiquidityPerTick_gasCostMinTickSpacing() public {
        uint256 gasCost = tick.getGasCostOfTickSpacingToMaxLiquidityPerTick(1);

        assertGt(gasCost, 0);
    }

    function test_tickSpacingToMaxLiquidityPerTick_gasCost60TickSpacing() public {
        uint256 gasCost = tick.getGasCostOfTickSpacingToMaxLiquidityPerTick(60);

        assertGt(gasCost, 0);
    }

    function test_tickSpacingToMaxLiquidityPerTick_gasCostMaxTickSpacing() public {
        int24 MAX_TICK_SPACING = 32767;
        uint256 gasCost = tick.getGasCostOfTickSpacingToMaxLiquidityPerTick(MAX_TICK_SPACING);

        assertGt(gasCost, 0);
    }

    // #getFeeGrowthInside
    function test_getFeeGrowthInside_returnsAllForTwoUninitializedTicksIfTickIsInside() public {
        (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) = tick.getFeeGrowthInside(-2, 2, 0, 15, 15);

        assertEq(feeGrowthInside0X128, 15);
        assertEq(feeGrowthInside1X128, 15);
    }

    function test_getFeeGrowthInside_returns0ForTwoUninitializedTicksIfTickIsAbove() public {
        (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) = tick.getFeeGrowthInside(-2, 2, 4, 15, 15);

        assertEq(feeGrowthInside0X128, 0);
        assertEq(feeGrowthInside1X128, 0);
    }

    function test_getFeeGrowthInside_returns0ForTwoUninitializedTicksIfTickIsBelow() public {
        (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) = tick.getFeeGrowthInside(-2, 2, -4, 15, 15);

        assertEq(feeGrowthInside0X128, 0);
        assertEq(feeGrowthInside1X128, 0);
    }

    function test_getFeeGrowthInside_subtractsUpperTickIfBelow() public {
        Pool.TickInfo memory info;

        info.feeGrowthOutside0X128 = 2;
        info.feeGrowthOutside1X128 = 3;
        info.liquidityGross = 0;
        info.liquidityNet = 0;

        tick.setTick(2, info);

        (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) = tick.getFeeGrowthInside(-2, 2, 0, 15, 15);

        assertEq(feeGrowthInside0X128, 13);
        assertEq(feeGrowthInside1X128, 12);
    }

    function test_getFeeGrowthInside_subtractsLowerTickIfAbove() public {
        Pool.TickInfo memory info;

        info.feeGrowthOutside0X128 = 2;
        info.feeGrowthOutside1X128 = 3;
        info.liquidityGross = 0;
        info.liquidityNet = 0;

        tick.setTick(-2, info);

        (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) = tick.getFeeGrowthInside(-2, 2, 0, 15, 15);

        assertEq(feeGrowthInside0X128, 13);
        assertEq(feeGrowthInside1X128, 12);
    }

    function test_getFeeGrowthInside_subtractsUpperAndLowerTickIfInside() public {
        Pool.TickInfo memory info;

        info.feeGrowthOutside0X128 = 2;
        info.feeGrowthOutside1X128 = 3;
        info.liquidityGross = 0;
        info.liquidityNet = 0;

        tick.setTick(-2, info);

        info.feeGrowthOutside0X128 = 4;
        info.feeGrowthOutside1X128 = 1;
        info.liquidityGross = 0;
        info.liquidityNet = 0;

        tick.setTick(2, info);

        (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) = tick.getFeeGrowthInside(-2, 2, 0, 15, 15);

        assertEq(feeGrowthInside0X128, 9);
        assertEq(feeGrowthInside1X128, 11);
    }

    function test_getFeeGrowthInside_worksCorrectlyWithOverflowOnInsideTick() public {
        Pool.TickInfo memory info;

        info.feeGrowthOutside0X128 = Constants.MAX_UINT256 - 3;
        info.feeGrowthOutside1X128 = Constants.MAX_UINT256 - 2;
        info.liquidityGross = 0;
        info.liquidityNet = 0;

        tick.setTick(-2, info);

        info.feeGrowthOutside0X128 = 3;
        info.feeGrowthOutside1X128 = 5;
        info.liquidityGross = 0;
        info.liquidityNet = 0;

        tick.setTick(2, info);

        (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) = tick.getFeeGrowthInside(-2, 2, 0, 15, 15);

        assertEq(feeGrowthInside0X128, 16);
        assertEq(feeGrowthInside1X128, 13);
    }
}
