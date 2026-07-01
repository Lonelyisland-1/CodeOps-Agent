@echo off
chcp 65001 >nul 2>&1
cd /d "%~dp0"

echo ====================================
echo  SuperBizAgent - Stopping Services
echo ====================================
echo.

setlocal enabledelayedexpansion

REM Step 1: Kill FastAPI by port 9900
echo [1/5] Stopping FastAPI (port 9900)...
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":9900"') do (
    if "%%a" neq "" (
        taskkill /F /PID %%a >nul 2>&1 && echo [OK] FastAPI stopped (PID %%a)
    )
)
taskkill /FI "WINDOWTITLE eq SuperBizAgent API*" /F >nul 2>&1
echo [INFO] FastAPI stopped
echo.

REM Step 2: Kill LHM Alert Agent
echo [2/5] Stopping LHM Alert Agent...
taskkill /FI "WINDOWTITLE eq LHM Alert Agent*" /F >nul 2>&1
echo [INFO] LHM Alert Agent stopped
echo.

REM Step 3: Kill Monitor MCP Server by port 8004
echo [3/5] Stopping Monitor MCP Server (port 8004)...
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":8004"') do (
    if "%%a" neq "" (
        taskkill /F /PID %%a >nul 2>&1 && echo [OK] Monitor MCP stopped (PID %%a)
    )
)
taskkill /FI "WINDOWTITLE eq Monitor MCP Server*" /F >nul 2>&1
echo [INFO] Monitor MCP stopped
echo.

REM Step 4: Kill LibreHardwareMonitor
echo [4/5] Stopping LibreHardwareMonitor...
taskkill /IM "LibreHardwareMonitor.exe" /F >nul 2>&1
if errorlevel 1 (
    echo [INFO] LibreHardwareMonitor not running
) else (
    echo [OK] LibreHardwareMonitor stopped
)
echo.

REM Step 5: Stop Docker containers
echo [5/5] Stopping Milvus containers...
docker ps --format "{{.Names}}" 2>nul | findstr "milvus-standalone" >nul 2>&1
if not errorlevel 1 (
    echo [INFO] Running: docker compose -f vector-database.yml down
    docker compose -f vector-database.yml down
    if errorlevel 1 (
        echo [ERROR] docker compose failed.
        echo [INFO] Please make sure Docker Desktop is running as Administrator.
        echo [INFO] Or run manually: docker compose -f vector-database.yml down
    ) else (
        echo [OK] Milvus containers stopped
    )
) else (
    echo [INFO] Milvus containers not running
)
echo.

endlocal

echo ====================================
echo  All services stopped!
echo ====================================
echo.
echo  Tip: To also delete volumes, run:
echo    docker compose -f vector-database.yml down -v
echo.
echo  If any process still holds port 9900, run:
echo    netstat -ano ^| findstr :9900
echo    taskkill /F /PID ^<PID^>
echo.
pause
