const web3 = require("web3");
const express = require("express");
const Tx = require("ethereumjs-tx");
const app = express();
const crypto = require("crypto");
const fs = require("fs");
const openpgp = require("openpgp");
const contract = require("truffle-contract");
require("dotenv").config();

app.use(express.json());

const satoshiTreasurePubKey = fs.readFileSync(
    "files/satoshiTreasurePublic.pem",
    "utf-8"
);
const mavrikJson = require("./build/Mavrik.json");

const port = 3000 || process.env.PORT;
const web3Provider = new web3.providers.HttpProvider(process.env.WEB3_PROVIDER);
const web3js = new web3(web3Provider, undefined, {
    transactionConfirmationBlocks: 1
});

async function verifyPgpSignature(signature, publicKey) {
    try {
        if (!publicKey) {
            publicKey = satoshiTreasurePubKey;
        }
        options = {
            message: await openpgp.cleartext.readArmored(signature), // parse armored message
            publicKeys: (await openpgp.key.readArmored(publicKey)).keys // for verification
        };

        let verified = await openpgp.verify(options);
        let valid = verified.signatures[0].valid;
        if (valid) {
            console.log("signed by " + verified.signatures[0].keyid.toHex());
            return true;
        }
    } catch (err) {
        console.log("error occured", err);
    }
}

async function sendSatTreasureKeyNFT(hunter) {
    const fromAddress = process.env.SATOSHI_TREASURER_APPROVER_ADDR;
    const privateKey = Buffer.from(
        process.env.SATOSHI_TREASURER_APPROVER_PRIV_KEY,
        "hex"
    );
    const contractAddress = process.env.MAVRIK_CONTRACT_ADDR;
    const mavrik = new web3js.eth.Contract(mavrikJson.abi, contractAddress);
    // get transaction count, later will used as nonce
    let count = await web3js.eth.getTransactionCount(fromAddress, "pending");
    let rawTransaction = {
        from: fromAddress,
        gasPrice: web3js.utils.toHex(20 * 1e9),
        gasLimit: web3js.utils.toHex(210000),
        to: contractAddress,
        data: mavrik.methods
            .mintNonFungible(process.env.SATOSHI_TREASURE_KEY_NFT_TYPE, [
                hunter
            ])
            .encodeABI(),
        nonce: web3js.utils.toHex(count)
    };
    //console.log(rawTransaction);
    let transaction = new Tx(rawTransaction);
    transaction.sign(privateKey);
    let txResult = await web3js.eth.sendSignedTransaction(
        "0x" + transaction.serialize().toString("hex")
    );
    return txResult;
}

app.post("/verify", async function(req, res) {
    let signature = req.body.data;
    let hunter = req.body.hunter;
    //let verified = await verifyPgpSignature(signature, satoshiTreasurePubKey);
    let verified = await verifyPgpSignature(
        signature,
        fs.readFileSync("files/test-pgp-public.pem")
    );
    if (verified) {
        console.log("Verified key. Sending ETH txn");
        let resp = await sendSatTreasureKeyNFT(hunter);
        if (resp && resp.transactionHash) {
            res.status(200).send(resp.transactionHash);
        } else {
            res.status(500).send("Ethereum txn error occured", resp);
        }
    } else {
        console.log("Key verification failed");
        res.status(500).send("Key verification failed");
    }
});

app.listen(port, () => console.log("Listening on port " + port));
