program dmc;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  Winapi.Windows,
  System.IOUtils,
  ActiveX,
  System.SysUtils,
  ManifestReader in 'ManifestReader.pas',
  XmlHelper in 'XmlHelper.pas',
  CodeGen in 'CodeGen.pas',
  GpCommandLineParser in 'GpCommandLineParser.pas';

// TODO
// - Replace invalid Delphi symbols (e.g. nil, begin, end) with safe words
// - Interfaced providers?

type TCommandLine = class
  strict private
    FInputFile       : String;
    FOutputFile      : String;
    FResourceFile    : String;
    FUseTraceLogging : Boolean;

  public
    [CLPPosition(1), CLPRequired, CLPDescription('Filename of the manifest xml to compile. A valid xml is assumed. If a invalid xml is provided this tool will be unstable.', '<ManifestFile>')]
    property ManifestFile : String read FInputFile write FInputFile;

    [CLPPosition(2), CLPRequired, CLPDescription('Filename of resulting *.pas file. The name of the generated unit will be deduced from this parameter.', '<OutputPasFile>')]
    property OutputPasFile : String read FOutputFile write FOutputFile;

    [CLPLongName('rc'), CLPDescription('Optional: Filename of the rc file emitted by mc.exe. The resource file needs to be included in the binary to allow event listener to read the metadata of the produced events.', '<path>')]
    property ResourceFile : String read FResourceFile write FResourceFile;

    [CLPLongName('tracelogging'), CLPDescription('Optional: Set this to use TraceLogging API (manifest-free ETW).')]
    property UseTraceLogging : Boolean read FUseTraceLogging write FUseTraceLogging;
end;

begin
{$IF DEBUG}
  ReportMemoryLeaksOnShutdown := true;
{$ENDIF}

  var CodeGen : TCodeGen;
  var CL      : TCommandLine;

  CoInitialize(nil); // required for MSXML
  try
    Cl  := TCommandLine.Create;
    var Opt := Default(TCodeGenOptions);

    if not CommandLineParser.Parse(cl) then begin
      // TODO error invalid cmd line
      Writeln('Invalid command line');

      for var s in CommandLineParser.Usage do begin
        Writeln(s);
      end;

      ExitCode := 1;
      exit;
    end;

    // Validate command line
    if not TFile.Exists(Cl.ManifestFile) then begin
      Writeln('Manifest file not found');
      ExitCode := 1;
      exit;
    end;

    Opt.InputFileName    := Cl.ManifestFile;
    Opt.OutputFileName   := Cl.OutputPasFile;
    Opt.UnitName         := ChangeFileExt(ExtractFileName(Cl.OutputPasFile), '');
    Opt.ResourceFileName := Cl.ResourceFile;
    Opt.UseTraceLogging  := Cl.UseTraceLogging;

    codeGen := TCodeGen.Create(opt);
    codeGen.GenerateCodeFile;

    if codeGen.Hints.Count > 0 then begin
      Writeln(Format('Hints (%d):', [codeGen.Hints.Count]));
      Writeln(codeGen.Hints.Text);
    end;

    if codeGen.Warnings.Count > 0 then begin
      Writeln(Format('Warnings (%d):', [codeGen.Warnings.Count]));
      Writeln(codeGen.Warnings.Text);
    end;

    if codeGen.Errors.Count > 0 then begin
      Writeln(Format('Errors (%d):', [codeGen.Errors.Count]));
      Writeln(codeGen.Errors.Text);
      ExitCode := 1;
    end;

    Writeln('Done.');
  finally
    FreeAndNil(CodeGen);
    FreeAndNil(CL);

    CoUninitialize;
  end;
end.
