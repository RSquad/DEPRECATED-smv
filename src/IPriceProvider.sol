pragma solidity >= 0.6.0;

interface IPriceProvider {
    function queryTonsPerVote(uint32 queryId) external;
    function queryTipsPerVote(uint32 queryId, address tokenRoot) external;
}

interface IPriceProviderCallback {
    function updateTonsPerVote(uint32 queryId, uint64 price) external;
    function updateTipsPerVote(uint32 queryId, uint64 price) external;
}