// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title FLXToken
 * @dev Native governance and reward token for the FreelanceX platform.
 * Used for DAO voting power, staking, and freelancer/employer incentives.
 */
contract FLXToken is ERC20, Ownable {
    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------
    constructor() ERC20("FreelanceX Token", "FLX") Ownable(msg.sender) {
        // Mint initial supply to the deployer (platform treasury or admin)
        _mint(msg.sender, 1_000_000 * 10 ** decimals());
    }

    // ---------------------------------------------------------------------
    // Admin Functions
    // ---------------------------------------------------------------------

    /**
     * @dev Mints new tokens to a specified address.
     * Can be used for rewarding freelancers or DAO incentives.
     * Restricted to the contract owner (DAO or platform admin).
     */
    function mint(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "Invalid address");
        _mint(to, amount);
    }

    /**
     * @dev Burns tokens from caller’s balance.
     * Allows users to voluntarily reduce supply (e.g., staking exit, burn events).
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    /**
     * @dev Burns tokens from another account (requires allowance).
     * Useful if DAO decides to penalize malicious users.
     */
    function burnFrom(address account, uint256 amount) external {
        _spendAllowance(account, msg.sender, amount);
        _burn(account, amount);
    }

    // ---------------------------------------------------------------------
    // View / Helper Methods
    // ---------------------------------------------------------------------

    /// @dev Returns total token supply (for external integrations)
    function totalSupplyFLX() external view returns (uint256) {
        return totalSupply();
    }

    /// @dev Returns token balance of a user
    function balanceOfFLX(address user) external view returns (uint256) {
        return balanceOf(user);
    }
}
