#!/usr/bin/env bash
set -euo pipefail

# --- YOU SET THESE ---
DEST="tex1p9ytl7f6qy274nu3gzaprqd9vh77xpt4eh05m4sz3qxxltxhepy7q4keasr"
UTXO="cab983e0fedefdb081384f5ea449d51399befc4f98753fe45c900765e2855737"
ASSET_ID="144c654344aa716d6f3abcc1ca90e5641e4e2a7f633bc09fe3baf64585819a49"  # L-BTC asset id
VOUT=0
RECIPIENT_AMT=0.00009000                # exact amount the other person should receive
FEE_SAT_VB=0.5                            # your target feerate in sat/vB (e.g., 1, 2, 3, 5, 10)

wallet="" #="-rpcwallet=w2"

# (Optional) choose a specific change address that belongs to *your* wallet.
# If you prefer automatic wallet change, comment the next line and we won't set changeAddress.
CHANGE_ADDR=$(elements-cli $wallet getnewaddress)

# Convert sat/vB -> BTC/kvB (Core/Elements expects BTC per kvB)
# 1 sat/vB == 0.00001000 BTC/kvB
FEE_BTC_PER_KVB=$(python3 - <<PY
sat_vb = $FEE_SAT_VB
print(f"{sat_vb * 0.00001:.8f}")
PY
)

# Build recipient output (exact amount, fee NOT subtracted from recipient)
RAW=$(elements-cli $wallet createrawtransaction \
  '[{"txid":"'"$UTXO"'","vout":'"$VOUT"'}]' \
  '[{"'"$DEST"'":'"$RECIPIENT_AMT"',"asset":"'"$ASSET_ID"'"}]')

# Prepare fund options: explicit change back to you, desired fee rate, RBF enabled.
# NOTE: If you ever want the fee to be deducted from the recipient instead,
# set subtractFeeFromOutputs to [0].
read -r -d '' FUND_OPTS <<JSON || true
{
  "feeRate": $FEE_BTC_PER_KVB,
  "replaceable": true,
  "changePosition": 1,
  "changeAddress": "$CHANGE_ADDR"
}
JSON

# Fund
FUNDED_JSON=$(elements-cli $wallet -named fundrawtransaction hexstring="$RAW" options="$FUND_OPTS")
FUNDED_HEX=$(echo "$FUNDED_JSON" | jq -r '.hex')
[ -n "$FUNDED_HEX" ] || { echo "failed to get FUNDED_HEX"; exit 1; }

# Show fee estimate and where change went
EST_FEE=$(echo "$FUNDED_JSON" | jq -r '.fee')
CHG_POS=$(echo "$FUNDED_JSON" | jq -r '.changepositions // .changepos // empty')
echo "Estimated fee (L-BTC): $EST_FEE"
[ -n "$CHG_POS" ] && echo "Change output position(s): $CHG_POS"
# Print fee in L-BTC and in satoshis
SAT_FEE=$(awk "BEGIN{printf(\"%.0f\", $EST_FEE * 100000000)}")
echo "Estimated fee (L-BTC): $EST_FEE  ->  $SAT_FEE sats"

# Quick sanity check
echo "$FUNDED_HEX" | xargs elements-cli $wallet decoderawtransaction >/dev/null

# Blind, sign, and send
echo "blinding…"
BLINDED_HEX=$(elements-cli $wallet blindrawtransaction "$FUNDED_HEX")
[ -n "$BLINDED_HEX" ] || { echo "failed to get BLINDED_HEX"; exit 1; }

SIGNED_JSON=$(elements-cli $wallet signrawtransactionwithwallet "$BLINDED_HEX")
SIGNED_HEX=$(echo "$SIGNED_JSON" | jq -r '.hex')
[ -n "$SIGNED_HEX" ] || { echo "failed to get SIGNED_HEX"; echo "$SIGNED_JSON"; exit 1; }

echo "broadcasting…"
TXID=$(elements-cli $wallet sendrawtransaction "$SIGNED_HEX")
echo "TXID: $TXID"

# Final summary
echo "Recipient: $DEST"
echo "Recipient gets (exact): $RECIPIENT_AMT L-BTC"
echo "Your fee target: $FEE_SAT_VB sat/vB  (~$EST_FEE L-BTC estimated)"
echo "All remaining L-BTC returns to you at change address: $CHANGE_ADDR"

