@echo off
:: query.bat - by David Bingham
:: Simple windows batch file to execute a ClearQuest query
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
set query=Personal Queries/MCD/FF - All ESM SDS IDS
set outfile=AllMgtDpars.csv
set gdrive=C:\Users\%userid%\Documents\"Google Drive"

ratlperl query.pl -u %userid% -p %password% -q "%query%" -c %outfile%

if %ERRORLEVEL% NEQ 0 goto alldone

:publish_results
:: Copy result CSV file to shared location
:: To have Google Docs recognize an updated file, it needs to either have
:: different content than the old version, or be completely new. It's not
:: enough to change the timestamp. So - let's erase and rewrite.
set gfile=%gdrive%\%outfile%
if exist %gfile% (
  del  %gdrive%\%outfile%
)
copy %outfile% %gdrive%\%outfile%

if %ERRORLEVEL% NEQ 0 goto alldone

:alldone
:: Quit this batch file, returning the result of the last executed commmand.
:: If we had an error, it gets passed out to the caller; if this was run
:: as a scheduled process, the scheduler receives the bad news.
if %ERRORLEVEL% NEQ 0 ( 
  echo Query Failed [%ERRORLEVEL%]
) else (
  echo Success
)
exit /b
