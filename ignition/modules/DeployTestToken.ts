const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

const TestTokenModule = buildModule("TestTokenModule", (m) => {
    const testToken = m.contract("TestToken", []);
    return { testToken };
});

export default TestTokenModule;
