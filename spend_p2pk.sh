source .env

TXID=8a4b99a546b0b395bf1b1929340ce348b81e6af19290ad97a2dc458f746290b3
ASSET_ID="144c654344aa716d6f3abcc1ca90e5641e4e2a7f633bc09fe3baf64585819a49"
DESTINATION="tex1q24p43v5eg6rvv076yu3xk62hm990d4hq7xrssc"

hal=./mylocalhal

FUND_TX=$(elements-cli decoderawtransaction $(elements-cli getrawtransaction $TXID))
echo $FUND_TX | jq

# TXID=$(echo $FUND_TX | jq '.txid')
# VOUT=$(echo $FUND_TX | jq '.vout')
VOUT=0
INPUT_VALUE=$(echo "$FUND_TX" | jq -r '(.vout[0].value * 100000000) | floor')
FEE=1000
VAL=0.00009
AMOUNT=$((INPUT_VALUE - FEE))

echo "TXID:  $TXID"
echo "VOUT:  $VOUT"
echo "VALUE: $INPUT_VALUE"
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
# curl -s "https://blockstream.info/liquidtestnet/api/tx/${TXID}"

SCRIPT_PUBKEY=$(curl -s "https://blockstream.info/liquidtestnet/api/tx/${TXID}" | jq -r '.vout[0].scriptpubkey')
echo "ScriptPubKey: $SCRIPT_PUBKEY"

UNSIGNED_TX_HEX=$(cat unsigned_tx.json | $hal tx create)

echo "UNSIGNED_TX_HEX: $UNSIGNED_TX_HEX"


SIGHASH_RESULT=$($hal simplicity sighash \
  "$UNSIGNED_TX_HEX" \
  0 \
  "$CMR" \
  "$CONTROL_BLOCK" \
  -i "${SCRIPT_PUBKEY}:${ASSET_ID}:${VAL}" \
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

TX_HEX=$(cat final_tx.json | hal-simplicity simplicity tx create)
echo "Transaction hex length: ${#TX_HEX}"
echo "First 100 chars: ${TX_HEX:0:100}..."

RESULT=$(echo "$TX_HEX" | curl -s -X POST "https://blockstream.info/liquidtestnet/api/tx" -d @-)
echo "$RESULT"
