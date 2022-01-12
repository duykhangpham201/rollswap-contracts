//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./libraries/Math.sol";
import "./RollswapERC20.sol";

contract RollswapPair is ReentrancyGuard {
    using SafeMath for uint256;
    using Math for uint256;
    using SafeERC20 for IERC20Metadata;

    IERC20Metadata public token0;
    IERC20Metadata public token1;
    RollswapERC20 public lpToken;

    event Mint(address sender, uint256 token0amount, uint256 token1amount);
    event Burn(address sender, uint256 lpTokenAmount);
    event Swap(
        address indexed sender,
        uint256 amount0in,
        uint256 amount1in,
        uint256 amount0out,
        uint256 amount1out,
        address indexed to
    );

    constructor(IERC20Metadata _token0, IERC20Metadata _token1) ReentrancyGuard() {

        token0 = IERC20Metadata(_token0);
        token1 = IERC20Metadata(_token1);
        lpToken = _createLPToken();
    }

    function _createLPToken() private returns (RollswapERC20) {
        string memory name = string(abi.encodePacked("Rollswap", token0.name(),"/", token1.name(), " LP Token"));
        string memory symbol = string(abi.encodePacked("Roll", token0.symbol(), "/", token1.symbol()));

        return new RollswapERC20(name, symbol, address(token0), address(token1));
    }

    function getReserve() public view returns (uint256, uint256) {
        return (IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)));
    }
 
    function addLiquidity(uint256 _token0amount, uint256 _token1amount) external nonReentrant {
        _transferTokensToPool(msg.sender, _token0amount, _token1amount );
        uint256 lpTokenAmount = _calculateLPTokenToMint(_token0amount,_token1amount);
        lpToken.mint(msg.sender, lpTokenAmount);

        emit Mint(msg.sender, _token0amount, _token1amount);
    }

    function _transferTokensToPool(address _provider, uint256 _token0amount, uint256 _token1amount) private {
        require(_token0amount>0 && _token1amount>0, "Token amount must be greater than 0");
        require(token0.allowance(_provider, address(this)) >= _token0amount && token1.allowance(_provider, address(this)) >= _token1amount);

        token0.safeTransferFrom(_provider,address(this), _token0amount);
        token1.safeTransferFrom(_provider, address(this), _token1amount);
    }

    function _calculateLPTokenToMint(uint256 _token0amount, uint256 _token1amount) private view returns (uint256) {
        uint256 lpTokenSupply = lpToken.totalSupply();
        if (lpTokenSupply == 0) {
            return (_token0amount * _token1amount).sqrt();
        } else {
            uint256 reserve0 = token0.balanceOf(address(this));
            uint256 reserve1 = token1.balanceOf(address(this));

            uint256 totalValueInPoolAsToken0 = reserve0.mul(2);
            uint256 token1AmountAddedAsToken0 = _token1amount.mul(reserve0).div(reserve1);
            uint256 totalValueAddedAsToken0 = _token0amount.add(token1AmountAddedAsToken0);

            uint256 totalFutureSupply = lpTokenSupply.mul(totalValueInPoolAsToken0).div((
                totalValueInPoolAsToken0.sub(totalValueAddedAsToken0)
            ));
            
            uint256 total = totalFutureSupply - lpTokenSupply;
            return total;
        }
    }

    function removeLiquidity(uint256 _lpTokenAmount) external nonReentrant {
        (uint256 token0amount, uint256 token1amount) = _getPoolOwnership(_lpTokenAmount);
        lpToken.burn(msg.sender, _lpTokenAmount);
        
        _transferTokenstoSender(msg.sender, token0amount, token1amount);

        emit Burn(msg.sender, _lpTokenAmount);
    }

    function _getPoolOwnership(uint256 _lpTokenAmount) private view returns (uint256 token0amount, uint256 token1amount)  {
        uint256 lpTokenSupply = lpToken.totalSupply();
        uint256 reserve0 = token0.balanceOf(address(this));
        uint256 reserve1 = token1.balanceOf(address(this));

        return (
            ((reserve0.mul(_lpTokenAmount).div(lpTokenSupply))),
            ((reserve1.mul(_lpTokenAmount).div(lpTokenSupply)))
        );

    }

    function _transferTokenstoSender(address _provider, uint256 _token0amount, uint256 _token1amount) private {
        token0.safeTransfer(_provider, _token0amount);
        token1.safeTransfer(_provider, _token1amount);
    }

    //review

    function swapTokens(uint256 _amount0out, uint256 _amount1out) external nonReentrant {
        require(_amount0out>0 || _amount1out>0);
        (uint256 reserve0, uint256 reserve1) = getReserve();
        require(_amount0out < reserve0 && _amount1out < reserve1);

        if (_amount0out > 0) {
            token0.safeTransfer(msg.sender, _amount0out);
        }

        if (_amount1out > 0) {
            token1.safeTransfer(msg.sender, _amount1out);
        }

        (uint256 balance0, uint256 balance1) = getReserve();
        uint256 amount0in = balance0 > reserve0 - _amount0out ? balance0 - (reserve0 - _amount0out) : 0;
        uint256 amount1in = balance1 > reserve1 - _amount1out ? balance1 - (reserve1 - _amount1out) : 0;
        
        require(amount0in > 0 || amount1in > 0 );
        uint256 balance0adjusted = balance0.mul(1000).sub(amount0in.mul(3));
        uint256 balance1adjusted = balance1.mul(1000).sub(amount1in.mul(3));
        
    }


}