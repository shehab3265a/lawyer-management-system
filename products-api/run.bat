@echo off
setlocal
cd /d "%~dp0"

set "ASPNETCORE_ENVIRONMENT=Development"
set "NUGET_PACKAGES=D:\nuget-packages"

echo Starting Products API at http://localhost:5280
echo Endpoints:
echo   GET  /api/products
echo   GET  /api/products/{id}
echo   POST /api/products
echo.

dotnet run --project Products.API --launch-profile http
endlocal
