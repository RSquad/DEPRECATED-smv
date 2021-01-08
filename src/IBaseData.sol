pragma solidity >= 0.6.0;

enum ProposalState { Undefined, New, OnVoting, Ended, Passed, Failed, Finalized, Distributed, Reserved, Last }
enum VoteCountModel { Undefined, Majority, SoftMajority, SuperMajority, Other, Reserved, Last }

interface IBaseData {

    struct ProposalInfo {
        uint32 id;          // Proposal ID
        uint32 start;       // Start of the voting
        uint32 end;         // Timestamp of the voting end
        uint16 options;     // Proposal custom options
        uint32 totalVotes;  // Maximal amount of votes accepted
        string description; // Proposal description
        string text;        // Proposal text
        address[] voters;   // List of contracts eligible to vote for this proposal
        uint32 ts;          // Creation time
    }

    struct VoteDistributionParameters {
        uint32 id;
        uint32 ts;
    }

    struct PadavanData {
        address userWalletAddress;
        address addr;
    }

    struct ProposalData {
        uint32 id;
        ProposalState state;
        address userWalletAddress;
        address addr;
        uint32 ts;
    }

    struct VotingResults {
        uint32 id;
        bool passed;
        uint32 votesFor;
        uint32 votesAgainst;
        uint32 totalVotes;
        VoteCountModel model;
        uint32 ts;
    }

}

