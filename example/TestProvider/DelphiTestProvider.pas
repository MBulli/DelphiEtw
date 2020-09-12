unit DelphiTestProvider;

interface

uses
  System.Classes,
  System.SysUtils,

  EventProvider,
  MfPack.EvntProv;


type EventProviderVersionTwo = class(TEventProvider)
  function TemplateT_StringWithInt(var   EventDescriptor : EVENT_DESCRIPTOR;
                                   const StringValue     : string;
                                         IntValue        : Integer) : Boolean;

  function TemplateT_TwoInts(var   EventDescriptor : EVENT_DESCRIPTOR;
                                   IntA            : Integer;
                                   IntB            : Integer) : Boolean;
end;

type TDelphiTestProvider = class

  protected
    Provider      : EventProviderVersionTwo;

    RandomTestEvent : EVENT_DESCRIPTOR;
    TwoIntsEvent    : EVENT_DESCRIPTOR;
  public
    constructor Create;
    destructor  Destroy; override;

    function EventWriteRandomTestEvent(const StringValue : string; IntValue : Integer) : boolean;
    function EventWriteTwoIntsEvent   (IntA, IntB : Integer) : boolean;
end;



implementation

{ TDelphiTestProvider }

constructor TDelphiTestProvider.Create;
begin
  Provider := EventProviderVersionTwo.Create(StringToGUID('{83ee142c-99df-496e-a92b-6fa432157fbd}'));

  EventDescCreate(RandomTestEvent, $1, $0, $0, $4, $1, $a, $0);
  EventDescCreate(TwoIntsEvent   , $2, $0, $0, $0, $0, $0, $0);
end;

destructor TDelphiTestProvider.Destroy;
begin
  FreeAndNil(Provider);

  inherited;
end;

function TDelphiTestProvider.EventWriteRandomTestEvent(const StringValue : string; IntValue : Integer) : boolean;
begin
  Result := true;
  if provider.IsEnabled then begin
    Result := Provider.TemplateT_StringWithInt(RandomTestEvent, StringValue, IntValue);
  end;
end;


function TDelphiTestProvider.EventWriteTwoIntsEvent(IntA, IntB: Integer): boolean;
begin
  Result := true;
  if provider.IsEnabled then begin
    Result := Provider.TemplateT_TwoInts(TwoIntsEvent, IntA, IntB);
  end;
end;

{ EventProviderVersionTwo }

function EventProviderVersionTwo.TemplateT_StringWithInt(var EventDescriptor: EVENT_DESCRIPTOR; const StringValue : string; IntValue : Integer): Boolean;
var EventData : array[0..1] of EVENT_DATA_DESCRIPTOR;
begin
  Result := true;

  if IsEnabled(EventDescriptor.Level, EventDescriptor.Keyword) then begin
     EventDataDescCreateStr(EventData[0], StringValue);
     EventDataDescCreate   (EventData[1], @IntValue, sizeof(Integer));

     WriteEvent(EventDescriptor, EventData);
  end;
end;

function EventProviderVersionTwo.TemplateT_TwoInts(
  var EventDescriptor: EVENT_DESCRIPTOR; IntA, IntB: Integer): Boolean;
var EventData : array[0..1] of EVENT_DATA_DESCRIPTOR;
begin
  Result := true;

  if IsEnabled(EventDescriptor.Level, EventDescriptor.Keyword) then begin
     EventDataDescCreate(EventData[0], @IntA, sizeof(Integer));
     EventDataDescCreate(EventData[1], @IntB, sizeof(Integer));

     WriteEvent(EventDescriptor, EventData);
  end;

end;

end.
