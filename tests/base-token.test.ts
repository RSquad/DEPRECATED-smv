import { TonClient } from "@tonclient/core";
import { TonContract } from "./contracts/ton-contract";
import deploySystem from "./parts/deploy-system";
import deployProposal from "./parts/deploy-proposal";
import deployPadavan from "./parts/deploy-padavan";
import rootTokenPackage from "./contracts/ton-packages/roottokencontract.package";
import batchGiverPackage from "./contracts/ton-packages/batch-giver.package";
import nseGiverPackage from "./contracts/ton-packages/nse-giver.package";
import { utf8ToHex } from "./utils/convert";
import { tokenWalletCode } from "./utils/code";
import { expect } from "chai";
import { sleep, waitForMessage, waitForTransaction } from "./utils/common";
import tontokenwalletPackage from "./contracts/ton-packages/tontokenwallet.package";
import reclaim from "./parts/reclaim";
import reclaimTokens from "./parts/reclaimTokens";
import checkProposalResults from "./parts/check-proposal-results";
import vote from "./parts/vote";

describe("base-token", () => {
  let client: TonClient;
  let batchGiver: TonContract;
  let nseGiver: TonContract;
  let userWallet: TonContract;
  let demiurge: TonContract;
  let proposal: TonContract;
  let padavan: TonContract;
  let rootToken: TonContract;
  let userToken: TonContract;
  let account: TonContract;

  before(async () => {
    const result = await deploySystem();
    client = result.client;
    demiurge = result.demiurge;
    userWallet = result.userWallet;
    batchGiver = result.batchGiver;
    nseGiver = result.nseGiver;
  });

  it("deploys proposal", async () => {
    proposal = (await deployProposal({ client, demiurge, userWallet })).proposal;
  });

  it("deploys padavan", async () => {
    padavan = (await deployPadavan({ client, demiurge, userWallet })).padavan;
  });

  it("deploys token root and user token wallet", async () => {
    rootToken = new TonContract({
      client,
      name: "rootToken",
      tonPackage: rootTokenPackage,
      keys: await client.crypto.generate_random_sign_keys(),
    });
    await rootToken.init();
    await nseGiver.call({ functionName: "sendGrams", input: { amount: 5e9, dest: rootToken.address } });
    await rootToken.deploy({
      input: {
        name: utf8ToHex("tip1"),
        symbol: utf8ToHex("TP1"),
        decimals: 0,
        root_public_key: `0x${rootToken.keys.public}`,
        root_owner: "0x0",
        wallet_code: tokenWalletCode,
        total_supply: 1000,
      },
    });

    userToken = new TonContract({
      client,
      name: "userToken",
      tonPackage: tontokenwalletPackage,
      keys: await client.crypto.generate_random_sign_keys(),
    });

    const deployWalletResult = await rootToken.call({
      functionName: "deployWallet",
      input: {
        _answer_id: 1,
        workchain_id: 0,
        pubkey: `0x${userToken.keys.public}`,
        internal_owner: 0,
        tokens: 30,
        grams: 1e9,
      },
    });
    expect(deployWalletResult.transaction.aborted).to.not.be.ok;

    userToken.address = deployWalletResult.decoded.output.value0;

    const tx = await waitForTransaction(
      client,
      {
        account_addr: { eq: userToken.address },
        now: { ge: deployWalletResult.transaction.now },
        orig_status: { eq: 3 },
        end_status: { eq: 1 },
        aborted: { eq: false },
      },
      "now aborted"
    );
    expect(tx.aborted).to.be.eq(false);

    console.log("rootToken address: ", rootToken.address);
    console.log("userToken address: ", userToken.address);
  });

  it("creates token account for padavan", async () => {
    const accountsBefore = (
      await padavan.callLocal({
        functionName: "getTokenAccounts",
      })
    ).value.allAccounts;

    console.log("accounts before", accountsBefore);
    expect(accountsBefore).to.be.a("object").that.is.empty;

    const createTokenAccountResult = await userWallet.call({
      functionName: "createTokenAccount",
      input: { root: rootToken.address },
    });

    const message = await waitForMessage(
      client,
      {
        dst: { eq: userWallet.address },
        src: { eq: padavan.address },
        created_at: { ge: createTokenAccountResult.transaction.now },
      },
      "value"
    );
    expect(parseInt(message.value, 16)).to.be.greaterThan(1e8);

    const accounts = (await padavan.callLocal({ functionName: "getTokenAccounts" })).value.allAccounts;

    console.log("accounts", accounts);
    account = new TonContract({
      name: "account",
      client,
      address: accounts[rootToken.address].addr,
      tonPackage: tontokenwalletPackage,
    });
  });

  it("deposits tokens to account", async () => {
    const tokenDeposit = 20;

    const depositsBefore = (await padavan.callLocal({ functionName: "getDeposits" })).value.allDeposits;

    console.log("deposits before: ", depositsBefore);
    await userToken.call({
      functionName: "transfer",
      input: { dest: account.address, tokens: tokenDeposit, grams: 2e7 },
    });

    const accountBalance = (await account.callLocal({ functionName: "getBalance" })).value.value0;

    expect(+accountBalance).to.be.eq(+tokenDeposit);

    await userWallet.call({
      functionName: "depositTokens",
      input: { returnTo: userToken.address, tokenId: `0x${rootToken.address.substr(2)}`, tokens: tokenDeposit },
    });

    const deposits = (await padavan.callLocal({ functionName: "getDeposits" })).value.allDeposits;

    console.log("deposits", deposits);
    const keys = Object.keys(deposits);
    expect(keys.length).to.be.eq(1);
    expect(deposits[keys[0]].tokenId).to.be.eq(`0x${rootToken.address.substr(2)}`);
    expect(deposits[keys[0]].amount).to.be.eq(tokenDeposit.toString(10));

    const info = (await padavan.callLocal({ functionName: "getVoteInfo" })).value;

    console.log("info: ", info);

    expect(parseInt(info.lockedVotes, 10)).to.be.eq(0);
    expect(parseInt(info.reqVotes, 10)).to.be.eq(0);
  });

  it("send 10 votes for proposal", async () => {
    const votesCount = 10;
    await vote({
      choice: "for",
      votesCount,
      client,
      proposal: proposal,
      padavan: padavan,
      userWallet,
    });
  });

  it("checks proposal result", async () => {
    await checkProposalResults({ choice: "for", proposal });
  });

  it("reclaim tokens", async () => {
    console.log("account balance before: ", (await account.callLocal({ functionName: "getBalance" })).value.value0);
    console.log("userToken balance before: ", (await userToken.callLocal({ functionName: "getBalance" })).value.value0);
    await reclaimTokens({ reclaimAmount: "all", client, userWallet, padavan });
    console.log("account balance: ", (await account.callLocal({ functionName: "getBalance" })).value.value0);
    console.log("userToken balance: ", (await userToken.callLocal({ functionName: "getBalance" })).value.value0);
  });
});
