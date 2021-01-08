import { TonClient } from "@tonclient/core";
import { TonContract } from "./contracts/ton-contract";
import deploySystem from "./parts/deploy-system";
import deployProposal from "./parts/deploy-proposal";
import deployPadavan from "./parts/deploy-padavan";
import depositToPadavan from "./parts/deposit-to-padavan";
import vote from "./parts/vote";
import checkProposalResults from "./parts/check-proposal-results";
import reclaim from "./parts/reclaim";
import { sleep, waitForMessage } from "./utils/common";

describe("base-depool", () => {
  let client: TonClient;
  let userWallet: TonContract;
  let demiurge: TonContract;
  let proposal: TonContract;
  let padavan: TonContract;
  let depool: TonContract;

  before(async () => {
    const result = await deploySystem();
    client = result.client;
    demiurge = result.demiurge;
    userWallet = result.userWallet;
    depool = result.depool;
  });

  it("deploys proposal", async () => {
    proposal = (await deployProposal({ client, demiurge, userWallet })).proposal;
  });

  it("deploys padavan", async () => {
    padavan = (await deployPadavan({ client, demiurge, userWallet })).padavan;
  });

  it("transfers 10 tons to padavan from depool", async () => {
    const addOrdinaryStakeResult = await userWallet.call({
      functionName: "addOrdinaryStake",
      input: { depool: depool.address, stake: 6e9 },
    });

    const msg = await waitForMessage(
      client,
      {
        src: { eq: depool.address },
        dst: { eq: userWallet.address },
        created_at: { ge: addOrdinaryStakeResult.transaction.now },
      },
      "value"
    );

    const participantInfo = (
      await depool.callLocal({ functionName: "getParticipantInfo", input: { addr: userWallet.address } })
    ).value;
    console.log("depool participant info: ", participantInfo);

    const padavanVoteInfoBefore = (await padavan.callLocal({ functionName: "getVoteInfo" })).value;
    console.log("padavan vote info before: ", padavanVoteInfoBefore);

    console.log("transfering stake");
    const transferStakeResult = await userWallet.call({
      functionName: "transferStake",
      input: { depool: depool.address, dest: padavan.address, amount: 6e9 },
    });

    await sleep(3000);

    const padavanVoteInfo = (await padavan.callLocal({ functionName: "getVoteInfo" })).value;
    console.log("padavan vote info: ", padavanVoteInfo);
  });

  it("send 6 votes for proposal", async () => {
    const votesCount = 6;
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

  it("reclaim tons", async () => {
    await reclaim({ reclaimAmount: "all", client, userWallet, padavan });
  });
});
