import { TonClient } from "@tonclient/core";
import { expect } from "chai";
import { TonContract } from "../contracts/ton-contract";
import padavanPackage from "../contracts/ton-packages/padavan.package";
import { sleep, waitForMessage } from "../utils/common";

export default async ({
  name = "padavan",
  client,
  demiurge,
  userWallet,
}: {
  name?: string;
  client: TonClient;
  demiurge: TonContract;
  userWallet: TonContract;
}) => {
  const alredyDeployedPadavans = (await demiurge.callLocal({ functionName: "getDeployed" })).value.padavans;
  expect(alredyDeployedPadavans).to.be.an("object");
  console.log(`${demiurge.name} alredy deployed padavans: `, alredyDeployedPadavans);

  console.log("deploying padavan");
  const padavan = new TonContract({
    client,
    name,
    tonPackage: padavanPackage,
    keys: await client.crypto.generate_random_sign_keys(),
  });
  await padavan.init({ initialData: { deployer: demiurge.address } });

  const deployPadavanResult = await userWallet.call({
    functionName: "deployPadavan",
    input: { userKey: `0x${padavan.keys.public}` },
  });
  expect(deployPadavanResult.transaction.aborted).to.not.be.ok;

  const message = await waitForMessage(
    client,
    {
      dst: { eq: userWallet.address },
      msg_type: { eq: 0 },
      created_at: { ge: deployPadavanResult.transaction.now },
    },
    "src dst value"
  );
  expect(message.aborted).to.not.be.ok;

  const deployedPadavans = (await demiurge.callLocal({ functionName: "getDeployed" })).value.padavans;
  console.log(`${demiurge.name} deployed padavans: `, deployedPadavans);
  console.log(`${padavan.name} address: `, padavan.address);
  console.log(`${userWallet.name} getInfo: `, (await userWallet.callLocal({ functionName: "getInfo" })).value);
  expect(deployedPadavans).to.be.an("object").that.is.not.empty;

  expect((await userWallet.callLocal({ functionName: "getInfo" })).value.padavan).to.be.eq(padavan.address);

  return { padavan };
};
