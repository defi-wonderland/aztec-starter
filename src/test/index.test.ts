import { EasyPrivateVotingContractArtifact, EasyPrivateVotingContract } from "../artifacts/EasyPrivateVoting.js"
import { TokenContract } from '@aztec/noir-contracts.js/Token';
import { AccountWallet, CompleteAddress, ContractDeployer, createLogger, Fr, PXE, waitForPXE, TxStatus, createPXEClient, getContractInstanceFromDeployParams, Logger, ContractInstanceWithAddress, ContractFunctionInteraction } from "@aztec/aztec.js";
import { getInitialTestAccountsWallets } from "@aztec/accounts/testing"

const setupSandbox = async () => {
    const { PXE_URL = 'http://localhost:8080' } = process.env;
    // TODO: implement reading the DelegationNote from an isolated PXE
    // 8080: cd ~/.aztec && docker-compose -f ./docker-compose.sandbox.yml up
    // 8081: aztec start --port 8081 --pxe --pxe.nodeUrl http://host.docker.internal:8080/
    // const DELEGATEE_PXE_URL = 'http://localhost:8081';

    const pxe = createPXEClient(PXE_URL);
    await waitForPXE(pxe);
    return pxe;
};

describe("Voting", () => {
    let pxe: PXE;
    let wallets: AccountWallet[] = [];
    let tokenAdmin: AccountWallet;
    let accounts: CompleteAddress[] = [];
    let tokenContract: TokenContract;
    let logger: Logger;
    let action: ContractFunctionInteraction;

    beforeAll(async () => {
        logger = createLogger('aztec:aztec-starter');
        logger.info("Aztec-Starter tests running.")

        pxe = await setupSandbox();

        wallets = await getInitialTestAccountsWallets(pxe);
        accounts = wallets.map(w => w.getCompleteAddress())

        // deploy the token contract
        const [deployerWallet, adminWallet] = wallets;
        tokenAdmin = adminWallet;
        tokenContract = await TokenContract.deploy(
            deployerWallet, 
            adminWallet.getCompleteAddress().address,
            "NAME___________________________",
            "SYMBOL_________________________",
            18
        ).send().deployed();

        const alice = wallets[0].getAddress();
        tokenContract.withWallet(tokenAdmin).methods.mint_to_private(alice, alice, 100).send().wait();
        
        action = tokenContract.methods.transfer_in_private(alice, alice, 100, 0);
    })

    it("Deploys the contract", async () => {
        const salt = Fr.random();
        const VotingContractArtifact = EasyPrivateVotingContractArtifact
        const [deployerWallet, adminWallet] = wallets; // using first account as deployer and second as contract admin
        const adminAddress = adminWallet.getCompleteAddress().address;

        const deploymentData = await getContractInstanceFromDeployParams(VotingContractArtifact,
            {
                constructorArgs: [adminAddress, tokenContract.address],
                salt,
                deployer: deployerWallet.getAddress()
            });
        const deployer = new ContractDeployer(VotingContractArtifact, deployerWallet);
        const tx = deployer.deploy(adminAddress, tokenContract.address).send({ contractAddressSalt: salt })
        const receipt = await tx.getReceipt();

        expect(receipt).toEqual(
            expect.objectContaining({
                status: TxStatus.PENDING,
                error: ''
            }),
        );

        const receiptAfterMined = await tx.wait({ wallet: deployerWallet });

        expect(await pxe.getContractInstance(deploymentData.address)).toBeDefined();
        expect(await pxe.isContractPubliclyDeployed(deploymentData.address)).toBeTruthy();
        expect(receiptAfterMined).toEqual(
            expect.objectContaining({
                status: TxStatus.SUCCESS,
            }),
        );

        expect(receiptAfterMined.contract.instance.address).toEqual(deploymentData.address)
    }, 300_000_000)

    it.only("It casts a vote", async () => {
        const candidate = new Fr(1)

        const contract = await EasyPrivateVotingContract.deploy(wallets[0], accounts[0].address, tokenContract.address).send().deployed();

        const witness = await wallets[0].createAuthWit({
            caller: contract.address,
            action
        });

        const tx = await contract.methods.cast_vote(candidate).send().wait();
        let count = await contract.methods.get_vote(candidate).simulate();
        expect(count).toBe(100n);
    }, 300_000)

    it("It should fail when trying to vote twice", async () => {
        const candidate = new Fr(1)

        const contract = await EasyPrivateVotingContract.deploy(wallets[0], accounts[0].address, tokenContract.address).send().deployed();

        const witness = await wallets[0].createAuthWit({
            caller: contract.address,
            action
        });

        await contract.methods.cast_vote(candidate).send().wait();

        // We try voting again, but our TX is dropped due to trying to emit duplicate nullifiers
        // first confirm that it fails simulation
        await expect(contract.methods.cast_vote(candidate).send().wait()).rejects.toThrow(/Nullifier collision/);
        // if we skip simulation, tx is dropped
        await expect(
            contract.methods.cast_vote(candidate).send({ skipPublicSimulation: true }).wait(),
        ).rejects.toThrow('Reason: Tx dropped by P2P node.');

    }, 300_000)

    it("It casts a delegated vote", async () => {
        const candidate = new Fr(1)
        const delegatee = accounts[1].address
        const random = new Fr(2)

        const contract = await EasyPrivateVotingContract.deploy(wallets[0], accounts[0].address, tokenContract.address).send().deployed();

        const witness = await wallets[0].createAuthWit({
            caller: contract.address,
            action
        });

        await contract.methods.delegate_vote(delegatee, random).send().wait();
        
        const tx = await contract.withWallet(wallets[1]).methods.cast_delegated_vote(candidate).send().wait();
        let count = await contract.methods.get_vote(candidate).simulate();
        expect(count).toBe(1n);
    }, 300_000)

    it("It should fail when trying to both delegate and vote", async () => {
        const candidate = new Fr(1)
        const delegatee = accounts[1].address
        const random = new Fr(2)

        const contract = await EasyPrivateVotingContract.deploy(wallets[0], accounts[0].address, tokenContract.address).send().deployed();

        const witness = await wallets[0].createAuthWit({
            caller: contract.address,
            action
        });
        
        await contract.methods.delegate_vote(delegatee, random).send().wait();

        // We try voting again, but our TX is dropped due to trying to emit duplicate nullifiers
        // first confirm that it fails simulation
        await expect(contract.methods.cast_vote(candidate).send().wait()).rejects.toThrow(/Nullifier collision/);
        // if we skip simulation, tx is dropped
        await expect(
            contract.methods.cast_vote(candidate).send({ skipPublicSimulation: true }).wait(),
        ).rejects.toThrow('Reason: Tx dropped by P2P node.');
    }, 300_000)

});