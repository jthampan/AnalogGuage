@echo off
setlocal enabledelayedexpansion

:: Define variables
set "TOPDIR=%CD%"
set "LOG_FOLDER=%TOPDIR%"
set "filename=meter.jpeg"
set "url=https://prod-34.southeastasia.logic.azure.com:443/workflows/037373ac6baa4cf498384ffdbc6efb2c/triggers/manual/paths/invoke?api-version=2016-06-01^&sp=%2Ftriggers%2Fmanual%2Frun^&sv=1.0^&sig=0FHEhzq8xpblOZqFbfOPHH4eRF2JUJhBPHn3n96i_-w"
set "failure_counter=0"
set "max_failures=2"

:: Main loop
:main_loop
:: Set the Singapore timezone
set TZ=Asia/Singapore
:: Get the current time in Singapore
for /f "delims=" %%a in ('powershell -command "(Get-Date).ToString('yyyy-MM-dd_HH-mm-ss')"') do set "folder_time=%%a"
mkdir "%TOPDIR%\log_%folder_time%"
set "LOG_FOLDER=%TOPDIR%\log_%folder_time%"

:: Execute the ifconfig command and capture its output
ipconfig >> "%LOG_FOLDER%\log.txt"

timeout /t 10 /nobreak

echo Starting Python Script at %folder_time% >> "%LOG_FOLDER%\log.txt"
call :run_python_script

if "!errorlevel!" gtr "0" (
    set /a "failure_counter+=1"
    if "!failure_counter!" equ "!max_failures!" (
        echo Continuous failures for 1 hour. Sending alert message... >> "%LOG_FOLDER%\log.txt"
        call :send_alert "Error: Unable to read gauge meter value for 1 hour"
        set "failure_counter=0"
    )
    echo Python script failed. Sleeping for 3600 seconds %folder_time% >> "%LOG_FOLDER%\log.txt"
    copy /y "%TOPDIR%\python_log.txt" "%LOG_FOLDER%"
    copy /y "%TOPDIR%\images" "%LOG_FOLDER%"
    call :send_folder log_%folder_time%
    timeout /t 3600 /nobreak
    goto :main_loop
)

echo Sleeping for 3600 seconds %folder_time% >> "%LOG_FOLDER%\log.txt"
copy /y "%TOPDIR%\python_log.txt" "%LOG_FOLDER%"
copy /y "%TOPDIR%\images" "%LOG_FOLDER%"
call :send_folder log_%folder_time%
timeout /t 3600 /nobreak
goto :main_loop


:send_folder
:: Set the URL
set "url=https://prod-34.southeastasia.logic.azure.com:443/workflows/037373ac6baa4cf498384ffdbc6efb2c/triggers/manual/paths/invoke?api-version=2016-06-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=0FHEhzq8xpblOZqFbfOPHH4eRF2JUJhBPHn3n96i_-w"

:: Get the folder path
set "folder_name=%1"

echo Sending folder %folder_name%

:: Create a temporary ZIP file
set "zip_file=%TEMP%\%folder_name%.zip"

:: Change the current directory to the parent directory of the folder
cd %TOPDIR%

:: Zip only the folder contents without the parent directory
powershell Compress-Archive -Path "%folder_name%\*" -DestinationPath "%zip_file%" -Force

:: Read the file contents
powershell "[System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes('%zip_file%'))" > "%zip_file%.b64"

:: Create the JSON body
(for /f "usebackq delims=" %%A in ("%zip_file%.b64") do (
    echo {
    echo     "fileName": "%folder_name%.zip",
    echo     "type": "application/zip",
    echo     "fileContent": "%%A"
    echo }
)) > "%TEMP%\json_payload.json"

:: Make the request
::Invoke-WebRequest -Uri "%url%" -Method POST -Headers @{"Content-Type" = "application/json"} -InFile "@%TEMP%\json_payload.json"

curl -X POST -H "Content-Type: application/json" --data-binary "@%TEMP%\json_payload.json" "https://prod-34.southeastasia.logic.azure.com:443/workflows/037373ac6baa4cf498384ffdbc6efb2c/triggers/manual/paths/invoke?api-version=2016-06-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=0FHEhzq8xpblOZqFbfOPHH4eRF2JUJhBPHn3n96i_-w"
::curl -X POST -H "Content-Type: application/json" --data-binary "@%TEMP%\json_payload.json" "%url%"

echo Removing zip file and folder path
cd %TOPDIR%

:: Remove the temporary ZIP file and base64 file
del "%zip_file%" "%zip_file%.b64"

:: Optionally, remove the original folder if needed
:: rmdir /s /q %TOPDIR%\%folder_name%


:send_file
:: Set the URL
set "url=https://prod-34.southeastasia.logic.azure.com:443/workflows/037373ac6baa4cf498384ffdbc6efb2c/triggers/manual/paths/invoke?api-version=2016-06-01^&sp=%2Ftriggers%2Fmanual%2Frun^&sv=1.0^&sig=0FHEhzq8xpblOZqFbfOPHH4eRF2JUJhBPHn3n96i_-w"

:: Read the file contents
set "file_name=%1"
for /f "delims=" %%A in ('powershell Get-Date -UFormat "yyyy-MM-dd_HH-mm-ss"') do set "current_timestamp=%%A"

:: Generate a timestamped file name
for %%A in ("%file_name%") do (
    set "ext=%%~xA"
    set "base=%%~nA"
    set "timestamped_file_name=%base%_%current_timestamp%%ext%"
)

:: Convert the file to base64
powershell "[System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes('%file_name%'))" > "%TEMP%\file_contents.b64"

:: Create the JSON body
(for /f "usebackq delims=" %%A in ("%TEMP%\file_contents.b64") do (
    echo {
    echo     "fileName": "%timestamped_file_name%",
    echo     "type": "image/txt",
    echo     "fileContent": "%%A"
    echo }
)) > "%TEMP%\json_payload.json"

:: Make the request
curl -X POST -H "Content-Type: application/json" --data-binary "@%TEMP%\json_payload.json" "%url%"

:: Clean up temporary files
del "%TEMP%\file_contents.b64" "%TEMP%\json_payload.json"


:send_image
:: Set the URL
set "url=https://prod-34.southeastasia.logic.azure.com:443/workflows/037373ac6baa4cf498384ffdbc6efb2c/triggers/manual/paths/invoke?api-version=2016-06-01^&sp=%2Ftriggers%2Fmanual%2Frun^&sv=1.0^&sig=0FHEhzq8xpblOZqFbfOPHH4eRF2JUJhBPHn3n96i_-w"

:: Read the file contents
set "file_name=%1"

:: Generate a timestamped file name
for /f "delims=" %%A in ('powershell Get-Date -UFormat "yyyy-MM-dd_HH-mm-ss"') do set "current_timestamp=%%A"

:: Extract file extension and base name
for %%A in ("%file_name%") do (
    set "ext=%%~xA"
    set "base=%%~nA"
    set "timestamped_file_name=%base%_%current_timestamp%%ext%"
)

:: Convert the file to base64
powershell "[System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes('%file_name%'))" > "%TEMP%\file_contents.b64"

:: Create the JSON body
(for /f "usebackq delims=" %%A in ("%TEMP%\file_contents.b64") do (
    echo {
    echo     "fileName": "%timestamped_file_name%",
    echo     "type": "image/jpeg",
    echo     "fileContent": "%%A"
    echo }
)) > "%TEMP%\json_payload.json"

:: Make the request
curl -X POST -H "Content-Type: application/json" --data-binary "@%TEMP%\json_payload.json" "%url%"

:: Clean up temporary files
del "%TEMP%\file_contents.b64" "%TEMP%\json_payload.json"


:send_alert
:: Usage: call :send_alert "error_message"
setlocal enabledelayedexpansion

:: Define variables
set "error_message=%~1"
set "url=https://prod-47.southeastasia.logic.azure.com:443/workflows/c0203e989f6f46eca748b3e30f0b2578/triggers/manual/paths/invoke?api-version=2016-06-01^&sp=%2Ftriggers%2Fmanual%2Frun^&sv=1.0^&sig=3gCM1_0pPhCL4CElKBs-vvtfJuF0J3IzD7vLil3Sgq4"

:: Get the current time in UTC
for /f "delims=" %%A in ('powershell Get-Date -UFormat "yyyy-MM-ddTHH:mm:ss.fffZ"') do set "current_time=%%A"

:: Construct the JSON payload
echo {"timestamp": "%current_time%", "message": "%error_message%"} > "%TEMP%\alert_payload.json"

:: Send the alert message using curl or any other HTTP client
curl -X POST -H "Content-Type: application/json" --data-binary "@%TEMP%\alert_payload.json" "%url%"

:: Clean up temporary files
del "%TEMP%\alert_payload.json"


:run_python_script
:: Usage: call :run_python_script "arg" "NUM_OF_METER"
setlocal enabledelayedexpansion

:: Define variables
set "arg=%~1"
set "NUM_OF_METER=%~2"

:: Run the Python script and capture the output
:: Run the Python script and capture the entire output
for /f "delims=" %%A in ('python analog_gr.py --test_mode bls --num_of_meter 1 --rotate crop1 clockwise --user_input crop1 40 320 0 4000') do (
    set "output=!output!%%A
)

:: Print Python script output to the log
echo Python script output !output! >> "%LOG_FOLDER%\log.txt"

:: Define the pattern to match for PSI values
set "psi_pattern=Current reading: For Image [0-9]+ ([0-9]+\.[0-9]+) PSI"

:: Find all PSI values using the pattern and store them in an array
set "match_count=0"
for /f "tokens=6" %%A in ('echo !output! ^| findstr /r "!psi_pattern!"') do (
    set "psi_values[!match_count!]=%%A"
    set /a "match_count+=1"
)

:: Count the number of detected PSI values
if "!match_count!" equ "0" (
    echo Error: No PSI values detected in Python script output >> "%LOG_FOLDER%\log.txt"
    call :send_alert "Error: Unable to read gauge meter values"
) else (
    :: Call python3 d2c.py with the PSI values as arguments
    setlocal disabledelayedexpansion
    for /l %%N in (0,1,!match_count!) do (
        call :run_d2c_python "!psi_values[%%N]!"
    )
)

:run_d2c_python
:: Usage: call :run_d2c_python "psi_value"
setlocal enabledelayedexpansion

:: Run the Python script and pass the PSI value as an argument
set "psi_value=%~1"
echo psi_value: %psi_value% 
python3 d2c.py !psi_value!


:cleanup
endlocal
exit /b 0
