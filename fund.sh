# fund
TX_HTML=$(curl -s "https://liquidtestnet.com/faucet?address=${ADDRESS}&action=lbtc")
echo "$TX_HTML"
TXID=$(echo "$TX_HTML" | sed -n 's/.*transaction \([0-9a-f]\{64\}\).*/\1/p')
if [ -n "$TXID" ]; then
  echo "Faucet transaction id: $TXID"
else
  echo "Could not find txid in faucet response" >&2
fi
