import { expect } from "chai";
import { TonContract } from "../contracts/ton-contract";
import batchGiverPackage from "../contracts/ton-packages/batch-giver.package";
import demiurgePackage from "../contracts/ton-packages/demiurge.package";
import depoolPackage from "../contracts/ton-packages/depool.package";
import nseGiverPackage from "../contracts/ton-packages/nse-giver.package";
import padavanPackage from "../contracts/ton-packages/padavan.package";
import priceproviderPackage from "../contracts/ton-packages/priceprovider.package";
import proposalPackage from "../contracts/ton-packages/proposal.package";
import userwalletPackage from "../contracts/ton-packages/userwallet.package";
import { proxyCode } from "../utils/code";
import { createClient } from "../utils/common";

export default async () => {
  const client = createClient();

  const nseGiver = new TonContract({
    client,
    name: "nseGiver",
    tonPackage: nseGiverPackage,
    keys: await client.crypto.generate_random_sign_keys(),
    address: process.env.NSE_GIVER_ADDRESS,
  });

  const batchGiver = new TonContract({
    client,
    name: "batchGiver",
    tonPackage: batchGiverPackage,
    keys: await client.crypto.generate_random_sign_keys(),
  });
  await batchGiver.init();

  const demiurge = new TonContract({
    client,
    name: "demiurge",
    tonPackage: demiurgePackage,
    keys: await client.crypto.generate_random_sign_keys(),
  });

  await demiurge.init({ input: { store: "0:0000000000000000000000000000000000000000000000000000000000000000" } });

  console.log("deploying demiurge");
  await nseGiver.call({ functionName: "sendGrams", input: { amount: 10_000_000_000, dest: demiurge.address } });
  await demiurge.deploy({ input: { store: "0:0000000000000000000000000000000000000000000000000000000000000000" } });

  const userWallet = new TonContract({
    client,
    name: "userWallet",
    tonPackage: userwalletPackage,
    keys: await client.crypto.generate_random_sign_keys(),
  });
  await userWallet.init();

  console.log("deploying userWallet");
  await nseGiver.call({ functionName: "sendGrams", input: { amount: 300_000_000_000, dest: userWallet.address } });
  await userWallet.deploy();

  const userWallet2 = new TonContract({
    client,
    name: "userWallet2",
    tonPackage: userwalletPackage,
    keys: await client.crypto.generate_random_sign_keys(),
  });
  await userWallet2.init();

  console.log("deploying userWallet2");
  await nseGiver.call({ functionName: "sendGrams", input: { amount: 300_000_000_000, dest: userWallet2.address } });
  await userWallet2.deploy();

  const priceProvider = new TonContract({
    client,
    name: "priceProvider",
    tonPackage: priceproviderPackage,
    keys: await client.crypto.generate_random_sign_keys(),
  });
  await priceProvider.init();

  console.log("priceProvider demiurge");
  await nseGiver.call({ functionName: "sendGrams", input: { amount: 10_000_000_000, dest: priceProvider.address } });
  await priceProvider.deploy();

  const demiurgeBalance = await demiurge.getBalance();
  expect(demiurgeBalance).to.be.a("number");
  expect(demiurgeBalance).to.be.greaterThan(0);
  const userWalletBalance = await userWallet.getBalance();
  expect(userWalletBalance).to.be.a("number");
  expect(userWalletBalance).to.be.greaterThan(0);
  const userWallet2Balance = await userWallet2.getBalance();
  expect(userWallet2Balance).to.be.a("number");
  expect(userWallet2Balance).to.be.greaterThan(0);
  const priceProviderBalance = await priceProvider.getBalance();
  expect(priceProviderBalance).to.be.a("number");
  expect(priceProviderBalance).to.be.greaterThan(0);

  console.log("set proposal SI");
  await demiurge.call({ functionName: "setProposalSI", input: { c: proposalPackage.image } });

  console.log("set padavan SI");
  await demiurge.call({ functionName: "setPadavanSI", input: { c: padavanPackage.image } });

  console.log("set price provider: ", priceProvider.address);
  await demiurge.call({ functionName: "setPriceProvider", input: { addr: priceProvider.address } });

  console.log("set target address userWallet");
  await userWallet.call({ functionName: "setTargetAddress", input: { target: demiurge.address } });

  console.log("set target address userWallet2");
  await userWallet2.call({ functionName: "setTargetAddress", input: { target: demiurge.address } });

  console.log("deploying DePool");
  const depool = new TonContract({
    client,
    name: "depool",
    tonPackage: depoolPackage,
    keys: await client.crypto.generate_random_sign_keys(),
  });
  await depool.init();
  await nseGiver.call({ functionName: "sendGrams", input: { amount: 100_000_000_000, dest: depool.address } });
  await depool.deploy({
    input: {
      minStake: 1e9,
      validatorAssurance: 100e9,
      proxyCode: proxyCode,
      validatorWallet: "0:0000000000000000000000000000000000000000000000000000000000000000",
      participantRewardFraction: 90,
    },
  });

  console.log("set depool address");
  await demiurge.call({
    functionName: "setDePool",
    input: { addr: depool.address },
  });
  return {
    client,
    demiurge,
    userWallet,
    userWallet2,
    batchGiver,
    nseGiver,
    depool,
  };
};
