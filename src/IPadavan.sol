pragma solidity >= 0.6.0;

import "IBaseData.sol";

interface IPadavan {
    function voteFor(address proposal, bool choice, uint32 votes) external;
    function depositTons(uint32 tons) external;
    function depositTokens(address returnTo, uint256 tokenId, uint64 tokens) external;
    function reclaimDeposit(uint32 deposit) external;
    function confirmVote(uint64 pid, uint32 deposit) external;
    function rejectVote(uint64 pid, uint32 deposit, uint16 ec) external;
    function updateStatus(uint64 pid, ProposalState state) external;
    
    function applyToGroup(address group, string name) external;
    function removeFromGroup(address group, uint32 id, address addr) external;

    function createTokenAccount(address tokenRoot) external;
    function onTransfer(address source, uint128 amount) external;
}
