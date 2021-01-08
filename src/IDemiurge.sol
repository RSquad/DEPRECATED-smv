pragma solidity >= 0.6.0;

import "IBaseData.sol";

interface IDemiurge is IBaseData {
    function deployPadavan(uint userKey) external;
    function deployProposal(uint32 totalVotes, uint32 start, uint32 end, string description, string text, VoteCountModel model) external;
    function deployProposalWithWhitelist(uint32 totalVotes, uint32 start, uint32 end, string description, string text, VoteCountModel model, address[] voters) external;
    function onPadavanDeploy(uint key) external;
    function onProposalDeploy() external;
    function onStateUpdate(ProposalState state) external;
    function reportResults(VotingResults results) external;
}
