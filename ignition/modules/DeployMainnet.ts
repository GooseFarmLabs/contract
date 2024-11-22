const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

// 30 days
const DEPOSIT_LOCK_TIME = 2592000;
// 14 days
const REDEEM_LOCK_TIME = 1209600;

const GooseMainnetModule = buildModule("GooseMainnetModule", (m) => {
    const owner = m.getParameter("owner");
    const dataStorage = m.contract("DataStorage", [owner,owner,DEPOSIT_LOCK_TIME,REDEEM_LOCK_TIME]);
    const vaultFactory = m.contract("VaultFactory", [dataStorage]);
    return { dataStorage,vaultFactory };
});

export default GooseMainnetModule;
