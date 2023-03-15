// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "hardhat/console.sol";

interface IUniswapV3Pool {
    function flash(address recipient, uint256 amount0, uint256 amount1, bytes calldata data) external;
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
}

contract CyclicArbitrage {
    address private immutable owner;
    address private flashPool;

    error InvalidBalance(uint256 balanceBefore, uint256 balanceAfter);
    error CallFailed(uint256 index, bytes returnData);

    constructor() {
        owner = msg.sender;
    }

    struct FlashAction {
        uint64 input;
        address to;
        uint256 value;
        bytes data;
    }

    function uniswapV3Flash(
        address pool, 
        address outputToken,
        uint256 minOutput,
        address recipient, 
        uint256 amount0, 
        uint256 amount1, 
        bytes calldata data
    ) external payable returns(uint256) {
        if (msg.sender != owner) revert();

        uint256 balanceBefore = IERC20(outputToken).balanceOf(address(this));

        flashPool = pool;
        IUniswapV3Pool(pool).flash(recipient, amount0, amount1, data);
        flashPool = address(0);

        uint256 balanceAfter = IERC20(outputToken).balanceOf(address(this));
        if (balanceAfter < balanceBefore + minOutput) revert InvalidBalance(balanceBefore, balanceAfter);

        if (msg.value > 0) block.coinbase.transfer(msg.value);

        return balanceAfter - balanceBefore;
    }

    function uniswapV3FlashCallback(uint256, uint256, bytes calldata data) external {
        if (msg.sender != flashPool) revert();

        (FlashAction[] memory actions) = abi.decode(data, (FlashAction[]));
        uint256 actionsLength = actions.length;

        bytes[] memory outputs = new bytes[](actionsLength);

        for (uint256 i = 0; i < actionsLength; i++) {
            FlashAction memory action = actions[i];

            uint256 actionInput = action.input;
            bytes memory actionData = action.data;

            if (actionInput != 0) {
                uint256 outputIndex = actionInput & 0xff;
                uint256 outputStart = (actionInput & 0xffff00) >> 8;
                uint256 dataStart = (actionInput & 0xffff000000) >> 24;

                bytes memory output = outputs[outputIndex];

                // add 32 to skip the bytes length
                assembly ("memory-safe") {
                    let d := mload(add(add(output, 32), outputStart))
                    mstore(add(add(actionData, 32), dataStart), d)
                }
            }

            (bool success, bytes memory outputData) = action.to.call{value: action.value}(actionData);
            if (!success) revert CallFailed(i, outputData);

            outputs[i] = outputData;
        }
    }

    function execute(address to, uint256 value, bytes calldata data) external {
        if (msg.sender != owner) revert();

        (bool success, bytes memory returnData) = to.call{value: value}(data);
        if (!success) revert CallFailed(0, returnData);
    }

    receive() external payable{}
}