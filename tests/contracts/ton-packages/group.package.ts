export default {"name":"Group","abi":{"ABI version":2,"header":["time"],"functions":[{"name":"initGroup","inputs":[{"name":"deployer","type":"address"}],"outputs":[]},{"name":"setDeployer","inputs":[{"name":"addr","type":"address"}],"outputs":[]},{"name":"setInitialMembers","inputs":[{"name":"addrs","type":"address[]"}],"outputs":[]},{"name":"initGroupTemplates","inputs":[],"outputs":[]},{"name":"applyFor","inputs":[{"name":"name","type":"bytes"}],"outputs":[]},{"name":"resign","inputs":[],"outputs":[]},{"name":"unseat","inputs":[{"name":"id","type":"uint32"},{"name":"addr","type":"address"}],"outputs":[]},{"name":"addMember","inputs":[{"name":"id","type":"uint32"},{"name":"addr","type":"address"}],"outputs":[]},{"name":"removeMember","inputs":[{"name":"addr","type":"address"}],"outputs":[]},{"name":"onProposalDeployed","inputs":[{"name":"id","type":"uint32"},{"name":"addr","type":"address"}],"outputs":[]},{"name":"onProposalCompletion","inputs":[{"name":"id","type":"uint32"},{"name":"result","type":"bool"}],"outputs":[]},{"name":"getMembers","inputs":[],"outputs":[{"name":"members","type":"map(address,uint32)"}]},{"name":"getActive","inputs":[],"outputs":[{"components":[{"name":"id","type":"uint32"},{"name":"proposalAddr","type":"address"},{"name":"topic","type":"uint8"},{"name":"subject","type":"address"}],"name":"active","type":"map(uint32,tuple)"}]},{"name":"getCandidates","inputs":[],"outputs":[{"name":"candidates","type":"map(address,uint32)"}]},{"name":"constructor","inputs":[],"outputs":[]}],"data":[],"events":[]},"image":"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"}