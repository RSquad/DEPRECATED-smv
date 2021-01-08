pragma solidity >=0.6.0;
pragma AbiHeader expire;
pragma AbiHeader time;

enum ContractType { Demiurge, Proposal, Padavan, VotingDebot, DemiurgeDebot, PriceProvider }

interface IDemiurgeStoreCallback {
    function updateABI(ContractType kind, string sabi) external;
    function updateDepools(mapping(address => bool) depools) external;
    function updateImage(ContractType kind, TvmCell image) external;
    function updateAddress(ContractType kind, address addr) external;
}

abstract contract DemiurgeStore {

    /*struct ABI {
        string votingDebotAbi;
        string padavanAbi;
        string proposalAbi;
        string demiurgeAbi;
    }*/

    mapping(uint8 => string) public abis;

    /*struct Images {
        TvmCell proposalImage;
        TvmCell padavanImage;
        TvmCell votingDebotImage;
        TvmCell demiurgeImage;
    }*/

    mapping(uint8 => TvmCell) public images;

    mapping(address => bool) public depools;

    address public priceProvider;

    modifier signed() {
        require(tvm.pubkey() == msg.pubkey(), 100);
        tvm.accept();
        _;
    }

    function setVotingDebotABI(string sabi) public signed {
        abis[uint8(ContractType.VotingDebot)] = sabi;
    }

    function setPadavanABI(string sabi) public signed {
        abis[uint8(ContractType.Padavan)] = sabi;
    }

    function setDemiurgeABI(string sabi) public signed {
        abis[uint8(ContractType.Demiurge)] = sabi;
    }

    function setProposalABI(string sabi) public signed {
        abis[uint8(ContractType.Proposal)] = sabi;
    }

    function setPadavanImage(TvmCell image) public signed {
        images[uint8(ContractType.Padavan)] = image;
    }

    function setProposalImage(TvmCell image) public signed {
        images[uint8(ContractType.Proposal)] = image;
    }

    function setVotingDebotImage(TvmCell image) public signed {
        images[uint8(ContractType.VotingDebot)] = image;
    }

    function setDemiurgeImage(TvmCell image) public signed {
        images[uint8(ContractType.Demiurge)] = image;
    }

    function addDepools(address[] addresses) public signed {
        uint len = addresses.length;
        for(uint i = 0; i < len; i++) {
            depools[addresses[i]] = true;
        }
    }

    function setPriceProvider(address addr) public signed {
        priceProvider = addr;
    }

    /*
     *  Query Store functions
     */

    function queryABI(ContractType kind) public view {
        string sabi = abis[uint8(kind)];
        IDemiurgeStoreCallback(msg.sender).updateABI{value: 0, flag: 64, bounce: false}(kind, sabi);
    }

    function queryDepools() public view {
        IDemiurgeStoreCallback(msg.sender).updateDepools{value: 0, flag: 64, bounce: false}(depools);
    }

    function queryImage(ContractType kind) public view {
        TvmCell image = images[uint8(kind)];
        IDemiurgeStoreCallback(msg.sender).updateImage{value: 0, flag: 64, bounce: false}(kind, image);
    }

    function queryAddress(ContractType kind) public view {
        address addr;
        if (kind == ContractType.PriceProvider) {
            addr = priceProvider;
        }
        IDemiurgeStoreCallback(msg.sender).updateAddress{value: 0, flag: 64, bounce: false}(kind, addr);
    }

}