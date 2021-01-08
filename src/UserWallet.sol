pragma solidity >= 0.6.0;

import "Base.sol";
import "IDemiurge.sol";
import "IPadavan.sol";
import "IProposal.sol";

interface IDePool {
    function addOrdinaryStake(uint64 stake) external;
    function transferStake(address dest, uint64 amount) external;
}

contract UserWallet is Base {

    address _deployer;

    uint32 _tokens;
    address _padavan;
    mapping (address => uint32) _proposals;

    constructor() public {
        tvm.accept();
    }

    function setTargetAddress(address target) public accept {
        _deployer = target;
    }

    function deployPadavan(uint userKey) external view accept {
        IDemiurge(_deployer).deployPadavan{value: DEPLOY_FEE}(userKey);
    }

    function deployProposal(uint32 totalVotes, uint32 start, uint32 end, string description, string text, VoteCountModel model) external view accept {
        IDemiurge(_deployer).deployProposal{value: DEPLOY_FEE}(totalVotes, start, end, description, text, model);
    }

    function requestProposalWithWhitelist(uint32 totalVotes, uint32 start, uint32 end, string description, string text, VoteCountModel model, address[] voters) external view accept {
        IDemiurge(_deployer).deployProposalWithWhitelist{value: DEPLOY_FEE}(totalVotes, start, end, description, text, model, voters);
    }

    function updatePadavan(address addr) external {
        _padavan = addr;
    }

    function onProposalDeployed(uint32 id, address addr) external {
        _proposals[addr] = id;
    }

    function depositTons(uint32 tons) public view accept {
        IPadavan(_padavan).depositTons{value: uint64(tons) * 1 ton + 1 ton, bounce: true}(tons);
    }

    function depositTokens(address returnTo, uint256 tokenId, uint64 tokens) public view accept {
        IPadavan(_padavan).depositTokens{value: 1.5 ton, bounce: true}
            (returnTo, tokenId, tokens);
    }

    function reclaimDeposit(uint32 votes) public view accept {
        IPadavan(_padavan).reclaimDeposit{value: 1 ton, bounce: true}
            (votes);
    }

    function voteFor(address proposal, bool choice, uint32 votes) public view accept {
        IPadavan(_padavan).voteFor{value: 1 ton, bounce: true}
            (proposal, choice, votes);
    }

    function createTokenAccount(address root) public view accept {
        IPadavan(_padavan).createTokenAccount{value: 2 ton + /*just for tests*/ 2 ton, bounce: true}
            (root);
    }

    function wrapUp(address proposal) public pure accept {
        IProposal(proposal).wrapUp{value: 0.1 ton}();
    }

    /*
    * DePool interface
    */

    function addOrdinaryStake(address depool, uint64 stake) public pure accept {
        IDePool(depool).addOrdinaryStake{value: 0.5 ton + stake}(stake);
    }

    function transferStake(address depool, address dest, uint64 amount) public pure accept {
        IDePool(depool).transferStake{value: 0.5 ton}(dest, amount);
    }


    /*
    *  Groups API
    */

    function applyToGroup(address group, string name) public view accept {
        IPadavan(_padavan).applyToGroup(group, name);
    }

    function removeFromGroup(address group, uint32 id, address addr) public view accept {
        IPadavan(_padavan).removeFromGroup(group, id, addr);
    }

     /* Receiving interface */

    /* Plain transfers */
    receive() external {
    }

    function transferFunds(address to, uint128 val) external view signed {
        to.transfer(val, true, 1);
    }

    function getInfo() public view returns (uint32 tokens, address padavan) {
        tokens = _tokens;
        padavan = _padavan;
    }

    function getDeployed() public view returns (address deployer, mapping (address => uint32) proposals) {
        deployer = _deployer;
        proposals = _proposals;
    }

}
