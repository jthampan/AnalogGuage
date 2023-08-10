# git commands
git status
git checkout <modified files>
git pull

# SendData commands, 1st arg test_mode, 2nd arg num of meter, 3rd arg optional sec
./Senddata.sh rp_test 1
./Senddata.sh bls_test 1
./Senddata.sh rp 1
./Senddata.sh bls 3

# Running python independently
# Default test_mode bls, num_of_meter 3, crop_horiz None

python3 analog_gr.py --test_mode rp --num_of_meter 1
python3 analog_gr.py --test_mode rp_test --num_of_meter 1
python3 analog_gr.py --test_mode bls --num_of_meter 3

python3 analog_gr.py --test_mode bls_test --num_of_meter 1 --meter_name meter1.jpeg
python3 analog_gr.py --test_mode bls_test --num_of_meter 3 --crop_horiz 50 --bright_thresh 110 --rotate crop1 counterclockwise crop2 clockwise --meter_name meter2.jpeg
python3 analog_gr.py --test_mode bls_test --num_of_meter 3 --crop_horiz 50 --rotate crop1 clockwise crop2 counterclockwise --meter_name meter3.jpeg
python3 analog_gr.py --test_mode bls_test --num_of_meter 3 --crop_horiz 25 --rotate crop1 clockwise crop2 counterclockwise --meter_name meter4.jpeg
python3 analog_gr.py --test_mode bls_test --num_of_meter 1 --crop_horiz 25 --rotate crop1 clockwise --meter_name meter5.jpeg
python3 analog_gr.py --test_mode bls_test --num_of_meter 1 --crop_horiz 25 --rotate crop1 clockwise --meter_name meter6.jpeg
python3 analog_gr.py --test_mode bls_test --num_of_meter 1 --crop_horiz 25 --rotate crop1 clockwise --meter_name meter7.jpeg
python3 analog_gr.py --test_mode bls_test --num_of_meter 1 --crop_horiz 25 --rotate crop1 clockwise --meter_name meter8.jpeg
python3 analog_gr.py --test_mode bls_test --num_of_meter 1 --crop_horiz 25 --rotate crop1 clockwise --meter_name meter9.jpeg


python3 analog_gr.py --test_mode rp_test --num_of_meter 1 --meter_name meter1.jpeg
