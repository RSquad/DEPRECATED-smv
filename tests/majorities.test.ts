import { TonClient } from "@tonclient/core";
import { TonContract } from "./contracts/ton-contract";
import deploySystem from "./parts/deploy-system";
import deployProposal from "./parts/deploy-proposal";
import deployPadavan from "./parts/deploy-padavan";
import depositToPadavan from "./parts/deposit-to-padavan";
import vote from "./parts/vote";
import checkProposalResults from "./parts/check-proposal-results";
import reclaim from "./parts/reclaim";

describe("majorities", () => {
  let client: TonClient;
  let userWallet: TonContract;
  let demiurge: TonContract;
  let proposal: TonContract;
  let proposal2: TonContract;
  let proposal3: TonContract;
  let proposal4: TonContract;
  let proposal5: TonContract;
  let proposal6: TonContract;
  let padavan: TonContract;

  before(async () => {
    const result = await deploySystem();
    client = result.client;
    demiurge = result.demiurge;
    userWallet = result.userWallet;
  });

  it("deploys proposal — soft majority", async () => {
    proposal = (
      await deployProposal({
        input: {
          model: 2,
        },
        client,
        demiurge,
        userWallet,
      })
    ).proposal;
  });

  it("deploys proposal2 — soft majority", async () => {
    proposal2 = (
      await deployProposal({
        input: {
          model: 2,
        },
        name: "proposal2",
        client,
        demiurge,
        userWallet,
      })
    ).proposal;
  });

  it("deploys proposal3 — super majority", async () => {
    proposal3 = (
      await deployProposal({
        input: {
          model: 3,
        },
        name: "proposal3",
        client,
        demiurge,
        userWallet,
      })
    ).proposal;
  });

  it("deploys proposal4 — super majority", async () => {
    proposal4 = (
      await deployProposal({
        input: {
          model: 3,
        },
        name: "proposal4",
        client,
        demiurge,
        userWallet,
      })
    ).proposal;
  });

  it("deploys proposal5 — majority", async () => {
    proposal5 = (
      await deployProposal({
        input: {
          model: 1,
        },
        name: "proposal5",
        client,
        demiurge,
        userWallet,
      })
    ).proposal;
  });

  it("deploys proposal6 — majority", async () => {
    proposal6 = (
      await deployProposal({
        input: {
          model: 1,
        },
        name: "proposal6",
        client,
        demiurge,
        userWallet,
      })
    ).proposal;
  });

  it("deploys padavan", async () => {
    padavan = (await deployPadavan({ client, demiurge, userWallet })).padavan;
  });

  it("deposits 100 tons to padavan", async () => {
    await depositToPadavan({ amount: 100, client, userWallet, padavan });
  });

  it("send 5 votes for proposal", async () => {
    const votesCount = 5;
    await vote({
      choice: "for",
      votesCount,
      client,
      proposal: proposal,
      padavan,
      userWallet,
    });
  });

  it("send 5 votes against proposal", async () => {
    const votesCount = 5;
    await vote({
      choice: "against",
      votesCount,
      client,
      proposal: proposal,
      padavan,
      userWallet,
    });
  });

  it("checks proposal result", async () => {
    await checkProposalResults({ choice: "against", proposal });
  });

  it("send 6 votes for proposal2", async () => {
    const votesCount = 6;
    await vote({
      choice: "for",
      votesCount,
      client,
      proposal: proposal2,
      padavan,
      userWallet,
    });
  });

  it("send 4 votes against proposal2", async () => {
    const votesCount = 4;
    await vote({
      choice: "against",
      votesCount,
      client,
      proposal: proposal2,
      padavan,
      userWallet,
    });
  });

  it("checks proposal result", async () => {
    await checkProposalResults({ choice: "for", proposal: proposal2 });
  });

  it("send 7 votes for proposal3", async () => {
    const votesCount = 7;
    await vote({
      choice: "for",
      votesCount,
      client,
      proposal: proposal3,
      padavan,
      userWallet,
    });
  });

  it("send 3 votes against proposal3", async () => {
    const votesCount = 3;
    await vote({
      choice: "against",
      votesCount,
      client,
      proposal: proposal3,
      padavan,
      userWallet,
    });
  });

  it("checks proposal3 result", async () => {
    await checkProposalResults({ choice: "for", proposal: proposal3 });
  });

  it("send 6 votes for proposal4", async () => {
    const votesCount = 6;
    await vote({
      choice: "for",
      votesCount,
      client,
      proposal: proposal4,
      padavan,
      userWallet,
    });
  });

  it("send 5 votes against proposal4", async () => {
    const votesCount = 4;
    await vote({
      choice: "against",
      votesCount,
      client,
      proposal: proposal4,
      padavan,
      userWallet,
    });
  });

  it("checks proposal4 result", async () => {
    await checkProposalResults({ choice: "against", proposal: proposal4 });
  });

  it("send 5 votes for proposal5", async () => {
    const votesCount = 5;
    await vote({
      choice: "for",
      votesCount,
      client,
      proposal: proposal5,
      padavan,
      userWallet,
    });
  });

  it("send 5 votes against proposal5", async () => {
    const votesCount = 5;
    await vote({
      choice: "against",
      votesCount,
      client,
      proposal: proposal5,
      padavan,
      userWallet,
    });
  });

  it("checks proposal5 result", async () => {
    await checkProposalResults({ choice: "against", proposal: proposal5 });
  });

  it("send 6 votes for proposal6", async () => {
    const votesCount = 6;
    await vote({
      choice: "for",
      votesCount,
      client,
      proposal: proposal6,
      padavan,
      userWallet,
    });
  });

  it("send 4 votes against proposal6", async () => {
    const votesCount = 4;
    await vote({
      choice: "against",
      votesCount,
      client,
      proposal: proposal6,
      padavan,
      userWallet,
    });
  });

  it("checks proposal6 result", async () => {
    await checkProposalResults({ choice: "for", proposal: proposal6 });
  });

  it("reclaim tons", async () => {
    await reclaim({ reclaimAmount: "all", client, userWallet, padavan });
  });
});
