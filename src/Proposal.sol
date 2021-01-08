pragma solidity >= 0.6.0;

import "Base.sol";
import "IProposal.sol";
import "IDemiurge.sol";
import "IPadavan.sol";
import "Padavan.sol";

contract Proposal is Base, IProposal {

    uint16 constant ERROR_NOT_AUTHORIZED_VOTER  =   302; // Only ProposalInitiatorWallet cal create proposals
    uint16 constant ERROR_TOO_EARLY_FOR_RECLAIM =   303; // Can't return deposit before proposal expiration

//    uint16 constant ERROR_NOT_AUTHORIZED_VOTER  = 250; // Votes are not accepted at this time
    uint16 constant ERROR_VOTING_NOT_STARTED    = 251;   // Votes are not accepted at this time
    uint16 constant ERROR_VOTING_HAS_ENDED      = 252;  // Votes are not accepted at this time
    uint16 constant ERROR_VOTER_IS_NOT_ELIGIBLE = 253;  // Voter is not eligible to vote for this proposal

    /* Stores root key,  Wallet code. */
    uint _rootKey;

    /* ??? where Voting Wallet code comes from? */
    TvmCell _votingWalletCode;
    
    ProposalInfo _info;
    address static deployer;

    bool _hasWhitelist;
    mapping (address => bool) _voters;
    TvmCell _padavanSI;

    struct ProposalStatus {
        ProposalState state;
        uint32 votesFor;
        uint32 votesAgainst;
    }

    VotingResults _results;

    ProposalState _state;
    uint32 _votesFor;
    uint32 _votesAgainst;
    VoteCountModel _voteCountModel;

    uint128 _accrued;

    event ProposalFinalized(VotingResults results);

    constructor() public {
        require(deployer == msg.sender);
        _state = ProposalState.New;
        IDemiurge(deployer).onProposalDeploy{value: DEF_RESPONSE_VALUE}();
    }

    function initProposal(ProposalInfo pi, TvmCell padavanSI) external {
        _info = pi;
        _padavanSI = padavanSI;
        _voteCountModel = VoteCountModel.Majority;

        if (_info.options & PROPOSAL_VOTE_SOFT_MAJORITY > 0) {
            _voteCountModel = VoteCountModel.SoftMajority;
        } else if (_info.options & PROPOSAL_VOTE_SUPER_MAJORITY > 0) {
            _voteCountModel = VoteCountModel.SuperMajority;
        }

        _hasWhitelist = (_info.options & PROPOSAL_HAS_WHITELIST > 0) ? true : false;
        if (_hasWhitelist) {
            for (address addr : _info.voters) {
                _voters[addr] = true;
            }
        }
    }

    function _canVote() private inline pure returns (bool) {
        return (msg.sender != address(0));
    }

    function wrapUp() external override {
        _wrapUp();
        msg.sender.transfer(0, false, 64);
    }

    /* Implements SMV algorithm and has vote function to receive ‘yes’ or ‘no’ votes from Voting Wallet. */
    function voteFor(uint256 key, bool choice, uint32 deposit) external override {
        TvmCell code = _padavanSI.toSlice().loadRef();
        TvmCell state = tvm.buildStateInit({
            contr: Padavan,
            varInit: {deployer: deployer},
            pubkey: key,
            code: code
        });
        address padavanAddress = address.makeAddrStd(0, tvm.hash(state));
        uint16 ec = 0;
        address from = msg.sender;

        if (padavanAddress != from) {
            ec = ERROR_NOT_AUTHORIZED_VOTER;
        } else if (now < _info.start) {
            ec = ERROR_VOTING_NOT_STARTED;
        } else if (now > _info.end) {
            ec = ERROR_VOTING_HAS_ENDED;
        } else if (_hasWhitelist) {
            if (!_voters.exists(from)) {
                ec = ERROR_VOTER_IS_NOT_ELIGIBLE;
            }
        }

        if (ec > 0) {
            IPadavan(from).rejectVote{value: 0, flag: 64, bounce: true}(_info.id, deposit, ec);
        } else {
            IPadavan(from).confirmVote{value: 0, flag: 64, bounce: true}(_info.id, deposit);
            if (choice) {
                _votesFor += deposit;
            } else {
                _votesAgainst += deposit;
            }
            _accrued += deposit;
        } 

        _wrapUp();
    }

    function finalize(bool passed) external me {
        tvm.accept();
        
        _results = VotingResults(_info.id, passed, _votesFor, 
            _votesAgainst, _info.totalVotes, _voteCountModel, uint32(now));
        ProposalState state = passed ? ProposalState.Passed : ProposalState.Failed;
        _transit(state);
        emit ProposalFinalized(_results);
        IDemiurge(deployer).reportResults(_results);        
    }

    function _calculateVotes(
        uint32 yes,
        uint32 no,
        uint32 total,
        VoteCountModel model
    ) private inline pure returns (bool) {
        bool passed = false;
        if (model == VoteCountModel.Majority) {
            passed = (yes > no);
        } else if (model == VoteCountModel.SoftMajority) {
            passed = (yes * total * 10 >= total * total + no * (8 * total  + 20));
        } else if (model == VoteCountModel.SuperMajority) {
            passed = (yes * total * 3 >= total * total + no * (total + 6));
        } else if (model == VoteCountModel.Other) {
            //
        }
        return passed;
    }

    function _tryEarlyComplete(
        uint32 yes,
        uint32 no,
        uint32 total,
        VoteCountModel model
    ) private inline pure returns (bool, bool) {
        (bool completed, bool passed) = (false, false);    
        if (model == VoteCountModel.Majority) {
            (completed, passed) = (2*yes > total) ? (true, true) : ((2*no >= total) ? (true, false) : (false, false));
        } else if (model == VoteCountModel.SoftMajority) {
            (completed, passed) = (2*yes > total) ? (true, true) : ((2*no >= total) ? (true, false) : (false, false));
        } else if (model == VoteCountModel.SuperMajority) {
            (completed, passed) = (3*yes > 2*total) ? (true, true) : ((3*no > total) ? (true, false) : (false, false));
        } else if (model == VoteCountModel.Other) {
            //
        }
        return (completed, passed);
    }

    function _transit(ProposalState state) private inline {
        _state = state;
        IDemiurge(deployer).onStateUpdate{value: 0.1 ton, bounce: true}(state);
    }

    function _wrapUp() private {
        (bool completed, bool passed) = (false, false);
        if (now > _info.end) {
            completed = true;
            passed = _calculateVotes(_votesFor, _votesAgainst, _info.totalVotes, _voteCountModel);
        } else {
            (completed, passed) = _tryEarlyComplete(
                _votesFor, _votesAgainst, _info.totalVotes, _voteCountModel);
        }

        if (completed) {
            _transit(ProposalState.Ended);
            this.finalize{value: DEF_COMPUTE_VALUE}(passed);
        }
    }

    function queryStatus() external override {
        IPadavan(msg.sender).updateStatus(_info.id, _state);
    }

    /*
    *   Get Methods
    */

    function getId() public view returns (uint256 id) {
        id = tvm.pubkey();
    }

    function getVotingResults() public view returns (VotingResults vr) {
        vr = _results;
    }

    function getInfo() public view returns (ProposalInfo info) {
        info = _info;
    }

    function getCurrentVotes() public view returns (uint32 votesFor, uint32 votesAgainst) {
        return (_votesFor, _votesAgainst);
    }

}
