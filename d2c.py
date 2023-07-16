import os
import sys
import random
import time
import json
import base64
import requests
from datetime import datetime, timedelta
import pytz
from azure.iot.device import IoTHubDeviceClient, Message

def send_request(psi1, psi2, psi3):
    # Get the current time in UTC
    current_time_utc = datetime.utcnow()

    # Convert to Singapore time
    tz = pytz.timezone('Asia/Singapore')
    current_time_sg = current_time_utc + timedelta(hours=8)
    current_time_sg = tz.localize(current_time_sg)

    current_time_str = current_time_sg.strftime('%Y-%m-%dT%H:%M:%S.%f')[:-3] + 'Z'
    payload = {
        "readings": [
            {"meter": "1", "reading": psi1},
            {"meter": "2", "reading": psi2},
            {"meter": "3", "reading": psi3}
        ],
        "timestamp": current_time_str
    }

    result = requests.post("https://prod-37.southeastasia.logic.azure.com:443/workflows/fd3da5cafc46411e92e3f3c8c720f8da/triggers/manual/paths/invoke?api-version=2016-06-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=7XkBBNRQF1K26tBUGe7BnAqR4xrTzFsajqrbaWyUzO4", json=payload)

    print(result)
    print(result.text)

def upload_file(name):
    url = "https://prod-34.southeastasia.logic.azure.com:443/workflows/037373ac6baa4cf498384ffdbc6efb2c/triggers/manual/paths/invoke?api-version=2016-06-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=0FHEhzq8xpblOZqFbfOPHH4eRF2JUJhBPHn3n96i_-w"

    file = open(name, 'rb')
    file_contents = file.read()
    base64_contents = base64.b64encode(file_contents).decode("utf-8")

    json_body = {
        "fileName": name,
        "type": "image/jpeg",
        "fileContent": base64_contents
    }

    result = requests.post(url, json=json_body)
    print(result.text)
    print(result.status_code)

    file.close()

def main():

    # Get the PSI values from the command line arguments
    psi1 = int(float(sys.argv[1]))
    psi2 = int(float(sys.argv[2]))
    psi3 = int(float(sys.argv[3]))

    send_request(psi1, psi2, psi3)

if __name__ == '__main__':
    main()
