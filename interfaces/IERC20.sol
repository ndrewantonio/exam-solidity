// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @notice Interface for interacting with an ERC20 token.
 */
interface IERC20 {
    /**
     * @notice Transfers tokens from one address to another.
     * @param sender The address sending the tokens.
     * @param recipient The address receiving the tokens.
     * @param amount The number of tokens to transfer.
     * @return A boolean value indicating whether the operation succeeded.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    /**
     * @notice Transfers tokens to a recipient.
     * @param recipient The address receiving the tokens.
     * @param amount The number of tokens to transfer.
     * @return A boolean value indicating whether the operation succeeded.
     */
    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    /**
     * @notice Gets the balance of tokens for an account.
     * @param account The address to query.
     * @return The token balance of the account.
     */
    function balanceOf(address account) external view returns (uint256);
}
