#!/bin/bash

capture_image() {
  filename="meter.jpg"
  nvgstcapture-1.0 --camsrc=0 --cap-dev-node=0 --automate --capture-auto --file-name="$filename"

  captured_filename=$(find . -maxdepth 1 -type f -name "meter.jpg_*.jpg" | sort -n | tail -1)
  mv "$captured_filename" "images/$filename"

  if [ -f "images/$filename" ]; then
    echo "Image captured successfully: images/$filename"
    send_image "images/$filename"
  else
    echo "Failed to capture image: $filename"
    send_alert "Failed to capture image: $filename"
    return 1
  fi

  return 0
}

send_image() {
    # Set the URL
    url="https://prod-34.southeastasia.logic.azure.com:443/workflows/037373ac6baa4cf498384ffdbc6efb2c/triggers/manual/paths/invoke?api-version=2016-06-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=0FHEhzq8xpblOZqFbfOPHH4eRF2JUJhBPHn3n96i_-w"

    # Read the file contents
    file_name="$1"
    file_contents=$(base64 -w 0 "$file_name")

    # Create the JSON body
    json_body=$(cat <<EOF
{
    "fileName": "$file_name",
    "type": "image/jpg",
    "fileContent": "$file_contents"
}
EOF
)

    # Print the JSON body
    echo "$json_body"

    # Make the request
    result=$(curl -X POST -H "Content-Type: application/json" -d "$json_body" "$url")

    # Print the result
    echo "$result"
    status_code=$(echo "$result" | awk '{print $NF}')
    echo "Status code: $status_code"
}

send_alert() {
  error_message=$1
  url="https://prod-47.southeastasia.logic.azure.com:443/workflows/c0203e989f6f46eca748b3e30f0b2578/triggers/manual/paths/invoke?api-version=2016-06-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=3gCM1_0pPhCL4CElKBs-vvtfJuF0J3IzD7vLil3Sgq4"

  # Construct the JSON payload for the alert message
  current_time=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
  payload='{"timestamp": "'$current_time'", "message": "'$error_message'"}'

  echo $payload
  # Send the alert message using curl or any other HTTP client
  curl -X POST -H "Content-Type: application/json" -d "$payload" "$url"
}

run_python_script() {
  # Run the Python script and capture the output
  output=$(python analog_gr_rp.py)

  expected_lines=3  # Number of expected lines in the output

  # Count the number of lines that match the expected pattern
  match_count=$(echo "$output" | grep -c "Current reading: For Image [0-9]+ [0-9]+\.[0-9]+ PSI")

  if [ "$match_count" -ne "$expected_lines" ]; then
	  echo "Error: Unexpected output format"
	  return 1
  fi

  # Extract the PSI values from the output
  psi1=$(echo "$output" | grep "Image 1" | awk '{print $6}')
  psi2=$(echo "$output" | grep "Image 2" | awk '{print $6}')
  psi3=$(echo "$output" | grep "Image 3" | awk '{print $6}')

  if [ -z "$psi1" ] || [ -z "$psi2" ] || [ -z "$psi3" ]; then
    echo "Error: Invalid output from Python script"
    send_alert "Error: Invalid output from Python script"
  else
    python3 d2c.py $psi1 $psi2 $psi3
  fi
}

failure_counter=0
max_failures=2  # Maximum number of failures before sending an alert

while true; do
  capture_image
  if [ "$?" -gt 0 ]; then
	  ((failure_counter++))
	  if [ "$failure_counter" -eq "$max_failures" ]; then
		  echo "Continuous failures for 1 hour. Sending alert message..."
		  send_alert "Error: Continous failure for 1 hr"
		  failure_counter=0
	  fi
	  continue
  fi
  sleep 10
  run_python_script
  if [ "$?" -gt 0 ]; then
	  ((failure_counter++))
	  if [ "$failure_counter" -eq "$max_failures" ]; then
		  echo "Continuous failures for 1 hour. Sending alert message..."
		  send_alert "Error: Continous failure for 1 hr"
		  failure_counter=0
	  fi
	  continue
  fi
  sleep 1800
done
