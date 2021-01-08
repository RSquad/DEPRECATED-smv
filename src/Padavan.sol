pragma solidity >= 0.6.0;

import "Base.sol";
import "IProposal.sol";
import "IDemiurge.sol";
import "IPadavan.sol";
import "IPriceProvider.sol";
import "ITokenRoot.sol";
import "ITokenWallet.sol";
import "IGroup.sol";

interface IDePool {
    function transferStake(address dest, uint64 amount) external;
}

contract Padavan is Base, IPadavan, IPriceProviderCallback {
    uint32 constant ERROR_UNAUTHORIZED_CALLER = 110;
    uint32 constant ERROR_NOT_ENOUGH_VOTES = 111;
    uint32 constant ERROR_NO_MORE_THAN_ONE_RECLAIM_AT_A_TIME = 112;
    uint32 constant ERROR_NOT_A_USER_WALLET = 113;
    uint32 constant ERROR_MSG_VALUE_TOO_LOW = 114;

    uint32 constant ERROR_TOKEN_ACCOUNT_ALREADY_EXISTS = 115;
    uint32 constant ERROR_INVALID_ROOT_CALLER = 116;
    uint32 constant ERROR_ANSWER_ID_NOT_FOUND = 117;
    uint32 constant ERROR_ACCOUNT_DOES_NOT_EXIST = 118;
    uint32 constant ERROR_DEPOSIT_NOT_FOUND = 119;
    uint32 constant ERROR_CALLER_IS_NOT_DEPOOL = 120;
    uint32 constant ERROR_DEPOSIT_WITH_SUCH_ID_EXISTS = 121;
    uint32 constant ERROR_PENDING_DEPOSIT_ALREADY_EXISTS = 122;
    uint32 constant ERROR_INVALID_DEPLOYER = 123;



    uint64 constant DEPOSIT_TONS_FEE = 1 ton;
    uint64 constant DEPOSIT_TIPS_FEE = 0.5 ton + DEPOSIT_TONS_FEE;
    uint64 constant QUERY_STATUS_FEE = 0.02 ton;

    struct Deposit {
        uint256 tokenId;
        address returnTo;
        uint64 amount;
        uint64 valuePerVote; //1e-9
        bool approved;
        uint256 depool;
    }

    struct TipAccount {
        address addr;
        uint256 walletKey;
        uint32 createdAt;
        uint128 balance;
    }

    // ProposalDeployer address
    address static deployer;
    // User wallet address.
    address _wallet;
    // Address of a service smc that knows voice price.
    address _priceProvider;
    // List of DePool addresses.
    mapping(address => bool) public depools;

    // Collection of padavan's token accounts.
    // map [token root address] => account struct
    mapping (address => TipAccount) tokenAccounts;
    // Set of deposits of different currencies (crystals, tip tokens, depool stake)
    // map [createdAt] => Deposit struct
    mapping (uint32 => Deposit) deposits;

    // predefined TokenId for Crystals currency
    uint256 _crystalsID = 0;
    // predefined TokenId for DePool Stake
    uint256 _depoolID = 1;

    // Set of proposal address for which user is voted and which are not finalized yet.
    mapping(address => uint32) public activeProposals;

    // Set of proposal votes.
    // Used for easy querying locked votes.
    // map [votes] -> counter
    mapping(uint32 => uint32) _spentVotes;

    // Number of votes requested to reclaim
    uint32 _requestedVotes;
    // Total number of votes avaliable to user.
    uint32 _totalVotes;
    // Number of votes that cannot be reclaimed until finish of one of active proposals.
    uint32 _lockedVotes;
    // Id of token deposit that is not approved yet.
    // If  == 0, there is no pending deposits.
    uint32 _pendingDepositId;

    event VoteRejected(uint64 pid, uint32 votes, uint16 ec);

    /*
     *  Helpers
     */
     
    modifier contractOnly() {
        require(msg.sender != address(0));
        _;
    }

    modifier onlyUserWallet() {
        require(msg.sender == _wallet, ERROR_NOT_A_USER_WALLET);
        _;
    }

    /*
    *  Initialization
    */

    constructor() public contractOnly {
        require(deployer == msg.sender, ERROR_INVALID_DEPLOYER);
        IDemiurge(deployer).onPadavanDeploy{value: 1 ton}(tvm.pubkey());
    }

    function initPadavan(address wallet, address voteProvider, mapping(address => bool) depoolAddrs) external {
        require(msg.sender == deployer, ERROR_UNAUTHORIZED_CALLER);
        _wallet = wallet;
        _priceProvider = voteProvider;
        depools = depoolAddrs;
    }

    /*
    *  Public Voting API
    */

    /// @notice Allows user to vote for proposal.
    function voteFor(address proposal, bool choice, uint32 votes) external override onlyUserWallet {
        optional(uint32) opt = activeProposals.fetch(proposal);
        uint32 proposalVotes = opt.hasValue() ? opt.get() : 0;
        uint32 availableVotes = _totalVotes - proposalVotes;
        require(votes <= availableVotes, ERROR_NOT_ENOUGH_VOTES);

        if (!opt.hasValue()) {
            activeProposals[proposal] = 0;
        }
        IProposal(proposal).voteFor{value: 0, flag: 64, bounce: true}(tvm.pubkey(), choice, votes);
    }

    /// @notice Called by Proposal smc in case if votes are accepted.
    function confirmVote(uint64 pid, uint32 deposit) external override contractOnly {
        // pid - unused
        pid = pid;

        optional(uint32) opt = activeProposals.fetch(msg.sender);
        require(opt.hasValue());
        uint32 propVotes = opt.get();
        uint32 newPropVotes = deposit + propVotes;
        activeProposals[msg.sender] = newPropVotes;

        _deleteSpentVotes(propVotes);

        _spentVotes[newPropVotes] += 1;

        _updateLockedVotes();
        // return change for `voteFor` back to user
        _wallet.transfer(0, false, 64);
    }

    /// @notice Called by Proposal smc in case if votes are rejected.
    function rejectVote(uint64 pid, uint32 deposit, uint16 ec) external override contractOnly {
        optional(uint32) opt = activeProposals.fetch(msg.sender);
        require(opt.hasValue());
        uint32 propVotes = opt.get();
        if (propVotes == 0) {
            delete activeProposals[msg.sender];
        }
        _wallet.transfer(0, false, 64);
        emit VoteRejected(pid, deposit, ec);
    }

    /// @notice Allows to withdraw unlocked user votes back in crystal or tons.
    /// @param votes - number of votes to reclaim.
    function reclaimDeposit(uint32 votes) external override onlyUserWallet {
        require(msg.value >= 1 ton, ERROR_MSG_VALUE_TOO_LOW);
        require(votes <= _totalVotes, ERROR_NOT_ENOUGH_VOTES);
        _requestedVotes = votes;

        if (_requestedVotes <= _totalVotes - _lockedVotes) {
            _unlockDeposit();
        }
        // need to query status of each active proposal
        optional(address, uint128) proposal = activeProposals.min();
        while (proposal.hasValue()) {
            (address addr, /* uint128 votes*/) = proposal.get();
            IProposal(addr).queryStatus{value: QUERY_STATUS_FEE, bounce: true, flag: 1}();
            proposal = activeProposals.next(addr);
        }
    }

    /*
    *  Groups API
    */

    function applyToGroup(address group, string name) external override onlyUserWallet {
        IGroup(group).applyFor(name);
    }

    function removeFromGroup(address group, uint32 id, address addr) external override onlyUserWallet {
        IGroup(group).unseat(id, addr);
    }

    /// @notice Receives proposal status. Called by Proposal smc as an answer on queryStatus().
    function updateStatus(uint64 pid, ProposalState state) external override contractOnly {
        pid = pid;
        optional(uint32) opt = activeProposals.fetch(msg.sender);
        require(opt.hasValue());
        tvm.accept();

        // if proposal is ended
        if (state >= ProposalState.Ended) {
            _deleteSpentVotes(opt.get());
            _updateLockedVotes();
            delete activeProposals[msg.sender];
        }

        if (_requestedVotes <= _totalVotes - _lockedVotes) {
            _unlockDeposit();
        }
    }
    
    /*
    *   Private functions
    */

    function _deleteSpentVotes(uint32 votes) private {
        optional(uint32) spentOpt = _spentVotes.fetch(votes);
        if (spentOpt.hasValue()) {
            uint32 counter = spentOpt.get();
            if (counter > 1) {
                _spentVotes[votes] = counter - 1;
            } else {
                delete _spentVotes[votes];
            }
        }
    }

    /// @notice update locked votes
    function _updateLockedVotes() private inline {
        uint32 maxVotes = 0;
        optional(uint32, uint32) maxVotesOpt = _spentVotes.max();
        if (maxVotesOpt.hasValue()) {
            (uint32 votes, ) = maxVotesOpt.get();
            maxVotes = votes;
        }
        if (_lockedVotes != maxVotes) {
            _lockedVotes = maxVotes;
        }
    }

    function _unlockDeposit() private {
        uint32 origVotes = _requestedVotes;

        optional(uint32, Deposit) depo = deposits.max();
        while (depo.hasValue()) {
            (uint32 createdAt, Deposit deposit) = depo.get();
            if (_requestedVotes != 0) {
                uint32 votes = math.min(_requestedVotes, uint32(deposit.amount / deposit.valuePerVote));
                uint64 value = uint64(deposit.valuePerVote * votes); 
                
                if (deposit.tokenId == _crystalsID) {
                    _wallet.transfer(value, false, 0);
                } else if (deposit.tokenId == _depoolID) {
                    // user can reclaim only all depool stake at once.
                    if (value >= deposit.amount) {
                        address depool = address.makeAddrStd(0, deposit.depool);
                        IDePool(depool).transferStake{value: 0.5 ton, flag: 1}
                            (deposit.returnTo, deposit.amount);
                    } else {
                        (votes, value) = (0, 0);
                    }
                } else {
                    TipAccount acc = tokenAccounts[address.makeAddrStd(0, deposit.tokenId)];
                    ITokenWallet(acc.addr).transfer{value: 0.1 ton + 0.1 ton}
                        (deposit.returnTo, value, 0.1 ton);
                }
    
                deposit.amount -= math.min(value, deposit.amount);
                if (deposit.amount == 0) {
                    delete deposits[createdAt];
                } else {
                    deposits[createdAt] = deposit;
                }
                _requestedVotes -= math.min(votes, _requestedVotes);
            }

            depo = deposits.prev(createdAt);
        }
        _totalVotes -= origVotes - _requestedVotes;
    }

    function _genId() private pure inline returns (uint32) {
        return uint32(now);
    }

    /* Receiving interface */

    /// @notice Plain receiving of tons.
    receive() external {
    }

    /// @notice Accept income messages.
    fallback() external {
    }

    /// @notice Plain transfer of tons.
    function transferFunds(address to, uint128 val) external view onlyUserWallet {
        to.transfer(val, true, 1);
    }


    /*
     *  Public Deposits API
     */

    /// @notice Allows to deposit crystals.
    // @param tons - number of crystals (NOT a nano crystals).
    function depositTons(uint32 tons) external override onlyUserWallet {
        uint32 createdAt = _genId();
        require(!deposits.exists(createdAt));
        require(msg.value >= uint64(tons) * 1 ton + DEPOSIT_TONS_FEE, ERROR_MSG_VALUE_TOO_LOW);
        
        deposits[createdAt] = Deposit(_crystalsID, _wallet, uint64(tons) * 1 ton, 0, true, 0);
        //tvm.rawReserve(address(this).balance - (msg.value - uint64(tons) * 1 ton), 0);
        IPriceProvider(_priceProvider).queryTonsPerVote{value: DEPOSIT_TONS_FEE - 0.1 ton, flag: 0, bounce: true}(createdAt);
    }   

    /// @notice Callback by Vote Provider as a response on request.
    function updateTonsPerVote(uint32 queryId, uint64 price) public override contractOnly {
        _convertDepositToVotes(queryId, price);
        _wallet.transfer(0, false, 64);
    }
    
    /// @notice Allows to deposit tip3 tokens
    /// @param returnTo - address to which return tokens in case of reclaim request.
    /// @param tokenId - ID of deposited tip3 token (it is a std addr of TokenRoot smc).
    /// @param tokens - Number of tokens to deposit.
    function depositTokens(address returnTo, uint256 tokenId, uint64 tokens) 
        external override onlyUserWallet {
        uint32 createdAt = _genId();
        require(!deposits.exists(createdAt), ERROR_DEPOSIT_WITH_SUCH_ID_EXISTS);
        require(_pendingDepositId == 0, ERROR_PENDING_DEPOSIT_ALREADY_EXISTS);
        require(msg.value >= DEPOSIT_TIPS_FEE, ERROR_MSG_VALUE_TOO_LOW);
        
        optional(TipAccount) opt = tokenAccounts.fetch(address.makeAddrStd(0, tokenId));
        require(opt.hasValue(), ERROR_ACCOUNT_DOES_NOT_EXIST);
        TipAccount acc = opt.get();
        
        _pendingDepositId = createdAt;
        ITokenWallet(acc.addr).getBalance_InternalOwner{value: 0, flag: 64, bounce: true}
            (tvm.functionId(onGetBalance));
        deposits[createdAt] = Deposit(tokenId, returnTo, tokens, 0, false, 0);
    }
    
    /// @notice Callback by Vote Provider as a response on request.
    function updateTipsPerVote(uint32 queryId, uint64 price) external override {
        _convertDepositToVotes(queryId, price);
        _wallet.transfer(0, false, 64);
    }

    /// @notice Receives deposit from depool.
    function onTransfer(address source, uint128 amount) external override contractOnly {
        require(depools.exists(msg.sender), ERROR_CALLER_IS_NOT_DEPOOL);
        tvm.accept();
        uint32 id = _genId();
        deposits[id] = Deposit(_depoolID, source, uint64(amount), 0, true, msg.sender.value);
        IPriceProvider(_priceProvider).queryTonsPerVote{value: 0.1 ton, flag: 1, bounce: true}(id);
    }

    /*
     *  Private deposit funcs
     */
    
    function _convertDepositToVotes(uint32 queryId, uint64 price) private inline {
        require(msg.sender == _priceProvider);
        optional(Deposit) opt = deposits.fetch(queryId);
        require(opt.hasValue(), ERROR_DEPOSIT_NOT_FOUND);
        Deposit depo = opt.get();
        deposits[queryId].valuePerVote = price;
        _totalVotes += uint32(depo.amount / price);
    }

    function _findTokenAccount(address addr) private view inline returns (optional(address, TipAccount)) {
        optional(address, TipAccount) account = tokenAccounts.min();
        while (account.hasValue()) {
            (address root, TipAccount acc) = account.get();
            if (acc.addr == addr) {
                return account;
            }
            account = tokenAccounts.next(root);
        }
        return account;
    }
    
    function onGetBalance(uint128 balance) public contractOnly {
        optional(address, TipAccount) account = _findTokenAccount(msg.sender);
        require(account.hasValue(), ERROR_ACCOUNT_DOES_NOT_EXIST);
        require(_pendingDepositId != 0);

        (address root, TipAccount acc) = account.get();

        uint128 prevBalance = acc.balance;
        tokenAccounts[root].balance = balance;

        optional(Deposit) opt = deposits.fetch(_pendingDepositId);
        require(opt.hasValue(), ERROR_DEPOSIT_NOT_FOUND);
        Deposit dep = opt.get();
        if (balance >= dep.amount + prevBalance) {
            deposits[_pendingDepositId].approved = true;
            IPriceProvider(_priceProvider).queryTipsPerVote{value: 0, flag: 64, bounce: true}
                (_pendingDepositId, root);
        } else {
            delete deposits[_pendingDepositId];
        }
        _pendingDepositId = 0;
    }

    /*
    *  Token Account Collection
    */

    function onTokenWalletDeploy(address wallet) public {
        optional(TipAccount) opt = tokenAccounts.fetch(msg.sender);
        require(opt.hasValue(), ERROR_INVALID_ROOT_CALLER);
        TipAccount acc = opt.get();

        acc.addr = wallet;
        tokenAccounts[msg.sender] = acc;

        _wallet.transfer(0, false, 64);
    }

    function createTokenAccount(address tokenRoot) external override onlyUserWallet {
        require(msg.value >= 2 ton, ERROR_MSG_VALUE_TOO_LOW);
        require(!tokenAccounts.exists(tokenRoot), ERROR_TOKEN_ACCOUNT_ALREADY_EXISTS);
        uint256 owner = address(this).value;
        tokenAccounts[tokenRoot] = TipAccount(address(0), owner, uint32(now), 0);

        ITokenRoot(tokenRoot).deployEmptyWallet{value: 0, flag: 64, bounce: true}
            (tvm.functionId(onTokenWalletDeploy), 0, 0, owner, 1 ton);
    }

    /*
    *  Get Methods
    */

    function getDeposits() public view returns (mapping (uint32 => Deposit) allDeposits) {
        allDeposits = deposits;
    }

    function getTokenAccounts() public view returns (mapping (address => TipAccount) allAccounts) {
        allAccounts = tokenAccounts;
    }

    function getVoteInfo() public view returns (uint32 reqVotes, uint32 totalVotes, uint32 lockedVotes) {
        reqVotes =  _requestedVotes;
        totalVotes =  _totalVotes;
        lockedVotes = _lockedVotes;
    }

    function getAddresses() public view returns (address userWallet, address priceProvider) {
        userWallet = _wallet;
        priceProvider = _priceProvider;
    }
}
