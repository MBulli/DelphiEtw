@echo off

set MC="C:\Program Files (x86)\Windows Kits\10\bin\10.0.19041.0\x86\mc.exe"
set DMC="..\dmc\Win32\Debug\dmc.exe"

mkdir TestProvider\Manifest\out\  2>NUL

REM Call mc.exe to compile the manifest to the message resources.
REM It does not matter if we use the C# or C++ backend

REM see https://docs.microsoft.com/en-us/windows/win32/wes/message-compiler--mc-exe-
REM C#:
%MC% -cs Test -h TestProvider\Manifest\out\ -r TestProvider\Manifest\out\ -z TestProvider.g  TestProvider\Manifest\TestProvider.man
REM C++:
REM %MC% -um      -h TestProvider\Manifest\out\ -r TestProvider\Manifest\out\ -z TestProvider.g  TestProvider\Manifest\TestProvider.man

REM We don't need the generated code just the *.rc, *.bin files.
del TestProvider\Manifest\out\TestProvider.g.cs

REM Now we call dmc.exe to generate Delphi code
%DMC% TestProvider\Manifest\TestProvider.man TestProvider\Manifest\out\GeneratedProvider.pas /rc:TestProvider\Manifest\out\TestProvider.g.rc

