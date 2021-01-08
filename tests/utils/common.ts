import { TonClient } from "@tonclient/core";
import { libNode } from "@tonclient/lib-node";

const NETWORK_MAP = {
  LOCAL: "http://0.0.0.0",
  DEVNET: "https://net.ton.dev",
};

const DEFAULT_WAIT_TIMEOUT = 30000;

export const createClient = (url = null) => {
  TonClient.useBinaryLibrary(libNode);
  return new TonClient({
    network: {
      server_address: url || NETWORK_MAP[process.env.NETWORK] || "https://net.ton.dev",
    },
  });
};

export const waitForMessage = async (client, filter: any, fields: string) => {
  try {
    const { result } = await client.net.wait_for_collection({
      collection: "messages",
      filter: filter,
      result: fields,
      timeout: DEFAULT_WAIT_TIMEOUT,
    });
    return result;
  } catch (err) {
    console.log(err);
  }
};

export const waitForTransaction = async (client, filter: any, fields: string) => {
  try {
    const { result } = await client.net.wait_for_collection({
      collection: "transactions",
      filter: filter,
      result: fields,
      timeout: DEFAULT_WAIT_TIMEOUT,
    });
    return result;
  } catch (err) {
    console.log(err);
  }
};

export const decodeInternalBody = async (client, abi: {}, body: string) => {
  const res = await client.abi.decode_message_body({
    abi: { type: "Contract", value: abi },
    body: body,
    is_internal: true,
  });
  return res;
};

export const sleep = (ms) => {
  return new Promise((resolve) => setTimeout(resolve, ms));
};
