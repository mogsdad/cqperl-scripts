@echo off
:: chart.bat - by David Bingham
:: Simple windows batch file to execute a ClearQuest chart query
:: and copy the results to a convenient location. In this case,
:: Google Drive is being used to sync the content from the PC to
:: the Cloud.
::
:: Parameters:
::   %1   userid
::   %2   password

:: If credentials not provided, prompt for them
IF "%~1"=="" (
  set /p userid="ClearQuest User ID: " %=%
  set /p password="ClearQuest Password: " %=%
) else (
  set userid=%~1
  set password=%~2
)

:: Set operating parameters
set query=Public Queries/Designer Fix Trend
set outfile=output_file.jpg
set gdrive=C:\Users\%userid%\Documents\"Google Drive"

ratlperl chart.cqpl -u %userid% -p %password% -q "%query%" -o %outfile%

:: To have Google Docs recognize an updated file, it needs to either have
:: different content than the old version, or be completely new. It's not
:: enough to change the timestamp. So - let's erase and rewrite.
set gfile=%gdrive%\%outfile%
if exist %gfile% (
  del  %gdrive%\%outfile%
)
copy %outfile% %gdrive%\%outfile%

:: Done
