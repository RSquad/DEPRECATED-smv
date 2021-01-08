import { expect } from "chai";
import { TonContract } from "../contracts/ton-contract";

export default async ({ choice, proposal }: { choice: "for" | "against"; proposal: TonContract }) => {
  const proposalVotingResults = (await proposal.callLocal({ functionName: "getVotingResults" })).value;
  console.log(`${proposal.name} results: `, proposalVotingResults.vr);

  expect(+proposalVotingResults.vr.votesFor).to.be.a("number");
  expect(+proposalVotingResults.vr.votesAgainst).to.be.a("number");
  expect(+proposalVotingResults.vr.totalVotes).to.be.a("number");
  expect(+proposalVotingResults.vr.ts)
    .to.be.a("number")
    .gte(0);
  expect(proposalVotingResults.vr.passed).to.be.eq(choice === "for");
};
