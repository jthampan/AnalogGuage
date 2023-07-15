#!/bin/bash

LOG_FOLDER=~/AnalogGuage

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
  # Run the Python script and capture the output
  output=$(python3 analog_gr_rp.py)

  echo "Python script output $output" >> $LOG_FOLDER/log.txt

  expected_lines=1  # Number of expected lines in the output

  # Count the number of lines that match the expected pattern
  match_count=$(echo "$output" | grep -c "Current reading: For Image [0-9]+ [0-9]+\.[0-9]+ PSI")

  # Extract the PSI values from the output
  psi1=$(echo "$output" | grep "Image 1" | awk '{print $6}')

  if [ -z "$psi1" ]; then
    echo "Error: Invalid output from Python script" >> $LOG_FOLDER/log.txt
    send_alert "Error: Unable to read guage meter value"
  else
    python3 d2c_rp.py $psi1
  fi
}

failure_counter=0
max_failures=2  # Maximum number of failures before sending an alert

while true; do
  cd $LOG_FOLDER
  rm -rf $LOG_FOLDER/log.txt

  current_time=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
  echo "Starting Image Capture at $current_time" > $LOG_FOLDER/log.txt
  # Execute the ifconfig command and capture its output
  ifconfig_output=$(ifconfig)

  # Write the output to the log file
  echo "$ifconfig_output" >> $LOG_FOLDER/log.txt

  capture_image
  if [ "$?" -gt 0 ]; then
	  ((failure_counter++))
	  if [ "$failure_counter" -eq "$max_failures" ]; then
		  echo "Continuous failures for 1 hour. Sending alert message..." >> $LOG_FOLDER/log.txt
		  send_alert "Error: Image doesnt capture for 1 hr"
		  failure_counter=0
	  fi
	  echo "Capture Image failed Sleeping for 3600 sec $current_time" >> $LOG_FOLDER/log.txt
	  send_file $LOG_FOLDER/log.txt
          sleep 3600
	  continue
  fi
  sleep 10
  echo "Starting Python Script at $current_time" >> $LOG_FOLDER/log.txt
  run_python_script
  if [ "$?" -gt 0 ]; then
	  ((failure_counter++))
	  if [ "$failure_counter" -eq "$max_failures" ]; then
		  echo "Continuous failures for 1 hour. Sending alert message..." >> $LOG_FOLDER/log.txt
		  send_alert "Error: Unable to read guage meter value for 1 hr"
		  failure_counter=0
	  fi
	  echo "Python script failed Sleeping for 3600 sec $current_time" >> $LOG_FOLDER/log.txt
	  send_file $LOG_FOLDER/log.txt
          sleep 3600
	  continue
  fi
  echo "Sleeping for 3600 sec $current_time" >> $LOG_FOLDER/log.txt
  send_file $LOG_FOLDER/log.txt
  sleep 3600
done
