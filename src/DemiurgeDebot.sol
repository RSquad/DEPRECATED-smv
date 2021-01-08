pragma solidity >=0.6.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;
import "Debot.sol";
import "IDemiurge.sol";
import "VotingDebot.sol";
import "DemiurgeStore.sol";

contract Demiurge {
    constructor(address store) public {

    }
}

contract DemuirgeDebot is DemiurgeStore, Debot, DError {

    // Debot context ids
    uint8 constant STATE_DEPLOY_VOTING_DEBOT_0 = 1;
    uint8 constant STATE_DEPLOY_VOTING_DEBOT_1 = 2;
    uint8 constant STATE_DEPLOY_VOTING_DEBOT_2 = 3;
    uint8 constant STATE_DEPLOY_VOTING_DEBOT_3 = 4;
    uint8 constant STATE_DEPLOY_VOTING_DEBOT_4 = 5;
    uint8 constant STATE_DEPLOY_DEMIURGE       = 6;
    uint8 constant STATE_TRANSFER              = 7;
    uint8 constant STATE_SET_DEMI              = 8;
    uint8 constant STATE_SUCCEEDED             = 9;

    uint128 constant MIN_DEBOT_BALANCE = 1 ton;
    /*
        Storage
    */

    TvmCell _votingDebotState;
    uint256 _deployKey;
    address _userDebotAddr;
    uint128 _userDebotBalance;
    address _newDemiAddr;

    // helper modifier
    modifier accept() {
        tvm.accept();
        _;
    }

    /*
     *   Init functions
     */

    constructor(address demi, address priceProv, string debotAbi) public signed {
        tvm.accept();
        init(DEBOT_TARGET_ADDR | DEBOT_ABI, debotAbi, "", demi);
        priceProvider = priceProv;
    }

    function setVotingDebotSI(TvmCell state) public signed {
        images[uint8(ContractType.VotingDebot)] = state;
        m_targetAbi = abis[uint8(ContractType.VotingDebot)];
        m_options |= DEBOT_TARGET_ABI;
    }

    function setDemiurgeAddress(address addr) public signed {
        m_target = addr;
        m_options |= DEBOT_TARGET_ADDR;
    }

    function deployDemiurge(uint256 pubkey) public signed {
        TvmCell image = tvm.insertPubkey(images[uint8(ContractType.Demiurge)], pubkey);
        m_target = new Demiurge{stateInit: image, value: 3 ton, bounce: true}(address(this));
    }

    /*
     *  Overrided Debot functions
     */

    function fetch() public override accept returns (Context[] contexts) {
		optional(string) none;

        contexts.push(Context(STATE_ZERO, 
            "Hello, user, i'm a Demiurge Debot! What do you want to do?", [
            ActionPrintEx("", "Current Demiurge: " + hexstring(m_target.get()), true, none, STATE_CURRENT),
            ActionGoto("Attach another demiurge", STATE_SET_DEMI),
            ActionGoto("Deploy new demiurge - start new voting platform onchain", STATE_DEPLOY_DEMIURGE),
            ActionGoto("Deploy user voting debot", STATE_DEPLOY_VOTING_DEBOT_0),
            ActionPrint("Quit", "quit", STATE_EXIT) ] ));

        contexts.push(Context(STATE_SET_DEMI,
            "Attach new demiurge:", [
            ActionInstantRun("Enter demiurge address:", "enterDemiAddress", STATE_SET_DEMI),
            ActionPrintEx("", "Sign message with keypair used to deploy me.", true, none, STATE_CURRENT),
            ActionSendMsg("Sign and attach new demiurge", "sendSetDemiMsg", "sign=by_user", STATE_SUCCEEDED),
            ActionGoto("Exit", STATE_EXIT) ] ));

        contexts.push(Context(STATE_SUCCEEDED,
            "Succeeded!", [
            ActionPrintEx("", "Please, restart debot.", true, none, STATE_CURRENT),
            ActionGoto("Exit", STATE_EXIT)] ));

        contexts.push(Context(STATE_DEPLOY_VOTING_DEBOT_0,
            "Deploy User Voting Debot:", [
            ActionPrintEx("", "I will guide you step by step to deploy your personal debot for voting.\nThis debot will help you create proposals, vote for proposals and also deposit and reclaim funds for voting", true, none, STATE_CURRENT),
            ActionGoto ("Ok, continue", STATE_DEPLOY_VOTING_DEBOT_1),
            ActionPrint("Quit", "Bye!", STATE_EXIT) ] ));
        
        contexts.push(Context(STATE_DEPLOY_VOTING_DEBOT_1,
            "Step 1 of 4:", [
            ActionPrintEx("", "Important: generate master keypair for user debot. Keep it in secret because you will use it to control debot.\nFor security reasons debot cannot do it for you. Please, use external tool for this and come back with generated keypair.", true, none, STATE_CURRENT),
            ActionGoto("I already generated keypair. Continue", STATE_DEPLOY_VOTING_DEBOT_2),
            ActionGoto("I will generate keypair and come back later", STATE_EXIT) ] ));
		
        contexts.push(Context(STATE_DEPLOY_VOTING_DEBOT_2,
            "Step 2 of 4:", [
            ActionPrintEx("", "Ok, now you have to enter public key from generated keypair.", true, none, STATE_CURRENT),
            ActionRun("Enter public key", "enterPubkey", STATE_DEPLOY_VOTING_DEBOT_3) ] ));

        optional(string) fargs;
        fargs.set("getSummaryArgs");
        contexts.push(Context(STATE_DEPLOY_VOTING_DEBOT_3,
            "Step 3 of 4:", [
            ActionPrintEx("", "Voting Debot address: {}\nVoting Debot public key: {}", true, fargs, STATE_CURRENT),
            ActionPrintEx("", "Please, send at least 10 tons to debot address before i will be able to deploy voting debot at this address.", true, none, STATE_CURRENT),
            ActionGoto("I have sent tons to this address. Continue", STATE_DEPLOY_VOTING_DEBOT_4),
            ActionGoto("Transfer tons from user multisig", STATE_TRANSFER),
            ActionPrint("Quit", "Bye!", STATE_EXIT) ] ));
        
        contexts.push(Context(STATE_DEPLOY_VOTING_DEBOT_4,
            "Step 4 of 4:", [
            ActionInstantRun("", "queryBalance", STATE_CURRENT),
            ActionPrintEx("", "I'm ready for deploy. Please, sign deploy message with generated keypair (at step 1).", true, none, STATE_CURRENT),
            ActionSendMsg("Sign and deploy", "sendDeployMsg", "sign=by_user", STATE_ZERO),
            ActionPrint("Quit", "Bye!", STATE_EXIT) ] ));

        fargs.set("getNewDemiArgs");
        contexts.push(Context(STATE_DEPLOY_DEMIURGE,
            "Deploy new demiurge:", [
            ActionPrintEx("", "Please, generate seed phrase for new demiurge.", true, none, STATE_CURRENT),
            ActionInstantRun("Enter public key generated from this phrase:", "enterDemiKey", STATE_CURRENT),
            ActionPrintEx("", "Generated demiurge address: {}", true, fargs, STATE_CURRENT),
            ActionPrintEx("", "Now, sign message with keypair used to deploy me.", true, none, STATE_CURRENT),
            ActionSendMsg("Sign and deploy", "sendDeployDemiMsg", "sign=by_user", STATE_SUCCEEDED),
            ActionGoto("Exit", STATE_EXIT) ] ));
    }

    function getVersion() public override accept returns (string name, uint24 semver) {
        name = "Demiurge DeBot";
        semver = (1 << 8) | 0;
    }

    function quit() public override accept { }

    uint32 constant ERROR_DEBOT_BALANCE_TOO_LOW = 1001;

    function getErrorDescription(uint32 error) public pure override returns (string desc) {
        if (error == ERROR_DEBOT_BALANCE_TOO_LOW) {
            return "User debot's balance is too low.";
        }
        return "unknown exception";
    }

    /*
     *  Helpers
     */

    function tokens(uint128 nanotokens) private pure returns (uint64, uint64) {
        uint64 decimal = uint64(nanotokens / 1e9);
        uint64 float = uint64(nanotokens - (decimal * 1e9));
        return (decimal, float);
    }


    function queryBalance() public accept returns (Action[] actions) {
        optional(string) args;
        args.set("getUserDebotAddress");
        actions = [ callEngine("getBalance", "", "setUserDebotBalance", args) ];
    }

    function setUserDebotBalance(uint128 arg1) public accept {
        _userDebotBalance = arg1;
        require(_userDebotBalance >= MIN_DEBOT_BALANCE, ERROR_DEBOT_BALANCE_TOO_LOW);
    }

    function getUserDebotAddress() public view accept returns (address addr) {
        addr = _userDebotAddr;
    }

    function enterPubkey(uint256 pubkey) public accept {
        _deployKey = pubkey;
        _votingDebotState = tvm.insertPubkey(images[uint8(ContractType.VotingDebot)], _deployKey);
        _userDebotAddr = address.makeAddrStd(0, tvm.hash(_votingDebotState));
    }

    function getSummaryArgs() public view accept returns (address param0, uint256 param1) {
        param0 = _userDebotAddr;
        param1 = _deployKey;
    }

    function enterDemiKey(uint256 pubkey) public accept {
        _deployKey = pubkey;
        TvmCell image = tvm.insertPubkey(images[uint8(ContractType.Demiurge)], pubkey);
        _newDemiAddr = address.makeAddrStd(0, tvm.hash(image));
    }

    function enterDemiAddress(address addr) public accept {
        _newDemiAddr = addr;
    }

    function getNewDemiArgs() public view accept returns (address param0) {
        param0 = _newDemiAddr;
    }

    /*
    *  Send Msg actions
    */

    function sendDeployMsg() public view accept returns (address dest, TvmCell body, TvmCell state) {
        dest = _userDebotAddr;
        body = tvm.encodeBody(VotingDebot, address(this), m_target);
        state = _votingDebotState;
    }

    function sendDeployDemiMsg() public view accept returns (address dest, TvmCell body) {
        dest = address(this);
        body = tvm.encodeBody(deployDemiurge, _deployKey);
    }

    function sendSetDemiMsg() public view accept returns (address dest, TvmCell body) {
        dest = address(this);
        body = tvm.encodeBody(setDemiurgeAddress, _newDemiAddr);
    }
}
