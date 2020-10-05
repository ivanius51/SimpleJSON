//------¬ --¬   --¬    --¬--¬   --¬ -----¬ ---¬   --¬--¬--¬   --¬-------¬-------¬ --¬
//--ã==--¬L--¬ --ã-    --¦--¦   --¦--ã==--¬----¬  --¦--¦--¦   --¦--ã====---ã====----¦
//------ã- L----ã-     --¦--¦   --¦-------¦--ã--¬ --¦--¦--¦   --¦-------¬-------¬L--¦
//--ã==--¬  L--ã-      --¦L--¬ --ã---ã==--¦--¦L--¬--¦--¦--¦   --¦L====--¦L====--¦ --¦
//------ã-   --¦       --¦ L----ã- --¦  --¦--¦ L----¦--¦L------ã--------¦-------¦ --¦
//L=====-    L=-       L=-  L===-  L=-  L=-L=-  L===-L=- L=====- L======-L======- L=-
//Script by Ivanius51 - http://GetScript.net          

unit JSON;

interface

uses 
  SysUtils
  , Classes
  ;

Type
  TJSONtype = (jsNull = 0, jsBool, jsInt, jsFloat, jsString, jsArray, jsObject);

  TJSONObject = Class
    Protected
      FType:TJSONtype;
      FKey:String;
      FValue:String;
      FChildsList:TStringList;
      FIsSimple : boolean;

      function GetIsNull: Boolean;
      function GetAsBool: Boolean;
      function GetAsInt: Integer;
      function GetAsDouble: Double;
      function GetCount: Integer;

      procedure GetJSONBuf(var aStream:String; var aTabCount : integer);
      procedure SetValue(const aValue : String);
      procedure SetKey(const aKey : String);
    Public
      Constructor Create; Override; Overload;
      Constructor Create(aType : TJSONtype); Override; Overload;
      Constructor Create(aData : String); Override; Overload;
      Destructor Destroy; Override;

      procedure add(aObject : TJSONObject);overload;
      procedure add(const aKey:string; aObject : TJSONObject);overload;
      
      Property SelfType : TJSONtype read FType;
      Property Value : String Read FValue write SetValue;
      Property Name : String Read FKey write SetKey;
      Property Count : Integer Read GetCount;
      Property IsSimple : boolean Read FIsSimple;

      Property AsDouble: Double Read GetAsDouble;
      Property AsInt: Integer Read GetAsInt;
      Property AsBool: Boolean Read GetAsBool;
      Property IsNull: Boolean Read GetIsNull;

      function GetItem(aIndex : Integer) : TJSONObject;
      function GetField(const aKey : String) : TJSONObject;
      function isFieldExists(const aKey : String) : Boolean;

      Property Field[const aKey : String]:TJSONObject Read GetField; default;
      Property Child[aIndex : Integer]:TJSONObject Read GetItem; default;
      
      function GetJSON : AnsiString;
  end;

  Function ParseJSON(aJSONString:String):TJSONObject;

implementation

const
  JR_OBJ = 'Only TJSONlist or TJSONobject object can be assigned to TJSONbase';
  JR_TYPE = 'Invalid data type assigned to TJSONbase';
  JR_LIST_VALUE = 'TJSONlist does not have a value by itself - it is an indexed array';
  JR_LIST_NAME = 'TJSONlist use only Integer indexes - not String';
  JR_INDEX = 'Index (%d) is outside the array (%d)';
  JR_NO_INDEX = 'TJSONbase is not an array and does not support indexes';
  JR_NO_NAME = 'Associative arrays does not support empty index';
  JR_OBJ_VALUE = 'TJSONobject does not have a value by itself - it is an indexed array';
  JR_BAD_TXT = 'Unsupported data type in TJSONbase.Text';
  JR_NO_COUNT = 'TJSONbase is not an array and does not have Count property';
  JR_PARSE_CHAR = 'Unexpected character at position %d';
  JR_PARSE_EMPTY = 'Empty element at position %d';
  JR_OPEN_LIST = 'Missing closing ]';
  JR_OPEN_OBJECT = 'Missing closing }';
  JR_OPEN_STRING = 'Unterminated string at position %d';
  JR_NO_COLON = 'Missing property name/value delimiter (:) at position %d';
  JR_NO_VALUE = 'Missing property value at position %d';
  JR_NO_COMMA = 'Missing comma at position %d';
  JR_BAD_FLOAT = 'Missing fractional part of a floating-point number at position %d';
  JR_BAD_EXPONENT = 'Exponent of the number is not integer at position %d';
  JR_UNQUOTED = 'Unquoted property name at position %d';
  JR_CONTROL = 'Control character (%d) encountered at position %d in %s';
  JR_ESCAPE = 'Unrecognized escape sequence at position %d in "%s"';
  JR_CODEPOINT = 'Invalid UNICODE escape sequence at position %d in "%s"';
  JR_UNESCAPED = 'Unescaped symbol at position %d in "%s"';
  JR_EMPTY_NAME = 'Empty property name at position %d';

Constructor TJSONObject.Create; Override; Overload;
Begin
  Inherited;
  FType:=jsNull;
  FValue:='';
  FKey:='';
  FIsSimple:=true;
  FChildsList:=TStringList.Create;
end;

Constructor TJSONObject.Create(aType : TJSONtype); Override; Overload;
Begin
  Inherited Create;
  Create();
  FType:=aType;
end;

Constructor TJSONObject.Create(aData: String); Override; Overload;
Begin
  Inherited Create;
  Create();
end;

Destructor TJSONObject.Destroy;
Begin
  FChildsList.Free;
  Inherited;
end;

procedure TJSONObject.SetValue(const aValue : String);
begin
  FValue := aValue;
end;

procedure TJSONObject.SetKey(const aKey : String);
begin
  FKey := aKey;
  FIsSimple := false;
end;

procedure TJSONObject.add(aObject : TJSONObject);overload;
begin
  //engine.msg('added by object',aObject.Name+'='+aObject.value);
  FChildsList.AddObject(aObject.Name,aObject);
end;

procedure TJSONObject.add(const aKey:string; aObject : TJSONObject);overload;
begin
  //engine.msg('added by key',aKey+'='+aObject.value);
  aObject.Name := aKey;
  FChildsList.AddObject(aKey,aObject);
end;

function TJSONObject.GetCount: Integer;
begin
  result:=FChildsList.count;
end;

function TJSONObject.GetItem(aIndex : Integer) : TJSONObject;
begin
  result := nil;
  if (aIndex<FChildsList.Count)and(aIndex>=0) then
  begin
    result:=TJSONObject(FChildsList.Objects[aIndex]);
  end else
  begin
    raise Exception.Create(Format('Try access not valid index %d, but count is %d.',[aIndex, FChildsList.Count]));
  end; 
end;

function TJSONObject.GetField(const aKey : String) : TJSONObject;
var
  index:integer;
begin
  result := nil;
  index := FChildsList.IndexOf(aKey);
  if (index>=0) then
  begin
    result:=TJSONObject(FChildsList.Objects[index]);
  end else
  begin
    print(Format('Try access key %s no exists.',[aKey]));
    //raise Exception.Create(Format('Try access key %s no exists.',[aKey]));
  end; 
end;

function TJSONObject.isFieldExists(const aKey : String) : Boolean;
var
  index:integer;
begin
  result := false;
  index := FChildsList.IndexOf(aKey);
  result := index >= 0;
end;

function TJSONObject.GetIsNull: Boolean;
begin
  result := (Ftype = jsNull) or (FValue = '');
end;

function TJSONObject.GetAsBool: Boolean;
begin
  result := 
  ((Ftype = jsBool) and (FValue.ToLower = 'true')) 
  or ((Ftype = jsInt) and (FValue <> '0')) 
  or ((Ftype = jsString) and (FValue <> '')) 
  or (Ftype <> jsNull);
end;

function TJSONObject.GetAsInt: Integer;
begin
  result := StrToIntDef(FValue, 0);
end;

function TJSONObject.GetAsDouble: Double;
begin
  result := StrToFloat(FValue);
end;

function TJSONobject.GetJSON : String;
Var
  Buf:String;
  tabCount:Integer;
Begin
  Buf:=('');
  try
    tabCount:=0;
    GetJSONBuf(Buf, tabCount);
    Result:=Buf;
  Finally
  end;
end;

procedure addCodeStyle(var aStream:String; var aTabCount : integer);
var
  i:Integer;
begin
  aStream:=aStream+#13#10;
  for i:=1 to aTabCount do
    aStream:=aStream+#9;
end;

procedure TJSONobject.GetJSONBuf(var aStream:String; var aTabCount : integer);
var
  i:Integer;
  currentIt : TJSONobject;
Begin
  if (FType = jsObject) then
  begin
    if ( not IsSimple ) then
    begin
      addCodeStyle(aStream, aTabCount);
      aStream:=aStream+EscapeString(FKey)+':';
      addCodeStyle(aStream, aTabCount);
    end;
    aStream:=aStream+'{';
    inc(aTabCount);
    for i:=0 to FChildsList.Count-1 Do
    Begin
      currentIt:=GetItem(i);
      if ( FChildsList.Count > 1 ) then
        addCodeStyle(aStream, aTabCount);
      currentIt.GetJSONBuf(aStream, aTabCount);
      If (i <> (FChildsList.Count-1)) then 
        aStream:=aStream+',';
    end;
    dec(aTabCount);
    if ( FChildsList.Count > 1 ) then
      addCodeStyle(aStream, aTabCount);
    aStream:=aStream+'}';
  end else
  if (FType = jsArray) then
  begin
    addCodeStyle(aStream, aTabCount);
    aStream:=aStream+EscapeString(FKey)+':';
    addCodeStyle(aStream, aTabCount);
    aStream:=aStream+'[';
    inc(aTabCount);
    for i:=0 to FChildsList.Count-1 Do
    Begin
      currentIt:=GetItem(i);
      addCodeStyle(aStream, aTabCount);
      currentIt.GetJSONBuf(aStream, aTabCount);
      If (i <> (FChildsList.Count-1)) then 
        aStream:=aStream+',';
    end;
    dec(aTabCount);
    addCodeStyle(aStream, aTabCount);
    aStream:=aStream+']';
  end else
  begin
    if ( not IsSimple ) then
    begin
      aStream:=aStream+EscapeString(FKey)+' : ';
    end;  
    if (FType = jsString) then
    begin
      aStream:=aStream+EscapeString(FValue);
    end
    else
    begin
      aStream:=aStream+FValue;
    end;
  end;
end;

  Function EscapeString(const aString : String): String;
  var
    i:Integer;
  Begin
    Result:='"';
    For i:=1 to Length(aString) do
      Case aString[i] Of
        '/', '\', '"': Result:=Result + '\' + aString[i];
        #8: Result:=Result+'\b';
        #9: Result:=Result+'\t';
        #10:Result:=Result+'\n';
        #12:Result:=Result+'\f';
        #13:Result:=Result+'\r';
      Else
        if aString[i] in [WideChar(' ') .. WideChar('~')] Then Result:=Result + aString[i]
          else Result:=Result + '\u' + IntToHex(Ord(aString[i]),4)
      end;
    Result:=Result+'"';
  end;

Function ParseJSON(aJSONString:String):TJSONObject;
var
  txt:String;
  txtpos:cardinal;
  procedure SkipSpace;
  Begin
    while
      ((txt[txtpos])=' ')
      or ((txt[txtpos])=#8)
      or ((txt[txtpos])=#9)
      or ((txt[txtpos])=#10)
      or ((txt[txtpos])=#12)
      or ((txt[txtpos])=#13)
    //in [#9, #10, #13, ' ']
    do
    begin
      Inc(txtpos);
    end;
  end;

  Function ParseRoot:TJSONObject; Forward;

  function ParseBase:TJSONObject;
  var
    ptrpos:cardinal;
    s:AnsiString;
    L:Integer;
    escaped:Boolean;
    is_float:Boolean;
  Begin
    //print('ParseBase');
    Result:=Nil;
    if txt[txtpos] = #0 then Exit;
    SkipSpace;
    case txt[txtpos] of
      '"':
        Begin
          inc(txtpos);
          ptrpos:=txt.IndexOf('"', txtpos+1);
          L:=ptrpos-txtpos;
          s:=copy(txt,txtpos,L);
          //engine.msg('ParseBase',s);
          Result:=TJSONObject.Create(jsString);
          Result.Value:=s;
          txtpos:=ptrpos+1;
        end;
      'n','N':
        Begin
          If txt[txtpos+1] in ['u','U'] Then
            if txt[txtpos+2] in ['l','L'] Then
              if txt[txtpos+3] In ['l','L'] then
              Begin
                Inc(txtpos,4);
                Result:=TJSONObject.Create;
                Result.Value:='';
              end;
        end;
      't','T':
        Begin
          if txt[txtpos+1] in ['r','R'] Then
            if txt[txtpos+2] in ['u','U'] Then
              if txt[txtpos+3] in ['e','E'] Then
              Begin
                Inc(txtpos,4);
                Result:=TJSONObject.Create(jsBool);
                Result.Value:='True';
              end;
        end;
      'f','F':
        Begin
          if txt[txtpos+1] in ['a','A'] Then
            if txt[txtpos+2] in ['l','L'] Then
              if txt[txtpos+3] in ['s','S'] Then
                if txt[txtpos+4] in ['e','E'] Then
                Begin
                  Inc(txtpos,5);
                  Result:=TJSONObject.Create(jsBool);
                  Result.Value:='False';
                end;
        end;
      '-','.','0'..'9':
        Begin
          is_float:=False;
          ptrpos:=txtpos+1;
          
          //
          while txt[ptrpos] in ['0'..'9'] do Inc(ptrpos); // integer part
          
          If txt[ptrpos] = '.' then
          Begin
            is_float:=True;
            Inc(ptrpos);
            if Not (txt[ptrpos] in ['0'..'9']) then
            Begin
              Result.Free;
              Raise Exception.Create(format(JR_BAD_FLOAT,[txtpos]));
            end;
            While txt[ptrpos] in ['0'..'9'] do Inc(ptrpos); // rational part
          end;
          if txt[ptrpos] in ['e','E'] Then
          Begin
            is_float:=True;
            Inc(ptrpos);
            if not (txt[ptrpos] in ['-','+','0'..'9']) then
            Begin
              Result.Free;
              Raise Exception.Create(format(JR_BAD_EXPONENT,[txtpos]));
            end;
            If txt[ptrpos] in ['+','-'] Then Inc(ptrpos); // exponent sign
            if not (txt[ptrpos] in ['0'..'9']) then
            Begin
              Result.Free;
              Raise Exception.Create(format(JR_BAD_EXPONENT,[txtpos]));
            end;
            While txt[ptrpos] in ['0'..'9'] do Inc(ptrpos); // exponent
          end;
          L:=ptrpos-txtpos;
          
          if L>0 Then
          begin
            s:=copy(txt,txtpos,L);
            if is_float then
            begin
              Result:=TJSONObject.Create(jsFloat);
              Result.Value:=s//StrToFloat(s)
            end
            else
            begin
              Result:=TJSONObject.Create(jsInt);
              Result.Value:=s;//StrToInt(s);
            end;
          End
          Else
          begin
            Result:=TJSONObject.Create(jsFloat);
            Result.Value:='0.0';
          end;
          txtpos:=ptrpos;
        end;
    Else
      Result:=ParseRoot;
    end;
  end;

  function ParseList:TJSONObject; // does not consume closing ]
  var
    Elem:TJSONObject;
    need_value,need_comma:Boolean;
  Begin
    //print('ParseList');
    Result:=TJSONObject.Create(jsArray);
    need_value:=False;
    need_comma:=False;
    While txt[txtpos] <> #0 Do
    Begin
      SkipSpace;
      if txt[txtpos] = #0 then
      Begin
        Result.Free;
        Raise Exception.Create(format(JR_OPEN_LIST,[txtpos]));
      end;
      Case txt[txtpos] Of
        ']':
          Begin
            If need_value then
            Begin
              Result.Free;
              Raise Exception.Create(format(JR_PARSE_EMPTY,[txtpos]));
            End;
            //Inc(txtpos);//???
            need_comma:=False;
            Break;
          end;
        ',':
          begin
            if need_value or (Result.Count=0) then
            Begin
              Result.Free;
              Raise Exception.Create(format(JR_PARSE_EMPTY,[txtpos]));
            end;
            Inc(txtpos);
            need_value:=True;
            need_comma:=False;
          end;
      else
        if need_comma then
        Begin
          Result.Free;
          Raise Exception.Create(format(JR_NO_COMMA,[txtpos]));
        end
        else
        Begin
          Elem:=ParseBase;
          If not Assigned(Elem) then
          Begin
            Result.Free;
            Raise Exception.Create(format(JR_PARSE_EMPTY,[txtpos]));
          end;
          Result.Add(Elem);
          need_value:=False;
          need_comma:=True;
        end;
      end;
    end;
  end;

  Function ParseName:WideString;
  var
    ptr:string;
    ptrpos:cardinal;
    s:AnsiString;
    L:Integer;
    escaped:Boolean;
  Begin
    Result:='';
    //print('ParseName');
    SkipSpace;
    if txt[txtpos] = '"' Then
    begin
      inc(txtpos);
      ptrpos:=txt.IndexOf('"', txtpos+1);
      L:=ptrpos-txtpos;
      s:=copy(txt,txtpos,L);
      //engine.msg('ParseName',s);
      Result:=s;
      //Raise Exception.Create(format(JR_EMPTY_NAME,[txtpos]));
      txtpos:=ptrpos+1;
    End;
    //Else Raise Exception.Create(format(JR_UNQUOTED,[txtpos]));
  end;

  function ParseObject:TJSONObject; // does not consume closing }
  var
    Title:WideString;
    Elem:TJSONObject;
    need_value,need_comma:Boolean;
  Begin
    //print('ParseObject');
    Result:=TJSONObject.Create(jsObject);
    need_value:=False;
    need_comma:=False;
    While txt[txtpos] <> #0 Do
    Begin
      SkipSpace;
      if txt[txtpos] = #0 then
      Begin
        Result.Free;        
        Raise Exception.Create(format(JR_OPEN_LIST,[txtpos]));
      end;
      Case txt[txtpos] Of
        '}':
          Begin
            If need_value then
            Begin
              Result.Free;              
              Raise Exception.Create(format(JR_PARSE_EMPTY,[txtpos]));
            end;
            //Inc(txtpos);
            need_comma:=False;
            Break;
          end;
        ',':
          begin
            if need_value 
              or (Result.Count=0) 
            then
            Begin
              Result.Free;              
              Raise Exception.Create(format(JR_PARSE_EMPTY,[txtpos]));
            end;
            Inc(txtpos);
            need_value:=True;
            need_comma:=False;
          end;
      else
        if need_comma then
        Begin
          Result.Free;          
          Raise Exception.Create(format(JR_NO_COMMA,[txtpos]));
        end
        else
        Begin
          Title:=ParseName;
          //Result.Name := Title;
          SkipSpace;
          If txt[txtpos] <> ':' then
          Begin
            Result.Free;            
            Raise Exception.Create(format(JR_NO_COLON,[txtpos]));
          end;
          Inc(txtpos);
          SkipSpace;
          if txt[txtpos] in [',','}'] then
          Begin
            Result.Free;            
            Raise Exception.Create(format(JR_NO_VALUE,[txtpos]));
          end;
          Elem:=ParseBase;
          If not Assigned(Elem) then
          Begin
            Result.Free;            
            Raise Exception.Create(format(JR_PARSE_EMPTY,[txtpos]));
          end else
          begin
            Result.Add(Title,Elem);
            Elem:=nil;
          end;
          need_value:=False;
          need_comma:=True;
        end;
      end;
    end;
  end;

  Function ParseRoot:TJSONObject;
  begin
    //print('ParseRoot');
    Result:=Nil;
    While (txt[txtpos] <> #0) do
    Begin
      SkipSpace;
      if (txt[txtpos] = #0) Then Break;
      case txt[txtpos] Of
        '{':
          begin
            Inc(txtpos);
            Result:=ParseObject;
            SkipSpace;
            if txt[txtpos] <> '}' then
            Begin
              Result.Free;              
              Raise Exception.Create(format(JR_OPEN_OBJECT,[txtpos]));
            end;
            Inc(txtpos);
            Break;
          End;
        '[':
          Begin
            Inc(txtpos);
            Result:=ParseList;
            SkipSpace;
            if txt[txtpos] <> ']' then
            Begin
              Result.Free;              
              Raise Exception.Create(format(JR_OPEN_LIST,[txtpos]));
            end;
            Inc(txtpos);
            Break;
          end;
      Else
        Result.Free;
        Raise Exception.Create(format(JR_PARSE_CHAR,[txtpos,txt]));
        break;        
      end;
    end;
  end;

Begin
  txtpos:=1;
  //print(txtpos);
  txt:=aJSONString;
  Result:=Nil;
  if (txt<>'') then
  try
    Result:=ParseRoot;
    SkipSpace;
    If txt[txtpos] <> #0 Then
    begin
      Result.Free;
      Raise Exception.Create(format(JR_PARSE_CHAR,[txtpos,txt]));
    End;
  Except
    Result.Free;
    
  End;
end;

var
  testJSON : TJSONObject;

begin
   with TSTRINGLIST.create do
   try
    loadfromfile('levels.json');
    testJSON := parseJSON(text);
   finally
    free;
   end;
   print(testJSON.getJSON());
   testJSON.free;
end.