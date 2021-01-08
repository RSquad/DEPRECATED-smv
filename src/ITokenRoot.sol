pragma solidity >= 0.6.0;

interface ITokenRoot {
    function deployEmptyWallet(
        uint32 _answer_id,
        int8 workchain_id,
        uint256 pubkey,
        uint256 internal_owner,
        uint128 grams
    ) external functionID(0xD);
}
