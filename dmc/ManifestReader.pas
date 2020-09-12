unit ManifestReader;

interface

uses
  System.Classes,
  System.Generics.Collections,
  System.SysUtils,
  System.Variants,
  XML.XMLDoc,
  XML.XMLIntf,

  XmlHelper;


type
TEventProvider = class;

TInstrumentation = class
  private
    FEvents   : TList<TEventProvider>;
    FCounters : TList<TObject>;

    procedure Clear;
  public
    constructor Create;
    destructor  Destroy; override;

    property Events   : TList<TEventProvider> read FEvents;
    property Counters : TList<TObject> read FCounters;
end;


TOpcode = record
  public
    FName   : String;
    FSymbol : String;
    FValue  : UInt8;
    // mofValue, message
end;

TLevel = record
  public
    FName   : String;
    FSymbol : String;
    FValue  : UInt8;
    // message
end;

TKeyword = record
  public
    FName   : String;
    FSymbol : String;
    FMask   : UInt64;
    // message
end;

TChannel = record
  public
    FName    : String;
    FSymbol  : String;
    FChID    : String;
    FType    : String;
end;

// TODO
//TFilter = record
//  private
//    FName   : String;
//    FSymbol : String;
//    FValue   : UInt8;
//    FVersion : UInt8; // optional
//    // message, tid...
//end;

TTask = record
  public
    FName      : String;
    FSymbol    : String;  // optional
    FValue     : UInt16;
    // FEventGUID : TGUID;   // optional
    // message
end;

// TODO
//TMapping = record
//  private
//    FValue   : UInt32;
//    FSymbol  : String;
//    FMessage : String;
//end;
//
//TMapType = (tmtEnum, tmtBitmask);
//
//TMap = record
//  private
//    FType     : TMapType;
//    FMappings : array of TMapping;
//end;

TTemplateData = record
  public
    FName    : String; // Vista+: optional
    FInType  : String;
    FOutType : String; // Vista+: optional and ignored
    FMap     : String; // optional

    FLength   : UInt16; // optional
    FCount    : UInt16; // optional

    FLengthRef : String;  // optional; used if variable sized array; Ref points to other template member
    FCountRef  : String;  // optional; same as FLengthRef

    FTags     : UInt32; // optional
end;

TTemplate = class
  public
    FTid  : String;
    FName : String;  // optional
//    FTags : UInt32;  // optional

    FData : TList<TTemplateData>;
    // Struct, binary, UserData

  public
    constructor Create;
    destructor  Destroy; override;

    function IsPlainString : boolean;
end;

TEventDefinition = record
  public
    FEventID  : UInt32; // xml: value
    FName     : String; // optional
    FLevel    : String; // optional
    FTemplate : String; // optional
    FChannel  : String; // optiomal
    FKeywords : String; // optional; A space-separated list of keyword names
    FTask     : String; // optional
    FOpcode   : String; // optional
    FSymbol   : String; // optional
    FVersion  : UInt8;  // optional

    // attributes, message, notLogged, suppressProjection

    function DelphiSymbol : string;
end;


TEventProvider = class
  public
    FName      : String;
    FGUID      : TGUID;
    FSymbol    : String;
    FResFile   : String;
    FMsgFile   : String;
    FParamFile : String;
    // namespace

    FChannels  : TList<TChannel>;
    FLevels    : TList<TLevel>;
    FTasks     : TList<TTask>;
    FOpcodes   : TList<TOpcode>;
    FKeywords  : TList<TKeyword>;
//    FMaps      : TList<TObject>;
    FTemplates : TList<TTemplate>;
    FEvents    : TList<TEventDefinition>;
    // namedQueries, filters, traits

  public
    constructor Create;
    destructor  Destroy; override;

    function DelphiSymbol : string;
end;


type TManifestReader = class
  private
    FInstrumentation : TInstrumentation;
    // FLocalization

    procedure ProcessInstrumentation(Node : IXMLNode);
  public
    constructor Create;
    destructor  Destroy; override;

    procedure LoadFromFile(const ManifestFilename : string);

    property Instrumentation : TInstrumentation read FInstrumentation;
end;

implementation

{ TManifestReader }

constructor TManifestReader.Create;
begin
  FInstrumentation := TInstrumentation.Create;
end;

destructor TManifestReader.Destroy;
begin
  FreeAndNil(FInstrumentation);

  inherited;
end;

procedure TManifestReader.LoadFromFile(const ManifestFilename : string);
begin
  FInstrumentation.Clear;

  var XML := LoadXMLDocument(ManifestFilename);

  var manifest := XML.DocumentElement;

  var instrumentation := manifest.ChildNodes.FindNode('instrumentation');
  var localization    := manifest.ChildNodes.FindNode('localization');

  ProcessInstrumentation(instrumentation);
end;

procedure TManifestReader.ProcessInstrumentation(Node: IXMLNode);
  function _HexStrToUInt64(const str : string) : UInt64;
  begin
    Result := StrToUInt64(str.Replace('0x', '$'));
  end;

  procedure _ProccessOpcodes(provider : TEventProvider; xOpcodes : IXMLNode);
  begin
    for var xOpcode in XMLEnumChildNodes(xOpcodes) do begin
      if xOpcode.LocalName <> 'opcode' then continue;

      var op := Default(TOpcode);
      op.FName   := XMLStringAttr(xOpcode, 'name');
      op.FSymbol := XMLStringAttr(xOpcode, 'symbol', true);
      op.FValue  := StrToInt(XMLStringAttr(xOpcode, 'value'));
      // mofValue, message

      provider.FOpcodes.Add(op);
    end;
  end;

begin
  if Node = nil then exit;

  var xEvents := Node.ChildNodes.FindNode('events');

  if (xEvents = nil) or (not xEvents.HasChildNodes) then exit;

  for var xProvider in XMLEnumChildNodes(xEvents) do begin
    if xProvider.LocalName <> 'provider' then continue;

    var provider := TEventProvider.Create;
    FInstrumentation.FEvents.Add(provider);
    provider.FName   := XMLStringAttr(xProvider, 'name');
    provider.FGUID   := StringToGUID(XMLStringAttr(xProvider, 'guid'));
    provider.FSymbol := XMLStringAttr(xProvider, 'symbol');

    provider.FResFile   := XMLStringAttr(xProvider, 'resourceFileName', true);
    provider.FMsgFile   := XMLStringAttr(xProvider, 'messageFileName', true);
    provider.FParamFile := XMLStringAttr(xProvider, 'parameterFileName', true);
    // helplink, message, source, warnOnApplicationCompatibilityError

    // <levels>
    for var xLevel in XMLEnumChildNodes(xProvider.ChildNodes.FindNode('levels')) do begin
      if xLevel.LocalName <> 'level' then continue;

      var lvl := Default(TLevel);
      lvl.FName   := XMLStringAttr(xLevel, 'name');
      lvl.FSymbol := XMLStringAttr(xLevel, 'symbol', true);
      lvl.FValue  := StrToInt(XMLStringAttr(xLevel, 'value'));
      // message

      provider.FLevels.Add(lvl);
    end;

    // <keywords>
    for var xKeyword in XMLEnumChildNodes(xProvider.ChildNodes.FindNode('keywords')) do begin
      if xKeyword.LocalName <> 'keyword' then continue;

      var kw := Default(TKeyword);
      kw.FName   := XMLStringAttr(xKeyword, 'name');
      kw.FSymbol := XMLStringAttr(xKeyword, 'symbol', true);
      kw.FMask   := _HexStrToUInt64(XMLStringAttr(xKeyword, 'mask'));

      provider.FKeywords.Add(kw);
    end;

    // <opcodes>
    _ProccessOpcodes(provider, xProvider.ChildNodes.FindNode('opcodes'));

    // <tasks>
    for var xTask in XMLEnumChildNodes(xProvider.ChildNodes.FindNode('tasks')) do begin
      if xTask.LocalName <> 'task' then continue;

      var task := Default(TTask);
      task.FName   := XMLStringAttr(xTask, 'name');
      task.FSymbol := XMLStringAttr(xTask, 'symbol', true);
      task.FValue  := StrToInt(XMLStringAttr(xTask, 'value'));

      // <opcodes>
      _ProccessOpcodes(provider, xTask.ChildNodes.FindNode('opcodes'));

      provider.FTasks.Add(task);
    end;

    // <channels>
    for var xChannel in XMLEnumChildNodes(xProvider.ChildNodes.FindNode('channels')) do begin
      if xChannel.LocalName <> 'channel' then continue;

      var channel := Default(TChannel);
      channel.FName   := XMLStringAttr(xChannel, 'name');
      channel.FChID   := XMLStringAttr(xChannel, 'chid', true);
      channel.FSymbol := XMLStringAttr(xChannel, 'symbol', true);

      provider.FChannels.Add(channel);
    end;

    // <templates>
    for var xTemplate in XMLEnumChildNodes(xProvider.ChildNodes.FindNode('templates')) do begin
      if xTemplate.LocalName <> 'template' then continue;

      var template := TTemplate.Create;
      provider.FTemplates.Add(template);

      template.FTid  := XMLStringAttr(xTemplate, 'tid');
      template.FName := XMLStringAttr(xTemplate, 'name', true);

      for var xTempChild in XMLEnumChildNodes(xTemplate) do begin
        if xTempChild.LocalName = 'data' then begin
          var xData := xTempChild;
          var data  := Default(TTemplateData);

          data.FName    := XMLStringAttr(xData, 'name');
          data.FInType  := XMLStringAttr(xData, 'inType');
          data.FOutType := XMLStringAttr(xData, 'outType', true);
          data.FMap     := XMLStringAttr(xData, 'map', true);
          data.FTags    := StrToUInt(XMLStringAttr(xData, 'tags', true, '0'));

          var lengthAttr := XMLStringAttr(xData, 'length', true);
          var countAttr  := XMLStringAttr(xData, 'count', true);

          var lengthNum : UInt32 := 0;
          var countNum  : UInt32 := 0;

          if TryStrToUInt(lengthAttr, lengthNum)
          then data.FLength    := lengthNum
          else data.FLengthRef := lengthAttr;

          if TryStrToUInt(countAttr, countNum)
          then data.FCount    := countNum
          else data.FCountRef := countAttr;

          template.FData.Add(data);
        end;
        // binary, struct, UserData
      end;
    end;

    // <events>
    for var xEvent in XMLEnumChildNodes(xProvider.ChildNodes.FindNode('events')) do begin
      if xEvent.LocalName <> 'event' then continue;

      var ev := Default(TEventDefinition);

      ev.FEventID  := StrToUInt(XMLStringAttr(xEvent, 'value'));
      ev.FName     := XMLStringAttr(xEvent, 'name', true);
      ev.FLevel    := XMLStringAttr(xEvent, 'level', true);
      ev.FTemplate := XMLStringAttr(xEvent, 'template', true);
      ev.FChannel  := XMLStringAttr(xEvent, 'channel', true);
      ev.FKeywords := XMLStringAttr(xEvent, 'keywords', true);
      ev.FTask     := XMLStringAttr(xEvent, 'task', true);
      ev.FOpcode   := XMLStringAttr(xEvent, 'opcode', true);
      ev.FSymbol   := XMLStringAttr(xEvent, 'symbol', true);
      ev.FVersion  := StrToUInt(XMLStringAttr(xEvent, 'version', true));

      provider.FEvents.Add(ev);
    end;
  end;

end;

{ TInstrumentation }

constructor TInstrumentation.Create;
begin
  FEvents   := TObjectList<TEventProvider>.Create;
  FCounters := nil;
end;

destructor TInstrumentation.Destroy;
begin
  FreeAndNil(FEvents);
  FreeAndNil(FCounters);

  inherited;
end;

procedure TInstrumentation.Clear;
begin
  FEvents.Clear;
//  FCounters.Clear;
end;

{ TEventProvider }

constructor TEventProvider.Create;
begin
  FChannels  := TList<TChannel>.Create;
  FLevels    := TList<TLevel>.Create;
  FTasks     := TList<TTask>.Create;
  FOpcodes   := TList<TOpcode>.Create;
  FKeywords  := TList<TKeyword>.Create;
//  FMaps      := TObjectList<TObject>.Create;
  FTemplates := TObjectList<TTemplate>.Create;
  FEvents    := TList<TEventDefinition>.Create;
end;

destructor TEventProvider.Destroy;
begin
  FreeAndNil(FChannels );
  FreeAndNil(FLevels   );
  FreeAndNil(FTasks    );
  FreeAndNil(FOpcodes  );
  FreeAndNil(FKeywords );
//  FreeAndNil(FMaps     );
  FreeAndNil(FTemplates);
  FreeAndNil(FEvents   );

  inherited;
end;

function TEventProvider.DelphiSymbol: string;
begin
  // TODO Delphi safe identifier
  if FSymbol = ''
  then Result := FName
  else Result := FSymbol;
end;

{ TTemplate }

constructor TTemplate.Create;
begin
  FData := TList<TTemplateData>.Create;
end;

destructor TTemplate.Destroy;
begin
  FreeAndNil(FData);

  inherited;
end;

function TTemplate.IsPlainString: boolean;
begin
  Result := (FData.Count = 1) and (FData[0].FInType = 'win:UnicodeString');
end;

{ TEventDefinition }

function TEventDefinition.DelphiSymbol: string;
begin
  // TODO Delphi safe identifier
  if FSymbol = ''
  then Result := FName
  else Result := FSymbol;
end;

end.
