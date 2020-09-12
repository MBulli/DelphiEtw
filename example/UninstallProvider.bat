@echo off


powershell -ExecutionPolicy Bypass -File ..\Uninstall-EventProviders.ps1 TestProvider\Manifest\TestProvider.man

pause