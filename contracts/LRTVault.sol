// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// Uncomment this line to use console.log
// import "hardhat/console.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "./interfaces/IDataStorage.sol";

contract LRTVault is ReentrancyGuardUpgradeable{
    using SafeERC20 for IERC20;

    uint256 public constant MAX_LOCK_TIME = 180 days;
    IDataStorage public dataStorage;
    address public token;      // LRT Token contract address
    uint256 public totalStakeAmount;
    uint256 public eventId;

    uint256 public lockTime;
    uint256 public maxLockAmount;
    mapping(address => uint256) public stakeAmounts;
    mapping(address => uint256) public availableAmounts;
    mapping(uint256 => DepositLock) private depositMap;
    uint256 private depositLockId;
    struct DepositLock{
        address account;
        uint256 amount;
        uint256 createTime;
    }

    event Deposit(uint256 indexed id,address user,address tokenContract,uint256 depositAmount,uint256 userBalance,uint256 vaultBalance,uint256 lockId,uint256 createTime);
    event Withdraw(uint256 indexed id,address user,address tokenContract,uint256 withdrawAmount,uint256 userBalance,uint256 vaultBalance,uint256 createTime);
    event MoveToken(address receiver,address tokenContract,uint256 amount,uint256 createTime);
    event UpdateDataStorage(address user,address oldStorage,address currentStorage);
    event UnLockDeposit(uint256 indexed lockId,address user,uint256 amount,uint256 createTime);
    event UpdateLockTime(uint256 oldLockTime,uint256 currentLockTime);
    event UpdateMaxLockAmount(uint256 oldLockAmount,uint256 currentLockAmount);

    constructor(address storageContract,address tokenContract,uint256 initialLockTime,uint256 initialMaxLockAmount) {
        require(storageContract != address(0) && tokenContract != address(0),"Invalid Zero Address");
        dataStorage = IDataStorage(storageContract);
        token = tokenContract;

        lockTime = initialLockTime;
        maxLockAmount = initialMaxLockAmount;
    }

    function deposit(uint256 amount) external{
        _deposit(msg.sender,amount);
    }

    function _deposit(address account,uint256 amount) internal nonReentrant{
        require(totalStakeAmount + amount <= maxLockAmount,"Insufficient available staking amount");
        require(amount >= dataStorage.minDepositMap(address(this)),"Deposit amount too small");
        uint256 beforeBalance = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransferFrom(account, address(this), amount);
        uint256 afterBalance = IERC20(token).balanceOf(address(this));
        amount = afterBalance - beforeBalance;
        stakeAmounts[account] += amount;
        totalStakeAmount += amount;
        emit Deposit(setEventId(),account,token,amount,stakeAmounts[account],totalStakeAmount,getDepositLockLength(),block.timestamp);
        depositMap[setDepositLockId()] = DepositLock(account,amount,block.timestamp);
    }

    function withdraw(uint256 amount) external{
        _withdraw(msg.sender,amount);
    }

    function withdrawAndUnlockDeposit(uint256 amount,uint256[] memory ids) external {
        unLockDeposit(ids);
        _withdraw(msg.sender,amount);
    }

    function _withdraw(address account,uint256 amount) internal nonReentrant{
        require(stakeAmounts[account] >= amount,"Insufficient balance");
        require(availableAmounts[account] >= amount,"Not enough available balance");
        stakeAmounts[account] -= amount;
        availableAmounts[account] -= amount;

        IERC20(token).safeTransfer(account,amount);
        totalStakeAmount -= amount;
        emit Withdraw(setEventId(),account, token, amount, stakeAmounts[account], totalStakeAmount, block.timestamp);
    }

    function unLockDeposit(uint256[] memory ids) public {
        for(uint256 i; i<ids.length; i++){
            _unLockDeposit(ids[i]);
        }
    }

    function _unLockDeposit(uint256 id) internal nonReentrant{
        DepositLock memory depositLock= depositMap[id];
        require(depositLock.createTime + lockTime <= block.timestamp,"The unlock time has not been reached");
        if(depositLock.amount == 0){
            return;
        }
        emit UnLockDeposit(id,depositLock.account,depositLock.amount,block.timestamp);

        availableAmounts[depositLock.account] += depositLock.amount;
        depositLock.amount = 0;
        depositMap[id] = depositLock;
    }

    function moveToken(address receiver,address tokenContract,uint256 amount) external onlyOwner{
        if(token == tokenContract){
            require(IERC20(token).balanceOf(address(this)) - totalStakeAmount >= amount,"Not enough airdrops");
        }else{
            if(amount == type(uint256).max){
                amount = IERC20(tokenContract).balanceOf(address(this));
            }
        }
        IERC20(tokenContract).safeTransfer(receiver,amount);
        emit MoveToken(receiver,tokenContract,amount,block.timestamp);
    }

    function setEventId() internal returns(uint256){
        return eventId++;
    }

    function updateDataStorageContract(address storageContract) external onlyOwner{
        require(storageContract != address(0),"Invalid Zero Address");
        emit UpdateDataStorage(msg.sender,address(dataStorage),storageContract);
        dataStorage = IDataStorage(storageContract);
        require(dataStorage.owner() != address(0),"Invalid Owner Address");
    }

    function updateLockTime(uint256 second) external onlyOwner{
        require(second <= MAX_LOCK_TIME,"Invalid Lock Time");
        emit UpdateLockTime(lockTime,second);
        lockTime = second;
    }

    function updateMaxLockAmount(uint256 amount) external onlyOwner{
        emit UpdateMaxLockAmount(maxLockAmount,amount);
        maxLockAmount = amount;
    }

    function setDepositLockId() internal returns(uint256) {
        return depositLockId++;
    }

    function getDepositLockInfo(uint256[] memory ids) public view returns(DepositLock[] memory) {
        DepositLock[] memory list = new DepositLock[](ids.length);
        for(uint256 i; i<ids.length; i++){
            list[i] = depositMap[ids[i]];
        }
        return list;
    }

    function getDepositLockLength() public view returns(uint256) {
        return depositLockId;
    }

    function getAvailableAmount(address account,uint256[] memory ids) public view returns(uint256){
        uint256 amount = availableAmounts[account];
        for(uint256 i; i<ids.length; i++){
            DepositLock memory depositLock = depositMap[ids[i]];
            if(depositLock.account == account){
                amount = depositLock.amount;
            }
        }
        return amount;
    }

    modifier onlyOwner()  {
        require(dataStorage.owner() == msg.sender,"Caller is not owner");
        _;
    }
}
