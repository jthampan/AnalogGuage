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
python3 analog_gr.py --test_mode bls_test --num_of_meter 3 --crop_horiz 50 --bright_thresh 110 --rotate crop1 counterclockwise crop2 clockwise --meter_name meter2.jpeg --test_dir bls_test_images --user_input crop1 40 320 0 4000 crop2 40 320 0 4000 crop3 40 320 0 400
python3 analog_gr.py --test_mode bls_test --num_of_meter 3 --crop_horiz 50 --rotate crop1 clockwise crop2 counterclockwise --meter_name meter3.jpeg --test_dir bls_test_images --user_input crop1 40 320 0 4000 crop2 40 320 0 4000 crop3 40 320 0 400 
python3 analog_gr.py --test_mode bls_test --num_of_meter 3 --crop_horiz 25 --rotate crop1 clockwise crop2 counterclockwise --meter_name meter4.jpeg --test_dir bls_test_images --user_input crop1 40 320 0 4000 crop2 40 320 0 4000 crop3 40 320 0 400
python3 analog_gr.py --test_mode bls_test --num_of_meter 1 --crop_horiz 25 --rotate crop1 clockwise --meter_name meter5.jpeg  --test_dir bls_test_images  --user_input crop1 40 320 0 4000
python3 analog_gr.py --test_mode bls_test --num_of_meter 1 --crop_horiz 25 --rotate crop1 clockwise --meter_name meter6.jpeg  --test_dir bls_test_images  --user_input crop1 40 320 0 4000
python3 analog_gr.py --test_mode bls_test --num_of_meter 1 --crop_horiz 25 --rotate crop1 clockwise --meter_name meter7.jpeg  --test_dir bls_test_images  --user_input crop1 40 320 0 4000
python3 analog_gr.py --test_mode bls_test --num_of_meter 1 --crop_horiz 25 --rotate crop1 clockwise --meter_name meter8.jpeg  --test_dir bls_test_images  --user_input crop1 40 320 0 4000
python3 analog_gr.py --test_mode bls_test --num_of_meter 1 --crop_horiz 25 --rotate crop1 clockwise --meter_name meter9.jpeg  --test_dir bls_test_images  --user_input crop1 40 320 0 4000

python3 analog_gr.py --test_mode bls_test --num_of_meter 1 --rotate crop1 clockwise --user_input crop1 40 320 0 4000 --test_dir bls_test_images/Aug_13
python3 analog_gr.py --test_mode bls_test --num_of_meter 1 --rotate crop1 clockwise --user_input crop1 40 320 0 4000 --test_dir bls_test_images/Aug_15
python3 analog_gr.py --test_mode bls_test --num_of_meter 1 --rotate crop1 clockwise --user_input crop1 40 320 0 4000 --test_dir bls_test_images/Aug_16

python3 analog_gr.py --test_mode rp_test --num_of_meter 1 --meter_name meter1.jpeg

# Cygwin Installation
Run setup-x86_64.exe

# to dowload a package to Cygwin
Open Cygwin Terminal
cd to AnalogGuage directory
For eg: to download zip
./setup-x86_64.exe -q -P zip

