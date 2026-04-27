# Create work library
vlib work

# Compile design files with coverage enabled
vlog -cover bcesft baseP_mult/*.*v
vlog -cover bcesft fe_modules/*.*v
vlog -cover bcesft frombytes/*.*v
vlog -cover bcesft ge_modules/*.*v
vlog -cover bcesft others/*.*v
vlog -cover bcesft sc_ops/*.*v
vlog -cover bcesft sha512/*.*v
vlog -cover bcesft Top_fsm/*.*v
vlog -cover bcesft *.*v

# Start simulation with coverage enabled
vsim -coverage -voptargs=+acc work.Ed25519_TOP_TB -sv_lib dpi_crypto_sign

# Exclude the testbench module by scope
coverage exclude -scope /Ed25519_TOP_TB

# Load waveform configuration
do wave.do

# Run the simulation
run -all

# Save coverage data to a file
coverage save ed25519_coverage.ucdb

# Optional: Generate a coverage report
coverage report -output ed25519_coverage.txt -details