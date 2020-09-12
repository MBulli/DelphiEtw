unit XmlHelper;

interface

uses
  System.SysUtils,
  System.Variants,
  XML.XMLDoc,
  XML.XMLIntf;


TYPE TXmlNodeListEnumerator = CLASS
    PRIVATE
      FNodeList : IXMLNodeList;
      FIndex    : INTEGER;

      CONSTRUCTOR Create(CONST NodeList : IXMLNodeList);

     PUBLIC
      FUNCTION  MoveNext   : Boolean;
      FUNCTION  GetCurrent : IXMLNode;
      PROCEDURE Reset;
      PROPERTY  Current    : IXMLNode READ GetCurrent;
  END;

TYPE TXmlNodeListEnumerable = RECORD
  PRIVATE
    FNodeList : IXMLNodeList;

  PUBLIC
    FUNCTION GetEnumerator: TXmlNodeListEnumerator;
END;

// Wrapper für FOR IN
FUNCTION  XMLEnumNodes     (CONST NodeList : IXMLNodeList) : TXmlNodeListEnumerable;
FUNCTION  XMLEnumChildNodes(CONST Parent   : IXMLNode    ) : TXmlNodeListEnumerable;

FUNCTION  XMLStringAttr(CONST Node       : IXMLNode;
                        CONST AttrName   : STRING;
                              IsOptional : Boolean = false;
                        CONST DefaultVal : STRING = '') : STRING;

implementation

FUNCTION XMLEnumNodes(CONST NodeList : IXMLNodeList) : TXmlNodeListEnumerable;

BEGIN  // of XMLEnumNodes
  Result := Default(TXmlNodeListEnumerable);
  Result.FNodeList := NodeList;
END;  // of XMLEnumNodes

FUNCTION XMLEnumChildNodes(CONST Parent : IXMLNode) : TXmlNodeListEnumerable;

BEGIN  // of XMLEnumChildNodes
  IF Parent = NIL
  THEN Result := Default(TXmlNodeListEnumerable)
  ELSE Result := XMLEnumNodes(Parent.ChildNodes);
END;   // of XMLEnumChildNodes

FUNCTION  XMLStringAttr(CONST Node       : IXMLNode;
                        CONST AttrName   : STRING;
                              IsOptional : Boolean = false;
                        CONST DefaultVal : STRING = '') : STRING;
BEGIN  // of XMLStringAttr
  IF IsOptional THEN BEGIN
    IF Node.HasAttribute(AttrName)
    THEN Result := VarToStr(Node.Attributes[AttrName])
    ELSE Result := DefaultVal;
  END
  ELSE BEGIN
    Result := VarToStr(Node.Attributes[AttrName]);
  END;
END;   // of XMLStringAttr

{ TXmlNodeListEnumerator }

CONSTRUCTOR TXmlNodeListEnumerator.Create(const NodeList: IXMLNodeList);
BEGIN
  FNodeList := NodeList;
  FIndex    := -1;
END;

FUNCTION TXmlNodeListEnumerator.GetCurrent: IXMLNode;
BEGIN
  Result := FNodeList[FIndex];
END;

FUNCTION TXmlNodeListEnumerator.MoveNext: Boolean;
BEGIN
  Inc(FIndex);

  Result := (FNodeList <> nil) and (FIndex <  FNodeList.Count);
END;

PROCEDURE TXmlNodeListEnumerator.Reset;
BEGIN
  FIndex := -1;
END;

{ TXmlNodeListEnumerable }

FUNCTION TXmlNodeListEnumerable.GetEnumerator: TXmlNodeListEnumerator;
BEGIN
  Result := TXmlNodeListEnumerator.Create(FNodeList);
END;


end.
