unit CodeGen;

interface

uses
  System.Classes,
  System.Generics.Collections,
  System.IOUtils,
  System.Math,
  System.SysUtils,

  ManifestReader;


// Value types for event metadata
// See enum TlgIn_t in TraceLoggingProvider.h  (WinSDK 10)
type TlgIn_t =
(
    TlgInNULL,
    TlgInUNICODESTRING,
    TlgInANSISTRING,
    TlgInINT8,
    TlgInUINT8,
    TlgInINT16,
    TlgInUINT16,
    TlgInINT32,
    TlgInUINT32,
    TlgInINT64,
    TlgInUINT64,
    TlgInFLOAT,
    TlgInDOUBLE,
    TlgInBOOL32,
    TlgInBINARY,
    TlgInGUID,
    _TlgInPOINTER_unsupported,
    TlgInFILETIME,
    TlgInSYSTEMTIME,
    TlgInSID,
    TlgInHEXINT32,
    TlgInHEXINT64,
    TlgInCOUNTEDSTRING,     // TDH_INTYPE_MANIFEST_COUNTEDSTRING
    TlgInCOUNTEDANSISTRING, // TDH_INTYPE_MANIFEST_COUNTEDANSISTRING
    _TlgInSTRUCT,           // TDH_INTYPE_RESERVED24
    TlgInCOUNTEDBINARY,     // TDH_INTYPE_MANIFEST_COUNTEDBINARY
    // New values go above this line, but _TlgInMax must not exceed 32.
    _TlgInMax,

    // These values depend on the bitness of the binary!!!
    TlgInINTPTR   = {$IFDEF CPU64BITS}TlgInINT64   {$ELSE}TlgInINT64   {$ENDIF},
    TlgInUINTPTR  = {$IFDEF CPU64BITS}TlgInUINT64  {$ELSE}TlgInUINT32  {$ENDIF},
    TlgInPOINTER  = {$IFDEF CPU64BITS}TlgInHEXINT64{$ELSE}TlgInHEXINT32{$ENDIF}
    {
    TlgInLONG    = sizeof(LONG)  == 8 ? TlgInINT64    : TlgInINT32,
    TlgInULONG   = sizeof(ULONG) == 8 ? TlgInUINT64   : TlgInUINT32,
    TlgInHEXLONG = sizeof(ULONG) == 8 ? TlgInHEXINT64 : TlgInHEXINT32,
    _TlgInCcount = 32, // Indicates that field metadata contains a const-array-count tag.
    TlgInVcount = 64,  // Indicates that field data contains variable-array-count tag.
    _TlgInChain = 128, // Indicates that field metadata contains a TlgOut tag.
    _TlgInCustom = TlgInVcount | _TlgInCcount, // Indicates that the field uses a custom serializer.
    _TlgInTypeMask = 31,
    _TlgInCountMask = TlgInVcount | _TlgInCcount,
    _TlgInFlagMask = _TlgInChain | TlgInVcount | _TlgInCcount
    }
);

type TEventParameters = record
  Id      : UInt16;
  Version : UInt8;
  Channel : UInt8;
  Level   : UInt8;
  Task    : UInt16;
  Opcode  : UInt8;
  Keyword : UInt64;
end;

type TCodeGenOptions = record
  InputFileName    : String;
  OutputFileName   : String;
  ResourceFileName : String;

  UnitName         : String;

  UseTraceLogging  : Boolean;
end;

type TCodeGen = class
  const IndentLookup : array  [0..3] of string = ('', '  ', '    ', '      ');
  private
    FReader    : TManifestReader;
    FOptions   : TCodeGenOptions;

    FBuffer    : TStringBuilder;
    FHints     : TStringList;
    FWarnings  : TStringList;
    FErrors    : TStringList;
    FTemplates : TDictionary<string,TTemplate>;

    procedure EmitLn(      Indent : Integer = 0;
                     const Value  : string = ''); overload;
    procedure EmitLn(      Indent : Integer;
                     const Format : string;
                     const Args   : array of const); overload;

    procedure LogHint   (const AFormat : string;
                         const Args    : array of const);

    procedure LogWarning(const AFormat : string;
                         const Args    : array of const);

    procedure LogError  (const AFormat : string;
                         const Args    : array of const);

    function MetadataTypeFromInType(const InType : String) : TlgIn_t;

    function ConstRequired       (const InType : String) : Boolean;
    function DelphiTypeFromInType(const InType : String) : String;
    function GetTemplate         (const Name   : String) : TTemplate;

    function LookupEvent         (Provider : TEventProvider;
                                  Event    : TEventDefinition) : TEventParameters;

    function  GenTemplateParameterList    (Template : TTemplate; IsCall : Boolean) : String;

    procedure GenProviderInterface     (Provider : TEventProvider);
    procedure GenProviderImplementation(Provider : TEventProvider);

    procedure GenInterface;
    procedure GenImplementation;

    procedure Reset;

  public

  constructor Create(Options : TCodeGenOptions);
  destructor  Destroy; override;

  function  Generate : string;
  procedure GenerateCodeFile;

  property Hints    : TStringList read FHints;
  property Warnings : TStringList read FWarnings;
  property Errors   : TStringList read FErrors;

end;

implementation

{ TCodeGen }

constructor TCodeGen.Create(Options : TCodeGenOptions);
begin
  FOptions   := Options;

  FReader    := TManifestReader.Create;
  FBuffer    := TStringBuilder.Create;
  FHints     := TStringList.Create;
  FWarnings  := TStringList.Create;
  FErrors    := TStringList.Create;
  FTemplates := TDictionary<string,TTemplate>.Create;
end;


destructor TCodeGen.Destroy;
begin
  FreeAndNil(FReader);
  FreeAndNil(FBuffer);
  FreeAndNil(FHints);
  FreeAndNil(FWarnings);
  FreeAndNil(FErrors);
  FreeAndNil(FTemplates);

  inherited;
end;


procedure TCodeGen.Reset;
begin
  FBuffer.Clear;
  FHints.Clear;
  FWarnings.Clear;
  FErrors.Clear;
  FTemplates.Clear;
end;


procedure TCodeGen.EmitLn(Indent : Integer; const Value: string);
begin
  FBuffer.Append(IndentLookup[Indent]).AppendLine(Value);
end;


procedure TCodeGen.EmitLn(Indent : Integer; const Format: string; const Args: array of const);
begin
  FBuffer.Append(IndentLookup[Indent]).AppendFormat(Format, Args).AppendLine;
end;


procedure TCodeGen.LogHint(const AFormat : string; const Args : array of const);
begin
  FHints.Add(Format(AFormat, Args));
end;


procedure TCodeGen.LogWarning(const AFormat : string; const Args : array of const);
begin
  FWarnings.Add(Format(AFormat, Args));
end;


procedure TCodeGen.LogError(const AFormat: string; const Args: array of const);
begin
  FErrors.Add(Format(AFormat, Args));
end;



function TCodeGen.ConstRequired(const InType: String): Boolean;
begin
  if InType = 'win:AnsiString' then exit(true);
  if InType = 'win:UnicodeString' then exit(true);

  Result := false;
end;


function TCodeGen.DelphiTypeFromInType(const InType: String): String;
begin
  assert(InType<>'', 'Empty InType');

  if InType = 'win:AnsiString'    then exit('AnsiString');
  if InType = 'win:UnicodeString' then exit('UnicodeString');
  if InType = 'win:Int8'          then exit('Int8');
  if InType = 'win:UInt8'         then exit('UInt8');
  if InType = 'win:Int16'         then exit('Int16');
  if InType = 'win:UInt16'        then exit('UInt16');
  if InType = 'win:Int32'         then exit('Int32');
  if InType = 'win:UInt32'        then exit('UInt32');
  if InType = 'win:Int64'         then exit('Int64');
  if InType = 'win:UInt64'        then exit('UInt64');
  if InType = 'win:HexInt32'      then exit('Int32');
  if InType = 'win:HexInt64'      then exit('Int64');
  if InType = 'win:Float'         then exit('Single');
  if InType = 'win:Double'        then exit('Double');
  if InType = 'win:Boolean'       then exit('LongBool');
  if InType = 'win:Pointer'       then exit('Pointer');

  // untested
  if InType = 'win:GUID'          then exit('TGUID');
  if InType = 'win:SID'           then exit('PSID');
  if InType = 'win:FILETIME'      then exit('TFileTime');
  if InType = 'win:SYSTEMTIME'    then exit('TSystemTime');
  if InType = 'win:Binary'        then exit('PByte');

  assert(false, Format('Unkown inType="%s"', [InType]));
end;


function TCodeGen.MetadataTypeFromInType(const InType: String): TlgIn_t;
begin
  assert(InType<>'', 'Empty InType');

  if InType = 'win:AnsiString'    then exit(TlgInANSISTRING);
  if InType = 'win:UnicodeString' then exit(TlgInUNICODESTRING);
  if InType = 'win:Int8'          then exit(TlgInINT8);
  if InType = 'win:UInt8'         then exit(TlgInUINT8);
  if InType = 'win:Int16'         then exit(TlgInINT16);
  if InType = 'win:UInt16'        then exit(TlgInUINT16);
  if InType = 'win:Int32'         then exit(TlgInINT32);
  if InType = 'win:UInt32'        then exit(TlgInUINT32);
  if InType = 'win:Int64'         then exit(TlgInINT64);
  if InType = 'win:UInt64'        then exit(TlgInUINT64);
  if InType = 'win:HexInt32'      then exit(TlgInHEXINT32);
  if InType = 'win:HexInt64'      then exit(TlgInHEXINT64);
  if InType = 'win:Float'         then exit(TlgInFLOAT);
  if InType = 'win:Double'        then exit(TlgInDOUBLE);
  if InType = 'win:Boolean'       then exit(TlgInBOOL32);
  if InType = 'win:Pointer'       then exit(TlgInPOINTER);

  // untested
  if InType = 'win:GUID'          then exit(TlgInGUID);
  if InType = 'win:SID'           then exit(TlgInSID);
  if InType = 'win:FILETIME'      then exit(TlgInFILETIME);
  if InType = 'win:SYSTEMTIME'    then exit(TlgInSYSTEMTIME);
  if InType = 'win:Binary'        then exit(TlgInBINARY);

  assert(false, Format('Unkown inType="%s"', [InType]));
  Result := TlgInNULL;
end;


function TCodeGen.LookupEvent(Provider : TEventProvider; Event: TEventDefinition): TEventParameters;

  function _LookupChannel(var ResultChannel : Byte) : boolean;
  begin
    Result := false;

    var index := 10;  // custom channels seem to start at 10
    for var chan in Provider.FChannels do begin
      if (chan.FChID <> '') and (chan.FChID = Event.FChannel)
       or (chan.FChID = '') and (chan.FName = Event.FChannel) then begin
        ResultChannel := index;
        exit(true);
      end;

      Inc(Index);
    end;
  end;


  function _LookupLevel(var ResultLevel : UInt8) : boolean;
  begin
    Result := false;
    for var lvl in Provider.FLevels do begin
      if lvl.FName = Event.FLevel then begin
        ResultLevel := lvl.FValue;
        exit(true);
      end;
    end;
  end;

  function _LookupTask(var ResultTask : UInt16) : boolean;
  begin
    Result := false;
    for var task in Provider.FTasks do begin
      if task.FName = Event.FTask then begin
        ResultTask := task.FValue;
        exit(true);
      end;
    end;
  end;

  function _LookupOpcode(var ResultOpcode : UInt8) : boolean;
  begin
    Result := false;
    for var Opcode in Provider.FOpcodes do begin
      if Opcode.FName = Event.FOpcode then begin
        ResultOpcode := Opcode.FValue;
        exit(true);
      end;
    end;
  end;

  function _LookupKeyword(const EventKeyword : string; var ResultKeyword : UInt64) : boolean;
  begin
    Result := false;
    for var Keyword in Provider.FKeywords do begin
      if Keyword.FName = EventKeyword then begin
        ResultKeyword := ResultKeyword or Keyword.FMask;
        exit(true);
      end;
    end;
  end;

begin
  // see winmeta.xml in Windows 10 SDK

  Result := Default(TEventParameters);
  Result.Id      := Event.FEventID;
  Result.Version := Event.FVersion;

  // Channel
  if Event.FChannel <> '' then begin
         if Event.FChannel = 'TraceClassic' then Result.Channel := 0
    else if Event.FChannel = 'System'       then Result.Channel := 8
    else if Event.FChannel = 'Application'  then Result.Channel := 9
    else if Event.FChannel = 'Security'     then Result.Channel := 10
    else if Event.FChannel = 'TraceLogging' then Result.Channel := 11
    else if not _LookupChannel(Result.Channel) then begin
      LogWarning('Channel "%s" not found', [Event.FChannel]);
    end;
  end;

  // Level
  if Event.FLevel <> '' then begin
         if Event.FLevel = 'win:LogAlways'     then Result.Level := 0
    else if Event.FLevel = 'win:Critical'      then Result.Level := 1
    else if Event.FLevel = 'win:Error'         then Result.Level := 2
    else if Event.FLevel = 'win:Warning'       then Result.Level := 3
    else if Event.FLevel = 'win:Informational' then Result.Level := 4
    else if Event.FLevel = 'win:Verbose'       then Result.Level := 5
    // win:ReservedLevel[6-15] are reserved for future use
    else if not _LookupLevel(Result.Level) then begin
      LogWarning('Level "%s" not found', [Event.FLevel]);
    end;
  end;

  // Task
  if Event.FTask <> '' then begin
    if Event.FTask = 'win:None' then begin
      Result.Task := 0
    end
    else if not _LookupTask(Result.Task) then begin
      LogWarning('Task "%s" not found', [Event.FTask]);
    end;
  end;

  // Opcode
  if Event.FOpcode <> '' then begin
         if Event.FOpcode = 'win:Info'      then Result.Opcode := 0
    else if Event.FOpcode = 'win:Start'     then Result.Opcode := 1
    else if Event.FOpcode = 'win:Stop'      then Result.Opcode := 2
    else if Event.FOpcode = 'win:DC_Start'  then Result.Opcode := 3
    else if Event.FOpcode = 'win:DC_Stop'   then Result.Opcode := 4
    else if Event.FOpcode = 'win:Extension' then Result.Opcode := 5
    else if Event.FOpcode = 'win:Reply'     then Result.Opcode := 6
    else if Event.FOpcode = 'win:Resume'    then Result.Opcode := 7
    else if Event.FOpcode = 'win:Suspend'   then Result.Opcode := 8
    else if Event.FOpcode = 'win:Send'      then Result.Opcode := 9
    else if Event.FOpcode = 'win:Receive'   then Result.Opcode := 240
    // win:ReservedOpcode[241-255] are reserved for future use
    else if not _LookupOpcode(Result.Opcode) then begin
      LogWarning('Opcode "%s" not found', [Event.FOpcode]);
    end;
  end;


  // Keywords
  if Event.FKeywords <> '' then begin
    for var item in Event.FKeywords.Split([' ']) do begin
      var keyword := Trim(item);

      if keyword = '' then continue;

           if keyword = 'win:AnyKeyword'        then Result.Keyword := Result.Keyword or $0
      else if keyword = 'win:ResponseTime'      then Result.Keyword := Result.Keyword or $01000000000000
    //else if keyword = 'win:ReservedKeyword49' then Result.Keyword := Result.Keyword or $02000000000000
      else if keyword = 'win:WDIDiag'           then Result.Keyword := Result.Keyword or $04000000000000
      else if keyword = 'win:SQM'               then Result.Keyword := Result.Keyword or $08000000000000
      else if keyword = 'win:AuditFailure'      then Result.Keyword := Result.Keyword or $10000000000000
      else if keyword = 'win:AuditSuccess'      then Result.Keyword := Result.Keyword or $20000000000000
      else if keyword = 'win:CorrelationHint'   then Result.Keyword := Result.Keyword or $40000000000000
      else if keyword = 'win:EventlogClassic'   then Result.Keyword := Result.Keyword or $80000000000000
      // win:ReservedKeyword[49, 56-63] are reserved for future use
      else if not _LookupKeyword(keyword, Result.Keyword) then begin
        LogWarning('Keyword "%s" not found', [keyword]);
      end;
    end;
  end;
end;


procedure TCodeGen.GenerateCodeFile;
begin
  var codeStr := Generate;

  if codeStr <> '' then begin
    TFile.WriteAllText(FOptions.OutputFileName, codeStr, TEncoding.UTF8);
  end;
end;


function TCodeGen.Generate : string;
begin
  Reset;

  try
    FReader.LoadFromFile(FOptions.InputFileName);
  except
    on E : Exception do begin
      LogError('Failed to read manifest XML with error: %s', [E.ToString]);
      exit('');
    end;
  end;

  // Preprocess templates
  for var evProvider in FReader.Instrumentation.Events do begin
    for var template in evProvider.FTemplates do begin
      if template.FData.Count = 0 then begin
        LogHint('Skipping empty template: "%s"', [template.FTid]);
        continue;
      end;

      if not FTemplates.ContainsKey(template.FTid) then begin
        FTemplates.Add(template.FTid, template);
      end
      else begin
        LogWarning('Template "%s" redefined. Redefinition will be ignored.', [template.FTid]);
      end;
    end;
  end;

  EmitLn(0, 'unit %s;', [FOptions.UnitName]);
  EmitLn;
  EmitLn(0, 'interface');
  EmitLn;
  EmitLn(0, 'uses');
  EmitLn(0, '  Winapi.Windows,');
  EmitLn(0, '  System.Classes,');
  EmitLn(0, '  System.SysUtils,');
  EmitLn(0, '  EventProvider,');
  EmitLn(0, '  WinApi.Evntprov;'); // MfPack dependency
  EmitLn;
  GenInterface;
  EmitLn;
  EmitLn(0, 'implementation');
  EmitLn;
  if FOptions.ResourceFileName <> '' then begin
    var filename := ExtractFileName(FOptions.ResourceFileName);
    filename     := ChangeFileExt(filename, '.res');
    // {$R 'TestProvider.g.res' 'Manifest\out\TestProvider.g.rc'}
    EmitLn(0, '{$R %s %s}', [QuotedStr(filename), QuotedStr(FOptions.ResourceFileName)]);
    EmitLn;
  end;
  GenImplementation;
  EmitLn;
  EmitLn(0, 'end.');

  Result := FBuffer.ToString;
end;


procedure TCodeGen.GenImplementation;
begin
  EmitLn(0, 'procedure _UnusedParam(var x : Integer); inline;');
  EmitLn(0, 'begin');
  EmitLn(0, '  // Used to suppres H2164: "Variable %s is declared but never used in %s."');
  EmitLn(0, '  // This will produce an additonal xor eax,eax and a mov on the callee site... should be okay.');
  EmitLn(0, '  x := 0;');
  EmitLn(0, 'end;');
  EmitLn;

//  GenInternalProviderImplementation;

  for var provider in FReader.Instrumentation.Events do begin
    GenProviderImplementation(provider);
  end;
end;


procedure TCodeGen.GenInterface;
begin
//  GenInternalProviderInterface;

  for var provider in FReader.Instrumentation.Events do begin
    GenProviderInterface(provider);
  end;
end;


function TCodeGen.GenTemplateParameterList(Template: TTemplate; IsCall : Boolean): String;
begin
  if Template = nil then exit('');

  var sb := TStringBuilder.Create;

  for var data in template.FData do begin
    if IsCall then begin
      // Parameter for function call
      sb.Append(data.FName).Append(', ');
    end
    else begin
      // Parameter definition
      if ConstRequired(data.FInType)
      then sb.Append('const ');

      sb.AppendFormat('%s : %s; ', [data.FName, DelphiTypeFromInType(data.FInType)]);
    end;
  end;

  sb.Remove(sb.Length-2, 2); // remove last ', ' or '; '

  Result := sb.ToString;
  FreeAndNil(sb);
end;


function TCodeGen.GetTemplate(const Name: String): TTemplate;
begin
  if not FTemplates.TryGetValue(Name, Result) then begin
    Result := nil;
  end;
end;


procedure TCodeGen.GenProviderInterface(Provider: TEventProvider);
begin
// type TDelphiTestProvider = class
//   protected
//     Provider      : EventProviderVersionTwo;
//
//     RandomTestEvent : EVENT_DESCRIPTOR;
//     TwoIntsEvent    : EVENT_DESCRIPTOR;
//   public
//     constructor Create;
//     destructor  Destroy; override;
//
//     function EventWriteRandomTestEvent(const StringValue : string; IntValue : Integer) : boolean;
//     function EventWriteTwoIntsEvent   (IntA, IntB : Integer) : boolean;
// end;

  EmitLn(0, 'type T%s = class(TEventProvider)', [Provider.DelphiSymbol]);

  if FOptions.UseTraceLogging then begin
    var ProviderName       := AnsiString(Provider.FName);
    var ProviderNameLength := Length(ProviderName);

    EmitLn(1, 'private');
    EmitLn(2, 'type TProviderNameTrait = packed record');
    EmitLn(3,   'Len  : UInt16;');
    EmitLn(3,   'Name : array[1..%d+1] of AnsiChar;', [ProviderNameLength]);
    EmitLn(2, 'end;');
    EmitLn;
    EmitLn(2, 'const CProviderNameTrait : TProviderNameTrait = (Len:Sizeof(TProviderNameTrait); Name:''%s''+#0);', [ProviderName]);
    EmitLn;
  end;

  EmitLn(1, 'protected');
  for var event in Provider.FEvents do begin
    EmitLn(2, '%s : EVENT_DESCRIPTOR;', [event.DelphiSymbol]);
  end;
  EmitLn;
  EmitLn(1, 'public');
  EmitLn(2, 'constructor Create;');
  EmitLn;
  for var event in Provider.FEvents do begin
    var parList := GenTemplateParameterList(GetTemplate(event.FTemplate), false);
    EmitLn(2, 'function EventWrite%s(%s) : boolean;', [event.DelphiSymbol, parList]);
  end;
  EmitLn(0, 'end;');
  EmitLn;
end;


procedure TCodeGen.GenProviderImplementation(Provider: TEventProvider);
begin
// { TDelphiTestProvider }
//
// constructor TDelphiTestProvider.Create;
// begin
//   Provider := EventProviderVersionTwo.Create(StringToGUID('{83ee142c-99df-496e-a92b-6fa432157fbd}'));
//
//   EventDescCreate(RandomTestEvent, $1, $0, $0, $4, $1, $a, $0);
//   EventDescCreate(TwoIntsEvent   , $2, $0, $0, $0, $0, $0, $0);
// end;
//

  var typeName := 'T' + Provider.DelphiSymbol;

  EmitLn(0, '{ %s }', [typeName]);
  EmitLn;
  EmitLn(0, 'constructor %s.Create;', [typeName]);
  EmitLn(0, 'begin');
  EmitLn(1, 'inherited Create(StringToGUID(''%s''));', [provider.FGUID.ToString]);
  EmitLn;
  for var event in provider.FEvents do begin
    var p  := LookupEvent(provider, event);
    var ch := IfThen(FOptions.UseTraceLogging, 11, p.Channel);  // manifest-free events are always on channel 11

    EmitLn(1, 'EventDescCreate(%s, %d, %d, %d, %d, %d, %d, %d);',
             [event.DelphiSymbol, p.Id, p.Version, ch, p.Level, p.Task, p.Opcode, p.Keyword]);
  end;
  EmitLn(0, 'end;');
  EmitLn;

// function TDelphiTestProvider.EventWriteRandomTestEvent(const StringValue : string; IntValue : Integer) : boolean;
// var _stack_alignment_ : Integer; // EventData needs to be dword-aligned
// var EventData : array[0..1] of EVENT_DATA_DESCRIPTOR;
// begin
//   _UnusedParam(_stack_alignment_);
//   Result := true;
//   if IsEnabled(EventDescriptor.Level, EventDescriptor.Keyword) then begin
//     EventDataDescCreateStr(EventData[0], StringValue);
//     EventDataDescCreate   (EventData[1], @IntValue, sizeof(Integer));
//
//     WriteEvent(EventDescriptor, EventData);
//   end;
// end;

  for var event in Provider.FEvents do begin
    var template      := GetTemplate(event.FTemplate);
    var parListDef    := GenTemplateParameterList(template, false);
    var parListCall   := GenTemplateParameterList(template, true);
    var emptyEvent    := (template = nil) or (template.FData.Count = 0);
    var plainStrEvent := (not emptyEvent) and template.IsPlainString;
    var templateEvent := (not emptyEvent) and (not plainStrEvent);
    var dataCount     := 0;


    if templateEvent then begin
      dataCount := template.FData.Count;

      if FOptions.UseTraceLogging then begin
        dataCount := dataCount + 2; // + provider name + metadata traits
      end;
    end;

    EmitLn(0, 'function %s.EventWrite%s(%s) : boolean;', [typeName, event.DelphiSymbol, parListDef]);
    if templateEvent then begin
      EmitLn(0, 'var _stack_alignment_ : Integer; // EventData needs to be dword-aligned');
      EmitLn(0, 'var EventData : array[0..%d] of EVENT_DATA_DESCRIPTOR;', [dataCount-1]);

      // Generate MetaData BLOB
      if FOptions.UseTraceLogging then begin
        //  type TEventMeta = packed record
        //    Len : UInt16;
        //    Tag : Byte; // always zero
        //    EN  : array[1..4+1] of AnsiChar;
        //
        //    N1  : array[1..8+1] of AnsiChar;
        //    T1  : Byte;
        //    N2  : array[1..7+1] of AnsiChar;
        //    T2  : Byte;
        //  end;
        //
        //  const MetaData : TEventMeta = (Len: sizeof(TEventMeta); Tag:0; N0:'Test'+#0; N1:'IntValue'+#0; T1:7; N2:'Astring'+#0; T2:2);


        // Metadata Definition
        EmitLn;
        EmitLn(0, 'type TEventMeta = packed record');
        // Header
        EmitLn(1, 'Len : UInt16;'); // total length
        EmitLn(1, 'Tag : Byte;'  ); // always zero
        // Event name
        EmitLn(1, 'EN  : array[1..%d+1] of AnsiChar;', [Length(event.FSymbol)]);

        // Event fields
        for var i := 0 to template.FData.Count-1 do begin
          EmitLn(1, 'N%d  : array[1..%d+1] of AnsiChar;', [i, Length(template.FData[i].FName)]);
          EmitLn(1, 'T%d  : Byte;', [i]);
        end;
        EmitLn(0, 'end;');
        EmitLn;

        // Metadata
        EmitLn(0, 'const MetaData : TEventMeta = (Len: sizeof(TEventMeta); Tag:0; EN:%s+#0;', [QuotedStr(event.FSymbol)]);
        for var i := 0 to template.FData.Count-1 do begin
          var data := template.FData[i];
          var dataType := MetadataTypeFromInType(data.FInType);
          var dataTypeStr : string;

          // Pointer type depends on bitness of the binary
          if dataType = TlgInPOINTER then begin
            dataTypeStr := Format('{$IFDEF CPU64BITS}%d{$ELSE}%d{$ENDIF}', [Ord(TlgInHEXINT64), Ord(TlgInHEXINT32)]);
          end
          else begin
            dataTypeStr := Ord(dataType).ToString;
          end;

          EmitLn(1, 'N%d:%s+#0; T%d:%s;', [i, QuotedStr(data.FName), i, dataTypeStr]);
        end;
        EmitLn(0, ');');
        EmitLn;
      end;
    end;

    EmitLn(0, 'begin');
    if templateEvent then begin
      EmitLn(1, '_UnusedParam(_stack_alignment_);');
    end;
    EmitLn(1, 'Result := true;');
    EmitLn(1, 'if IsEnabled(%s.Level, %s.Keyword) then begin', [event.DelphiSymbol, event.DelphiSymbol]);
    if emptyEvent then begin
      // empty event
      EmitLn(2, 'Result := WriteEvent(@%s);', [event.DelphiSymbol]);
    end
    else if plainStrEvent then begin
      EmitLn(2, 'Result := WriteMessageEvent(Value, %s.Level, %s.Keyword);', [event.DelphiSymbol, event.DelphiSymbol]);
    end
    else begin
      // templated event
      var idx := 0;

      // 0) Event metadata (TraceLogging)
      if FOptions.UseTraceLogging then begin
        // Include provider name trait
        EmitLn(2, 'EventDataDescCreate(EventData[0], @CProviderNameTrait, SizeOf(CProviderNameTrait));');
        EmitLn(2, 'EventData[0].DUMMYSTRUCTNAME._Type := EVENT_DATA_DESCRIPTOR_TYPE_PROVIDER_METADATA;');
        EmitLn;

        // Include event metadata for decoding (manifest-free provider)
        EmitLn(2, 'EventDataDescCreate(EventData[1], @MetaData, MetaData.Len);');
        EmitLn(2, 'EventData[1].DUMMYSTRUCTNAME._Type := EVENT_DATA_DESCRIPTOR_TYPE_EVENT_METADATA;');
        EmitLn;

        idx := 2;
      end;

      // 1) EventDataDesc
      for var data in template.FData do begin
        var pasType := Self.DelphiTypeFromInType(data.FInType);

        if data.FInType = 'win:UnicodeString' then begin
          EmitLn(2, 'EventDataDescCreateStr(EventData[%d], %s);', [idx, data.FName])
        end
        else if data.FInType = 'win:SID' then begin
          EmitLn(2, 'EventDataDescCreate   (EventData[%d], %s, GetLengthSid(%s));', [idx, data.FName, data.FName]);
        end
        else if data.FInType = 'win:Binary' then begin
          EmitLn(2, 'EventDataDescCreate   (EventData[%d], %s, 1);', [idx, data.FName]);
        end
        else begin
          EmitLn(2, 'EventDataDescCreate   (EventData[%d], @%s, sizeof(%s));', [idx, data.FName, pasType]);
        end;

        Inc(idx);
      end;

      // 2) WriteEvent
      EmitLn;
      EmitLn(2, 'WriteEvent(@%s, %d, Pointer(@EventData[0]));', [event.DelphiSymbol, dataCount]);
    end;


    EmitLn(1, 'end;');
    EmitLn(0, 'end;');
    EmitLn;
  end;
end;

end.
