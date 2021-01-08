pragma solidity >= 0.6.0;

interface IGroup {
    function applyFor(string name) external;
    function unseat(uint32 id, address addr) external;
}