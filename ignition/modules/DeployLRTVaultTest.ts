const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

const LRTVaultTestModule = buildModule("LRTVaultTestModule", (m) => {
    const storageContract = m.getParameter("storageContract");
    const tokenContract = m.getParameter("tokenContract");
    const LRTContract = m.contract("LRTVault", [storageContract,tokenContract,3600,10000000000000000000000n]);
    return { LRTContract };
});

export default LRTVaultTestModule;
