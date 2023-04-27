import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect, use } from "chai";
import { ethers } from "hardhat";
import * as hre from "hardhat"

import { fillAndSign } from './utils/UserOp'
import { arrayify, defaultAbiCoder, hexConcat, parseEther } from 'ethers/lib/utils'
import { UserOperation } from './utils/UserOperation'
import { simulationResultCatch } from "./utils/testutils";

import bigInt from 'big-integer'
import { Buffer } from 'buffer';
import forge from 'node-forge';
import { addHexPrefix } from './utils/addHexPrefix'

describe("VoterAA", function () {

    let batcher: any
    let batcherAddress: any

    let voterKey: any
    let voterKeyAddress: any

    let EntryPoint: any
    let CentralElectionComissionAA: any
    let CentralElectionComissionPaymaster: any
    let VoterAA: any
    let VoterAAFactory: any
    let Tallier: any
    let Ballots: any

    let entryPoint: any
    let centralElectionComissionAA: any
    let centralElectionComissionPaymaster: any
    let voterAA: any
    let voterAAFactory: any
    let tallier: any
    let ballots: any

    let rsa_keypair: any
    let rsa_public_key: any
    let rsa_private_key: any

    describe("Deployment", function () {

        before(async function () {

            let network = await hre.network;
            console.log("Network name: "+network.name)

            let signers = await ethers.getSigners()
            batcher = signers[0]
            batcherAddress = batcher.address
  
            voterKey = signers[1]
            voterKeyAddress = voterKey.address
            
            console.log("Batcher address: " + batcherAddress)
            console.log("Voter address: " + voterKeyAddress)

            EntryPoint = await ethers.getContractFactory("EntryPoint")
            CentralElectionComissionAA =  await ethers.getContractFactory("CentralElectionComissionAA")
            CentralElectionComissionPaymaster = await ethers.getContractFactory("CentralElectionComissionPaymaster")
            VoterAA = await ethers.getContractFactory("VoterAA")
            VoterAAFactory = await ethers.getContractFactory("VoterAAFactory")
            Tallier = await ethers.getContractFactory("Tallier")
            Ballots = await ethers.getContractFactory("Ballots")

        });

        it("Deployment", async function () {

            rsa_keypair = forge.pki.rsa.generateKeyPair({bits: 2048});

            // Export public and private keys
            const e = rsa_keypair.publicKey.e.toString(16);
            const n = rsa_keypair.publicKey.n.toString(16);

            rsa_public_key = {
                'exponent': addHexPrefix(e),
                'modulus': addHexPrefix(n),
            }

            entryPoint = await EntryPoint.connect(batcher).deploy()
            centralElectionComissionAA = await CentralElectionComissionAA.connect(batcher).deploy()
            centralElectionComissionPaymaster = await CentralElectionComissionPaymaster.connect(batcher).deploy()
            voterAA = await VoterAA.connect(batcher).deploy();
            voterAAFactory = await VoterAAFactory.connect(batcher).deploy()
            tallier = await Tallier.connect(batcher).deploy()
            ballots = await Ballots.connect(batcher).deploy()


            console.log("EntryPoint addresss: " + entryPoint.address)
            console.log("CentralElectionComissionAA address: " + centralElectionComissionAA.address)
            console.log("CentralElectionComissionPaymaster address: " + centralElectionComissionPaymaster.address)
           
            await voterAAFactory.initialize(centralElectionComissionAA.address)
            await centralElectionComissionPaymaster.initialize(centralElectionComissionAA.address)
            await tallier.initialize(centralElectionComissionAA.address)
            await ballots.initialize(centralElectionComissionAA.address)
            await centralElectionComissionAA.initialize(
                entryPoint.address, 
                voterAAFactory.address, 
                tallier.address,
                ballots.address,
                rsa_public_key
            )

            let pub = await centralElectionComissionAA.rsaPubKey();
            //console.log(pub)

        });

        it('fund paymaster', async function() {
            
            let balanceOfCECPaymasterBefore = await entryPoint.connect(batcher).balanceOf(centralElectionComissionPaymaster.address)
            console.log(balanceOfCECPaymasterBefore)

            await entryPoint.connect(batcher).depositTo(centralElectionComissionPaymaster.address, { value: ethers.utils.parseEther('1.2') })

            let balanceOfCECPaymasterAfter = await entryPoint.connect(batcher).balanceOf(centralElectionComissionPaymaster.address)
            console.log(balanceOfCECPaymasterAfter)
        })

        it('cecAA add candidate', async function () {

            let candidate = {'info': '0xabcd'}
            let cecAA_listCandidate = await centralElectionComissionAA.populateTransaction.listCandidate(candidate)
            let cecAA_listCandidate_calldata = cecAA_listCandidate.data
            let userOp = await fillAndSign(
                {
                    sender: centralElectionComissionAA.address,
                    callData: cecAA_listCandidate_calldata,
                    paymasterAndData: hexConcat([centralElectionComissionPaymaster.address])
                },
                batcher,
                entryPoint
            )
            // console.log(userOp)

            let userOpHash = await entryPoint.getUserOpHash(userOp)
            // console.log("userOpHash: " + userOpHash)

            const md = forge.md.sha256.create()
            md.update(userOpHash.toLowerCase())
            // console.log("0x" + md.digest().toHex())

            let sha256 = await centralElectionComissionAA.calcUserOpHashSha256(userOpHash)
            console.log(sha256)

            const signature = rsa_keypair.privateKey.sign(md);
            let rsa_signature = forge.util.bytesToHex(signature)
            
            userOp.signature = "0x" + rsa_signature
            // console.log(userOp)
            await entryPoint.connect(batcher).handleOps([userOp], batcherAddress)

            let candidate0 = await tallier.getCandidate(0)
            console.log(candidate0)
        })

        it('cecAA submit voting keys of voter', async function () {

            let stampedVotingKeyAddress = await centralElectionComissionAA.stamp(voterKeyAddress)

            let m = bigInt(stampedVotingKeyAddress.slice(2), 16)
            let d = bigInt(rsa_keypair.privateKey.d.toString(16), 16)
            let n = bigInt(rsa_keypair.publicKey.n.toString(16), 16)
            let s = m.modPow(d, n)
            let unblindedSignature = "0x" + s.toString(16)

            let cecAA_submitVotingKey = await centralElectionComissionAA.populateTransaction.submitVotingKey(stampedVotingKeyAddress, unblindedSignature)
            let cecAA_submitVotingKey_calldata = cecAA_submitVotingKey.data
            let userOp = await fillAndSign(
                {
                    sender: centralElectionComissionAA.address,
                    callData: cecAA_submitVotingKey_calldata,
                    paymasterAndData: hexConcat([centralElectionComissionPaymaster.address])

                },
                batcher,
                entryPoint
            )
            //console.log(userOp)

            let userOpHash = await entryPoint.getUserOpHash(userOp)
            //console.log("userOpHash: " + userOpHash)
            const md = forge.md.sha256.create()
            md.update(userOpHash.toLowerCase())
            //console.log("0x" + md.digest().toHex())

            const signature = rsa_keypair.privateKey.sign(md);
            let rsa_signature = forge.util.bytesToHex(signature)
          
            userOp.signature = "0x" + rsa_signature
            //console.log(userOp)
            await entryPoint.connect(batcher).handleOps([userOp], batcherAddress)

            let voterAA0Address = await voterAAFactory.getVoterAA(0);
            console.log(voterAA0Address)
            
            voterAA = await VoterAA.connect(batcher).attach(voterAA0Address)
        })

        it('VoterAA submit vote using paymaster', async function () {
          
            let voterAA_submitVote_calldata = (await voterAA.populateTransaction.submitVote(0)).data

            let userOp = await fillAndSign(
                {
                    sender: voterAA.address,
                    callData: voterAA_submitVote_calldata,
                    paymasterAndData: hexConcat([centralElectionComissionPaymaster.address])
                },
                batcher,
                entryPoint
            )

            let userOpHash = await entryPoint.getUserOpHash(userOp)
            let signature = await voterKey.signMessage(arrayify(userOpHash))
            userOp.signature = signature
            await entryPoint.connect(batcher).handleOps([userOp], batcherAddress)
            let totalVotes = await tallier.totalVotes()
            expect(totalVotes).to.be.eq(1)
        })




    });
});