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
import forge from 'node-forge';
import { addHexPrefix } from './utils/addHexPrefix'

describe("Registration Voters", function () {

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

        it("RSA signature test", async function () {

            console.log("voterKeyAddress: " + voterKeyAddress)

            let stampedvoterKeyAddress = await centralElectionComissionAA.stamp(voterKeyAddress)
            console.log("Stamped voter address: " + stampedvoterKeyAddress)

            const md = forge.md.sha256.create()
            md.update(stampedvoterKeyAddress.toLowerCase())
            // console.log("digest:");
            // console.log("0x" + md.digest().toHex())

            const signature = rsa_keypair.privateKey.sign(md)
            let rsa_signature = forge.util.bytesToHex(signature)
            // console.log("rsa_signature: ")
            // console.log(rsa_signature)

            let cecPublicKey = await centralElectionComissionAA.rsaPubKey();
            console.log(cecPublicKey)

            let s_bigInt = bigInt(rsa_signature, 16)
            let e_bigInt = bigInt(cecPublicKey.exponent.slice(2), 16)
            let n_bigInt = bigInt(cecPublicKey.modulus.slice(2), 16)
            
            // console.log(s_bigInt)
            // console.log(e_bigInt)
            // console.log(n_bigInt)

            let m_hex = s_bigInt.modPow(e_bigInt, n_bigInt).toString(16)
            // console.log("m_hex")
            // console.log(m_hex)

            let messageOnContract = await centralElectionComissionAA.getMessage("0x" + rsa_signature)
            // console.log("messageOnContract:")
            // console.log(messageOnContract)

            let unpad_m_hex = m_hex.slice(m_hex.length - 64)
            // console.log("unpad_m_hex")
            // console.log(unpad_m_hex)
            
            expect(unpad_m_hex).to.be.eq(md.digest().toHex())

         
        });

        it('Blind signature', async function() {

            let cecPublicKey = await centralElectionComissionAA.rsaPubKey();
            
            let d_bigInt = bigInt(rsa_keypair.privateKey.d.toString(16), 16)
            //console.log(d_bigInt)

            let e_bigInt = bigInt(cecPublicKey.exponent.slice(2), 16)
            let n_bigInt = bigInt(cecPublicKey.modulus.slice(2), 16)
            
            let r
            let gcd
            do {
               r = bigInt.randBetween(bigInt.zero, n_bigInt)
               gcd = bigInt.gcd(r, n_bigInt)
              
            } while (gcd.notEquals(1))
            let r_inv = r.modInv(n_bigInt)

            let stampedvoterKeyAddress = await centralElectionComissionAA.stamp(voterKeyAddress)
            let m = bigInt(stampedvoterKeyAddress.slice(2), 16)
            console.log("m:")
            console.log(m.toString(16))
            let blinded_m = m.multiply(r.pow(e_bigInt)).mod(n_bigInt) 
           // console.log(blinded_m.toString(16))
    
            // DO NOT rsa_keypair.privateKey.sign(md), because forge signature = (PADDING||h(m))^d mod n
            let blinded_s = blinded_m.modPow(d_bigInt, n_bigInt)
            let s_bigInt = blinded_s.multiply(r_inv).mod(n_bigInt)
            
            let m_ = s_bigInt.modPow(e_bigInt, n_bigInt)
            console.log(m_.toString(16))

            expect(m.toString(16)).to.be.eq(m_.toString(16))
    
        });

    
    
    });
});