// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./ERC20.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "./interfaces/IDataStorage.sol";
import "./USDVault.sol";

contract LpToken is ERC20,ReentrancyGuardUpgradeable{

    uint256 public constant MAX_DEVIATION = 1000;
    address public vault;
    address private immutable _asset;
    uint256 public price;     // total stake USDT / lpToken totalSupply
    uint256 public maxDeviation = 20; // max 10000
    uint256 public updateTime;
    uint256 public constant INTERVAL_TIME = 12 hours;
    uint8 public PRICE_DECIMAL;

    event UpdateIntervalTime(uint256 oldIntervalTime,uint256 currentIntervalTime);
    event UpdateDeviation(uint256 oldDeviation,uint256 currentDeviation);
    event UpdateDataStorage(address user,address oldStorage,address currentStorage);
    event UpdatePrice(address account,uint256 oldPrice,uint256 currentPrice);

    constructor(address assetToken,string memory name,string memory symbol,uint8 decimals) ERC20(name,symbol,decimals){
        _asset = assetToken;
        vault = msg.sender;
        price = 10 ** decimals;
        PRICE_DECIMAL = decimals;
    }

    function mint(uint256 assetAmount,uint256 minShareAmount) external nonReentrant onlyVault returns(uint256){
        uint256 shares = convertToShares(assetAmount);
        require(shares >= minShareAmount,"Insufficient output shares");
        _mint(address(this),shares);
        return shares;
    }

    function burn(uint256 shares,uint256 minAssetAmount) external nonReentrant onlyVault{
        uint256 assetAmount = convertToAssets(shares);
        require(assetAmount >= minAssetAmount,"Insufficient output asset");
        _burn(address(this),shares);
    }

    function updatePrice(uint256 currentPrice) external onlyManager{
        require(block.timestamp - updateTime > INTERVAL_TIME,"UpdateTime Error");
        updateTime = block.timestamp;

        uint256 max = price * (10000 + maxDeviation) / 10000;
        uint256 min = price * (10000 - maxDeviation) / 10000;
        require(currentPrice >= min && currentPrice <= max,"Price exceeded");
        emit UpdatePrice(msg.sender,price,currentPrice);
        price = currentPrice;
    }

    function forceUpdatePrice(uint256 currentPrice) external onlyOwner{
        require(block.timestamp - updateTime > INTERVAL_TIME,"UpdateTime Error");
        updateTime = block.timestamp;
        uint256 maxPrice = price * (10000 + MAX_DEVIATION) / 10000;
        uint256 minPrice = price * (10000 - MAX_DEVIATION) / 10000;
        require(currentPrice >= minPrice && currentPrice <= maxPrice,"Price exceeded");
        emit UpdatePrice(msg.sender,price,currentPrice);
        price = currentPrice;
    }

    function updateDeviation(uint256 deviation) external onlyOwner {
        require(deviation > 0 && deviation <= MAX_DEVIATION,"Deviation Error");
        emit UpdateDeviation(maxDeviation,deviation);
        maxDeviation = deviation;
    }

    function convertToShares(uint256 assets) public view virtual returns (uint256) {
        return assets * (10 ** PRICE_DECIMAL) / price;
    }

    function convertToAssets(uint256 shares) public view virtual returns (uint256) {
        return shares *  price / (10 ** PRICE_DECIMAL);
    }

    function asset() public view returns (address) {
        return address(_asset);
    }

    modifier onlyManager() {
        require(IDataStorage(USDVault(vault).dataStorage()).manager() == msg.sender,"Caller is not manager");
        _;
    }

    modifier onlyVault()  {
        require(vault == msg.sender,"Caller is not vault");
        _;
    }

    modifier onlyOwner() {
        require(IDataStorage(USDVault(vault).dataStorage()).owner() == msg.sender,"Caller is not owner");
        _;
    }
}
