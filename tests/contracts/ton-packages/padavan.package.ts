export default {"name":"Padavan","abi":{"ABI version":2,"header":["time"],"functions":[{"name":"constructor","inputs":[],"outputs":[]},{"name":"initPadavan","inputs":[{"name":"wallet","type":"address"},{"name":"voteProvider","type":"address"},{"name":"depoolAddrs","type":"map(address,bool)"}],"outputs":[]},{"name":"voteFor","inputs":[{"name":"proposal","type":"address"},{"name":"choice","type":"bool"},{"name":"votes","type":"uint32"}],"outputs":[]},{"name":"confirmVote","inputs":[{"name":"pid","type":"uint64"},{"name":"deposit","type":"uint32"}],"outputs":[]},{"name":"rejectVote","inputs":[{"name":"pid","type":"uint64"},{"name":"deposit","type":"uint32"},{"name":"ec","type":"uint16"}],"outputs":[]},{"name":"reclaimDeposit","inputs":[{"name":"votes","type":"uint32"}],"outputs":[]},{"name":"updateStatus","inputs":[{"name":"pid","type":"uint64"},{"name":"state","type":"uint8"}],"outputs":[]},{"name":"transferFunds","inputs":[{"name":"to","type":"address"},{"name":"val","type":"uint128"}],"outputs":[]},{"name":"depositTons","inputs":[{"name":"tons","type":"uint32"}],"outputs":[]},{"name":"updateTonsPerVote","inputs":[{"name":"queryId","type":"uint32"},{"name":"price","type":"uint64"}],"outputs":[]},{"name":"depositTokens","inputs":[{"name":"returnTo","type":"address"},{"name":"tokenId","type":"uint256"},{"name":"tokens","type":"uint64"}],"outputs":[]},{"name":"updateTipsPerVote","inputs":[{"name":"queryId","type":"uint32"},{"name":"price","type":"uint64"}],"outputs":[]},{"name":"onTransfer","inputs":[{"name":"source","type":"address"},{"name":"amount","type":"uint128"}],"outputs":[]},{"name":"onGetBalance","inputs":[{"name":"balance","type":"uint128"}],"outputs":[]},{"name":"onTokenWalletDeploy","inputs":[{"name":"wallet","type":"address"}],"outputs":[]},{"name":"createTokenAccount","inputs":[{"name":"tokenRoot","type":"address"}],"outputs":[]},{"name":"getDeposits","inputs":[],"outputs":[{"components":[{"name":"tokenId","type":"uint256"},{"name":"returnTo","type":"address"},{"name":"amount","type":"uint64"},{"name":"valuePerVote","type":"uint64"},{"name":"approved","type":"bool"},{"name":"depool","type":"uint256"}],"name":"allDeposits","type":"map(uint32,tuple)"}]},{"name":"getTokenAccounts","inputs":[],"outputs":[{"components":[{"name":"addr","type":"address"},{"name":"walletKey","type":"uint256"},{"name":"createdAt","type":"uint32"},{"name":"balance","type":"uint128"}],"name":"allAccounts","type":"map(address,tuple)"}]},{"name":"getVoteInfo","inputs":[],"outputs":[{"name":"reqVotes","type":"uint32"},{"name":"totalVotes","type":"uint32"},{"name":"lockedVotes","type":"uint32"}]},{"name":"getAddresses","inputs":[],"outputs":[{"name":"userWallet","type":"address"},{"name":"priceProvider","type":"address"}]},{"name":"depools","inputs":[],"outputs":[{"name":"depools","type":"map(address,bool)"}]},{"name":"activeProposals","inputs":[],"outputs":[{"name":"activeProposals","type":"map(address,uint32)"}]}],"data":[{"key":1,"name":"deployer","type":"address"}],"events":[{"name":"VoteRejected","inputs":[{"name":"pid","type":"uint64"},{"name":"votes","type":"uint32"},{"name":"ec","type":"uint16"}],"outputs":[]}]},"image":"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"}