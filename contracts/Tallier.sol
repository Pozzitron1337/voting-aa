// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./eth-infinitism-aa/core/BaseAccount.sol";
import "./eth-infinitism-aa/samples/callback/TokenCallbackHandler.sol";

import "./CentralElectionComissionAA.sol";

contract Tallier is Initializable {

    CentralElectionComissionAA public centralElectionComissionAA;
    
    Candidate[] public candidates;

    struct Candidate {
        bytes info;
    }

    /**
     * @dev candidate id => amount of votes
     */
    mapping(uint256 => uint256) public votes;

    /**
     * @dev sum of all votes
     */
    uint256 public totalVotes;

    // uint256 public totalVotes;

    modifier onlyCentralElectionComissionAA() {
        require(msg.sender == address(centralElectionComissionAA));
        _;
    }

    function initialize(
        CentralElectionComissionAA _centralElectionComissionAA
    ) public initializer {
        centralElectionComissionAA =_centralElectionComissionAA;
    }

    function listCandidate(Candidate memory _candidate) public onlyCentralElectionComissionAA {
        candidates.push(_candidate);
    }

    // function unlistCandidate(uint256 candidateId) public onlyCentralElectionComissionAA {
    // }

    /**
     * @param candidateId id of candidate in array `candidates`
     */
    function submitVote(uint256 candidateId) public {
        centralElectionComissionAA.isVoterAAListed(msg.sender);
        require(candidateId < getCandidatesLength(), "Tallier: invalid candidateId");
        votes[candidateId]++;
        totalVotes++;
    }



    function getCandidate(uint256 index) public view returns(Candidate memory) {
        require(index < candidates.length);
        return candidates[index];
    }

    function getCandidatesLength() public view returns(uint256) {
        return candidates.length;
    }

}