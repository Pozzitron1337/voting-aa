// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";

import "./eth-infinitism-aa/core/BaseAccount.sol";
import "./eth-infinitism-aa/samples/callback/TokenCallbackHandler.sol";

import "./CentralElectionComissionAA.sol";
import "./Tallier.sol";
import "./Ballots.sol";

contract VoterAA is BaseAccount, TokenCallbackHandler, Initializable {

    using ECDSAUpgradeable for bytes32;

    IEntryPoint public _entryPoint;

    CentralElectionComissionAA public centralElectionComissionAA;

    /**
     * @dev ECDSA secp256k1 key
     */
    address public votingKey;

    function initialize(
        IEntryPoint entryPoint_,
        CentralElectionComissionAA centralElectionComissionAA_,
        address votingKey_
    ) public initializer {
        _entryPoint = entryPoint_;
        centralElectionComissionAA = centralElectionComissionAA_;
        votingKey = votingKey_;
    }

    function execute(address target, uint256 value, bytes calldata data) external {
        _requireFromEntryPoint();
        (bool success, bytes memory result) = target.call{value : value}(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    //====================================
    // First protocol way to submit vote

    function submitVote(uint256 candidateId) public {
        _requireFromEntryPoint();
        Tallier tallier = centralElectionComissionAA.tallier();
        tallier.submitVote(candidateId);
        Ballots ballots = centralElectionComissionAA.ballots();
        uint256 tokenId = centralElectionComissionAA.voterAABallot(address(this));
        ballots.submitVote(tokenId, candidateId);
    }

    //====================================

    //====================================
    // Second protocol

    function submitVoteProof(bytes memory proof) public {
        _requireFromEntryPoint();
        // some zero knowledge protocol
    }

    function sumbitRevealVote(uint256 candidateId) public {
        _requireFromEntryPoint();
        // reveal the witness of proof
    }

    //====================================

    function _validateSignature(
        UserOperation calldata userOp, 
        bytes32 userOpHash
    ) internal view override returns (uint256 validationData) {
        bytes32 hash = userOpHash.toEthSignedMessageHash();
        if (votingKey != hash.recover(userOp.signature))
            return SIG_VALIDATION_FAILED;
        return 0;
    }

    function _requireFromEntryPoint() internal override view {
        require(msg.sender == address(_entryPoint), "No entryPoint");
    }

    function entryPoint() public view override returns (IEntryPoint) {
        return _entryPoint;
    }


}