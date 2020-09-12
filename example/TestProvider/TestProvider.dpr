program TestProvider;

// { $ R 'TestProvider.g.res' 'Manifest\out\TestProvider.g.rc'}

uses
  Vcl.Forms,
  MainForm in 'MainForm.pas' {Form1},
  WinApi.Evntprov in '..\..\src\MfPack\MfPack\src\WinApi.Evntprov.pas',
  WinApi.WinApiTypes in '..\..\src\MfPack\MfPack\src\WinApi.WinApiTypes.pas',
  EventProvider in '..\..\src\EventProvider.pas',
  GeneratedProvider in 'Manifest\out\GeneratedProvider.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
