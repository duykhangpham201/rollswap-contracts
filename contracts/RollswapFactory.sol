//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./RollswapPair.sol";

contract RollswapFactory {
    event PairCreated(address token0, address token1, address pair, uint);

    function createPair(address token0, address token1) external returns (address pair) {
        require(token0 != token1);
        
    }

}