# Soft Majority Voting Smart-contract System

## Overview

The purpose of the System is to automate the decentralized governance for Free TON communities through voting.

## System’s Smart contracts

### The main smart contracts of the System

#### **Demiurge**

It is a central smart contract in a voting system. It is a ledger that creates and stores proposals and user padavan addresses. After deployment demiurge requests Demiurge Store smart contract to gain proposal and padavan images (tvc), list of depool addresses and address of vote price provider.

Demiurge starts in preworking mode in which it has several checks that must be passed before it will accept requests to deploy proposals and padavans. Checks contains the following:

1. Check that the demiurge contains a proposal image.
2. Check that the demiurge contains a padavan image.
3. Check that demiurge contains a list of depools.
4. Check that demiurge contains the address of a price provider.
   When the check mask becomes equal to 0 Demiurge is ready to work.

`PUBLIC API`

`constructor(address store)`

`store` - address of Demiurge Store that stores all ABIs and TVCs of the voting system.

> Remark: Demiurge Debot is a Demiurge Store as well.

Called on demiurge deployment. Calls Demiurge Store to acquire necessary parameters.

`deployPadavan(uint userKey)`

Called by internal message only and paid by caller. Allows to deploy Padavan smart contract.

`userKey` - public key sent by user that is inserted into an instance of Padavan before deployment.

`deployProposal(uint32 totalVotes, uint32 start, uint32 end, string description, string text, VoteCountModel model)`

Called by internal message only and paid by caller. Allows to create and deploy Proposal smart contract.

`totalVotes` - total number of votes for proposal.

`start` - unixtime when proposal starts accepting votes.

`end` - unixtime when proposal finishes accepting votes.

`description` - short name of the proposal.

`text` - any information about the proposal.

`model` - voting model, can be soft majority, super majority or simple majority.

`deployProposalWithWhitelist(uint32 totalVotes, uint32 start, uint32 end, string description, string text, VoteCountModel model, address[] voters)`

Called by internal message only and paid by caller. Allows to create and deploy Proposal that accepts votes only from Padavans from voters list.

All parameters are the same as in `deployProposal`.

`voters` - white list of Padavan addresses that can vote for proposal.

`function onStateUpdate(ProposalState state)`

Called by any proposal (created previously by this demiurge) to notify about his new status.

#### **Padavan**

Padavan smart contract is a user ballot that allows users to vote for proposals. Padavan accepts deposits of different types (tons, tip3 tokens, depool stakes), converts them to votes and sends votes to proposals. Votes cannot be converted into deposits and received back until all the proposals that the Padavan voted for are completed. The User can vote for different proposals with a different number of votes, but a number of locked votes in padavan is always the maximum number of votes spent for one proposal.

At any time a user can ask to reclaim some deposits equivalent to a number of votes. When it happens Padavan starts to query the status of all voted proposals. If any of them is already completed Padavan removes it from the active proposals list and updates the value of locked votes. If the required number of votes becomes less or equal to unlocked votes then Padavan converts the requested number of votes into a deposit (tons, tokens or stake) and sends it back to the user.

Padavan is controlled by a user contract that requested `deployPadavan` from Demiurge.

`PUBLIC API`

`function voteFor(address proposal, bool choice, uint32 votes)`

Called by internal message only and paid by caller. Allows to vote for the proposal with certain votes (yes or no).

`proposal` - address of proposal to vote for.

`choice` - ‘yes’ or ‘no’.

`votes` - number of votes to send for proposal.

`function depositTons(uint32 tons)`

Called by internal message only and paid by caller. Allows to deposit tons into Padavan. Deposit is converted to votes using the vote price requested from PriceProvider smart contract.

`tons` - number of tons to deposit and lock in Padavan.

`function depositTokens(address returnTo, uint256 tokenId, uint64 tokens)`

Called by internal message only and paid by caller. Allows to deposit and lock tip3 tokens into Padavan. Tokens must be already transferred to Padavan’s tip3 token account (wallet) before this function is called. This function checks that the balance of Padavan’s token wallet must be bigger then `tokens` argument. If so then the deposit is accepted and locked in a token account and converted into votes.

`returnTo` - address of user token wallet to which return tokens when they will be unlocked.

`tokenId` - ID of tip3 token. It is an address of the root token wallet without workchain id.

`tokens` - number tip3 tokens to deposit into Padavan.

`function reclaimDeposit(uint32 deposit)`

Called by internal message only and paid by caller. Allows to return deposits (tons, tip3 tokens, depool stake) back to the user.

`deposit` - number of votes that must be converted to deposits and returned to the user.

`function confirmVote(uint64 pid, uint32 deposit)`

Called by Proposal to notify Padavan that votes are accepted.

`pid` - proposal id.

`deposit` - number of accepted votes.

`function rejectVote(uint64 pid, uint32 deposit, uint16 ec)`

Called by Proposal to notify Padavan that votes are rejected.

`pid` - proposal id.

`deposit` - number of rejected votes.

`ec` - reason of rejection (exit code).

`function updateStatus(uint64 pid, ProposalState state)`

Called by Proposal to response on Padavan’s queryStatus request.

`state` - proposal current state (can be New, onVoting, FInalized, Ended, Passed, Failed).

`function createTokenAccount(address tokenRoot)`

Allows user to create tip3 token wallet controlled by Padavan. Created token wallet can be used to deposit tip3 tokens to it.

`tokenRoot` - address of token root smart contract that emits tip3 tokens.

`function onTransfer(address source, uint128 amount)`

Called by DePool to transfer ownership of user stake to Padavan.

`source` - address of user wallet that transfers ownership to Padavan.

`amount` - number of transferred nanotons.

### Proposal

Smart contract that accumulates votes from Padavans. Deployed by Demiurge by user request (`deployProposal`) Notifies about its state to Demiurge.

Can be optionally instantiated with a white list of Padavan addresses. In that case Proposal accepts votes only from addressed from this list.

`PUBLIC API`

`voteFor(uint256 key, bool choice, uint32 deposit)`

Called by Padavans to vote for the proposal. Proposal makes a verification check (see TIP3 spec) to be sure that the sender is a Padavan smc.

`key` - Padavan public key. Used in a verification check.

`choice` - “yes” or “no”.

`deposit` - number of votes.

`queryStatus()` Called by Padavan to query Proposal status.

`wrapUp()`

Can be called by any smart contract by internal message. Asks

### Proposal to update its status.

#### **Demiurge Debot**

An entry point to an onchain voting system. Allows to deploy new Demiurge to blockchain or to attach to existing Demiurge. Also deploys Voting Debot for users.
Debot implements the interface of Demiurge Store and stores all images (tvc) and ABIs of voting system contracts.

#### **Voting Debot**

Debot that works on behalf of the user. Deploys Padavan and allows to create new proposals, deposit tons, convert them to votes and vote for existing proposals.

### External smart contracts used by voting system

#### **NSEGiver**

Builtin giver of NodeSE. Used to deploy contracts in local node tests.

#### **RootTokenContract & TONTokenWallet**

TIP3 smart contracts. Can be found here:
https://github.com/tonlabs/ton-labs-contracts/tree/master/cpp/tokens-fungible

#### **DePool**

DePool smart contract. Used to transfer ownership of user stake to Padavan. Can be found here:
https://github.com/tonlabs/ton-labs-contracts/tree/master/cpp/solidity/depool

#### **PriceProvider**

Simple smart contract that implements an interface of converting tons and tokens to votes.

## Smart contracts used by test system

#### **UserWallet**

Test user wallet used to send requests to Demiurge and control Padavan.

#### **BatchGiver**

Giver smart contract that allows to make several transfers in one transaction. Used to increase speed of contracts deployment.

## Testing

All tests of the System are located in the tests directory.

For tests used:

```
"chai": "^4.2.0",
"mocha": "^8.2.1",
"typescript": "^4.1.3",
"@tonclient/core": "^1.5.0",
"@tonclient/lib-node": "^1.5.0"
```

To run tests, it is proposed to use Node in the package ton-dev-cli (https://github.com/tonlabs/ton-dev-cli). Important! Docker is required for correct work of tondev.

- Install node.js (https://nodejs.org/en/)
- Install docker (https://www.docker.com)
- Install tondev. `npm install -g ton-dev-cli` If you encounter problems during installation, read the instructions in the official repository
- Go to the project folder and install the dependencies npm install
- Create `.env` file at the root of the project and fill it in. Available variables (this example can be used to work with Node SE):

```
NSE_GIVER_ADDRESS=0:841288ed3b55d9cdafa806807f02a0ae0c169aa5edfe88a789a6482429756a94
NETWORK=LOCAL
```

Run Node SE tondev start
Run tests:
npm run test will run all available tests
npm run test:TEST_NAME will run the specified test, where the TEST_NAME is the name of the test (see “Description of tests”)
Infrastructure
The project infrastructure consists of the following directories:

```
├── index.ts
├── package-lock.json
├── package.json
├── src     // smart-contracts source code
├── tests   // tests dir
│   ├── base-against.test.ts  // base voting scenario #1 (against)
│   ├── base-depool.test.ts   // base voting scenario #2
│   ├── base-token.test.ts    // base voting scenario #3
│   ├── base.test.ts          // base voting scenario #1
│   ├── majorities.test.ts    // test different majorities
│   └── whitelist.test.ts     // test whitelist
│   ├── contracts             // ton contracts packages dir
│   │   ├── ton-contract.ts             // class for ton-contracts
│   │   └── ton-packages                // ton-contracts packages with tvc and abi
│   │       ├── alt-giver.package.ts
│   │       ├── batch-giver.package.ts
│   │       ├── console.package.ts
│   │       ├── demiurge.package.ts
│   │       ├── depool.package.ts
│   │       ├── dev-giver.package.ts
│   │       ├── group.package.ts
│   │       ├── nse-giver.package.ts
│   │       ├── padavan.package.ts
│   │       ├── priceprovider.package.ts
│   │       ├── proposal.package.ts
│   │       ├── roottokencontract.package.ts
│   │       ├── tontokenwallet.package.ts
│   │       └── userwallet.package.ts
│   ├── parts                 // test parts dir
│   │   ├── check-proposal-results.ts
│   │   ├── deploy-padavan.ts
│   │   ├── deploy-proposal.ts
│   │   ├── deploy-system.ts
│   │   ├── deposit-to-padavan.ts
│   │   ├── reclaim.ts
│   │   ├── reclaimTokens.ts
│   │   └── vote.ts
│   ├── utils                 // test utils dir
│   │   ├── code.ts
│   │   ├── common.ts
│   │   └── convert.ts
└── tsconfig.json
```

### ton-contracts.ts

Class for working with TON contracts. It provides a convenient interface for deploying, calling, getting balance, and so on. Used in tests everywhere.

Interface:

```
export class TonContract {
 client: TonClient;
 name: string;
 tonPackage: TonPackage;
 keys?: KeyPair;
 address?: string;

 async init(params?: any): Promise<void> {}

 async callLocal({ functionName, input = {} }: { functionName: string; input?: {} }): Promise<DecodedMessageBody> {}

 async call({ functionName, input }: { functionName: string; input?: any }): Promise<ResultOfProcessMessage> {}

 async calcAddress({ initialData } = { initialData: {} }): Promise<string> {}

 async deploy({ initialData, input }: { initialData?: any; input?: any } = {}): Promise<ResultOfSendMessage> {}

 async getBalance(): number {}
}
```

### ton-packages.ts

Package which consists of ABI and tvc.

Interface:

```
type TonPackage = {
 image: string;
 abi: {};
};
```
