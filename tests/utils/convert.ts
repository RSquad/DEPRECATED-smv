const convert = (from, to) => (str) => Buffer.from(str, from).toString(to);

export const utf8ToHex = convert("utf8", "hex");
