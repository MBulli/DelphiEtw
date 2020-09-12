unit MainForm;

interface

uses
  WinApi.Messages,
  WinApi.Windows,
  System.Classes,
  System.SysUtils,
  System.Variants,
  Vcl.Controls,
  Vcl.Dialogs,
  Vcl.Forms,
  Vcl.Graphics,
  Vcl.StdCtrls,

  GeneratedProvider;

type
  TForm1 = class(TForm)
    Button2: TButton;
    procedure Button2Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
    FProvider : TDelphiTestProvider;
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

procedure TForm1.FormCreate(Sender: TObject);
begin
  FProvider := TDelphiTestProvider.Create;
end;

procedure TForm1.Button2Click(Sender: TObject);
begin
  FProvider.EventWriteRandomTestEvent('Hallo', 42, 19);
  FProvider.EventWriteTwoIntsEvent(42, 21);
end;



end.


