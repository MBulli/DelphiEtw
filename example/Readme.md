
Prerequisites:
- Installed Windows SDK (you might need to change the path to mc.exe in CompileManifest.bat)

Steps to run the example:

1. Compile dmc.exe
2. Run CompileManifest.bat
3. Run InstallProvider.bat
4. Compile TestProvider and TraceListener
5. Run TraceListener.exe
6. Run TestProvider.exe

7. Run UninstallProvider.bat to remove the TestProvider from the system.

You can query the provider with
> wevtutil get-publisher Delphi-Test-Provider /ge:true 