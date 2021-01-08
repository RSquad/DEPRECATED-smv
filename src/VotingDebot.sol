pragma solidity >=0.6.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;
import "Debot.sol";
import "DemiurgeStore.sol";
import "Base.sol";
import "IDemiurge.sol";
import "IPadavan.sol";
import "IProposal.sol";

contract DemiurgeClient is Base {

    address _demiurge;

    function requestPadavan(uint userKey) external view signed {
        IDemiurge(_demiurge).deployPadavan{value: DEPLOY_FEE}(userKey);
    }

    function requestProposal(
        uint32 totalVotes,
        uint32 start,
        uint32 end,
        string description,
        string text,
        VoteCountModel model
    ) external view signed {
        IDemiurge(_demiurge).deployProposal{value: DEPLOY_FEE}(totalVotes, start, end, description, text, model);
    }
}

abstract contract PadavanClient is Base {

    address _padavan;

    function updatePadavan(address addr) external virtual;

    function depositTons(uint32 tons) public view signed {
        IPadavan(_padavan).depositTons{value: uint64(tons) * 1 ton + 1 ton, bounce: true}(tons);
    }

    function depositTokens(address returnTo, uint256 tokenId, uint64 tokens) public view signed {
        IPadavan(_padavan).depositTokens{value: 1.5 ton, bounce: true}
            (returnTo, tokenId, tokens);
    }

    function reclaimDeposit(uint32 votes) public view signed {
        IPadavan(_padavan).reclaimDeposit{value: 1 ton, bounce: true}
            (votes);
    }

    function voteFor(address proposal, bool choice, uint32 votes) public view signed {
        IPadavan(_padavan).voteFor{value: 1 ton, bounce: true}
            (proposal, choice, votes);
        IProposal(proposal).wrapUp{value: 0.02 ton}();
    }

    function createTokenAccount(address root) public view signed {
        IPadavan(_padavan).createTokenAccount{value: 2 ton + /*just for tests*/ 2 ton, bounce: true}
            (root);
    }
}

contract VotingDebot is Debot, DError, PadavanClient, DemiurgeClient {

    // Debot context ids
    uint8 constant STATE_PRE_MAIN = 1;
    uint8 constant STATE_DEPOSITS = 2;
    uint8 constant STATE_VOTE = 3;
    uint8 constant STATE_VIEW = 4;
    uint8 constant STATE_NEW_PROP = 5;
    uint8 constant STATE_DEPOSIT_TONS = 6;
    uint8 constant STATE_DEPOSIT_TOKENS = 7;
    uint8 constant STATE_CREATE_ACC = 8;
    uint8 constant STATE_DEPLOY_PADAVAN = 9;
    uint8 constant STATE_DEPOSIT_STAKE = 10;
    uint8 constant STATE_VIEW_ALL = 11;
    uint8 constant STATE_VIEW_MY = 12;
    uint8 constant STATE_COMPLETED = 13;
    uint8 constant STATE_DEPOSIT_TOKENS2 = 14;
    uint8 constant STATE_NEW_PROP2 = 15;
    uint8 constant STATE_NEW_PROP3 = 16;
    uint8 constant STATE_RECLAIM = 17;
    
    struct TipAccount {
        address addr;
        uint256 walletKey;
        uint32 createdAt;
        uint128 balance;
    }

    struct CurrentToken {
        TipAccount info;
        uint256 id;
        address returnTo;
        address root;
    }

    struct VotingProposal {
        bool choice;
        address addr;
        uint32 id;
    }

    struct VoteInfo {
        // Number of votes requested to reclaim
        uint32 reqVotes;
        // Total number of votes available to user.
        uint32 totalVotes;
        // Number of votes that cannot be reclaimed until finish of one of active proposals.
        uint32 lockedVotes;
    }

    uint8 constant ABI_PROPOSAL = 1;
    uint8 constant ABI_DEMIURGE = 2;
    uint8 constant ABI_PADAVAN = 3;
    mapping(uint8 => string) _abis;

    /*
        Storage
    */

    address _demiDebot;

    uint256 _ballotId;

    VoteInfo _padavanInfo;
    
    VotingProposal _votingProposal;

    ProposalInfo _newprop;

    uint32 _tons;
    uint64 _tokens;
    uint32 _votes;

    uint32 _proposalCount;
    mapping(address => uint32) _activeProposals;
    mapping (uint32 => ProposalData) _data;
    mapping (uint32 => ProposalInfo) _info;
    mapping (address => TipAccount) _tokenAccounts;
    
    CurrentToken _currToken;


    modifier contractOnly() {
        require(msg.sender != address(0), 100);
        _;
    }

    /*
     *   Init functions
     */

    constructor(address demiDebot, address demiurge) signed public {
        _demiurge = demiurge;
        _demiDebot = demiDebot;
        
        DemiurgeStore(demiDebot).queryABI{value: 0.02 ton, bounce: true}(ContractType.Proposal);
        DemiurgeStore(demiDebot).queryABI{value: 0.02 ton, bounce: true}(ContractType.Demiurge);
        DemiurgeStore(demiDebot).queryABI{value: 0.02 ton, bounce: true}(ContractType.VotingDebot);
        DemiurgeStore(demiDebot).queryABI{value: 0.02 ton, bounce: true}(ContractType.Padavan);
    }

    function updateABI(ContractType kind, string sabi) external {
        require(msg.sender == _demiDebot);
        if (kind == ContractType.Demiurge) {
            _abis[ABI_DEMIURGE] = sabi;
        } else if (kind == ContractType.Proposal) {
            _abis[ABI_PROPOSAL] = sabi;
        } else if (kind == ContractType.Padavan) {
            m_targetAbi = sabi;
            m_options |= DEBOT_TARGET_ABI;
            _abis[ABI_PADAVAN] = sabi;
        } else if (kind == ContractType.VotingDebot) {
            m_debotAbi = sabi;
            m_options |= DEBOT_ABI;
        }
    }

    function updatePadavan(address addr) external override {
        _padavan = addr;
        m_target = addr;
        m_options |= DEBOT_TARGET_ADDR;
    }

    /*
     *  Overridden Debot functions
     */

    function fetch() public override accept returns (Context[] contexts) {
		optional(string) none;
        optional(string) fargs;
        
        if (_padavan == address(0)) {
            contexts.push(Context(STATE_ZERO, 
                "Hello, i'm your personal Voting Debot!\nYou don't have a padavan contract yet. Ready to deploy?", [
                ActionGoto("Yes, deploy", STATE_DEPLOY_PADAVAN),
                ActionGoto("Quit", STATE_EXIT) ] ));

        } else {
            fargs.set("getVoteArgs");
            contexts.push(Context(STATE_ZERO, 
                "Hello, i'm your personal Voting Debot!", [
                ActionInstantRun("", "switchTargetToDemiurge", STATE_CURRENT),
                ActionGetMethod("", "getProposalData", none, "setProposalData", true, STATE_CURRENT),
                ActionGetMethod("", "getProposalInfo", none, "setProposalInfo", true, STATE_CURRENT),
                ActionInstantRun("", "switchTargetToPadavan", STATE_CURRENT),
                ActionGetMethod("", "getVoteInfo", none, "setVoteInfo", true, STATE_CURRENT),
                ActionGetMethod("", "activeProposals", none, "setActiveProps", true, STATE_CURRENT),
                ActionPrintEx("", "Active proposals: {}\nTotal votes: {}\nLocked votes: {}\nAvailable votes: {}\nBallot address: {}", true, fargs, STATE_CURRENT),
                ActionGoto("Acquire votes", STATE_DEPOSITS),
                ActionGoto("Reclaim votes", STATE_RECLAIM),
                ActionGoto("Vote for proposal", STATE_VOTE),
                ActionGoto("View my proposals", STATE_VIEW_MY),
                ActionGoto("View all proposals", STATE_VIEW_ALL),
                ActionGoto("Create new proposal", STATE_NEW_PROP),
                ActionGoto("Quit", STATE_EXIT) ] ));
        }

        contexts.push(Context(STATE_RECLAIM,
            "", [
            ActionInstantRun("Enter number of votes:", "enterVotes", STATE_CURRENT),
            ActionSendMsg("Sign and reclaim", "sendReclaimDeposit", "sign=by_user", STATE_ZERO) ] ));

        contexts.push(Context(STATE_DEPOSITS,
            "Deposit menu:", [
            ActionGoto ("Deposit tons", STATE_DEPOSIT_TONS),
            ActionGoto("Return", STATE_ZERO) ] ));
        
        contexts.push(Context(STATE_VOTE,
            "Follow the instruction:", [
            ActionInstantRun("Enter proposal id:", "enterProposalId", STATE_CURRENT),
            ActionInstantRun("Enter votes count:", "enterVotes", STATE_CURRENT),
            ActionSendMsg("Vote Yes", "sendVoteForYes", "sign=by_user", STATE_ZERO),
            ActionSendMsg("Vote No", "sendVoteForNo", "sign=by_user", STATE_ZERO) ] ));

        contexts.push(Context(STATE_VIEW_ALL,
            "View proposals:", [
            ActionInstantRun("List of proposals", "printProposals", STATE_CURRENT),
            ActionGoto("Return", STATE_ZERO) ] ));
		
        contexts.push(Context(STATE_VIEW_MY,
            "List of voted proposals:", [
            ActionInstantRun("", "printActiveProposals", STATE_CURRENT),
            ActionGoto("Return", STATE_ZERO) ] ));
        
        (uint64 decimal, uint64 float) = tokens(DEPLOY_FEE);
        contexts.push(Context(STATE_DEPLOY_PADAVAN,
            "Deploy Padavan:", [
            ActionInstantRun("", "generateId", STATE_CURRENT),
            ActionPrintEx("", "Deploy fee is " + string(decimal) + "." + string(float) + " tons", true, none, STATE_CURRENT),
            ActionSendMsg("Deploy", "sendRequestPadavan", "sign=by_user", STATE_COMPLETED)
            ] ));

        contexts.push(Context(STATE_COMPLETED,
            "Deploy succeeded!", [
            ActionPrintEx("", "Please, restart debot.", true, none, STATE_CURRENT),
            ActionGoto("Exit", STATE_EXIT) ] ));

        contexts.push(Context(STATE_DEPOSIT_TONS,
            "Deposit tons:", [
            ActionInstantRun("Enter an integer number of tons:", "enterTons", STATE_CURRENT),
            ActionSendMsg("Sign and deposit", "sendDepositTons", "sign=by_user", STATE_ZERO),
            ActionGoto("Exit", STATE_EXIT) ] ));

        contexts.push(Context(STATE_NEW_PROP,
            "Create Proposal:", [
            ActionInstantRun("Enter total votes:", "enterMaxVotes", STATE_CURRENT),
            ActionInstantRun("Enter start time (unixtime):", "enterStart", STATE_CURRENT),
            ActionInstantRun("Enter end time (unixtime):", "enterEnd", STATE_CURRENT),
            ActionInstantRun("Enter description:", "enterDesc", STATE_CURRENT),
            ActionInstantRun("Enter text:", "enterProposalText", STATE_NEW_PROP2) ]));

        contexts.push(Context(STATE_NEW_PROP2,
            "Choose voting model:", [
            ActionRun("Super majority", "enterModelSuper", STATE_NEW_PROP3),
            ActionRun("Soft majority", "enterModelSoft", STATE_NEW_PROP3) ] ));

        contexts.push(Context(STATE_NEW_PROP3,
            "", [
            ActionSendMsg("Sign and create", "sendRequestProposal", "sign=by_user", STATE_ZERO) ] ));
        
    }

    function getVersion() public override accept returns (string name, uint24 semver) {
        name = "Voting DeBot";
        semver = (1 << 8) | 2;
    }

    function quit() public override accept { }

    uint32 constant ERROR_ZERO_ADDRESS = 1001;

    function getErrorDescription(uint32 error) public pure override returns (string desc) {
        error;
        return "unknown exception";
    }

    function switchTargetToDemiurge() public accept {
        m_target = _demiurge;
        m_targetAbi = _abis[ABI_DEMIURGE];
    }

    function switchTargetToPadavan() public accept {
        m_target = _padavan;
        m_targetAbi = _abis[ABI_PADAVAN];
    }
    /*
     *  Helpers
     */


    function tokens(uint128 nanotokens) private pure returns (uint64, uint64) {
        uint64 decimal = uint64(nanotokens / 1e9);
        uint64 float = uint64(nanotokens - (decimal * 1e9));
        return (decimal, float);
    }

    function generateId() public accept returns (Action[] actions) {
        optional(string) args;
        args.set("getLength");
        actions = [callEngine("genRandom", "", "setRandom", args)];
    }

    function getLength() public pure accept returns (uint32 length) {
        length = 32;
    }

    function setRandom(bytes buffer) public accept {
        _ballotId = buffer.toSlice().decode(uint256);
    }

    function setVoteInfo(uint32 reqVotes, uint32 totalVotes, uint32 lockedVotes) public accept {
        _padavanInfo.reqVotes = reqVotes;
        _padavanInfo.totalVotes = totalVotes;
        _padavanInfo.lockedVotes = lockedVotes;
    }

    function setActiveProps(mapping(address => uint32) activeProposals) public accept {
        _activeProposals = activeProposals;
        optional(address, uint32) prop = _activeProposals.min();
        uint32 count = 0;
        while (prop.hasValue()) {
            (address addr, ) = prop.get();
            count += 1;
            prop = _activeProposals.next(addr);
        }
        _proposalCount = count;
    }

    function getVoteArgs() public view accept returns (
        uint32 number0, uint32 number1, uint32 number2, uint32 number3, address param4
    ) {
        number0 = _proposalCount;
        number1 = _padavanInfo.totalVotes;
        number2 = _padavanInfo.lockedVotes;
        number3 = _padavanInfo.totalVotes - _padavanInfo.lockedVotes;
        param4 = _padavan;
    }
    
    function setProposalData(mapping(uint32 => ProposalData) proposals) public accept {
        _data = proposals;
    }

    function setProposalInfo(mapping(uint32 => ProposalInfo) proposals) public accept {
        _info = proposals;
    }

    function printProposals() public accept returns (Action[] actions) {
        optional(uint32, ProposalData) prop = _data.min();
        while (prop.hasValue()) {
            (uint32 id, ) = prop.get();
            prop = _data.next(id);
            actions = _printProp(id, actions);
        }
    }

    function _printProp(uint32 id, Action[] actions) private returns (Action[]) {
        optional(string) fargs;
        fargs.set("getProposalArgs");
        Action act = ActionPrintEx("", "ID {} {}\nStart: {}, End: {}\nState: {}, Total votes: {}, options: {}, Address: {}, creator: {}\n", true, fargs, STATE_CURRENT);
        TvmBuilder b;
        b.store(id);
        act.misc = b.toCell();
        actions.push(act);
        return actions;
    }

    function getProposalArgs(TvmCell misc) public view accept returns (
        uint32 number0, string str1, uint32 utime2, uint32 utime3, string str4, uint32 number5, string str6, address param7, address param8
    ) {
        uint32 id = misc.toSlice().decode(uint32);
        ProposalInfo info = _info[id];
        ProposalData data = _data[id];
        number0 = id;
        str1 = info.description;
        utime2 = info.start;
        utime3 = info.end;
        str4 = _stateToString(data.state);
        number5 = info.totalVotes;
        uint16 options = info.options;
        string opt = "";
        if (options & PROPOSAL_VOTE_SOFT_MAJORITY != 0) {
            opt = opt + "\"soft majority\"";
        } else if (options & PROPOSAL_VOTE_SUPER_MAJORITY != 0) {
            opt = opt + "\"super majority\"";
        }
        str6 = opt;
        param7 = data.addr;
        param8 = data.userWalletAddress;
    }

    function _stateToString(ProposalState state) inline private pure returns (string) {
        if (state <= ProposalState.New) {
            return "New";
        } 
        if (state == ProposalState.OnVoting) {
            return "Voting";
        }
        if (state == ProposalState.Ended) {
            return "Ended";
        }
        if (state == ProposalState.Passed) {
            return "Passed";
        }
        if (state == ProposalState.Failed) {
            return "Failed";
        }
        if (state == ProposalState.Finalized) {
            return "Finalized";
        }
        if (state == ProposalState.Distributed) {
            return "Distributed";
        }
        return "unknown";
    }

    function printActiveProposals() public accept returns (Action[] actions) {
        optional(string) none;
        if (_activeProposals.empty()) {
            actions.push(ActionPrintEx("", "No active proposals", true, none, STATE_CURRENT));
            return actions;
        }
        optional(address, uint32) prop = _activeProposals.min();
        while (prop.hasValue()) {
            (address addr, uint32 votes) = prop.get();
            prop = _activeProposals.next(addr);
            uint32 id = _findProposal(addr);
            actions = _printProp(id, actions);
            actions.push(ActionPrintEx("", "Sent votes: " + string(votes), true, none, STATE_CURRENT));
        }
    }

    function _findProposal(address findAddr) private view returns (uint32) {
        optional(uint32, ProposalData) prop = _data.min();
        while (prop.hasValue()) {
            (uint32 id, ProposalData pd) = prop.get();
            if (pd.addr == findAddr) {
                return id;
            }
            prop = _data.next(id);
        }
        return 0;
    }

    function enterProposalId(uint32 id) public accept {
        _votingProposal.id = id;
        //require(_data.exists(id));
    }

    function enterVotes(uint32 votes) public accept {
        _votes = votes;
    }

    function enterTons(uint32 tons) public {
        _tons = tons;
    }

    function enterTokens(uint64 value) public {
        _tokens = value;
    }

    function enterReturnTo(address returnTo) public {
        _currToken.returnTo = returnTo;
    }

    function enterRootAddress(address root) public {
        _currToken.root = root;
    }

    function enterMaxVotes(uint32 maxVotes) public {
        _newprop.totalVotes = maxVotes;
    }

    function enterStart(uint32 start) public {
        _newprop.start = start;
    }

    function enterEnd(uint32 end) public {
        _newprop.end = end;
    }

    function enterDesc(string desc) public {
        _newprop.description = desc;
    }

    function enterProposalText(string text) public {
        _newprop.text = text;
    }

    function enterModelSuper() public {
        _newprop.options |= PROPOSAL_VOTE_SUPER_MAJORITY;
    }

    function enterModelSoft() public {
        _newprop.options |= PROPOSAL_VOTE_SOFT_MAJORITY;
    }

    /*
    * Send Msg Requests
    */

    function sendRequestPadavan() public view accept returns (address dest, TvmCell body) {
        dest = address(this);
        body = tvm.encodeBody(DemiurgeClient.requestPadavan, _ballotId);
    }

    function sendVoteForYes() public view accept returns (address dest, TvmCell body) {
        (dest, body) = _sendVoteFor(true);
    }

    function sendVoteForNo() public view accept returns (address dest, TvmCell body) {
        (dest, body) = _sendVoteFor(false);
    }

    function _sendVoteFor(bool choice) private view inline returns (address dest, TvmCell body) {
        dest = address(this);
        address propAddr = _data[_votingProposal.id].addr;
        body = tvm.encodeBody(PadavanClient.voteFor, propAddr, choice, _votes);
    }

    function sendRequestProposal() public view accept returns (address dest, TvmCell body) {
        dest = address(this);
        ProposalInfo prop = _newprop;
        VoteCountModel model;
        if (prop.options & PROPOSAL_VOTE_SOFT_MAJORITY != 0) {
            model = VoteCountModel.SoftMajority;
        } else {
            model = VoteCountModel.SuperMajority;
        }

        body = tvm.encodeBody(
            DemiurgeClient.requestProposal,
            prop.totalVotes,
            prop.start,
            prop.end,
            prop.description,
            prop.text,
            model
        );
    }

    function sendDepositTons() public view accept returns (address dest, TvmCell body) {
        dest = address(this);
        body = tvm.encodeBody(PadavanClient.depositTons, _tons);
    }

    function sendDepositTokens() public view accept returns (address dest, TvmCell body) {
        dest = address(this);
        body = tvm.encodeBody(PadavanClient.depositTokens, _currToken.returnTo, _currToken.id, _tokens);
    }

    function sendReclaimDeposit() public view accept returns (address dest, TvmCell body) {
        dest = address(this);
        body = tvm.encodeBody(PadavanClient.reclaimDeposit, _votes);
    }

    function sendCreateAccount() public view accept returns (address dest, TvmCell body) {
        dest = address(this);
        body = tvm.encodeBody(PadavanClient.createTokenAccount, _currToken.root);
    }
    
}