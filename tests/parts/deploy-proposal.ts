import { TonClient } from "@tonclient/core";
import { expect } from "chai";
import { TonContract } from "../contracts/ton-contract";
import proposalPackage from "../contracts/ton-packages/proposal.package";
import { decodeInternalBody, waitForMessage } from "../utils/common";

export default async ({
  input = {},
  client,
  name = "proposal",
  demiurge,
  userWallet,
}: {
  input?: {};
  name?: string;
  client: TonClient;
  demiurge: TonContract;
  userWallet: TonContract;
}) => {
  const alredyDeployedProposals = (await demiurge.callLocal({ functionName: "getDeployed" })).value.proposals;
  expect(alredyDeployedProposals).to.be.an("object");
  console.log(`${demiurge.name} alredy deployed proposals: `, alredyDeployedProposals);

  const proposal = new TonContract({
    client,
    name,
    tonPackage: proposalPackage,
  });
  await proposal.init();

  console.log("deploying proposal");
  const deployProposalResult = await userWallet.call({
    functionName: "deployProposal",
    input: {
      totalVotes: 10,
      start: Math.round(Date.now() / 1000),
      end: Math.round(Date.now() / 1000 + 100),
      description: "aaddcc",
      text: "aaddcc",
      model: 2,
      ...input,
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

  return { proposal };
};
