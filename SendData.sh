#!/bin/bash

TOPDIR=$(pwd)
LOG_FOLDER=$TOPDIR

capture_image() {
  filename="meter.jpeg"
  nvgstcapture-1.0 --camsrc=0 --cap-dev-node=0 --automate --capture-auto --file-name="$filename" &>> $LOG_FOLDER/log.txt

  captured_filename=$(find . -maxdepth 1 -type f -name "meter.jpeg_*.jpg" | sort -n | tail -1)
  
  mv "$captured_filename" "images/$filename"
  
  if [ $? -ne 0 ]; then
    echo "Failed to move captured image $captured_filename. Exiting..." >> $LOG_FOLDER/log.txt
    send_alert "Failed to move captured image $captured_filename. Exiting..."
    return 1
  fi

  if grep -q "/dev/video0 does not exist" "$LOG_FOLDER/log.txt"; then
    echo "/dev/video0 does not exist. Exiting..."
    send_alert "video0 does not exist Failed to capture guage image: $filename"
    return 1
  fi

  if [ -f "images/$filename" ]; then
    echo "Guage image captured successfully: images/$filename" >> $LOG_FOLDER/log.txt
    send_image "images/$filename"
  else
    echo "Failed to capture image: $filename" >> $LOG_FOLDER/log.txt
    send_alert "Failed to capture guage image: $filename"
    return 1
  fi

  return 0
}

send_folder() {
    # Set the URL
    url="https://prod-34.southeastasia.logic.azure.com:443/workflows/037373ac6baa4cf498384ffdbc6efb2c/triggers/manual/paths/invoke?api-version=2016-06-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=0FHEhzq8xpblOZqFbfOPHH4eRF2JUJhBPHn3n96i_-w"

    # Get the folder path
    folder_name="$1"

    echo "Sending folder $folder_name"
    # Create a temporary ZIP file
    zip_file="/tmp/$folder_name.zip"

    # Change the current directory to the parent directory of the folder
    cd $TOPDIR

    # Zip only the folder contents without the parent directory
    zip -r "$zip_file" "$folder_name"

    # Read the file contents
    file_contents=$(base64 -w 0 "$zip_file")

    # Create the JSON body
    json_body=$(cat <<EOF
{
    "fileName": "$folder_name.zip",
    "type": "application/zip",
    "fileContent": "$file_contents"
}
EOF
)

    # Create a temporary JSON file for the payload
    json_file="/tmp/json_payload.json"
    echo "$json_body" > "$json_file"

    # Make the request
    result=$(curl -X POST -H "Content-Type: application/json" --data-binary "@$json_file" "$url")

    echo "Removing zip file and folder path"

    cd $TOPDIR

    # Remove the temporary ZIP file
    rm "$zip_file" "$json_file"
    rm -rf $TOPDIR/$folder_name
}

send_file() {
    # Set the URL
    url="https://prod-34.southeastasia.logic.azure.com:443/workflows/037373ac6baa4cf498384ffdbc6efb2c/triggers/manual/paths/invoke?api-version=2016-06-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=0FHEhzq8xpblOZqFbfOPHH4eRF2JUJhBPHn3n96i_-w"

    # Read the file contents
    file_name="$1"
    current_timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
    timestamped_file_name="${file_name%.*}_${current_timestamp}.${file_name##*.}"    
    file_contents=$(base64 -w 0 "$file_name")

    # Create the JSON body
    json_body=$(cat <<EOF
{
    "fileName": "$timestamped_file_name",
    "type": "image/txt",
    "fileContent": "$file_contents"
}
EOF
)
    # Make the request
    result=$(curl -X POST -H "Content-Type: application/json" -d "$json_body" "$url")
}

send_image() {
    # Set the URL
    url="https://prod-34.southeastasia.logic.azure.com:443/workflows/037373ac6baa4cf498384ffdbc6efb2c/triggers/manual/paths/invoke?api-version=2016-06-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=0FHEhzq8xpblOZqFbfOPHH4eRF2JUJhBPHn3n96i_-w"

    # Read the file contents
    file_name="$1"
    current_timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
    timestamped_file_name="${file_name%.*}_${current_timestamp}.${file_name##*.}"    
    file_contents=$(base64 -w 0 "$file_name")

    # Create the JSON body
    json_body=$(cat <<EOF
{
    "fileName": "$timestamped_file_name",
    "type": "image/jpeg",
    "fileContent": "$file_contents"
}
EOF
)

    # Make the request
    result=$(curl -X POST -H "Content-Type: application/json" -d "$json_body" "$url")
}

send_alert() {
  error_message=$1
  url="https://prod-47.southeastasia.logic.azure.com:443/workflows/c0203e989f6f46eca748b3e30f0b2578/triggers/manual/paths/invoke?api-version=2016-06-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=3gCM1_0pPhCL4CElKBs-vvtfJuF0J3IzD7vLil3Sgq4"

  # Construct the JSON payload for the alert message
  current_time=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
  payload='{"timestamp": "'$current_time'", "message": "'$error_message'"}'

  echo "Sending Alert message $payload" >> $LOG_FOLDER/log.txt
  # Send the alert message using curl or any other HTTP client
  curl -X POST -H "Content-Type: application/json" -d "$payload" "$url"
}

run_python_script() {

  echo "ARG $arg Number of meter $NUM_OF_METER"
  # Run the Python script and capture the output
  output=$(python3 analog_gr.py --test_mode $arg --num_of_meter $NUM_OF_METER)

  echo "Python script output $output" >> $LOG_FOLDER/log.txt

  # Define the pattern to match for PSI values
  psi_pattern="Current reading: For Image [0-9]+ ([0-9]+\.[0-9]+) PSI"

  # Find all PSI values using the pattern and store them in an array
  psi_values=()
  while read -r line; do
    if [[ $line =~ $psi_pattern ]]; then
      psi_values+=("${BASH_REMATCH[1]}")
    fi
  done <<< "$output"

  # Count the number of detected PSI values
  match_count=${#psi_values[@]}

  if [ "$match_count" -eq 0 ]; then
    echo "Error: No PSI values detected in Python script output" >> $LOG_FOLDER/log.txt
    send_alert "Error: Unable to read gauge meter values"
  else
    # Call python3 d2c.py with the PSI values as arguments
    python3 d2c.py "${psi_values[@]}"
  fi
}

failure_counter=0
max_failures=2  # Maximum number of failures before sending an alert

arg=$1
NUM_OF_METER=$2

# Check if the third argument ($3) is provided
if [ -n "$3" ]; then
    SEC="$3"
else
    SEC=3600
fi

while true; do

  # Set the Singapore timezone
  export TZ='Asia/Singapore'
  # Get the current time in Singapore
  folder_time=$(date '+%Y-%m-%d_%H-%M-%S')
  mkdir -p $TOPDIR/log_$folder_time
  LOG_FOLDER=$TOPDIR/log_$folder_time

  echo "Starting Image Capture at $folder_time" > $LOG_FOLDER/log.txt
  # Execute the ifconfig command and capture its output
  ifconfig_output=$(ifconfig)

  # Write the output to the log file
  echo "$ifconfig_output" >> $LOG_FOLDER/log.txt

  if [ $arg != "rp_test" ] && [ $arg != "bls_test" ]; then
    capture_image
  fi
  if [ "$?" -gt 0 ]; then
	  ((failure_counter++))
	  if [ "$failure_counter" -eq "$max_failures" ]; then
		  echo "Continuous failures for 1 hour. Sending alert message..." >> $LOG_FOLDER/log.txt
		  send_alert "Error: Image doesnt capture for 1 hr"
		  failure_counter=0
	  fi
	  echo "Capture Image failed Sleeping for 3600 sec $folder_time" >> $LOG_FOLDER/log.txt
  	  cp -rf $TOPDIR/images $LOG_FOLDER
	  send_folder log_$folder_time
          sleep $SEC
	  continue
  fi
  sleep 10
  echo "Starting Python Script at $folder_time" >> $LOG_FOLDER/log.txt
  run_python_script
  if [ "$?" -gt 0 ]; then
	  ((failure_counter++))
	  if [ "$failure_counter" -eq "$max_failures" ]; then
		  echo "Continuous failures for 1 hour. Sending alert message..." >> $LOG_FOLDER/log.txt
		  send_alert "Error: Unable to read guage meter value for 1 hr"
		  failure_counter=0
	  fi
	  echo "Python script failed Sleeping for 3600 sec $folder_time" >> $LOG_FOLDER/log.txt
          cat $TOPDIR/python_log.txt >> $LOG_FOLDER/log.txt
  	  cp -rf $TOPDIR/images $LOG_FOLDER
	  send_folder log_$folder_time
          sleep $SEC
	  continue
  fi
  echo "Sleeping for 3600 sec $folder_time" >> $LOG_FOLDER/log.txt

  cat $TOPDIR/python_log.txt >> $LOG_FOLDER/log.txt
  cp -rf $TOPDIR/images $LOG_FOLDER
  send_folder log_$folder_time
  sleep $SEC
done
