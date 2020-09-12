@echo off


powershell -ExecutionPolicy Bypass -File ..\Install-EventProviders.ps1 TestProvider\Manifest\TestProvider.man TestProvider\Win32\Debug\TestProvider.exe -PrintInfo

pause