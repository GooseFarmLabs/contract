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

contract CustomizedVault is ReentrancyGuardUpgradeable{
    using SafeERC20 for IERC20;

    IDataStorage public dataStorage;
    LpToken public lpToken;
    address public token;      // U Token contract address
    uint256 public eventId;

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

    event UpdateDataStorage(address user,address oldStorage,address currentStorage);
    event CreateLp(address lp);

    constructor(address storageContract,address tokenContract) {
        require(storageContract != address(0) && tokenContract != address(0),"Invalid Zero Address");
        token = tokenContract;
        dataStorage = IDataStorage(storageContract);

        lpToken = new LpToken(tokenContract,string.concat('VLpToken-',IERC20Metadata(tokenContract).name()),string.concat('VLP-',IERC20Metadata(tokenContract).symbol()),IERC20Metadata(tokenContract).decimals());
        emit CreateLp(address(lpToken));
    }

    function deposit(address account,uint256 amount,uint256 minShare) external onlyOwner{
        _deposit(account,amount,minShare);
    }

    function _deposit(address account,uint256 amount,uint256 minShare) internal{
        uint256 shares = lpToken.mint(amount,minShare);

        balanceMap[account] += shares;

        emit Deposit(setEventId(),account,amount,shares,lpToken.price(),getDepositLockLength(),0,lpToken.totalSupply(),block.timestamp);

        depositMap[setDepositLockId()] = DepositLock(account,shares,block.timestamp);
        _unLockDeposit(getDepositLockLength() - 1);
    }

    function _unLockDeposit(uint256 id) internal{
        DepositLock memory depositLock= depositMap[id];
        if(depositLock.share == 0){
            return;
        }
        emit UnLockDeposit(id,depositLock.account,depositLock.share,block.timestamp);

        availableShare[depositLock.account] += depositLock.share;
        depositLock.share = 0;
        depositMap[id] = depositLock;
    }

    function withdraw(uint256[] memory ids) external onlyOwner{
        for(uint256 i; i<ids.length; i++){
            _withdraw(ids[i]);
        }
    }

    function _withdraw(uint256 id) internal{
        RedeemLock memory redeemLock = redeemMap[id];
        if(redeemLock.share == 0){
            return;
        }

        emit Withdraw(setEventId(),redeemLock.account,redeemLock.assetAmount,redeemLock.share,redeemLock.price,lpToken.totalSupply(),block.timestamp);
        emit UnLockRedeem(id,redeemLock.account,redeemLock.share,block.timestamp);

        balanceMap[redeemLock.account] -= redeemLock.share;
        redeemLock.share = 0;
        redeemLock.assetAmount = 0;
        redeemMap[id] = redeemLock;
    }

    function redeem(address account,uint256 share,uint256 minAssetAmount) external onlyOwner{
        _redeem(account,share,minAssetAmount);
    }

    function _redeem(address account,uint256 share,uint256 minAssetAmount) internal{
        require(availableShare[account] >= share,"Available balance not enough");

        uint256 assetAmount = lpToken.convertToAssets(share);
        require(assetAmount >= minAssetAmount,"Asset amount error");

        availableShare[account] -= share;
        lpToken.burn(share,0);
        emit Redeem(setEventId(),account,assetAmount,share,lpToken.price(),getRedeemLockLength(),0,lpToken.totalSupply(),block.timestamp);

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

    modifier onlyOwner()  {
        require(dataStorage.owner() == msg.sender,"Caller is not owner");
        _;
    }
}
