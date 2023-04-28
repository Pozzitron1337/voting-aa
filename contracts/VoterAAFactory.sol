// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./CentralElectionComissionAA.sol";
import "./VoterAA.sol";

contract VoterAAFactory is Initializable {

    CentralElectionComissionAA public centralElectionComissionAA;

    VoterAA[] public voterAAs;

    /**
     * @dev voterAA address => voterAA id in `voterAAs` array
     */
    mapping(address => uint256) public voterAAids;
    /**
     * @dev voting key of voter => voterAA address
     */
    mapping(address => address) public votingKeyToVoterAA;

    modifier onlyCentralElectionComissionAA() {
        require(msg.sender == address(centralElectionComissionAA), "VoterAAFactory: msg.sender not cecAA");
        _;
    }

    function initialize(
        CentralElectionComissionAA centralElectionComissionAA_
    ) public initializer {
        centralElectionComissionAA = centralElectionComissionAA_;
    }

    function deployVoterAA(address votingKey) public onlyCentralElectionComissionAA returns (VoterAA){
        require(votingKeyToVoterAA[votingKey] == address(0), "VoterAAFactory: deployed");
        VoterAA voterAA = new VoterAA();
        voterAA.initialize(
            centralElectionComissionAA.entryPoint(),
            centralElectionComissionAA,
            votingKey
        );
        uint256 voterAAId = voterAAs.length;
        voterAAs.push(voterAA);
        voterAAids[address(voterAA)] = voterAAId;
        votingKeyToVoterAA[votingKey] = address(voterAA);
        return voterAA;
    }

    function getVoterAA(uint256 voterAAid) public view returns(address) {
        require(voterAAid < voterAAs.length, "VoterAAFactory: not exist");
        return address(voterAAs[voterAAid]);
    }

    function isVoterAAExist(address votingKey) public view returns (bool) {
        if (votingKeyToVoterAA[votingKey] == address(0)) {
            return false;
        } else {
            return true;
        }
    }

    function isVoterAAListed(address voterAA) public view returns(bool) {
        if(voterAAs.length == 0) {
            return false;
        } else {
            return address(voterAAs[voterAAids[voterAA]]) == voterAA;
        }
    }


}