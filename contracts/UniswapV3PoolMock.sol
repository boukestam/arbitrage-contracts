// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IUniswapV3FlashCallback {
    /// @notice Called to `msg.sender` after transferring to the recipient from IUniswapV3Pool#flash.
    /// @dev In the implementation you must repay the pool the tokens sent by flash plus the computed fee amounts.
    /// The caller of this method must be checked to be a UniswapV3Pool deployed by the canonical UniswapV3Factory.
    /// @param fee0 The fee amount in token0 due to the pool by the end of the flash
    /// @param fee1 The fee amount in token1 due to the pool by the end of the flash
    /// @param data Any data passed through by the caller via the IUniswapV3PoolActions#flash call
    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external;
}

contract UniswapV3PoolMock {
  address private immutable token0;
  address private immutable token1;

  uint256 private immutable fee;

  constructor(address _token0, address _token1, uint256 _fee) {
    token0 = _token0;
    token1 = _token1;
    fee = _fee;
  }

  function balance0() private view returns (uint256) {
    return IERC20(token0).balanceOf(address(this));
  }

  function balance1() private view returns (uint256) {
    return IERC20(token1).balanceOf(address(this));
  }

  function flash(
      address recipient,
      uint256 amount0,
      uint256 amount1,
      bytes calldata data
  ) external {
        uint256 fee0 = amount0 * (1e6 - fee) / 1e6;
        uint256 fee1 = amount1 * (1e6 - fee) / 1e6;
        uint256 balance0Before = balance0();
        uint256 balance1Before = balance1();

        if (amount0 > 0) IERC20(token0).transfer(recipient, amount0);
        if (amount1 > 0) IERC20(token1).transfer(recipient, amount1);

        IUniswapV3FlashCallback(msg.sender).uniswapV3FlashCallback(fee0, fee1, data);

        uint256 balance0After = balance0();
        uint256 balance1After = balance1();

        require(balance0Before + fee0 <= balance0After, 'F0');
        require(balance1Before + fee1 <= balance1After, 'F1');

        // sub is safe because we know balanceAfter is gt balanceBefore by at least fee
        uint256 paid0 = balance0After - balance0Before;
        uint256 paid1 = balance1After - balance1Before;
    }
}