// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract DataStorage is OwnableUpgradeable{

    uint256 public constant MAX_REDEEM_LOCK_TIME = 60 days;

    address public manager;
    uint256 public depositLockTime;
    uint256 public redeemLockTime;

    mapping(address => uint256) public minDepositMap;
    mapping(address => bool) public vaults;

    event UpdateDepositLockTime(uint256 oldLockTime,uint256 currentLockTime);
    event UpdateRedeemLockTime(uint256 oldLockTime,uint256 currentLockTime);
    event SetVaultMinDeposit(address vault,uint256 amount);
    event UpdateVault(address vault,bool flag);
    event UpdateManager(address oldManager,address currentManager);

    constructor(address initialOwner,address initialManager,uint256 initialDepositLockTime,uint256 initialRedeemLockTime){
        require(initialOwner != address(0) && initialManager != address(0),"Invalid Zero Address");
        _transferOwnership(initialOwner);
        manager = initialManager;
        depositLockTime = initialDepositLockTime;
        redeemLockTime = initialRedeemLockTime;
    }

    function updateDepositLockTime(uint256 lockTime) external onlyOwner{
        emit UpdateDepositLockTime(depositLockTime,lockTime);
        depositLockTime = lockTime;
    }

    function updateRedeemLockTime(uint256 lockTime) external onlyOwner {
        require(lockTime <= MAX_REDEEM_LOCK_TIME,"Invalid LockTime");
        emit UpdateRedeemLockTime(redeemLockTime,lockTime);
        redeemLockTime = lockTime;
    }

    function setVaultMinDeposit(address vault,uint256 minAmount) external onlyOwner{
        minDepositMap[vault] = minAmount;
        emit SetVaultMinDeposit(vault,minAmount);
    }

    function addVault(address vault) external onlyOwner {
        vaults[vault] = true;
        emit UpdateVault(vault,true);
    }

    function delVault(address vault) external onlyOwner{
        vaults[vault] = false;
        minDepositMap[vault] = 0;
        emit UpdateVault(vault,false);
        emit SetVaultMinDeposit(vault,0);
    }

    function updateManager(address account) external onlyOwner{
        emit UpdateManager(manager,account);
        manager = account;
    }
}
