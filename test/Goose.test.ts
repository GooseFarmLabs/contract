import { loadFixture,setBalance } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import GooseTestModule from "../ignition/modules/DeployGooseTest";
import {ethers, ignition} from "hardhat";
import TestTokenModule from "../ignition/modules/DeployTestToken";
import LRTVaultTestModule from "../ignition/modules/DeployLRTVaultTest";
import USDVaultTestModule from "../ignition/modules/DeployUSDVaultTest";


describe("GooseContract", function () {

    const TOKEN_DECIMALS = 18;

    const DEPOSIT_LOCK_TIME = 864000n;
    const REDEEM_LOCK_TIME = 86400n;
    const MIN_DEPOSIT_AMOUNT = 100n;
    const ERROR_DEPOSIT_AMOUNT = 80n;
    const depositAmount = 500n;
    const ERROR_WITHDRAW_AMOUNT = 1000n;

    async function deployGooseContractFixture(){
        const [owner,addr1,addr2] = await ethers.getSigners();
        const {dataStorage,vaultFactory,rewardPool} = await ignition.deploy(GooseTestModule,{
            parameters: {
                GooseTestModule: {
                    owner: owner.address,
                    manager: addr1.address
                }
            }
        });
        const {testToken} = await ignition.deploy(TestTokenModule,{});
        return {dataStorage,vaultFactory,rewardPool,testToken,owner,addr1,addr2};
    }

    describe("USDVault Contract Test",function (){
        it("deposit token to USDVault contract", async () =>{
            const { dataStorage,testToken,addr1,addr2 } = await loadFixture(deployGooseContractFixture);
            const { USDContract } = await ignition.deploy(USDVaultTestModule,{
                parameters: {
                    USDVaultTestModule: {
                        storageContract: await dataStorage.getAddress(),
                        tokenContract: await testToken.getAddress()
                    }
                }
            });
            await USDContract.updateCustodian(addr2);
            await testToken.approve(USDContract.getAddress(),ethers.MaxUint256);
            await expect(USDContract.deposit(10n ** BigInt(TOKEN_DECIMALS) * depositAmount,0)).to.not.be.reverted;
            await expect(USDContract.deposit(10n ** BigInt(TOKEN_DECIMALS) * ERROR_DEPOSIT_AMOUNT,0)).to.not.be.reverted;
            await expect(dataStorage.connect(addr1).setVaultMinDeposit(await USDContract.getAddress(),10n ** BigInt(TOKEN_DECIMALS) * MIN_DEPOSIT_AMOUNT)).to.not.be.reverted;
            await expect(USDContract.deposit(10n ** BigInt(TOKEN_DECIMALS) * ERROR_DEPOSIT_AMOUNT,0)).to.be.reverted;
        });
        it("redeem token for USDVault contract", async () =>{
            const { dataStorage,testToken,owner,addr1,addr2 } = await loadFixture(deployGooseContractFixture);
            const { USDContract } = await ignition.deploy(USDVaultTestModule,{
                parameters: {
                    USDVaultTestModule: {
                        storageContract: await dataStorage.getAddress(),
                        tokenContract: await testToken.getAddress()
                    }
                }
            });
            await expect(USDContract.updateCustodian(addr2)).to.not.be.reverted;
            await testToken.approve(USDContract.getAddress(),ethers.MaxUint256);
            await expect(USDContract.deposit(10n ** BigInt(TOKEN_DECIMALS) * depositAmount,0)).to.not.be.reverted;
            await expect(USDContract.redeemAndUnLockDeposit(10n ** BigInt(TOKEN_DECIMALS) * depositAmount,0,[0])).to.be.reverted;
            await expect(dataStorage.connect(addr1).updateDepositLockTime(DEPOSIT_LOCK_TIME)).to.not.be.reverted;
            await ethers.provider.send("evm_increaseTime",[864000]);
            await expect(USDContract.redeemAndUnLockDeposit(10n ** BigInt(TOKEN_DECIMALS) * depositAmount,0,[0])).to.not.be.reverted;
            const result = await USDContract.getDepositLockInfo([0]);
            expect(result[0].account).to.be.equal(owner.address);
            expect(result[0].share).to.be.equal(0);

        });
        it("withdraw token for USDVault contract", async () =>{
            const { dataStorage,testToken,owner,addr1,addr2 } = await loadFixture(deployGooseContractFixture);
            const { USDContract } = await ignition.deploy(USDVaultTestModule,{
                parameters: {
                    USDVaultTestModule: {
                        storageContract: await dataStorage.getAddress(),
                        tokenContract: await testToken.getAddress()
                    }
                }
            });
            await expect(USDContract.updateCustodian(addr2)).to.not.be.reverted;
            await testToken.approve(USDContract.getAddress(),ethers.MaxUint256);
            await expect(USDContract.deposit(10n ** BigInt(TOKEN_DECIMALS) * depositAmount,0)).to.not.be.reverted;
            await expect(dataStorage.connect(addr1).updateDepositLockTime(DEPOSIT_LOCK_TIME)).to.not.be.reverted;
            await ethers.provider.send("evm_increaseTime",[864000]);
            await expect(USDContract.redeemAndUnLockDeposit(10n ** BigInt(TOKEN_DECIMALS) * depositAmount,0,[0])).to.not.be.reverted;
            await testToken.transfer(USDContract.getAddress(),10n ** BigInt(TOKEN_DECIMALS) * depositAmount);
            const ids = [0];
            await expect(USDContract.withdraw(ids)).to.be.reverted;
            await expect(dataStorage.connect(addr1).updateRedeemLockTime(REDEEM_LOCK_TIME)).to.not.be.reverted;
            await ethers.provider.send("evm_increaseTime",[86400]);
            await expect(USDContract.withdraw(ids)).to.not.be.reverted;
        });
    });

    describe("LRTVault Contract Test",function (){
        it("deposit token to LRTVault contract",async () =>{
            const { dataStorage,testToken,addr1 } = await loadFixture(deployGooseContractFixture);
            const { LRTContract } = await ignition.deploy(LRTVaultTestModule,{
                parameters: {
                    LRTVaultTestModule: {
                        storageContract: await dataStorage.getAddress(),
                        tokenContract: await testToken.getAddress()
                    }
                }
            });
            await testToken.approve(LRTContract.getAddress(),ethers.MaxUint256);
            await expect(LRTContract.deposit(10n ** BigInt(TOKEN_DECIMALS) * ERROR_DEPOSIT_AMOUNT)).to.not.be.reverted;
            await expect(dataStorage.connect(addr1).setVaultMinDeposit(await LRTContract.getAddress(),10n ** BigInt(TOKEN_DECIMALS) * MIN_DEPOSIT_AMOUNT)).to.not.be.reverted;
            await expect(LRTContract.deposit(10n ** BigInt(TOKEN_DECIMALS) * ERROR_DEPOSIT_AMOUNT)).to.be.reverted;
        });
        it("withdraw token for LRTVault contract",async () =>{
            const { dataStorage,testToken,addr1 } = await loadFixture(deployGooseContractFixture);
            const { LRTContract } = await ignition.deploy(LRTVaultTestModule,{
                parameters: {
                    LRTVaultTestModule: {
                        storageContract: await dataStorage.getAddress(),
                        tokenContract: await testToken.getAddress()
                    }
                }
            });
            await testToken.approve(LRTContract.getAddress(),ethers.MaxUint256);
            await expect(LRTContract.deposit(10n ** BigInt(TOKEN_DECIMALS) * depositAmount)).to.not.be.reverted;
            await expect(LRTContract.withdraw(10n ** BigInt(TOKEN_DECIMALS) * ERROR_WITHDRAW_AMOUNT)).to.be.reverted;
            await expect(LRTContract.connect(addr1).withdraw(10n ** BigInt(TOKEN_DECIMALS) * depositAmount)).to.be.reverted;
            await expect(LRTContract.withdraw(10n ** BigInt(TOKEN_DECIMALS) * depositAmount)).to.not.be.reverted;
        });
    });

    describe("VaultFactory Contract Test",function (){
        it("create LRT vault contract",async () =>{
            const { vaultFactory,testToken } = await loadFixture(deployGooseContractFixture);
            await expect(await vaultFactory.createLRTVault(testToken)).to.not.be.reverted;
        });
        it("create USD vault contract",async () =>{
            const { vaultFactory,testToken } = await loadFixture(deployGooseContractFixture);
            await expect(await vaultFactory.createUSDVault(testToken)).to.not.be.reverted;
        });
    });

    describe("DataStorage Contract Test", function (){
       it("check owner address",async () =>{
           const { dataStorage,owner } = await loadFixture(deployGooseContractFixture);
           expect(await dataStorage.owner()).to.be.equal(owner.address);
       });
        it("check manager address",async () =>{
            const { dataStorage,addr1 } = await loadFixture(deployGooseContractFixture);
            expect(await dataStorage.manager()).to.be.equal(addr1.address);
        });
       it("could not updateDepositLockTime if not owner",async () =>{
           const { dataStorage,addr2 } = await loadFixture(deployGooseContractFixture);
           await expect(dataStorage.connect(addr2).updateDepositLockTime(DEPOSIT_LOCK_TIME)).to.be.reverted;
       });
       it("should be able to updateDepositLockTime by owner",async () =>{
           const { dataStorage,addr1 } = await loadFixture(deployGooseContractFixture);
           await expect(dataStorage.connect(addr1).updateDepositLockTime(DEPOSIT_LOCK_TIME)).to.not.be.reverted;
       });
       it("could not updateRedeemLockTime if not owner",async () =>{
           const { dataStorage,addr2 } = await loadFixture(deployGooseContractFixture);
           await expect(dataStorage.connect(addr2).updateRedeemLockTime(REDEEM_LOCK_TIME)).to.be.reverted;
       });
       it("should be able to updateRedeemLockTime by owner",async () =>{
           const { dataStorage,addr1 } = await loadFixture(deployGooseContractFixture);
           await expect(dataStorage.connect(addr1).updateRedeemLockTime(REDEEM_LOCK_TIME)).to.not.be.reverted;
       });
       it("could not setVaultMinDeposit if not owner",async () =>{
           const { dataStorage,vaultFactory,testToken,addr2 } = await loadFixture(deployGooseContractFixture);
           const tx = await vaultFactory.createLRTVault(await testToken.getAddress());
           const data = await ethers.provider.getTransactionReceipt(tx.hash);
           const logs = data?.logs;
           const lrtVaultAddress = '0x' + logs[0].data.substring(26,66);
           await expect(dataStorage.connect(addr2).setVaultMinDeposit(lrtVaultAddress,10n ** BigInt(TOKEN_DECIMALS) * MIN_DEPOSIT_AMOUNT)).to.be.reverted;
       });
       it("should be able to setVaultMinDeposit by owner",async () =>{
           const { dataStorage,vaultFactory,testToken,addr1 } = await loadFixture(deployGooseContractFixture);
           const tx = await vaultFactory.createLRTVault(await testToken.getAddress());
           const data = await ethers.provider.getTransactionReceipt(tx.hash);
           const logs = data?.logs;
           const lrtVaultAddress = '0x' + logs[0].data.substring(26,66);
           await expect(dataStorage.connect(addr1).setVaultMinDeposit(lrtVaultAddress,10n ** BigInt(TOKEN_DECIMALS) * MIN_DEPOSIT_AMOUNT)).to.not.be.reverted;
       });
    });



});
