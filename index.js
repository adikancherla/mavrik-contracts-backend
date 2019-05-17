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

const firebase = require("firebase-admin");
const serviceAccount = require(process.env.SERVICE_ACCOUNT_KEY_FILE);

firebase.initializeApp({
    credential: firebase.credential.cert(serviceAccount)
});

const rootRef = firebase.firestore().collection(process.env.FIREBASE_ROOT_REF);
const huntersRef = rootRef.doc(process.env.FIREBASE_HUNTERS_REF);

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
        console.log("Error occured", err);
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

async function addToFirebase(reqBody) {
    let finder = reqBody.hunter;
    let key = reqBody.key;
    let data = {};
    let keyData = {
        createdAt: firebase.firestore.FieldValue.serverTimestamp(),
        updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
        finders: {},
        helpers: {}
    };
    let finderData = {
        address: finder
    };
    keyData.finders[finder] = finderData;
    data[key] = keyData;

    let result = await huntersRef.set(data, { merge: true });
    return result;
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
        // add to firebase
        console.log("Verified key. Adding to firebase");
        let result = await addToFirebase(req.body);
        console.log(result);
        res.status(200).send(result);

        //send eth txn
        console.log("Sending ETH txn");
        let resp = await sendSatTreasureKeyNFT(hunter);
        if (resp && resp.transactionHash) {
            console.log(resp.transactionHash);
        } else {
            console.log("Ethereum txn error occured", resp);
        }
    } else {
        console.log("Key verification failed");
        res.status(500).send("Key verification failed");
    }
});

app.listen(port, () => console.log("Listening on port " + port));
