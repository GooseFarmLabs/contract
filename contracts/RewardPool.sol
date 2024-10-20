// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "./interfaces/IDataStorage.sol";

contract RewardPool is ReentrancyGuardUpgradeable{
    using SafeERC20 for IERC20;
    IDataStorage public dataStorage;

    // reward token => account => already claim amount
    mapping(address => mapping(address => uint256)) public claimedRewards;
    // reward token => root
    mapping(address => bytes32) public rootMap;
    mapping(bytes32 => bool) public verified;

    event Claim(address account,address token,uint256 claimAmount,uint256 totalAmount,uint256 createTime);
    event UpdateRootAndToken(bytes32 root,address token);
    event UpdateDataStorage(address user,address oldStorage,address currentStorage);

    constructor(address storageContract){
        require(storageContract != address(0),"Invalid Zero Address");
        dataStorage = IDataStorage(storageContract);
    }

    function setRootAndToken(bytes32 root, address token) external onlyOwner{
        rootMap[token] = root;
        emit UpdateRootAndToken(root,token);
    }

    function claimAll(address account,address[] memory tokens,uint256[] memory amounts,bytes32[][] calldata merkleProofs) external{
        for(uint256 i; i<tokens.length; i++){
            claim(account,tokens[i],amounts[i],merkleProofs[i]);
        }
    }

    function claim(address account,address token,uint256 amount,bytes32[] calldata merkleProof) public nonReentrant{
        require(claimedRewards[token][account] < amount,"Already claimed");
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(getChainId(), account, amount))));
        require(!verified[leaf],"Already verify");
        require(MerkleProof.verifyCalldata(merkleProof,rootMap[token],leaf),"Invalid proof");
        require(IERC20(token).balanceOf(address(this)) >= amount - claimedRewards[token][account],"Insufficient balance");
        IERC20(token).safeTransfer(account,amount - claimedRewards[token][account]);

        emit Claim(account,token,amount - claimedRewards[token][account],amount,block.timestamp);

        claimedRewards[token][account] = amount;

        verified[leaf] = true;
    }

    function updateDataStorageContract(address storageContract) external onlyOwner{
        require(storageContract != address(0),"Invalid Zero Address");
        emit UpdateDataStorage(msg.sender,address(dataStorage),storageContract);
        dataStorage = IDataStorage(storageContract);
        require(dataStorage.owner() != address(0),"Invalid Owner Address");
    }

    function getChainId() internal view returns (uint256) {
        return block.chainid;
    }

    modifier onlyOwner()  {
        require(dataStorage.owner() == msg.sender,"Caller is not owner");
        _;
    }
}
