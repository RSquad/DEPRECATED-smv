import { TonClient } from "@tonclient/core";
import { TonContract } from "./contracts/ton-contract";
import deploySystem from "./parts/deploy-system";
import deployProposal from "./parts/deploy-proposal";
import deployPadavan from "./parts/deploy-padavan";
import depositToPadavan from "./parts/deposit-to-padavan";
import vote from "./parts/vote";
import checkProposalResults from "./parts/check-proposal-results";
import reclaim from "./parts/reclaim";

describe("base-against", () => {
  let client: TonClient;
  let userWallet: TonContract;
  let demiurge: TonContract;
  let proposal: TonContract;
  let padavan: TonContract;

  before(async () => {
    const result = await deploySystem();
    client = result.client;
    demiurge = result.demiurge;
    userWallet = result.userWallet;
  });

  it("deploys proposal", async () => {
    proposal = (await deployProposal({ client, demiurge, userWallet })).proposal;
  });

  it("deploys padavan", async () => {
    padavan = (await deployPadavan({ client, demiurge, userWallet })).padavan;
  });

  it("deposits 10 tons to padavan", async () => {
    await depositToPadavan({ amount: 10, client, userWallet, padavan });
  });

  it("send 10 votes against proposal", async () => {
    const votesCount = 10;
    await vote({
      choice: "against",
      votesCount,
      client,
      proposal: proposal,
      padavan: padavan,
      userWallet,
    });
  });

  it("checks proposal result", async () => {
    await checkProposalResults({ choice: "against", proposal });
  });

  it("reclaim tons", async () => {
    await reclaim({ reclaimAmount: "all", client, userWallet, padavan });
  });
});
