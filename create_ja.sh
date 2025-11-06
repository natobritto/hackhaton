cat > contract.simf << 'EOF'
mod witness {}

mod param {}

fn main() {

}
EOF

the_simc=./simc

COMPILED_PROGRAM=$($the_simc me.simf | awk '/^Program:/{f=1; next} f{print; exit}')
echo "program: $COMPILED_PROGRAM"

PROGRAM_B64=$COMPILED_PROGRAM
echo "Program (base64): $PROGRAM_B64"
CMR=$(hal-simplicity simplicity simplicity info "$PROGRAM_B64" 2>&1 | jq -r '.cmr')
echo "CMR: $CMR"
ADDRESS=$(hal-simplicity simplicity simplicity info "$PROGRAM_B64" 2>&1 | jq -r '.liquid_testnet_address_unconf')
echo "Address: $ADDRESS"
PROGRAM_HEX=$(echo -n "$PROGRAM_B64" | base64 -d | xxd -p | tr -d '\n')
echo "Program (hex): $PROGRAM_HEX"
CONTROL_BLOCK="bef5919fa64ce45f8306849072b26c1bfdd2937e6b81774796ff372bd1eb5362d2"

echo "=== All Values ==="
echo "Program (hex): $PROGRAM_HEX"
echo "CMR:           $CMR"
echo "Control Block: $CONTROL_BLOCK"
echo "Address:       $ADDRESS"

