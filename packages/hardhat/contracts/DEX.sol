pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: MIT
// import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract DEX {
    using SafeMath for uint256;
    IERC20 token;

    constructor(address token_addr) {
        token = IERC20(token_addr);
    }

    // write your funcitons here...
    uint256 public totalLiquidity;
    mapping(address => uint256) public liquidity;

    /**
     *  @dev : Initialize token liquidity
     */
    function init(uint256 tokens) public payable returns (uint256) {
        require(totalLiquidity == 0, "DEX:init - already has liquidity");
        totalLiquidity = address(this).balance;
        liquidity[msg.sender] = totalLiquidity;
        require(token.transferFrom(msg.sender, address(this), tokens));
        return totalLiquidity;
    }

    /**
     * @dev : Deposit liquidity
     */
    function deposit() public payable returns (uint256) {
        uint256 eth_reserve = address(this).balance.sub(msg.value);
        uint256 token_reserve = token.balanceOf(address(this));
        uint256 token_amount = (msg.value.mul(token_reserve) / eth_reserve).add(
            1
        );
        uint256 liquidity_minted = msg.value.mul(totalLiquidity) / eth_reserve;
        liquidity[msg.sender] = liquidity[msg.sender].add(liquidity_minted);
        totalLiquidity = totalLiquidity.add(liquidity_minted);
        require(token.transferFrom(msg.sender, address(this), token_amount));
        return liquidity_minted;
    }

    /**
     * @dev : Withdraw liquidity
     */
    function withdraw(uint256 amount) public returns (uint256, uint256) {
        // Amount of liquidity tokens
        uint256 token_reserve = token.balanceOf(address(this));

        // Estimate Ether
        uint256 eth_amount = amount.mul(address(this).balance) / totalLiquidity;
        // Estimate ERC20 Token
        uint256 token_amount = amount.mul(token_reserve) / totalLiquidity;
        // Substract liquidity
        liquidity[msg.sender] = liquidity[msg.sender].sub(eth_amount);
        totalLiquidity = totalLiquidity.sub(eth_amount);
        (bool sent, ) = msg.sender.call{value: eth_amount}("");

        require(sent, "Failed to send user eth.");
        // Return what sender supplied
        require(token.transfer(msg.sender, token_amount));
        return (eth_amount, token_amount);
    }

    function price(
        uint256 input_amount,
        uint256 input_reserve,
        uint256 output_reserve
    ) public view returns (uint256) {
        uint256 input_amount_with_fee = input_amount.mul(997);
        uint256 numerator = input_amount_with_fee.mul(output_reserve);
        uint256 denominator = input_reserve.mul(1000).add(
            input_amount_with_fee
        );
        return numerator / denominator;
    }

    /**
     *  @dev : Convert Ether to a specific token
     */
    function ethToToken() public payable returns (uint256) {
        uint256 token_reserve = token.balanceOf(address(this));
        uint256 tokens_bought = price(
            msg.value,
            address(this).balance.sub(msg.value),
            token_reserve
        );
        require(token.transfer(msg.sender, tokens_bought));
        return tokens_bought;
    }

    /**
     *  @dev : Convert tokens to Ether
     */
    function tokenToEth(uint256 tokens) public returns (uint256) {
        uint256 token_reserve = token.balanceOf(address(this));
        uint256 eth_bought = price(
            tokens,
            token_reserve,
            address(this).balance
        );
        (bool sent, ) = msg.sender.call{value: eth_bought}("");
        require(sent, "Failed to send user eth.");
        require(token.transferFrom(msg.sender, address(this), tokens));
        return eth_bought;
    }
}
