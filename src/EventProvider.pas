unit EventProvider;

interface

uses
  Winapi.Windows,
  System.Classes,
  System.SysUtils,

  WinApi.EvntProv,
  WinApi.WinApiTypes;

type TEventProvider = class
  private
    FProviderID : TGUID;
    FRegHandle  : REGHANDLE;
    FEnabled    : Integer;
    FLevel      : Byte;
    FAnyKeyword : ULONGLONG;
    FAllKeyword : ULONGLONG;

    procedure EtwRegister;
    procedure EtwUnregister;

  protected
    procedure EventDataDescCreateStr(out EvDesc : EVENT_DATA_DESCRIPTOR; const Data : UnicodeString); overload;
    procedure EventDataDescCreateStr(out EvDesc : EVENT_DATA_DESCRIPTOR; const Data : AnsiString);    overload;

  public
    constructor Create(ProviderGuid : TGuid);
    destructor  Destroy; override;

    property RegistrationHandle : REGHANDLE read FRegHandle;

    function IsEnabled : Boolean; overload;  inline;
    function IsEnabled(level : Byte; keywords : Int64) : Boolean; overload; inline;

    // WriteEvent Api
    function WriteEvent(const EventDescriptor : PCEVENT_DESCRIPTOR) : boolean;    overload;


    function WriteEvent(const EventDescriptor : PCEVENT_DESCRIPTOR;
                        const UserData        : array of EVENT_DATA_DESCRIPTOR) : boolean; overload;

    function WriteEvent(const EventDescriptor : PCEVENT_DESCRIPTOR;
                              UserDataCount   : Integer;
                              UserData        : Pointer ) : boolean;    overload;

    function WriteMessageEvent(const EventMessage  : string;
                                     EventLevel    : Byte   = 0;
                                     EventKeywords : UInt64 = 0) : Boolean;
end;

implementation

procedure EtwEnableCallback(const SourceId        : TGUID;
                                  IsEnabled       : ULONG;
                                  Level           : UCHAR;
                                  MatchAnyKeyword : ULONGLONG;
                                  MatchAllKeyword : ULONGLONG;
                                  FilterData      : PEVENT_FILTER_DESCRIPTOR;
                                  CallbackContext : PVOID); stdcall;
var self : TEventProvider;
begin
  self := TObject(CallbackContext) as TEventProvider;

  self.FEnabled    := IsEnabled;
  self.FLevel      := Level;
  self.FAnyKeyword := MatchAnyKeyword;
  self.FAllKeyword := MatchAllKeyword;
end;

{ TEventProvider }

constructor TEventProvider.Create(ProviderGuid : TGuid);
begin
  if TOSVersion.Major < 6 then begin
    raise Exception.Create('Vista or newer required');
  end;

  FProviderID := ProviderGuid;
  FRegHandle  := 0;
  FEnabled    := 0;

  EtwRegister;
end;


destructor TEventProvider.Destroy;
begin
  EtwUnregister;

  inherited;
end;


function TEventProvider.IsEnabled: boolean;
begin
  Result := FEnabled <> 0;
end;


function TEventProvider.IsEnabled(Level : Byte; Keywords : Int64): Boolean;
begin
  Result := (FRegHandle <> 0) and EventProviderEnabled(FRegHandle, Level, Keywords);
end;


procedure TEventProvider.EtwRegister;
var Err : Integer;
begin
  Err := EventRegister(FProviderID, EtwEnableCallback, self, FRegHandle);
  if Err <> 0 then begin
    RaiseLastOSError(Err);
  end;
end;


procedure TEventProvider.EtwUnregister;
begin
  if FRegHandle <> 0 then begin
    EventUnregister(FRegHandle);
    FRegHandle := 0;
  end;
end;


procedure TEventProvider.EventDataDescCreateStr(out EvDesc : EVENT_DATA_DESCRIPTOR; const Data : UnicodeString);
const NullStr : UnicodeString = 'NULL';
begin
  // NUll terminated => (len+1)*2
  if Data = ''
  then EventDataDescCreate(EvDesc, PWideChar(NullStr), (Length(NullStr)+1)*sizeof(WideChar))
  else EventDataDescCreate(EvDesc, PWideChar(Data   ), (Length(Data   )+1)*sizeof(WideChar));
end;


procedure TEventProvider.EventDataDescCreateStr(out EvDesc : EVENT_DATA_DESCRIPTOR; const Data : AnsiString);
const NullStr : AnsiString = 'NULL';
begin
  // NUll terminated => (len+1)
  if Data = ''
  then EventDataDescCreate(EvDesc, PAnsiChar(NullStr), (Length(NullStr)+1)*sizeof(AnsiChar))
  else EventDataDescCreate(EvDesc, PAnsiChar(Data   ), (Length(Data   )+1)*sizeof(AnsiChar));
end;


function TEventProvider.WriteEvent(const EventDescriptor : PCEVENT_DESCRIPTOR): boolean;
begin
  Result := WriteEvent(EventDescriptor, 0, nil);
end;


function TEventProvider.WriteEvent(const EventDescriptor : PCEVENT_DESCRIPTOR; const UserData : array of EVENT_DATA_DESCRIPTOR) : boolean;
begin
  Result := WriteEvent(EventDescriptor, Length(UserData), Pointer(@UserData[0]));
end;


function TEventProvider.WriteEvent(const EventDescriptor: PCEVENT_DESCRIPTOR; UserDataCount: Integer; UserData: Pointer): boolean;
begin
  var Err := EventWrite(FRegHandle, EventDescriptor, UserDataCount, UserData);
//  var Err := EventWriteTransfer(FRegHandle, EventDescriptor, nil, nil, UserDataCount, UserData);
  if Err <> 0 then begin
    RaiseLastOSError(Err);
  end;
  Result := true;
end;

function TEventProvider.WriteMessageEvent(const EventMessage: string; EventLevel: Byte; EventKeywords: UInt64): boolean;
begin
  Result := true;

  if Length(EventMessage) > 32724 then begin
    raise Exception.Create('Event too long');
  end;

  var Err := EventWriteString(FRegHandle, EventLevel, EventKeywords, PWideChar(EventMessage));
  if Err <> 0 then begin
    RaiseLastOSError(Err);
  end;
end;


end.
