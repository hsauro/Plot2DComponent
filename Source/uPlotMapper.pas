unit uPlotMapper;

interface

Uses SysUtils,
     Types;

type
  TPointD = record
    X: Double;
    Y: Double;
    class function Create(const AX, AY: Double): TPointD; static;
    procedure Offset(const APoint: TPointD);  overload;
    procedure Offset(const ADeltaX, ADeltaY: Double); overload;
  end;

  // Define the structure
  TRectD = record
    Left, Top, Right, Bottom: Double;

    // Helper to calculate Width
    function Width: Double; inline;
    // Helper to calculate Height
    function Height: Double; inline;

    function CenterPoint: TPointD;

    procedure Inflate(const DX, DY: Double);
  end;


  TPlotMapper = record
  public
    DataRect:  TRectD;  // Data coordinate space  (Double: survives deep zoom)
    PixelRect: TRectF;  // Screen pixel space     (Single: pixels are Single)

    LogX, LogY: Boolean;  // Log scale flags (affect MapX/MapY)

    function UnmapX(APixel: Single): Double;
    function UnmapY(APixel: Single): Double;

    function MapX(AValue: Double): Single;
    function MapY(AValue: Double): Single;
    function MapPoint(const APt: TPointD): TPointD;
    function IsInBounds(const APt: TPointD): Boolean;
  end;

implementation

Uses Math;

class function TPointD.Create(const AX, AY: Double): TPointD;
begin
  Result.X := AX;
  Result.Y := AY;
end;

procedure TPointD.Offset(const APoint: TPointD);
begin
  Self.X := Self.X + APoint.X;
  Self.Y := Self.Y + APoint.Y;
end;

procedure TPointD.Offset(const ADeltaX, ADeltaY: Double);
begin
  Self.Offset(TPointD.Create(ADeltaX, ADeltaY));
end;

// ----------------------------------------------------------------------------

function TRectD.Width: Double;
begin
  Result := Right - Left;
end;

function TRectD.Height: Double;
begin
  Result := Bottom - Top;
end;


function TRectD.CenterPoint: TPointD;
begin
  Result.X := (Right - Left)/2.0 + Left;
  Result.Y := (Bottom - Top)/2.0 + Top;
end;


procedure TRectD.Inflate(const DX, DY: Double);
begin
  Left   := Left   - DX;
  Top    := Top    - DY;
  Right  := Right  + DX;
  Bottom := Bottom + DY;
end;


// ----------------------------------------------------------------

function TPlotMapper.UnmapX(APixel: Single): Double;
var
  Min, Max: Double;
begin
  if LogX then
  begin
    Min    := Log10(Math.Max(DataRect.Left,  1e-9));
    Max    := Log10(Math.Max(DataRect.Right, 1e-9));
    Result := Power(10, Min + (APixel - PixelRect.Left) * (Max - Min) / PixelRect.Width);
  end
  else
    Result := DataRect.Left +
              (APixel - PixelRect.Left) * (DataRect.Width / PixelRect.Width);
end;

function TPlotMapper.UnmapY(APixel: Single): Double;
var
  Min, Max: Double;
begin
  // Mirror of MapY: pixel bottom = data minimum
  if LogY then
  begin
    Min    := Log10(Math.Max(DataRect.Top,    1e-9));
    Max    := Log10(Math.Max(DataRect.Bottom, 1e-9));
    Result := Power(10, Min + (PixelRect.Bottom - APixel) * (Max - Min) / PixelRect.Height);
  end
  else
    Result := DataRect.Top +
              (PixelRect.Bottom - APixel) * (DataRect.Height / PixelRect.Height);
end;


function TPlotMapper.MapX(AValue: Double): Single;
var
  V, Min, Max: Double;
begin
  if LogX then begin
    V   := Log10(Math.Max(AValue,          1e-9));
    Min := Log10(Math.Max(DataRect.Left,   1e-9));
    Max := Log10(Math.Max(DataRect.Right,  1e-9));
    Result := PixelRect.Left + (V - Min) * (PixelRect.Width / (Max - Min));
  end else
    Result := PixelRect.Left + (AValue - DataRect.Left) * (PixelRect.Width / DataRect.Width);
end;

function TPlotMapper.MapY(AValue: Double): Single;
var
  V, Min, Max: Double;
begin
  // Inverted Y: data minimum maps to pixel bottom
  if LogY then begin
    V   := Log10(Math.Max(AValue,         1e-9));
    Min := Log10(Math.Max(DataRect.Top,   1e-9));
    Max := Log10(Math.Max(DataRect.Bottom,1e-9));
    Result := PixelRect.Bottom - (V - Min) * (PixelRect.Height / (Max - Min));
  end else
    Result := PixelRect.Bottom - (AValue - DataRect.Top) * (PixelRect.Height / DataRect.Height);
end;

function TPlotMapper.MapPoint(const APt: TPointD): TPointD;
begin
  Result := TPointD.Create(MapX(APt.X), MapY(APt.Y));
end;

function TPlotMapper.IsInBounds(const APt: TPointD): Boolean;
begin
  Result := (APt.X >= DataRect.Left)  and (APt.X <= DataRect.Right) and
            (APt.Y >= DataRect.Top)   and (APt.Y <= DataRect.Bottom);
end;

end.
