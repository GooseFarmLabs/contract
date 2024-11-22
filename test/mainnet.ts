import {ethers, ignition} from "hardhat";
import GooseMainnetModule from "../ignition/modules/DeployMainnet";


describe("GooseContract", function () {

    async function deployGooseContractFixture(){
        const [owner] = await ethers.getSigners();
        const {dataStorage,vaultFactory} = await ignition.deploy(GooseMainnetModule,{
            parameters: {
                GooseMainnetModule: {
                    owner: owner.address
                }
            }
        });
        return {dataStorage,vaultFactory,owner};
    }
    describe("Deploy To Ethereum Testnet",function (){
        it("deploy contract", async () => {
            const { dataStorage,vaultFactory } = await deployGooseContractFixture();
        }).timeout(1000000);
    });
});
