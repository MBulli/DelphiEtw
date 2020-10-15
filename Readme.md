DelphiEtw
---
This repo is an attempt to bring Event Tracing for Windows (ETW) to the Delphi world.
At its core, ETW is just a plain Win32 API, but there are some important tools missing for non-MS toolchains.
Currently the focus is only on producing events in Delphi.
For consuming ETW events the TraceEvent C# library is recommended.

EventProvider.pas
---
Object-oriented wrapper for the `Evntprov.h` Win32 API.
Can be used to manually write an ETW provider.
Depends on [MfPack](https://github.com/FactoryXCode/MfPack) (`WinApi.Evntprov.pas` and `WinApi.WinApiTypes.pas`).

dmc.exe
---
Given a manifest xml file the Delphi Message Compiler (dmc.exe) generates Delphi code to easily emit ETW events in Delphi.
The generated code is based on `EventProvider.pas` and consist mainly of wrapper functions for each event defined by the manifest.
This process is analgous to the `mc.exe` in the Windows SDK.
Note that `mc.exe` is still needed, as `dmc.exe` can't produce the binary manifest format which needs to be included in the resources section of your providers binary.

Known issues:

- Less to no error checking in dmc. Just use a [valid manifest](https://docs.microsoft.com/en-us/windows/win32/wes/eventmanifestschema-schema) ;)
- Traits are not supported ([https://docs.microsoft.com/en-us/windows/win32/etw/provider-traits](https://docs.microsoft.com/en-us/windows/win32/etw/provider-traits))
- ActivityID not supported ([https://docs.microsoft.com/en-us/windows/win32/api/evntprov/nf-evntprov-eventactivityidcontrol](https://docs.microsoft.com/en-us/windows/win32/api/evntprov/nf-evntprov-eventactivityidcontrol))
- Only basic types for template members are supported (no dynamic or static arrays; no structs)
- No kernel-mode code generation
- TraceLogging is not supported (yet).

Un/Install-EventProviders.ps1
---
Helper script to easily install or uninstall ETW providers on a system.
It sets the `resourceFile` and `messageFileName` attributes before calling wevtutil.exe.


How to use?
---
Please see the Readme.md and the bat-files in the example folder.


Writing a manifest
---
`ecmangen.exe` is a GUI tool to write manifest files.
`dmc` was only tested with xml files produced with ecmangen.
However, any valid manifest should work just fine.
Sadly `ecmangen.exe` is no longer shipped with the SDK starting with Windows SDK 16267.
(see: [blogs.windows.com/windowsdeveloper](https://blogs.windows.com/windowsdeveloper/2017/08/22/windows-10-sdk-preview-build-16267-mobile-emulator-build-15240-released/#SmZ2UGrkkrtcA9W2.97))
You can find the tool in older SDKs (<16267) or e.g. in the Win 8.1 SDK.

Resources
---

- [https://kallanreed.wordpress.com/2016/05/28/creating-an-etw-provider-step-by-step/](https://kallanreed.wordpress.com/2016/05/28/creating-an-etw-provider-step-by-step/)
- [https://github.com/gix/event-trace-kit](https://github.com/gix/event-trace-kit)

MS resources:

- [https://github.com/microsoft/perfview/tree/master/src/TraceEvent](https://github.com/microsoft/perfview/tree/master/src/TraceEvent)
- [https://docs.microsoft.com/en-us/windows/win32/wes/message-compiler--mc-exe-](https://docs.microsoft.com/en-us/windows/win32/wes/message-compiler--mc-exe-)
- [https://docs.microsoft.com/en-us/windows-server/administration/windows-commands/wevtutil](https://docs.microsoft.com/en-us/windows-server/administration/windows-commands/wevtutil)
- [https://docs.microsoft.com/en-us/windows/win32/wes/writing-an-instrumentation-manifest](https://docs.microsoft.com/en-us/windows/win32/wes/writing-an-instrumentation-manifest)
- [https://docs.microsoft.com/en-us/windows/win32/wes/eventmanifestschema-schema](https://docs.microsoft.com/en-us/windows/win32/wes/eventmanifestschema-schema)

TraceLogging resources (aka manifest-free logging):

- [https://docs.microsoft.com/en-us/windows/win32/tracelogging/trace-logging-portal](https://docs.microsoft.com/en-us/windows/win32/tracelogging/trace-logging-portal)
- [https://ticehurst.com/2019/11/04/manifest-free-etw-in-cpp.html](https://ticehurst.com/2019/11/04/manifest-free-etw-in-cpp.html)
- [https://github.com/billti/cpp-etw](https://github.com/billti/cpp-etw)