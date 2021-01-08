import { TonClient } from "@tonclient/core";
import { TonContract } from "./contracts/ton-contract";
import deploySystem from "./parts/deploy-system";
import deployProposal from "./parts/deploy-proposal";
import deployPadavan from "./parts/deploy-padavan";
import depositToPadavan from "./parts/deposit-to-padavan";
import vote from "./parts/vote";
import checkProposalResults from "./parts/check-proposal-results";
import reclaim from "./parts/reclaim";
import { expect } from "chai";
import proposalPackage from "./contracts/ton-packages/proposal.package";
import { decodeInternalBody, waitForMessage } from "./utils/common";

describe("whitelist", () => {
  let client: TonClient;
  let userWallet: TonContract;
  let userWallet2: TonContract;
  let demiurge: TonContract;
  let proposal: TonContract;
  let padavan: TonContract;
  let padavan2: TonContract;

  before(async () => {
    const result = await deploySystem();
    client = result.client;
    demiurge = result.demiurge;
    userWallet = result.userWallet;
    userWallet2 = result.userWallet2;
  });

  it("deploys padavan", async () => {
    padavan = (await deployPadavan({ client, demiurge, userWallet, name: "padavan" })).padavan;
  });

  it("deploys padavan2", async () => {
    padavan2 = (await deployPadavan({ client, demiurge, userWallet: userWallet2, name: "padavan2" })).padavan;
  });

  it("deploys proposal", async () => {
    const alredyDeployedProposals = (await demiurge.callLocal({ functionName: "getDeployed" })).value.proposals;
    expect(alredyDeployedProposals).to.be.an("object");
    console.log(`${demiurge.name} alredy deployed proposals: `, alredyDeployedProposals);

    proposal = new TonContract({
      client,
      name: "proposal",
      tonPackage: proposalPackage,
    });
    await proposal.init();

    console.log("deploying proposal");
    const deployProposalResult = await userWallet.call({
      functionName: "requestProposalWithWhitelist",
      input: {
        totalVotes: 10,
        start: Math.round(Date.now() / 1000),
        end: Math.round(Date.now() / 1000 + 100),
        description: "aaddcc",
        text: "aaddcc",
        model: 2,
        voters: [padavan2.address],
      },
    });
    expect(deployProposalResult.transaction.aborted).to.not.be.ok;

    const message = await waitForMessage(
      client,
      {
        dst: { eq: userWallet.address },
        created_at: { ge: deployProposalResult.transaction.now },
      },
      "body"
    );
    expect(message.aborted).to.not.be.ok;

    const deployedProposal = (await demiurge.callLocal({ functionName: "getDeployed" })).value.proposals;
    expect(deployedProposal).to.be.an("object").to.be.an("object").that.is.not.empty;
    console.log(`${demiurge.name} deployed proposals: `, deployedProposal);

    const decoded = await decodeInternalBody(client, userWallet.tonPackage.abi, message.body);
    expect(decoded.name).to.be.eq("onProposalDeployed");

    proposal.address = decoded.value.addr;
    console.log("proposal address: ", proposal.address);

    console.log("proposal info: ", await proposal.callLocal({ functionName: "getInfo" }));

    const id = (await proposal.callLocal({ functionName: "getId" })).value.id;
    expect(id).to.be.eq(
      `0x000000000000000000000000000000000000000000000000000000000000000${Object.keys(alredyDeployedProposals).length}`
    );
    console.log("proposal id: ", id);
  });

  it("deposits 10 tons to padavan", async () => {
    await depositToPadavan({ amount: 10, client, userWallet, padavan });
  });

  it("deposits 10 tons to padavan2", async () => {
    await depositToPadavan({ amount: 10, client, userWallet: userWallet2, padavan: padavan2 });
  });

  it("sends 10 votes for proposal from padavan, returns error", async () => {
    const votesCount = 10;
    try {
      await vote({
        choice: "for",
        votesCount,
        client,
        proposal: proposal,
        padavan: padavan,
        userWallet,
      });
      expect(false).to.be.ok;
    } catch (err) {
      console.log(err);
    }
  });

  it("send 10 votes for proposal from padavan2", async () => {
    const votesCount = 10;
    await vote({
      choice: "for",
      votesCount,
      client,
      proposal: proposal,
      padavan: padavan2,
      userWallet: userWallet2,
    });
  });

  it("checks proposal result", async () => {
    await checkProposalResults({ choice: "for", proposal });
  });

  it("reclaim tons", async () => {
    await reclaim({ reclaimAmount: "all", client, userWallet, padavan });
  });

  it("reclaim tons padavan2", async () => {
    await reclaim({ reclaimAmount: "all", client, userWallet: userWallet2, padavan: padavan2 });
  });
});
