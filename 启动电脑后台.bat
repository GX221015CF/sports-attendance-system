@echo off
chcp 65001 >nul
title Sports Attendance - Admin Web Launcher

cd /d "%~dp0admin_web"
if errorlevel 1 (
  echo Failed to enter admin_web. Please make sure this script is in the project root.
  pause
  exit /b 1
)

where npm >nul 2>nul
if errorlevel 1 (
  echo npm was not found. Please install Node.js, then run this script again.
  pause
  exit /b 1
)

if not exist node_modules (
  echo Installing dependencies, please wait...
  npm install
  if errorlevel 1 (
    echo npm install failed. Please check the error messages above.
    pause
    exit /b 1
  )
)

echo Starting admin web...
echo If the browser does not open automatically, check the Local URL in this window.
echo Default URL: http://localhost:5173
start http://localhost:5173

npm run dev

pause
