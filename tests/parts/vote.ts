import { TonClient } from "@tonclient/core";
import { expect } from "chai";
import { TonContract } from "../contracts/ton-contract";
import { waitForMessage } from "../utils/common";

export default async ({
  choice,
  votesCount,
  client,
  padavan,
  proposal,
  userWallet,
}: {
  choice: "for" | "against";
  votesCount: number;
  client: TonClient;
  padavan: TonContract;
  proposal: TonContract;
  userWallet: TonContract;
}) => {
  console.log("votes count: ", votesCount);

  const padavanVoteInfoBefore = (await padavan.callLocal({ functionName: "getVoteInfo" })).value;
  console.log(`${padavan.name} vote info before: `, padavanVoteInfoBefore);

  const proposalCurrentVotesBefore = (await proposal.callLocal({ functionName: "getCurrentVotes" })).value;
  console.log(`${proposal.name} current votes before: `, proposalCurrentVotesBefore);

  const voteForResult = await userWallet.call({
    functionName: "voteFor",
    input: { proposal: proposal.address, choice: choice === "for", votes: votesCount },
  });

  const message = await waitForMessage(
    client,
    {
      src: { eq: padavan.address },
      dst: { eq: userWallet.address },
      created_at: { ge: voteForResult.transaction.now },
    },
    "value"
  );
  expect(parseInt(message.value, 16)).to.be.greaterThan(5e8);

  await waitForMessage(
    client,
    {
      src: { eq: proposal.address },
      dst: { eq: padavan.address },
      created_at: { ge: voteForResult.transaction.now },
    },
    "body"
  );

  const padavanVoteInfo = (await padavan.callLocal({ functionName: "getVoteInfo" })).value;
  const proposalCurrentVotes = (await proposal.callLocal({ functionName: "getCurrentVotes" })).value;

  console.log(`${padavan.name} vote info: `, padavanVoteInfo);
  console.log(`${proposal.name} current votes: `, proposalCurrentVotes);

  expect(+padavanVoteInfo.totalVotes).to.be.eq(+padavanVoteInfoBefore.totalVotes);
  expect(+padavanVoteInfo.reqVotes).to.be.eq(+padavanVoteInfoBefore.reqVotes);

  if (choice === "for") {
    expect(+proposalCurrentVotes.votesFor).to.be.eq(+proposalCurrentVotesBefore.votesFor + votesCount);
    expect(+proposalCurrentVotes.votesAgainst).to.be.eq(+proposalCurrentVotesBefore.votesAgainst);
  } else {
    expect(+proposalCurrentVotes.votesFor).to.be.eq(+proposalCurrentVotesBefore.votesFor);
    expect(+proposalCurrentVotes.votesAgainst).to.be.eq(+proposalCurrentVotesBefore.votesAgainst + votesCount);
  }
};
