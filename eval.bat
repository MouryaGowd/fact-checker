@echo off
setlocal
cd /d "%~dp0"
set PYTHONUTF8=1

rem Usage:  eval.bat                 run all 50 cases
rem         eval.bat --limit 5       quick smoke run
rem         eval.bat --lang hi       only Hindi cases
rem Any arguments are passed straight to eval.run_eval.

for %%T in (uv curl ollama) do (
  where %%T >nul 2>&1
  if errorlevel 1 (
    echo [X] %%T not found. Run setup.bat first.
    pause
    exit /b 1
  )
)

ollama list >nul 2>&1
if errorlevel 1 (
  echo Starting Ollama server...
  start "Ollama" /min ollama serve
  timeout /t 6 /nobreak >nul
)

curl -s -f http://127.0.0.1:8000/api/health >nul 2>&1
if not errorlevel 1 goto :ready

echo Starting backend...
start "Fact Checker Backend" /min /d "%~dp0backend" cmd /c uv run uvicorn app.main:app --port 8000
set /a TRIES=0
:waitloop
curl -s -f http://127.0.0.1:8000/api/health >nul 2>&1
if not errorlevel 1 goto :ready
set /a TRIES+=1
if %TRIES% GEQ 30 (
  echo [X] Backend did not start within 60 seconds. Run run.bat and check its window for errors.
  pause
  exit /b 1
)
timeout /t 2 /nobreak >nul
goto :waitloop

:ready
echo Backend is up. Running eval - a full run takes a long time on a local model.
echo.
pushd backend
uv run python -m eval.run_eval %*
set RC=%ERRORLEVEL%
popd

echo.
if exist "backend\eval\results\latest.md" (
  echo Report: %~dp0backend\eval\results\latest.md
  start "" "backend\eval\results\latest.md"
) else (
  echo No report was written. Scroll up for the error.
)
echo.
echo To send the report back, run:
echo   git add backend/eval/results
echo   git commit -m "Add eval results"
echo   git push
pause
exit /b %RC%
