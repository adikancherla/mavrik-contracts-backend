const web3 = require("web3");
const express = require("express");
const Tx = require("ethereumjs-tx");
const app = express();
const crypto = require("crypto");
const fs = require("fs");
const openpgp = require("openpgp");
require("dotenv").config();

app.use(express.json());

const satoshiTreasurePubKey = fs.readFileSync(
    "files/satoshiTreasurePublic.pem",
    "utf-8"
);

const signAndVerifyPGP = async () => {
    try {
        const pubkey = fs.readFileSync("files/test-pgp-public.pem", "utf-8");
        const privkey = fs.readFileSync("files/test-pgp-private.pem", "utf-8");
        //sign the hash of the message 'Apple' instead of clear text
        const msg = crypto
            .createHash("sha256")
            .update("Apple")
            .digest("hex");

        //sign
        let privKeyObj = (await openpgp.key.readArmored(privkey)).keys[0];
        let options = {
            message: openpgp.cleartext.fromText(msg), // CleartextMessage or Message object
            privateKeys: [privKeyObj] // for signing
        };
        let signature = await openpgp.sign(options);
        //console.log(signature);

        //verify
        let verified = await verifyPgpSignature(signature.data, pubkey);
        if (verified) {
            console.log("Verified!!");
        } else {
            console.log("verification failed");
        }
    } catch (err) {
        console.log("error occured", err);
    }
};

const signAndVerifyRSA = () => {
    const privateKey = fs.readFileSync("files/test-rsa-private.pem", "utf-8");
    const publicKey = fs.readFileSync("files/test-rsa-public.pem", "utf-8");
    const message = "Hello world";

    const signer = crypto.createSign("sha256");
    signer.update(message);
    signer.end();

    const signature = signer.sign(privateKey);
    const signatureHex = signature.toString("hex");

    const verifier = crypto.createVerify("sha256");
    verifier.update(message);
    verifier.end();

    const verified = verifier.verify(publicKey, signature);

    console.log(
        JSON.stringify(
            {
                message: message,
                signature: signatureHex,
                verified: verified
            },
            null,
            2
        )
    );
};

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

//signAndVerifyRSA();
//signAndVerifyPGP();

const ethMainnetEndPoint =
    "https://mainnet.infura.io/v3/45cf804e13ad4412b7d88d9cea4e5906";

const ethKovanEndPoint =
    "https://kovan.infura.io/v3/45cf804e13ad4412b7d88d9cea4e5906";

//Infura HttpProvider Endpoint
//web3js = new web3(new web3.providers.HttpProvider(ethKovanEndPoint));
//web3js = new web3(new web3.providers.HttpProvider(ethMainnetEndPoint));
options = {};
web3js = new web3(new web3.providers.HttpProvider("http://127.0.0.1:7545"));

app.post("/verify", async function(req, res) {
    let signature = req.body.data;
    //let verified = await verifyPgpSignature(signature, satoshiTreasurePubKey);
    let verified = await verifyPgpSignature(
        signature,
        fs.readFileSync("files/test-pgp-public.pem")
    );
    if (verified) {
        console.log("Verified signature. Sending ETH txn");
    } else {
        console.log("Signature verification failed");
    }
    res.end();
});

function sendTx() {
    var myAddress = "ADDRESS_THAT_SENDS_TRANSACTION";
    var privateKey = Buffer.from("YOUR_PRIVATE_KEY", "hex");
    var toAddress = "ADRESS_TO_SEND_TRANSACTION";

    //contract abi is the array that you can get from the ethereum wallet or etherscan
    var contractABI = YOUR_CONTRACT_ABI;
    var contractAddress = "YOUR_CONTRACT_ADDRESS";
    //creating contract object
    var contract = new web3js.eth.Contract(contractABI, contractAddress);

    var count;
    // get transaction count, later will used as nonce
    web3js.eth.getTransactionCount(myAddress).then(function(v) {
        console.log("Count: " + v);
        count = v;
        var amount = web3js.utils.toHex(1e16);
        //creating raw tranaction
        var rawTransaction = {
            from: myAddress,
            gasPrice: web3js.utils.toHex(20 * 1e9),
            gasLimit: web3js.utils.toHex(210000),
            to: contractAddress,
            value: "0x0",
            data: contract.methods.transfer(toAddress, amount).encodeABI(),
            nonce: web3js.utils.toHex(count)
        };
        console.log(rawTransaction);
        //creating tranaction via ethereumjs-tx
        var transaction = new Tx(rawTransaction);
        //signing transaction with private key
        transaction.sign(privateKey);
        //sending transacton via web3js module
        web3js.eth
            .sendSignedTransaction(
                "0x" + transaction.serialize().toString("hex")
            )
            .on("transactionHash", console.log);

        contract.methods
            .balanceOf(myAddress)
            .call()
            .then(function(balance) {
                console.log(balance);
            });
    });
}

app.listen(3000, () => console.log("Listening on port 3000!"));
