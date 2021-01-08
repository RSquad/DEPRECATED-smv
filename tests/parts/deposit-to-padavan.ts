import { TonClient } from "@tonclient/core";
import { expect } from "chai";
import { TonContract } from "../contracts/ton-contract";
import { waitForMessage } from "../utils/common";

export default async ({
  amount,
  client,
  userWallet,
  padavan,
}: {
  amount: number;
  client: TonClient;
  userWallet: TonContract;
  padavan: TonContract;
}) => {
  console.log(`${userWallet.name} balance: `, (+(await userWallet.getBalance()) / 1e9).toFixed(3));
  console.log(`${padavan.name} balance: `, (+(await padavan.getBalance()) / 1e9).toFixed(3));

  console.log("depositing tons to padavan");
  const depositTonsResult = await userWallet.call({ functionName: "depositTons", input: { tons: amount } });
  expect(depositTonsResult.transaction.aborted).to.not.be.ok;

  const message = await waitForMessage(
    client,
    {
      src: { eq: padavan.address },
      dst: { eq: userWallet.address },
      created_at: { ge: depositTonsResult.transaction.now },
    },
    "value"
  );
  expect(message.aborted).to.not.be.ok;
  expect(parseInt(message.value, 16)).to.be.greaterThan(500_000_000);

  const deposits = (
    await padavan.callLocal({
      functionName: "getDeposits",
    })
  ).value.allDeposits;

  const keys = Object.keys(deposits);
  expect(keys.length).to.be.eq(1);
  expect(parseInt(deposits[keys[0]].tokenId, 16)).to.be.eq(0);
  expect(deposits[keys[0]].amount).to.be.eq((amount * 1e9).toString(10));

  const padavanVoteInfo = (
    await padavan.callLocal({
      functionName: "getVoteInfo",
    })
  ).value;
  expect(parseInt(padavanVoteInfo.totalVotes, 10)).to.be.eq(amount);
  expect(parseInt(padavanVoteInfo.lockedVotes, 10)).to.be.eq(0);
  expect(parseInt(padavanVoteInfo.reqVotes, 10)).to.be.eq(0);

  console.log(`${userWallet.name} balance: `, (+(await userWallet.getBalance()) / 1e9).toFixed(3));
  console.log(`${padavan.name} balance: `, (+(await padavan.getBalance()) / 1e9).toFixed(3));
  console.log(`${padavan.name} deposits: `, deposits);
  console.log(`${padavan.name} vote info: `, padavanVoteInfo);
};
