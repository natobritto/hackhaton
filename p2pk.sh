hal=./mylocalhal
simc=./simc

# Generate a new keypair using $hal
KEYPAIR=$($hal keypair generate)
echo "$KEYPAIR" | jq '.'

TEST_PRIVKEY=$(echo "$KEYPAIR" | jq -r '.secret')
TEST_PUBKEY=$(echo "$KEYPAIR" | jq -r '.x_only')

echo "Private Key: $TEST_PRIVKEY"
echo "Public Key (x-only): $TEST_PUBKEY"

cat > p2pk_contract.simf <<EOF
fn main() {
    let pubkey: Pubkey = 0x${TEST_PUBKEY};
    let msg: u256 = jet::sig_all_hash();
    let sig: Signature = witness::SIG;
    jet::bip_0340_verify((pubkey, msg), sig);
}
EOF

$simc p2pk_contract.simf

PROGRAM_B64=$($simc p2pk_contract.simf 2>&1 | awk 'NR==2')
CMR=$($hal simplicity info "$PROGRAM_B64" 2>&1 | jq -r '.cmr')
ADDRESS=$($hal simplicity info "$PROGRAM_B64" 2>&1 | jq -r '.liquid_testnet_address_unconf')
PROGRAM_HEX=$(echo -n "$PROGRAM_B64" | base64 -d | xxd -p | tr -d '\n')
CONTROL_BLOCK="bef5919fa64ce45f8306849072b26c1bfdd2937e6b81774796ff372bd1eb5362d2"

echo "=== Contract Values ==="
echo "CMR:     $CMR"
echo "Address: $ADDRESS"
echo "Program: ${PROGRAM_HEX:0:50}..."

curl "https://liquidtestnet.com/faucet?address=${ADDRESS}&action=lbtc"

TXID=$(curl -s "https://blockstream.info/liquidtestnet/api/address/${ADDRESS}/utxo" | jq -r '.[0].txid')
VOUT=$(curl -s "https://blockstream.info/liquidtestnet/api/address/${ADDRESS}/utxo" | jq -r '.[0].vout')
INPUT_VALUE=$(curl -s "https://blockstream.info/liquidtestnet/api/address/${ADDRESS}/utxo" | jq -r '.[0].value')

echo "TXID:  $TXID"
echo "VOUT:  $VOUT"
echo "VALUE: $INPUT_VALUE"

DESTINATION="tex1qjnr7j6u7tzh4q7djumh9rtldv5q7yllxuhaasp"
FEE=500
AMOUNT=$((INPUT_VALUE - FEE))
ASSET_ID="144c654344aa716d6f3abcc1ca90e5641e4e2a7f633bc09fe3baf64585819a49"

echo "Destination: $DESTINATION"
echo "Amount: $AMOUNT"
echo "Fee: $FEE"

cat > unsigned_tx.json <<EOF
{
  "version": 2,
  "locktime": {"Blocks": 0},
  "inputs": [{
    "txid": "$TXID",
    "vout": $VOUT,
    "script_sig": {"hex": ""},
    "sequence": 0,
    "is_pegin": false,
    "has_issuance": false,
    "witness": {
      "script_witness": [
        "",
        "$PROGRAM_HEX",
        "$CMR",
        "$CONTROL_BLOCK"
      ]
    }
  }],
  "outputs": [
    {
      "script_pub_key": {"address": "$DESTINATION"},
      "asset": {"type": "explicit", "asset": "$ASSET_ID"},
      "value": {"type": "explicit", "value": $AMOUNT},
      "nonce": {"type": "null"}
    },
    {
      "script_pub_key": {"hex": ""},
      "asset": {"type": "explicit", "asset": "$ASSET_ID"},
      "value": {"type": "explicit", "value": $FEE},
      "nonce": {"type": "null"}
    }
  ]
}
EOF


# Query the funding transaction to get scriptPubKey
SCRIPT_PUBKEY=$(curl -s "https://blockstream.info/liquidtestnet/api/tx/${TXID}" | jq -r '.vout[0].scriptpubkey')
echo "ScriptPubKey: $SCRIPT_PUBKEY"

UNSIGNED_TX_HEX=$(cat unsigned_tx.json | $hal tx create)

SIGHASH_RESULT=$($hal simplicity sighash \
  "$UNSIGNED_TX_HEX" \
  0 \
  "$CMR" \
  "$CONTROL_BLOCK" \
  -i "${SCRIPT_PUBKEY}:${ASSET_ID}:0.001" \
  -x "$TEST_PRIVKEY" \
  -p "$TEST_PUBKEY")

echo "$SIGHASH_RESULT" | jq '.'

SIGNATURE=$(echo "$SIGHASH_RESULT" | jq -r '.signature')
echo "Signature: $SIGNATURE"

cat > final_tx.json <<EOF
{
  "version": 2,
  "locktime": {"Blocks": 0},
  "inputs": [{
    "txid": "$TXID",
    "vout": $VOUT,
    "script_sig": {"hex": ""},
    "sequence": 0,
    "is_pegin": false,
    "has_issuance": false,
    "witness": {
      "script_witness": [
        "$SIGNATURE",
        "$PROGRAM_HEX",
        "$CMR",
        "$CONTROL_BLOCK"
      ]
    }
  }],
  "outputs": [
    {
      "script_pub_key": {"address": "$DESTINATION"},
      "asset": {"type": "explicit", "asset": "$ASSET_ID"},
      "value": {"type": "explicit", "value": $AMOUNT},
      "nonce": {"type": "null"}
    },
    {
      "script_pub_key": {"hex": ""},
      "asset": {"type": "explicit", "asset": "$ASSET_ID"},
      "value": {"type": "explicit", "value": $FEE},
      "nonce": {"type": "null"}
    }
  ]
}
EOF

cat final_tx.json | jq '.inputs[0].witness.script_witness | map(length)'

TX_HEX=$(cat final_tx.json | $hal simplicity tx create)
echo "Transaction hex length: ${#TX_HEX}"
echo "First 100 chars: ${TX_HEX:0:100}..."

RESULT=$(echo "$TX_HEX" | curl -s -X POST "https://blockstream.info/liquidtestnet/api/tx" -d @-)
echo "$RESULT"

# cat > witness.wit <<EOF
# {
#   "SIG": {
#     "value": "$SIGNATURE"
#   }
# }
# EOF




















