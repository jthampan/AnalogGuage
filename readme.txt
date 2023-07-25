# SendData commands
./Senddata_combined.sh rp_test
./Senddata_combined.sh bls_test
./Senddata_combined.sh rp
./Senddata_combined.sh bls


# Running python
python3 analog_gr.py rp 1
python3 analog_gr.py rp_test 1
python3 analog_gr.py bls 1
python3 analog_gr.py bls_test 1
