import { TonClient } from "@tonclient/core";
import { expect } from "chai";
import { TonContract } from "../contracts/ton-contract";
import { waitForMessage } from "../utils/common";

export default async ({
  reclaimAmount,
  userWallet,
  padavan,
  client,
}: {
  reclaimAmount: "all" | number;
  userWallet: TonContract;
  padavan: TonContract;
  client: TonClient;
}) => {
  const deposits = (
    await padavan.callLocal({
      functionName: "getDeposits",
    })
  ).value.allDeposits;
  const padavanActiveProposalsBefore = (await padavan.callLocal({ functionName: "activeProposals" })).value
    .activeProposals;
  const padavanVoteInfoBefore = (
    await padavan.callLocal({
      functionName: "getVoteInfo",
    })
  ).value;

  console.log(`${userWallet.name} balance: `, (+(await userWallet.getBalance()) / 1e9).toFixed(3));
  console.log(`${padavan.name} balance: `, (+(await padavan.getBalance()) / 1e9).toFixed(3));
  console.log(`${padavan.name} deposits: `, deposits);
  console.log(`${padavan.name} vote info before: `, padavanVoteInfoBefore);
  console.log(`${padavan.name} active proposals before: `, padavanActiveProposalsBefore);

  const _reclaimAmount = reclaimAmount === "all" ? +padavanVoteInfoBefore.totalVotes : reclaimAmount;

  console.log("reclaim amount: ", _reclaimAmount);

  await userWallet.call({
    functionName: "reclaimDeposit",
    input: { votes: _reclaimAmount },
  });

  const padavanVoteInfo = (
    await padavan.callLocal({
      functionName: "getVoteInfo",
    })
  ).value;

  const padavanActiveProposals = (await padavan.callLocal({ functionName: "activeProposals" })).value.activeProposals;

  console.log(`${userWallet.name} balance: `, (+(await userWallet.getBalance()) / 1e9).toFixed(3));
  console.log(`${padavan.name} balance: `, (+(await padavan.getBalance()) / 1e9).toFixed(3));
  console.log(`${padavan.name} active proposals: `, padavanActiveProposals);
  console.log(`${padavan.name} deposits: `, deposits);
  console.log(`${padavan.name} vote info: `, padavanVoteInfo);
};
