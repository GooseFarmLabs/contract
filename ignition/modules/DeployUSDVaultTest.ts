const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

const USDVaultTestModule = buildModule("USDVaultTestModule", (m) => {
    const storageContract = m.getParameter("storageContract");
    const tokenContract = m.getParameter("tokenContract");
    const USDContract = m.contract("USDVault", [storageContract,tokenContract]);
    return { USDContract };
});

export default USDVaultTestModule;
