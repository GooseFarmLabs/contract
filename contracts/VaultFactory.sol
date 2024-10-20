// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// Uncomment this line to use console.log
// import "hardhat/console.sol";
import "./LRTVault.sol";
import "./USDVault.sol";

contract VaultFactory{

    address public dataStorageContract;

    event CreateLRTVault(address vault,address token,uint256 createTime);
    event CreateUSDVault(address vault,address token,uint256 createTime);

    constructor(address storageContract){
        require(storageContract != address(0),"Invalid Zero Address");
        dataStorageContract = storageContract;
    }

    function createLRTVault(address token,uint256 initialLockTime,uint256 initialMaxLockAmount) external{
        LRTVault vault = new LRTVault(dataStorageContract,token,initialLockTime,initialMaxLockAmount);
        emit CreateLRTVault(address(vault), token, block.timestamp);
    }

    function createUSDVault(address token) external{
        USDVault vault = new USDVault(dataStorageContract,token);
        emit CreateUSDVault(address(vault), token, block.timestamp);
    }
}
