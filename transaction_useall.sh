DEST="tlq1qq2g07nju42l0nlx0erqa3wsel2l8prnq96rlnhml262mcj7pe8w6ndvvyg237japt83z24m8gu4v3yfhaqvrqxydadc9scsmw"
UTXO="c7d29e21db249fefab1f128a51052eb05bc78c339b8d0a4674ac3edc5c13766a"
ASSET_ID="144c654344aa716d6f3abcc1ca90e5641e4e2a7f633bc09fe3baf64585819a49" #btc
VOUT=0 #check your tx
VAL=0.00093973

wallet="-rpcwallet=w2"

RAW=$(elements-cli $wallet createrawtransaction \
  '[{"txid":"'"$UTXO"'","vout":'"$VOUT"'}]' \
  '[{"'"$DEST"'":'$VAL',"asset":"'"$ASSET_ID"'"}]')
echo "$RAW" | xargs elements-cli $wallet decoderawtransaction >/dev/null  # quick sanity check

FUNDED_JSON=$(elements-cli $wallet -named fundrawtransaction hexstring="$RAW")
FUNDED_HEX=$(echo "$FUNDED_JSON" | jq -r '.hex')
[ -n "$FUNDED_HEX" ] || { echo "failed to get FUNDED_HEX"; exit 1; }

echo "blind"
BLINDED_HEX=$(elements-cli $wallet blindrawtransaction  $FUNDED_HEX)
# echo $BLINDED_JSON
# BLINDED_HEX=$(echo "$BLINDED_JSON" | jq -r '.hex')
[ -n "$BLINDED_HEX" ] || { echo "failed to get SIGNED_HEX"; echo "$BLINDED_JSON"; exit 1; }
SIGNED_JSON=$(elements-cli $wallet signrawtransactionwithwallet "$BLINDED_HEX")
SIGNED_HEX=$(echo "$SIGNED_JSON" | jq -r '.hex')
[ -n "$SIGNED_HEX" ] || { echo "failed to get SIGNED_HEX"; echo "$SIGNED_JSON"; exit 1; }

# echo $SIGNED_HEX

echo "sending tx"
TXID=$(elements-cli $wallet sendrawtransaction "$SIGNED_HEX")
echo "$TXID"
