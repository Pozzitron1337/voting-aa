// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./eth-infinitism-aa/core/BaseAccount.sol";
import "./eth-infinitism-aa/samples/callback/TokenCallbackHandler.sol";

import "./VoterAAFactory.sol";
import "./Tallier.sol";
import "./Ballots.sol";

import "hardhat/console.sol";

contract CentralElectionComissionAA is BaseAccount, TokenCallbackHandler, Initializable {

    /**
     * @dev leet CEntral E1ection C0mission ACount AB57raction 
     */ 
    bytes32 public constant STAMP = hex'CEE1C0ACAB570000000000000000000000000000000000000000000000000000'; 

    IEntryPoint public _entryPoint;

    VoterAAFactory public voterAAFactory;

    Tallier public tallier;

    Ballots public ballots;

    RSA_public_key public rsaPubKey;



    /**
     * @notice the evidence that voterAA has ballot with tokenId
     * @dev voterAA address => tokenId of ballot
     */
    mapping(address => uint256) public voterAABallot;

    struct RSA_public_key {
        bytes exponent; // e
        bytes modulus;  // n
    }

    function initialize(
        IEntryPoint entryPoint_,
        VoterAAFactory voterAAFactory_,
        Tallier tallier_,
        Ballots ballots_,
        RSA_public_key memory rsaPubKey_
    ) public initializer {
        _entryPoint = entryPoint_;
        voterAAFactory = voterAAFactory_;
        tallier = tallier_;
        ballots = ballots_;
        rsaPubKey = rsaPubKey_;
    }

    /**
     * @notice execute any transaction from CentralElectionComission
     * @param target contract address
     * @param value amout of ETH
     * @param data fuction selector and encoded params
     */
    function execute(address target, uint256 value, bytes calldata data) external {
        _requireFromEntryPoint();
        (bool success, bytes memory result) = target.call{value : value}(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    function listCandidate(Tallier.Candidate memory _candidate) public {
        _requireFromEntryPoint();
        tallier.listCandidate(_candidate);
    }

    /**
     * @notice submit voting key and voterAA get ballot
     * @dev submotting voting key is next:
     *      1. verify the unblinded signature
     *      2. deploy VoterAA with voting key `votingKey`
     *      3. mint ballot to VoterAA
     * @param stampedVotingKeyAddress stamped voting key address of voter
     * @param unblindedSignature RSA signature of `stampedVotingKeyAddress`
     */
    function submitVotingKey(bytes32 stampedVotingKeyAddress, bytes memory unblindedSignature) external returns (VoterAA voterAA){
        _requireFromEntryPoint();
        require(verifyUnblindedRSASignature(stampedVotingKeyAddress, unblindedSignature), "CentralElectionComissionAA: false unblined signature");
        address votingKey = unstamp(stampedVotingKeyAddress);
        voterAA = voterAAFactory.deployVoterAA(votingKey);
        uint256 tokenId = ballots.mint(address(voterAA));
        voterAABallot[address(voterAA)] = tokenId;
    }

    /**
     * @notice verify the RSA signature
     * @dev the ublinded signature calculates like that
            unblindedSignature == (STAMP || votingKey)^d mod n
            the verification calculated like that
            (STAMP||votingKey) == unblindedSignature^e mod n
     */
    function verifyUnblindedRSASignature(bytes32 stampedVotingKeyAddress,bytes memory unblindedSignature) public view returns(bool) {
        bytes memory stampedVotingKeyAddress_ = modexp(unblindedSignature, rsaPubKey.exponent, rsaPubKey.modulus);
        if (bytes32(stampedVotingKeyAddress_) != stampedVotingKeyAddress)
            return false;
        return true;
    }

    function _validateSignature(
        UserOperation calldata userOp, 
        bytes32 userOpHash
    ) internal override returns (uint256 validationData) {
        return verifyPKCS1v1_5RSASignature(userOp, userOpHash);
    }

    /**
     * @notice verify the PKCS1v1_5 RSA signature
     * @dev PKCS1v1_5 signature calculates as
     *      signature = (PADDING||sha256(userOpHash) ^ d mod n
     *      signature calculates from `node-forge` npm package
     */
    function verifyPKCS1v1_5RSASignature( 
        UserOperation calldata userOp, 
        bytes32 userOpHash
    ) public view returns(uint256 validationData) {
        RSA_public_key memory pubKey = rsaPubKey;
        
        //get the sha256 hash of message from signature 
        bytes memory paddedSha256UserOpHash = modexp(userOp.signature, pubKey.exponent, pubKey.modulus);
        bytes32 userOpHash_;
        assembly {
            // get byte length of paddedUserOpHash
            let bytes_length := mload(paddedSha256UserOpHash)
            // read last 32 bytes
            // last 32 bytes contain the 
            userOpHash_ := mload(add(paddedSha256UserOpHash, bytes_length))
        }
        bytes32 userOpHash_sha256 = calcUserOpHashSha256(userOpHash);
        if (userOpHash_sha256 != userOpHash_)
            return SIG_VALIDATION_FAILED;
        return 0;
    }

    /**
     * @notice return the sha256 of given `userOpHash` input, that compliant with offchain sha256 on node-forge js package
     * @dev steps to be hexdigest to be compliant with offchain sha256
     *      1. convert bytes32 to hex string
     *      2. encodePacked the hex string 
     *      3. calculate sha256 of hex string
     * @param userOpHash keccak256 hash of struct UserOperation. Calculates on entryPoint.getUserOpHash(op)
     */
    function calcUserOpHashSha256(bytes32 userOpHash) public pure returns(bytes32) {
        bytes memory alphabet = "0123456789abcdef";
        bytes memory userOpHashString = new bytes(66);
        userOpHashString[0] = "0";
        userOpHashString[1] = "x";
        unchecked { // values overflow will not occured
            for (uint256 i = 0; i < 32; i++) {
                uint8 currentByte = uint8(userOpHash[i]);
                userOpHashString[2 * i + 2] = alphabet[currentByte >> 4];
                userOpHashString[2 * i + 3] = alphabet[currentByte & 0x0f];
            }
        }
        return sha256(abi.encodePacked(string(userOpHashString)));
    }

    /** 
     * @notice return the address with stamp
     * @dev exmaple: 
     *      addr = 0xE6D0bAB1aaa209b4b3f57C7561C3c58dBE5f9A49
     *      stamp(addr) = 0xCEE1C0ACAB57000000000000E6D0bAB1aaa209b4b3f57C7561C3c58dBE5f9A49
     */
    function stamp(address addr) public pure returns (bytes32) {
        return STAMP | (bytes32(bytes20(addr)) >> 96);
    }

    /**
     * @notice remove stamp from address
     * @dev exmaple: 
     *      stampedAddress = 0xCEE1C0ACAB57000000000000E6D0bAB1aaa209b4b3f57C7561C3c58dBE5f9A49
     *      unstamp(stampedAddress) = 0xE6D0bAB1aaa209b4b3f57C7561C3c58dBE5f9A49
     */
    function unstamp(bytes32 stampedAddress) public pure returns (address) {
        return address(bytes20(stampedAddress << 96)); 
    }

    function convertBytes32ToUint256(bytes32 stampedAddress) public pure returns (uint256) {
        return uint256(stampedAddress);
    }

    function checkStamp(bytes32 stampedAddress) public pure returns(bool) {
        bytes32 STAMP_MASK = hex'FFFFFFFFFFFF0000000000000000000000000000000000000000000000000000';
        if (STAMP == stampedAddress & STAMP_MASK) {
            return true;
        } else {
            return false;
        }
    }

    // v - verify message, v(m) є {0,1}
    // 0 - invalid, 1 - valid
    // s_1 * s_2 = (v(m_1) * v(m_2))^d modn n !=> s_3 = v(m_3) ^ d mod n 
    function verify(address voterKey, bytes memory signature) public view returns (bool) {
        bytes memory message = modexp(signature, rsaPubKey.exponent, rsaPubKey.modulus);
        bytes32 stampedVoter = stamp(voterKey);
        if (bytes32(message) == stampedVoter) {
            return true;
        } else {
            return false;
        }
    }

    function getMessage(bytes memory signature) public view returns(bytes memory) {
        return modexp(signature, rsaPubKey.exponent, rsaPubKey.modulus);
    }

    function modexp(
        bytes memory signature, 
        bytes memory exponent, 
        bytes memory modulus
    ) public  view returns(bytes memory) {
        bytes memory r;
        assembly {
            let sl := mload(signature)
            let el := mload(exponent)
            let nl := mload(modulus)

            let freemem := mload(0x40) // Free memory pointer is always stored at 0x40

            mstore(freemem, sl)         // arg[0] = sig.length @ +0
            
            mstore(add(freemem,32),el) // arg[1] = exp.length @ +32
            
            mstore(add(freemem,64), nl) // arg[2] = mod.length @ +64
            
            // arg[3] = base.bits @ + 96
            // Use identity built-in (contract 0x4) as a cheap memcpy
            let success := staticcall(450, 0x4, add(signature,32), sl, add(freemem,96), sl)
            
            // arg[4] = exp.bits @ +96+base.length
            let size := add(96, sl)
            success := staticcall(450, 0x4, add(exponent,32), el, add(freemem,size), el)
            
            // arg[5] = mod.bits @ +96+base.length+exp.length
            size := add(size,el)
            success := staticcall(450, 0x4, add(modulus,32), nl, add(freemem,size), nl)
            
            switch success case 0 { invalid() } //fail where we haven't enough gas to make the call

            // Total size of input = 96+base.length+exp.length+mod.length
            size := add(size,nl)
            // Invoke contract 0x5, put return value right after mod.length, @ +96
            success := staticcall(sub(gas(), 1350), 0x5, freemem, size, add(freemem, 0x60), nl)

            switch success case 0 { invalid() } //fail where we haven't enough gas to make the call

            let length := nl
            let msword_ptr := add(freemem, 0x60)

            ///the following code removes any leading words containing all zeroes in the result.
            for { } eq ( eq(length, 0x20), 0) { } {                   // for(; length!=32; length-=32)
                switch eq(mload(msword_ptr),0)                        // if(msword==0):
                    case 1 { msword_ptr := add(msword_ptr, 0x20) }    //     update length pointer
                    default { break }                                 // else: loop termination. non-zero word found
                length := sub(length,0x20)                          
            }
            
            r := sub(msword_ptr,0x20)
            mstore(r, length)

            // point to the location of the return value (length, bits)
            // assuming mod length is multiple of 32, return value is already in the right format.
            mstore(0x40, add(add(96, freemem),nl)) //deallocate freemem pointer
        }
        return r;
    }

    function isVoterAAListed(address voterAA) public view returns(bool) {
        return voterAAFactory.isVoterAAListed(voterAA);
    }

    function _requireFromEntryPoint() internal override view {
        require(msg.sender == address(_entryPoint), "CentralElectionComissionAA: msg.sender no entryPoint");
    }

    function entryPoint() public view override returns (IEntryPoint) {
        return _entryPoint;
    }


}