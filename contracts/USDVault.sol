// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// Uncomment this line to use console.log
// import "hardhat/console.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "./interfaces/IDataStorage.sol";
import "./LpToken.sol";

contract USDVault is ReentrancyGuardUpgradeable{
    using SafeERC20 for IERC20;

    uint256 public constant MAX_REDEEM_LOCK_TIME = 60 days;
    uint256 public constant UPDATE_CUSTODIAN_WAITING_TIME = 2 days;
    uint256 public updatePreCustodianTime;

    IDataStorage public dataStorage;
    LpToken public lpToken;
    address public token;      // U Token contract address
    address public custodian;
    address private preCustodian;
    uint256 public eventId;
    bool private _initializing;

    mapping(address => uint256) public balanceMap;    // user total share balance
    mapping(address => uint256) public availableShare; // user avalible share balance

    mapping(uint256 => DepositLock) private depositMap;
    uint256 private depositLockId;
    mapping(uint256 => RedeemLock) private redeemMap;
    uint256 private redeemLockId;

    struct DepositLock{
        address account;
        uint256 share;
        uint256 createTime;
    }

    struct RedeemLock{
        address account;
        uint256 assetAmount;
        uint256 share;      // lp amount
        uint256 price;       // total USD / total shares
        uint256 createTime;
    }

    event Deposit(uint256 indexed id,address user,uint256 depositAsset,uint256 depositShare,uint256 price,uint256 lockId,uint256 lockTime,uint256 totalShares,uint256 createTime);
    event Withdraw(uint256 indexed id,address user,uint256 withdrawAsset,uint256 withdrawShare,uint256 price,uint256 totalShares,uint256 createTime);
    event Redeem(uint256 indexed id,address user,uint256 redeemAsset,uint256 redeemShare,uint256 price,uint256 lockId,uint256 lockTime,uint256 totalShares,uint256 createTime);

    event UnLockDeposit(uint256 indexed lockId,address user,uint256 share,uint256 createTime);
    event UnLockRedeem(uint256 indexed lockId,address user,uint256 share,uint256 createTime);

    event UpdateCustodian(address user,address oldCustodian,address currentCustodian);
    event UpdatePreCustodian(address user,address oldCustodian,address currentCustodian);
    event UpdateDataStorage(address user,address oldStorage,address currentStorage);
    event CreateLp(address lp);

    constructor(address storageContract,address tokenContract) {
        require(storageContract != address(0) && tokenContract != address(0),"Invalid Zero Address");
        token = tokenContract;
        dataStorage = IDataStorage(storageContract);

        lpToken = new LpToken(tokenContract,string.concat('LpToken-',IERC20Metadata(tokenContract).name()),string.concat('LP-',IERC20Metadata(tokenContract).symbol()),IERC20Metadata(tokenContract).decimals());
        emit CreateLp(address(lpToken));
    }

    function deposit(uint256 amount,uint256 minShare) external{
        _deposit(msg.sender,amount,minShare);
    }

    function _deposit(address account,uint256 amount,uint256 minShare) internal nonReentrant{
        require(amount >= dataStorage.minDepositMap(address(this)),"Deposit amount too small");
        require(custodian != address(0),"Invalid custodian Address");
        uint256 beforeBalance = IERC20(token).balanceOf(custodian);
        IERC20(token).safeTransferFrom(account, custodian, amount);
        uint256 afterBalance = IERC20(token).balanceOf(custodian);
        amount = afterBalance - beforeBalance;

        uint256 shares = lpToken.mint(amount,minShare);

        balanceMap[account] += shares;

        emit Deposit(setEventId(),account,amount,shares,lpToken.price(),getDepositLockLength(),dataStorage.depositLockTime(),lpToken.totalSupply(),block.timestamp);

        depositMap[setDepositLockId()] = DepositLock(account,shares,block.timestamp);
    }

    function unLockDeposit(uint256[] memory ids) public{
        for(uint256 i; i<ids.length; i++){
            _unLockDeposit(ids[i]);
        }
    }

    function _unLockDeposit(uint256 id) internal nonReentrant{
        DepositLock memory depositLock= depositMap[id];
        require(depositLock.createTime + dataStorage.depositLockTime() <= block.timestamp,"Lock time not enough");
        if(depositLock.share == 0){
            return;
        }
        emit UnLockDeposit(id,depositLock.account,depositLock.share,block.timestamp);

        availableShare[depositLock.account] += depositLock.share;
        depositLock.share = 0;
        depositMap[id] = depositLock;
    }

    function withdraw(uint256[] memory ids) external{
        for(uint256 i; i<ids.length; i++){
            _withdraw(ids[i]);
        }
    }

    function _withdraw(uint256 id) internal nonReentrant{
        RedeemLock memory redeemLock = redeemMap[id];
        uint256 lockTime = dataStorage.redeemLockTime();
        if(lockTime > MAX_REDEEM_LOCK_TIME){
            lockTime = MAX_REDEEM_LOCK_TIME;
        }
        require(redeemLock.createTime + lockTime <= block.timestamp,"Lock time not enough");
        if(redeemLock.share == 0){
            return;
        }

        IERC20(token).safeTransfer(redeemLock.account,redeemLock.assetAmount);

        emit Withdraw(setEventId(),redeemLock.account,redeemLock.assetAmount,redeemLock.share,redeemLock.price,lpToken.totalSupply(),block.timestamp);
        emit UnLockRedeem(id,redeemLock.account,redeemLock.share,block.timestamp);

        balanceMap[redeemLock.account] -= redeemLock.share;
        redeemLock.share = 0;
        redeemLock.assetAmount = 0;
        redeemMap[id] = redeemLock;
    }

    function redeemAndUnLockDeposit(uint256 amount,uint256 minAssetAmount,uint256[] memory ids) external {
        unLockDeposit(ids);
        _redeem(msg.sender,amount,minAssetAmount);
    }

    function redeem(uint256 share,uint256 minAssetAmount) external {
        _redeem(msg.sender,share,minAssetAmount);
    }

    function _redeem(address account,uint256 share,uint256 minAssetAmount) internal nonReentrant{
        require(availableShare[account] >= share,"Available balance not enough");

        uint256 assetAmount = lpToken.convertToAssets(share);
        require(assetAmount >= minAssetAmount,"Asset amount error");

        availableShare[account] -= share;
        lpToken.burn(share,0);
        emit Redeem(setEventId(),account,assetAmount,share,lpToken.price(),getRedeemLockLength(),dataStorage.redeemLockTime(),lpToken.totalSupply(),block.timestamp);

        redeemMap[setRedeemLockId()] = RedeemLock(account,assetAmount,share,lpToken.price(),block.timestamp);
    }

    function setDepositLockId() internal returns(uint256) {
        return depositLockId++;
    }

    function setRedeemLockId() internal returns (uint256) {
        return redeemLockId++;
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

    function getRedeemLockInfo(uint256[] memory ids) public view returns(RedeemLock[] memory) {
        RedeemLock[] memory list = new RedeemLock[](ids.length);
        for(uint256 i; i<ids.length; i++){
            list[i] = redeemMap[ids[i]];
        }
        return list;
    }

    function getRedeemLockLength() public view returns(uint256) {
        return redeemLockId;
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

    function getWithdrawAmount(address account,uint256[] memory ids) external view returns (uint256,uint256) {
        uint256 assetAmount;
        uint256 share;
        for(uint256 i; i<ids.length; i++){
            RedeemLock memory redeemLock = redeemMap[ids[i]];
            if(account == redeemLock.account){
                share += redeemLock.share;
                assetAmount += redeemLock.assetAmount;
            }
        }
        return (assetAmount,share);
    }

    function getAvailableAmount(address account,uint256[] memory ids) external view returns(uint256){
        uint256 available = availableShare[account];
        for(uint256 i; i<ids.length; i++){
            DepositLock memory depositLock = depositMap[ids[i]];
            if(account == depositLock.account){
                available += depositLock.share;
            }
        }
        return available;
    }

    function updatePreCustodian(address account) external onlyOwner {
        require(account != address(0),"Invalid Zero Address");
        emit UpdatePreCustodian(msg.sender,preCustodian,account);
        preCustodian = account;
        updatePreCustodianTime = block.timestamp;
    }

    function initialCustodian(address account) external onlyOwner{
        require(!_initializing,"Already Initialized");
        _initializing = true;
        emit UpdateCustodian(msg.sender,custodian,account);
        custodian = account;
    }

    function updateCustodian(address account) external onlyOwner {
        require(account == preCustodian,"Invalid Custodian Address");
        require(updatePreCustodianTime + UPDATE_CUSTODIAN_WAITING_TIME <= block.timestamp,"Insufficient Waiting Time");
        emit UpdateCustodian(msg.sender,custodian,preCustodian);
        custodian = preCustodian;
    }

    modifier onlyOwner()  {
        require(dataStorage.owner() == msg.sender,"Caller is not owner");
        _;
    }
}
