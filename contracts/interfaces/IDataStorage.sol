// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IDataStorage{

    function owner() external view returns(address);

    function manager() external view returns(address);

    function depositLockTime() external view returns(uint256);

    function redeemLockTime() external view returns(uint256);

    function minDepositMap(address) external view returns(uint256);

    function updateDepositLockTime(uint256) external;

    function updateRedeemLockTime(uint256) external;

    function setVaultMinDeposit(address,uint256) external;
}
