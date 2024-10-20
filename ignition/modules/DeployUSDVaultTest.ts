const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

// const storageContract = "0xdC154f5A1427AF9Ae0278c03FaFb06BB80B5EF70";
// const tokenContract = "0x08B7C366d6494ac6F74Fec4976e4A12D7bb7f7F4";

const USDVaultTestModule = buildModule("USDVaultTestModule", (m) => {
    const storageContract = m.getParameter("storageContract");
    const tokenContract = m.getParameter("tokenContract");
    const USDContract = m.contract("USDVault", [storageContract,tokenContract]);
    return { USDContract };
});

export default USDVaultTestModule;
