@echo off
set script=raphael.arrow

cmd /c "coffee -v"
echo.
if not (%errorlevel%) == (0) (
  cls
  color 0e
  echo. &echo. &echo.
  echo ====================================================================
  echo   This script requires installation of the CoffeeScript compiler.
  echo   Refer to coffeescript.org for details.
  echo ====================================================================
  echo. &echo. &echo.
) else (
  echo Watching %script%.coffee for changes...
  coffee -l -w -c %script%
)
pause
