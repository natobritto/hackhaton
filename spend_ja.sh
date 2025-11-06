cat > contract.simf << 'EOF'
mod witness {}

mod param {}

fn main() {

}
EOF

the_simc=./simc

COMPILED_PROGRAM=$($the_simc me.simf | awk '/^Program:/{f=1; next} f{print; exit}')

PROGRAM_B64=$COMPILED_PROGRAM
CMR=$(hal-simplicity simplicity simplicity info "$PROGRAM_B64" 2>&1 | jq -r '.cmr')
ADDRESS=$(hal-simplicity simplicity simplicity info "$PROGRAM_B64" 2>&1 | jq -r '.liquid_testnet_address_unconf')
PROGRAM_HEX=$(echo -n "$PROGRAM_B64" | base64 -d | xxd -p | tr -d '\n')
CONTROL_BLOCK="bef5919fa64ce45f8306849072b26c1bfdd2937e6b81774796ff372bd1eb5362d2"

echo "=== All Values ==="
echo "Program (hex): $PROGRAM_HEX"
echo "CMR:           $CMR"
echo "Control Block: $CONTROL_BLOCK"
echo "Address:       $ADDRESS"

# # fund
# TX_HTML=$(curl -s "https://liquidtestnet.com/faucet?address=${ADDRESS}&action=lbtc")
# echo "$TX_HTML"
# TXID=$(echo "$TX_HTML" | sed -n 's/.*transaction \([0-9a-f]\{64\}\).*/\1/p')
# if [ -n "$TXID" ]; then
#   echo "Faucet transaction id: $TXID"
# else
#   echo "Could not find txid in faucet response" >&2
# fi

# 8eb51cb199fdd9e15d1e098e35e03267fe7ff27623e996cfcfe7fb72fa1181e7

TXID=1bb2fe9a9d0eb237d524d663dfe8f945e3f9ee58670b5e717a7c2ce5740ef90f

FUND_TX=$(elements-cli decoderawtransaction $(elements-cli getrawtransaction $TXID))

echo $FUND_TX | jq

# ADDRESS=878e8b3cb5c38731ac4ea5a37c6a22b6379684c44d13db17f6453fc8e483fe3e

# ====================================================

TXID=$(echo $FUND_TX | jq '.txid')
# VOUT=$(echo $FUND_TX | jq '.vout')
VOUT=0
INPUT_VALUE=$(echo "$FUND_TX" | jq -r '(.vout[0].value * 100000000) | floor')
FEE=1000
AMOUNT=$((INPUT_VALUE - FEE))
ASSET_ID="144c654344aa716d6f3abcc1ca90e5641e4e2a7f633bc09fe3baf64585819a49"
DESTINATION="tex1q24p43v5eg6rvv076yu3xk62hm990d4hq7xrssc"

cat > transaction.json << EOF
{
  "version": 2,
  "locktime": {"Blocks": 0},
  "inputs": [{
    "txid": $TXID,
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

TX_HEX=$(cat transaction.json | hal-simplicity simplicity tx create)

RESULT=$(echo "$TX_HEX" | curl -s -X POST "https://blockstream.info/liquidtestnet/api/tx" -d @-)
echo "$RESULT"

