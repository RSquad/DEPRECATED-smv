pragma solidity >= 0.6.0;
pragma msgValue 2e7;

import "IBaseData.sol";

contract Base is IBaseData  {

    uint16 constant ERROR_DIFFERENT_CALLER =  211;
    
    uint32 constant VOTE_COST = 1e8;

    uint128 constant START_BALANCE = 3 ton;
    uint128 constant DEPLOYER_FEE = 0.1 ton;
    uint128 constant DEPLOY_FEE = START_BALANCE + DEPLOYER_FEE;
    uint128 constant DEF_RESPONSE_VALUE = 3e7;
    uint128 constant DEF_COMPUTE_VALUE = 2e8;
    uint128 constant DEPLOY_PROPOSAL_FEE = 5 ton;

    uint16 constant PROPOSAL_HAS_WHITELIST          = 2;
    uint16 constant PROPOSAL_VOTE_SOFT_MAJORITY     = 4;
    uint16 constant PROPOSAL_VOTE_SUPER_MAJORITY    = 8;

    modifier signed {
        require(msg.pubkey() == tvm.pubkey(), 101);
        tvm.accept();
        _;
    }

    modifier me {
        require(msg.sender == address(this), ERROR_DIFFERENT_CALLER);
        _;
    }

    modifier accept {
        tvm.accept();
        _;
    }

    function _votesFromTons(uint128 val) internal pure inline returns (uint32) {
        return uint32(val / VOTE_COST);
    }
/*
    function _available() private pure inline returns (uint128) {
        uint128 b = _shrink(address(this).balance);
        return b > 0 ? (b - 1) : 0;
    }

    function _canSpend(uint128 val) private inline pure returns (uint128) {
        return math.min(val, _available());
    }
*/
}
