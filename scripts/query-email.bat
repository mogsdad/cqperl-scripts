@echo off
:: query-email.bat - by David Bingham
:: Simple windows batch file to execute a ClearQuest query, convert
:: the CSV results to an HTML table, and email to the user.
::
:: Parameters:
::   %1   userid
::   %2   password

:: Simple logger
:: Logfile name shares batchfile name
:: Each log prepended by timestamp & file name
set logfile=%~n0.log
set "log=call :logger "
%log% Batch file invoked.

GOTO :main

:logger
:: ECHO all parameters to both console
:: and logfile.
echo %*
echo %date%, %time%, %~nx0: %* >> %logfile%
EXIT /B 0

:main

:: If credentials not provided, prompt for them
IF "%~1"=="" (
  %log% Prompt for credentials.
  set /p userid="ClearQuest User ID: " %=%
  set /p password="ClearQuest Password: " %=%
) else (
  %log% Credentials provided.
  set userid=%~1
  set password=%~2
)

:: Set operating parameters
set query=Public Queries/Product Queries/Management Apps/SDS-CC/All Releases/SDS CC PEC Query
set outfile=SdsccPEC.csv
set htmlfile=SdsccPEC.html

ratlperl query.pl -u %userid% -p %password% -q "%query%" -c %outfile% -l %logfile%
if %ERRORLEVEL% NEQ 0 goto alldone

ratlperl csv2html.pl headers < %outfile% > %htmlfile%

ratlperl query-email.pl -u %userid% -p %password% -c %outfile% -l %logfile%
if %ERRORLEVEL% NEQ 0 goto alldone

:alldone
:: Quit this batch file, returning the result of the last executed commmand.
:: If we had an error, it gets passed out to the caller; if this was run
:: as a scheduled process, the scheduler receives the bad news.
if %ERRORLEVEL% NEQ 0 ( 
  %log% Query Failed [%ERRORLEVEL%]
) else (
  %log% Success
)
%log% ----------------------------------------------------------------- 
exit /b
