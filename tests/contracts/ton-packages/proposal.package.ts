export default {
  name: "Proposal",
  abi: {
    "ABI version": 2,
    header: ["time"],
    functions: [
      { name: "constructor", inputs: [], outputs: [] },
      {
        name: "initProposal",
        inputs: [
          {
            components: [
              { name: "id", type: "uint32" },
              { name: "start", type: "uint32" },
              { name: "end", type: "uint32" },
              { name: "options", type: "uint16" },
              { name: "totalVotes", type: "uint32" },
              { name: "description", type: "bytes" },
              { name: "text", type: "bytes" },
              { name: "voters", type: "address[]" },
              { name: "ts", type: "uint32" },
            ],
            name: "pi",
            type: "tuple",
          },
          { name: "padavanSI", type: "cell" },
        ],
        outputs: [],
      },
      { name: "wrapUp", inputs: [], outputs: [] },
      {
        name: "voteFor",
        inputs: [
          { name: "key", type: "uint256" },
          { name: "choice", type: "bool" },
          { name: "deposit", type: "uint32" },
        ],
        outputs: [],
      },
      { name: "finalize", inputs: [{ name: "passed", type: "bool" }], outputs: [] },
      { name: "queryStatus", inputs: [], outputs: [] },
      { name: "getId", inputs: [], outputs: [{ name: "id", type: "uint256" }] },
      {
        name: "getVotingResults",
        inputs: [],
        outputs: [
          {
            components: [
              { name: "id", type: "uint32" },
              { name: "passed", type: "bool" },
              { name: "votesFor", type: "uint32" },
              { name: "votesAgainst", type: "uint32" },
              { name: "totalVotes", type: "uint32" },
              { name: "model", type: "uint8" },
              { name: "ts", type: "uint32" },
            ],
            name: "vr",
            type: "tuple",
          },
        ],
      },
      {
        name: "getInfo",
        inputs: [],
        outputs: [
          {
            components: [
              { name: "id", type: "uint32" },
              { name: "start", type: "uint32" },
              { name: "end", type: "uint32" },
              { name: "options", type: "uint16" },
              { name: "totalVotes", type: "uint32" },
              { name: "description", type: "bytes" },
              { name: "text", type: "bytes" },
              { name: "voters", type: "address[]" },
              { name: "ts", type: "uint32" },
            ],
            name: "info",
            type: "tuple",
          },
        ],
      },
      {
        name: "getCurrentVotes",
        inputs: [],
        outputs: [
          { name: "votesFor", type: "uint32" },
          { name: "votesAgainst", type: "uint32" },
        ],
      },
    ],
    data: [{ key: 1, name: "deployer", type: "address" }],
    events: [
      {
        name: "ProposalFinalized",
        inputs: [
          {
            components: [
              { name: "id", type: "uint32" },
              { name: "passed", type: "bool" },
              { name: "votesFor", type: "uint32" },
              { name: "votesAgainst", type: "uint32" },
              { name: "totalVotes", type: "uint32" },
              { name: "model", type: "uint8" },
              { name: "ts", type: "uint32" },
            ],
            name: "results",
            type: "tuple",
          },
        ],
        outputs: [],
      },
    ],
  },
  image:
    "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",
};
