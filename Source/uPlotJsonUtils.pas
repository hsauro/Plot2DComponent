unit uPlotJsonUtils;

// ---------------------------------------------------------------------------
//  uPlotJsonUtils
//
//  Small shared helpers used by the SaveToJson / LoadFromJson methods that
//  the plot classes implement.  Two concerns:
//
//    * TAlphaColor <-> "#AARRGGBB" hex string (same convention used by
//      uPlotDefaults so plot files and defaults files look consistent).
//    * Reading a value from a TJSONObject with a fallback default, so a
//      missing or wrong-typed key leaves the caller's current value intact
//      (forward/backward-compatible load behaviour).
// ---------------------------------------------------------------------------

interface

uses
  System.SysUtils,
  System.JSON,
  System.UITypes;

function AlphaColorToHex(C: TAlphaColor): string;
function HexToAlphaColor(const S: string; Default: TAlphaColor): TAlphaColor;

// Readers: return Default when Obj is nil, the key is absent, or the stored
// value is not of the expected JSON type.
function JBool (const Obj: TJSONObject; const Key: string; const Default: Boolean): Boolean;
function JInt  (const Obj: TJSONObject; const Key: string; const Default: Integer): Integer;
function JFloat(const Obj: TJSONObject; const Key: string; const Default: Double): Double;
function JStr  (const Obj: TJSONObject; const Key: string; const Default: string): string;
function JColor(const Obj: TJSONObject; const Key: string; const Default: TAlphaColor): TAlphaColor;

// Writers: add a typed pair to Obj.
procedure JPutBool (const Obj: TJSONObject; const Key: string; const Value: Boolean);
procedure JPutInt  (const Obj: TJSONObject; const Key: string; const Value: Integer);
procedure JPutFloat(const Obj: TJSONObject; const Key: string; const Value: Double);
procedure JPutStr  (const Obj: TJSONObject; const Key: string; const Value: string);
procedure JPutColor(const Obj: TJSONObject; const Key: string; const Value: TAlphaColor);

implementation

function AlphaColorToHex(C: TAlphaColor): string;
begin
  Result := Format('#%.8x', [Cardinal(C)]);   // #AARRGGBB
end;

function HexToAlphaColor(const S: string; Default: TAlphaColor): TAlphaColor;
var
  Hex: string;
  V:   Int64;
begin
  Result := Default;
  Hex := S.Trim;
  if Hex.StartsWith('#') then
    Hex := Hex.Substring(1);

  case Length(Hex) of
    6: Hex := 'FF' + Hex;   // assume full opacity when alpha omitted
    8: { already AARRGGBB } ;
  else
    Exit;
  end;

  if TryStrToInt64('$' + Hex, V) then
    Result := TAlphaColor(V);
end;

function JBool(const Obj: TJSONObject; const Key: string; const Default: Boolean): Boolean;
var
  V: TJSONValue;
begin
  Result := Default;
  if Obj = nil then Exit;
  V := Obj.GetValue(Key);
  if V is TJSONBool then
    Result := TJSONBool(V).AsBoolean;
end;

function JInt(const Obj: TJSONObject; const Key: string; const Default: Integer): Integer;
var
  V: TJSONValue;
begin
  Result := Default;
  if Obj = nil then Exit;
  V := Obj.GetValue(Key);
  if V is TJSONNumber then
    Result := TJSONNumber(V).AsInt;
end;

function JFloat(const Obj: TJSONObject; const Key: string; const Default: Double): Double;
var
  V: TJSONValue;
begin
  Result := Default;
  if Obj = nil then Exit;
  V := Obj.GetValue(Key);
  if V is TJSONNumber then
    Result := TJSONNumber(V).AsDouble;
end;

function JStr(const Obj: TJSONObject; const Key: string; const Default: string): string;
var
  V: TJSONValue;
begin
  Result := Default;
  if Obj = nil then Exit;
  V := Obj.GetValue(Key);
  if V is TJSONString then
    Result := TJSONString(V).Value;
end;

function JColor(const Obj: TJSONObject; const Key: string; const Default: TAlphaColor): TAlphaColor;
begin
  Result := HexToAlphaColor(JStr(Obj, Key, ''), Default);
end;

procedure JPutBool(const Obj: TJSONObject; const Key: string; const Value: Boolean);
begin
  Obj.AddPair(Key, TJSONBool.Create(Value));
end;

procedure JPutInt(const Obj: TJSONObject; const Key: string; const Value: Integer);
begin
  Obj.AddPair(Key, TJSONNumber.Create(Value));
end;

procedure JPutFloat(const Obj: TJSONObject; const Key: string; const Value: Double);
begin
  Obj.AddPair(Key, TJSONNumber.Create(Value));
end;

procedure JPutStr(const Obj: TJSONObject; const Key: string; const Value: string);
begin
  Obj.AddPair(Key, Value);
end;

procedure JPutColor(const Obj: TJSONObject; const Key: string; const Value: TAlphaColor);
begin
  Obj.AddPair(Key, AlphaColorToHex(Value));
end;

end.
