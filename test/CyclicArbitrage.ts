import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";
import { AbiCoder, parseEther } from "ethers/lib/utils";
import { BigNumber } from "ethers";

const FEE = 500;

describe("CyclicArbitrage", function () {
  async function deployFixture() {
    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount] = await ethers.getSigners();

    const CyclicArbitrage = await ethers.getContractFactory("CyclicArbitrage");
    const arbitrage = await CyclicArbitrage.deploy();

    const ERC20Mock = await ethers.getContractFactory("ERC20Mock");
    const token0 = await ERC20Mock.deploy("Token 0", "TST0");
    const token1 = await ERC20Mock.deploy("Token 1", "TST1");

    const UniswapV3PoolMock = await ethers.getContractFactory(
      "UniswapV3PoolMock"
    );
    const pool = await UniswapV3PoolMock.deploy(
      token0.address,
      token1.address,
      FEE
    );

    await token0.mint(pool.address, parseEther("100"));
    await token1.mint(pool.address, parseEther("100"));

    return { arbitrage, token0, token1, pool, owner, otherAccount };
  }

  describe("Flash", function () {
    it("Should flash arbitrage", async function () {
      const { arbitrage, token0, token1, pool, owner } = await loadFixture(
        deployFixture
      );

      const loanAmount = parseEther("10");
      const fee = loanAmount.mul(1e6 - FEE).div(1e6);
      const profit = parseEther("0.2");

      const mintTx = await token0.populateTransaction.mint(
        arbitrage.address,
        fee.add(profit)
      );

      const repayTx = await token0.populateTransaction.transfer(
        pool.address,
        loanAmount.add(fee)
      );

      const profitBalanceTx = await token0.populateTransaction.balanceOf(
        arbitrage.address
      );

      const profitTransferTx = await token0.populateTransaction.transfer(
        owner.address,
        1 // will be filled in with balance
      );

      const profitTransferInput = BigNumber.from(2).or(BigNumber.from(4 + 32).shl(24));

      const abiCoder = new AbiCoder();

      const data = abiCoder.encode(
        ["tuple(uint64 input, address to, uint256 value, bytes data)[]"],
        [
          [
            [0, mintTx.to, 0, mintTx.data],
            [0, repayTx.to, 0, repayTx.data],
            [0, profitBalanceTx.to, 0, profitBalanceTx.data],
            [profitTransferInput, profitTransferTx.to, 0, profitTransferTx.data],
          ],
        ]
      );

      await arbitrage.uniswapV3Flash(
        pool.address,
        token0.address,
        0,
        arbitrage.address,
        loanAmount,
        0,
        data
      );

      const gas = await arbitrage.estimateGas.uniswapV3Flash(
        pool.address,
        token0.address,
        0,
        arbitrage.address,
        loanAmount,
        0,
        data
      );

      console.log("Gas: " + gas.toString());

      expect(await token0.balanceOf(owner.address)).to.equal(profit);
    });

    // it("Should fail if the unlockTime is not in the future", async function () {
    //   // We don't use the fixture here because we want a different deployment
    //   const latestTime = await time.latest();
    //   const Lock = await ethers.getContractFactory("Lock");
    //   await expect(Lock.deploy(latestTime, { value: 1 })).to.be.revertedWith(
    //     "Unlock time should be in the future"
    //   );
    // });
  });
});
