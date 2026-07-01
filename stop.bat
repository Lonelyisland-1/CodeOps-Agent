@echo off
chcp 65001 >nul 2>&1
cd /d "%~dp0"

echo ====================================
echo  SuperBizAgent - Stopping Services
echo ====================================
echo.

REM Stop FastAPI
echo [1/5] Stopping FastAPI (port 9900)...
taskkill /FI "WINDOWTITLE eq SuperBizAgent API*" /F >nul 2>&1
if errorlevel 1 (
    echo [INFO] FastAPI not running or already stopped
) else (
    echo [OK] FastAPI stopped
)
echo.

REM Stop LHM Alert Agent
echo [2/5] Stopping LHM Alert Agent...
taskkill /FI "WINDOWTITLE eq LHM Alert Agent*" /F >nul 2>&1
if errorlevel 1 (
    echo [INFO] LHM Alert Agent not running or already stopped
) else (
    echo [OK] LHM Alert Agent stopped
)
echo.

REM Stop Monitor MCP Server
echo [3/5] Stopping Monitor MCP Server (port 8004)...
taskkill /FI "WINDOWTITLE eq Monitor MCP Server*" /F >nul 2>&1
if errorlevel 1 (
    echo [INFO] Monitor MCP Server not running or already stopped
) else (
    echo [OK] Monitor MCP Server stopped
)
echo.

REM Stop LibreHardwareMonitor
echo [4/5] Stopping LibreHardwareMonitor...
taskkill /IM "LibreHardwareMonitor.exe" /F >nul 2>&1
if errorlevel 1 (
    echo [INFO] LibreHardwareMonitor not running
) else (
    echo [OK] LibreHardwareMonitor stopped
)
echo.

REM Stop Docker containers
echo [5/5] Stopping Milvus containers...
docker ps --format "{{.Names}}" 2>nul | findstr "milvus-standalone" >nul 2>&1
if not errorlevel 1 (
    echo [INFO] Running: docker compose -f vector-database.yml down
    docker compose -f vector-database.yml down
    if errorlevel 1 (
        echo [ERROR] docker compose failed.
        echo [INFO] Please make sure Docker Desktop is running as Administrator.
        echo [INFO] Alternatively, run manually in this directory:
        echo [INFO]   docker compose -f vector-database.yml down
    ) else (
        echo [OK] Milvus containers stopped
    )
) else (
    echo [INFO] Milvus containers not running
)
echo.

echo ====================================
echo  All services stopped!
echo ====================================
echo.
echo  Tip: To also delete volumes, run:
echo    docker compose -f vector-database.yml down -v
echo.
pause
