// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";

import "./CentralElectionComissionAA.sol";

contract Ballots is Initializable, ERC721EnumerableUpgradeable {

    CentralElectionComissionAA public centralElectionComissionAA;

    uint256 public totalBallots;

    uint256 public totalSubmits;

    /**
     * @param voterAA address of voter account abstraction
     * @param voteFor the vote for candidate
     * @param info some additional info about ballot
     */
    struct Ballot {
        address voterAA;
        uint256 voteFor;
        bytes info;
    }

    /**
     * @dev token id => Ballot struct
     */
    mapping(uint256 => Ballot) public ballot;

    /**
     * @dev token id => token URI
     */
    mapping(uint256 => string) public _tokenURI;

    modifier onlyCentralElectionComissionAA() {
        require(msg.sender == address(centralElectionComissionAA), "Ballots: msg.sender not CEC");
        _;
    }

    function initialize(CentralElectionComissionAA centralElectionComissionAA_) public initializer {
        centralElectionComissionAA = centralElectionComissionAA_;
        totalBallots = 0;
        totalSubmits = 0;
    }

    function setTokenURI(uint256 tokenId, string memory uri) public onlyCentralElectionComissionAA {
        require(_exists(tokenId), "Ballots: tokenId not exist");
        _tokenURI[tokenId] = uri;
    } 

    function setBallotInfo(uint256 tokenId, bytes memory ballotInfo) public onlyCentralElectionComissionAA {
        require(_exists(tokenId), "Ballots: tokenId not exist");
        ballot[tokenId].info = ballotInfo;
    } 

    function mint(address to) public onlyCentralElectionComissionAA returns(uint256 tokenId) {
        tokenId = totalBallots;
        totalBallots++;
        _mint(to, tokenId);
        ballot[tokenId] = Ballot({
            voterAA: to,
            voteFor: type(uint256).max, //not submit vote
            info: "0x"
        });
    }

    function submitVote(uint256 tokenId, uint256 voteFor) public {
        require(msg.sender == ownerOf(tokenId), "Ballots: not ballot owner");
        ballot[tokenId].voteFor;
        totalSubmits++;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override {
        require(ballot[tokenId].voteFor != type(uint256).max, "Ballots: ballot not casted");
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return _tokenURI[tokenId];
    } 
    

}