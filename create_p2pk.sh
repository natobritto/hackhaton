# hal=./mylocalhal
hal="hal-simplicity simplicity"

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

./simc p2pk_contract.simf

PROGRAM_B64=$(./simc p2pk_contract.simf 2>&1 | awk 'NR==2')
CMR=$($hal simplicity info "$PROGRAM_B64" 2>&1 | jq -r '.cmr')
ADDRESS=$($hal simplicity info "$PROGRAM_B64" 2>&1 | jq -r '.liquid_testnet_address_unconf')

PROGRAM_HEX=$(echo -n "$PROGRAM_B64" | base64 -d | xxd -p | tr -d '\n')


CONTROL_BLOCK="bef5919fa64ce45f8306849072b26c1bfdd2937e6b81774796ff372bd1eb5362d2"

echo "=== Contract Values ==="
echo "CMR:     $CMR"
echo "Address: $ADDRESS"
echo "Program: ${PROGRAM_HEX:0:50}..."

# Save important variables to a local .env (permissions restricted)
cat > .env <<EOF
# Generated .env - sensitive values
TEST_PRIVKEY="$TEST_PRIVKEY"
TEST_PUBKEY="$TEST_PUBKEY"
CMR="$CMR"
ADDRESS="$ADDRESS"
PROGRAM_B64="$PROGRAM_B64"
PROGRAM_HEX="$PROGRAM_HEX"
CONTROL_BLOCK="$CONTROL_BLOCK"
EOF

echo "Saved variables to .env"








