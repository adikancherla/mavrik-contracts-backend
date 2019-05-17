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

    //const mavrik = contract(mavrikJson);
    //console.log(mavrik);
    //console.log(web3Provider);
    // mavrik.setProvider(web3Provider);

    // const instance = await mavrik.at(contractAddress);
    // console.log(instance);
    // const result = await instance.mintNonFungible(
    //     process.env.SATOSHI_TREASURE_KEY_NFT_TYPE,
    //     [hunter],
    //     { from: fromAddress }
    // );
    // console.log(result);
    // return result;
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

// const signAndVerifyPGP = async () => {
//     try {
//         const pubkey = fs.readFileSync("files/test-pgp-public.pem", "utf-8");
//         const privkey = fs.readFileSync("files/test-pgp-private.pem", "utf-8");
//         //sign the hash of the message 'Apple' instead of clear text
//         const msg = crypto
//             .createHash("sha256")
//             .update("Apple")
//             .digest("hex");

//         //sign
//         let privKeyObj = (await openpgp.key.readArmored(privkey)).keys[0];
//         let options = {
//             message: openpgp.cleartext.fromText(msg), // CleartextMessage or Message object
//             privateKeys: [privKeyObj] // for signing
//         };
//         let signature = await openpgp.sign(options);
//         //console.log(signature);

//         //verify
//         let verified = await verifyPgpSignature(signature.data, pubkey);
//         if (verified) {
//             console.log("Verified!!");
//         } else {
//             console.log("verification failed");
//         }
//     } catch (err) {
//         console.log("error occured", err);
//     }
// };

// const signAndVerifyRSA = () => {
//     const privateKey = fs.readFileSync("files/test-rsa-private.pem", "utf-8");
//     const publicKey = fs.readFileSync("files/test-rsa-public.pem", "utf-8");
//     const message = "Hello world";

//     const signer = crypto.createSign("sha256");
//     signer.update(message);
//     signer.end();

//     const signature = signer.sign(privateKey);
//     const signatureHex = signature.toString("hex");

//     const verifier = crypto.createVerify("sha256");
//     verifier.update(message);
//     verifier.end();

//     const verified = verifier.verify(publicKey, signature);

//     console.log(
//         JSON.stringify(
//             {
//                 message: message,
//                 signature: signatureHex,
//                 verified: verified
//             },
//             null,
//             2
//         )
//     );
// };

//signAndVerifyRSA();
//signAndVerifyPGP();
