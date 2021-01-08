pragma solidity >= 0.6.0;

import "IDemiurge.sol";
import "Padavan.sol";
import "Proposal.sol";
import "DemiurgeStore.sol";

abstract contract IClient {
    function updatePadavan(address addr) external {}
    function onProposalDeployed(uint32 id, address addr) external {}
    function onProposalCompletion(uint32 id, bool result) external {}    
}
 /*
    Exception codes:
    101 Not authorized to administer contest
    102 ID is already taken
*/
contract Demiurge is IDemiurge, IDemiurgeStoreCallback, Base {

    uint16 constant ERROR_NOT_AUTHORIZED_WALLET =       300; // Only UserWallet can request padavans
    uint16 constant ERROR_PADAVAN_ALREADY_DEPLOYED =    301; // Padavan already deployed
    uint16 constant ERROR_PROPOSAL_ALREADY_DEPLOYED =   302; // Proposal already deployed
    uint16 constant ERROR_NOT_ALL_CHECKS_PASSED =       303;
    uint16 constant ERROR_INIT_ALREADY_COMPLETED =      304;

    uint128 constant DEF_PROPOSAL_VALUE = 1e9;
    uint128 constant DEF_USER_WALLET_VALUE = 3e9;
        
    uint16 constant DEFAULT_OPTIONS = 0;

    uint8 constant CHECK_PROPOSAL = 1;
    uint8 constant CHECK_PADAVAN = 2;
    uint8 constant CHECK_DEPOOLS = 4;
    uint8 constant CHECK_PRICEPROVIDER = 8;

    TvmCell _padavanSI;
    TvmCell _proposalSI;

    address  public _priceProvider;
    address  public _infoCenter;

    mapping (uint => PadavanData) _deployedPadavans;
    mapping (address => uint32) _deployedProposals;

    mapping (uint32 => ProposalInfo) _proposalInfo;
    mapping (uint32 => ProposalData) _proposalData;
    VotingResults[] _votingResults;

    uint32 _deployedPadavansCounter;
    uint32 _deployedProposalsCounter;
    uint16 _version = 2;

    // Address of Demiurge Store - smc where all tvc and abi are stored.
    address demiStore;

    uint8 _checkList;

    mapping(address => bool) _depools;

    /*
    *  Inline work with checklist
    */

    function _createChecks() private inline {
        _checkList = CHECK_PADAVAN | CHECK_PROPOSAL | CHECK_PRICEPROVIDER | CHECK_DEPOOLS;
    }

    function _passCheck(uint8 check) private inline {
        _checkList &= ~check;
    }

    function _allCheckPassed() private view inline returns (bool) {
        return (_checkList == 0);
    }

    modifier checksEmpty() {
        require(_allCheckPassed(), ERROR_NOT_ALL_CHECKS_PASSED);
        _;
    }

    modifier signedAndChecksNotPassed() {
        require(tvm.pubkey() == msg.pubkey(), 100);
        require(!_allCheckPassed(), ERROR_INIT_ALREADY_COMPLETED);
        tvm.accept();
        _;
    }

    /*
    * Initialization functions
    */

    constructor(address store) public {
        if (msg.sender == address(0)) {
            require(msg.pubkey() == tvm.pubkey(), 101);
        }
        tvm.accept();

        if (store != address(0)) {
            demiStore = store;
            DemiurgeStore(demiStore).queryImage{value: 0.02 ton, bounce: true}(ContractType.Proposal);
            DemiurgeStore(demiStore).queryImage{value: 0.02 ton, bounce: true}(ContractType.Padavan);
            DemiurgeStore(demiStore).queryDepools{value: 0.02 ton, bounce: true}();
            DemiurgeStore(demiStore).queryAddress{value: 0.02 ton, bounce: true}(ContractType.PriceProvider);
        }
        _deployedPadavansCounter = 0;
        _deployedProposalsCounter = 0;

        _createChecks();
    }

    function updateImage(ContractType kind, TvmCell image) external override {
        require(msg.sender == demiStore);
        tvm.accept();
        if (kind == ContractType.Proposal) {
            _proposalSI = image;
            _passCheck(CHECK_PROPOSAL);
        } else if (kind == ContractType.Padavan) {
            _padavanSI = image;
            _passCheck(CHECK_PADAVAN);
        }
    }

    function updateDepools(mapping(address => bool) depools) external override {
        require(msg.sender == demiStore);
        tvm.accept();
        _depools = depools;
        _passCheck(CHECK_DEPOOLS);
    }

    function updateAddress(ContractType kind, address addr) external override {
        require(msg.sender == demiStore);
        tvm.accept();
        if (kind == ContractType.PriceProvider) {
            _priceProvider = addr;
            _passCheck(CHECK_PRICEPROVIDER);
        }
    }

    function updateABI(ContractType kind, string sabi) external override {
        require(false); kind; sabi;
    }

    /*
     * Public Deploy API
     */

    function deployPadavan(uint userKey) external override checksEmpty {
        require(!_deployedPadavans.exists(userKey), ERROR_PADAVAN_ALREADY_DEPLOYED);
        require(msg.value >= DEPLOY_FEE);
        TvmCell code = _padavanSI.toSlice().loadRef();
        TvmCell state = tvm.buildStateInit({
            contr: Padavan,
            varInit: {deployer: address(this)},
            pubkey: userKey,
            code: code
        });
        address addr = new Padavan {stateInit: state, value: START_BALANCE}();
        _deployedPadavans[userKey] = PadavanData(msg.sender, addr);
    }

    function onPadavanDeploy(uint key) external override {
        optional(PadavanData) opt = _deployedPadavans.fetch(key);
        require(opt.hasValue());
        PadavanData data = opt.get();
        require(msg.sender == data.addr);
        _deployedPadavansCounter++;
        Padavan(data.addr).initPadavan{value:0, flag: 64}
            (data.userWalletAddress, _priceProvider, _depools);
        IClient(data.userWalletAddress).updatePadavan(data.addr);
    }

    function _deployProposal(uint32 totalVotes, uint32 start, uint32 end, uint16 options, string description, string text, VoteCountModel model, address[] voters) private {
        uint32 key = _deployedProposalsCounter;
        require(msg.value >= DEPLOY_FEE);

        if (model == VoteCountModel.SoftMajority) {
            options |= PROPOSAL_VOTE_SOFT_MAJORITY;
        } else if (model == VoteCountModel.SuperMajority) {
            options |= PROPOSAL_VOTE_SUPER_MAJORITY;
        }

        ProposalInfo pi = ProposalInfo(key, start, end, options, totalVotes, description, text, voters, uint32(now));
        _proposalInfo[key] = pi;

        TvmCell code = _proposalSI.toSlice().loadRef();
        TvmCell state = tvm.buildStateInit({
            contr: Proposal,
            varInit: {deployer: address(this)},
            pubkey: key,
            code: code
        });

        address addr = new Proposal {stateInit: state, value: START_BALANCE}();
        _deployedProposals[addr] = key;
        _proposalData[key] = ProposalData(key, ProposalState.New, msg.sender, addr, uint32(now));
    }

    function deployProposal(uint32 totalVotes, uint32 start, uint32 end, string description, string text, VoteCountModel model) external override checksEmpty {
        address[] noVoters;
        delete noVoters;
        _deployProposal(totalVotes, start, end, DEFAULT_OPTIONS, description, text, model, noVoters);
    }

    function deployProposalWithWhitelist(uint32 totalVotes, uint32 start, uint32 end, string description, string text, VoteCountModel model, address[] voters) external override checksEmpty {
        _deployProposal(totalVotes, start, end, PROPOSAL_HAS_WHITELIST, description, text, model, voters);
    }

    function onProposalDeploy() external override {
        optional(uint32) opt = _deployedProposals.fetch(msg.sender);
        require(opt.hasValue());
        uint32 key = opt.get();
        
        ProposalInfo pi = _proposalInfo[key];

        Proposal(msg.sender).initProposal{value: DEF_COMPUTE_VALUE}(pi, _padavanSI);

        ProposalData pd = _proposalData[key];
        IClient(pd.userWalletAddress).onProposalDeployed(key, pd.addr);

        _deployedProposalsCounter++;
    }

    function onStateUpdate(ProposalState state) external override {
        optional(uint32) opt = _deployedProposals.fetch(msg.sender);
        require(opt.hasValue());
        uint32 key = opt.get();
        _proposalData[key].state = state;
        msg.sender.transfer(0, false, 64);
    }

    function reportResults(VotingResults results) external override {
        optional(uint32) opt = _deployedProposals.fetch(msg.sender);
        require(opt.hasValue());
        uint32 key = opt.get();
        _votingResults.push(results);
        ProposalData data = _proposalData[key];
        IClient(data.userWalletAddress).onProposalCompletion(key, results.passed);
    }

    /*
    *  Setters
    */

    function setProposalSI(TvmCell c) external signedAndChecksNotPassed {
        _proposalSI = c;
        _passCheck(CHECK_PROPOSAL);
    }

    function setPadavanSI(TvmCell c) external signedAndChecksNotPassed {
        _padavanSI = c;
        _passCheck(CHECK_PADAVAN);
    }

    function setPriceProvider(address addr) external signedAndChecksNotPassed {
        _priceProvider = addr;
        _passCheck(CHECK_PRICEPROVIDER);
    }

    function setDePool(address addr) external signedAndChecksNotPassed {
        _depools[addr] = true;
        _passCheck(CHECK_DEPOOLS);
    }

    function setInfoCenter(address addr) external signed {
        _infoCenter = addr;
    }

    function upgrade(TvmCell c) external view signed {
        tvm.setcode(c);
    }

    function grant(address addr, uint128 value) view external signed {
        addr.transfer(value, false, 3);
    }

    /*
    *   Get methods
    */

    function getImages() public view returns (TvmCell padavan, TvmCell proposal) {
        padavan = _padavanSI;
        proposal = _proposalSI;
    }

    function getDeployed() public view returns (mapping (uint => PadavanData) padavans, mapping (address => uint32) proposals) {
        padavans = _deployedPadavans;
        proposals = _deployedProposals;
    }

    function getVotingResults() public view returns (VotingResults[] results) {
        results = _votingResults;
    }

    function getProposalInfo() public view returns (mapping (uint32 => ProposalInfo) proposals) {
        proposals = _proposalInfo;
    }

    function getProposalData() public view returns (mapping (uint32 => ProposalData) proposals) {
        proposals = _proposalData;
    }

    function getStats() public view returns (uint16 version, uint32 deployedPadavansCounter, uint32 deployedProposalsCounter) {
        version = _version;
        deployedPadavansCounter = _deployedPadavansCounter;
        deployedProposalsCounter = _deployedProposalsCounter;
    }

    function getPadavan(uint key) public view returns (PadavanData data) {
        data = _deployedPadavans[key];
    }

}
