// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SingleSidedPool is ReentrancyGuard, Ownable {
    uint256 public withdrawalFee; // Fee in basis points (30 = 0.3%)

    mapping(address => mapping(address => uint256)) public liquidityBalance;

    event Deposit(address indexed user, address indexed token, uint256 amount);
    event Withdraw(address indexed user, address indexed token, uint256 amount);
    event WithdrawalFeeUpdated(uint256 newFeeBps);

    constructor(uint256 _withdrawalFee) Ownable(msg.sender) {
        require(_withdrawalFee <= 500, "Fee cannot exceed 5%");
        withdrawalFee = _withdrawalFee;
    }

    function setWithdrawalFee(uint256 fee) external onlyOwner {
        require(fee <= 500, "Fee cannot exceed 5%");
        withdrawalFee = fee;
        emit WithdrawalFeeUpdated(fee);
    }

    function deposit(address tokenA, uint256 amountA) external {
        require(amountA > 0, "Amount must be greater than 0");
        require(tokenA != address(0), "Invalid token address");

        IERC20 token = IERC20(tokenA);
        require(token.transferFrom(msg.sender, address(this), amountA), "Transfer failed");

        liquidityBalance[msg.sender][tokenA] += amountA;

        emit Deposit(msg.sender, tokenA, amountA);
    }

    function withdraw(address tokenA, uint256 amountA) external nonReentrant {
        require(liquidityBalance[msg.sender][tokenA] >= amountA, "Insufficient balance");

        IERC20 token = IERC20(tokenA);

        uint256 feeAmount = (amountA * withdrawalFee) / 10_000;
        uint256 amountAfterFee = amountA - feeAmount;

        liquidityBalance[msg.sender][tokenA] -= amountA;

        require(token.transfer(msg.sender, amountAfterFee), "Transfer failed");
        require(token.transfer(owner(), feeAmount), "Fee transfer failed");

        emit Withdraw(msg.sender, tokenA, amountAfterFee);
    }

    function getLiquidity(address user, address token) external view returns (uint256) {
        return liquidityBalance[user][token];
    }
}