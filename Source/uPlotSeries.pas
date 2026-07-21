unit uPlotSeries;

interface

Uses SysUtils,
     Classes,
     System.UIConsts,
     System.UITypes,
     System.JSON,
     Generics.Collections,
     System.Types,
     Skia,
     uPlotMapper;

type
  TSeriesKind = (skSimulation, skData); // Add more types later on if we need to
  TSourceType = (stCSVFile, stFunction);
  TMarkerShape = (symPoint, symSquare, symCircle, symCross, symTimes, symDiamond, symTriangle);
  TLineStyle = (ltSolid, ltDashDash, ltDotDot);

  TDataList = TList<TPointD>;

 TPlotSeries = class
  private
      FName : string;
      FXLabel: string;
      FYLabel: string;
      // Line Styling
      FLineColor: TAlphaColor;
      FLineWidth: Single;
      FLineVisible : Boolean;
      FLineStyle : TLineStyle;
      FVisible : Boolean;
      FShowInLegend : Boolean;

      // Marker Styling
      FMarkerSize: Single;
      FMarkerFillColor: TAlphaColor;
      FMarkerStrokeColor: TAlphaColor;
      FMarkerStrokeWidth: Single;
      FMarkerShape : TMarkerShape;
      FMarkerVisible : Boolean;
      // Optional back-reference from a plotted point to the data it came from. Sparse: only
      // points added via the tagged AddXY overload have an entry, keyed by their Data index.
      // Keyed (not a parallel list) so Clear/Clone/JSON need no alignment upkeep.
      FSourceTags : TDictionary<Integer, Integer>;
  public
      SeriesKind : TSeriesKind; // put what ever you want here to identify a particular type of series
      SeriesId : String; // More detailed identifier, usually a file name for data
      Data: TDataList;   // Stores a list of X,Y pairs
      // Free-form per-series identifier for the host (e.g. which source dataset/branch this
      // series represents). The component never interprets it.
      Tag : Integer;

      constructor Create(const AName: string; AStrokeColor: TAlphaColor; ShowMarkers : Boolean = True);
      destructor Destroy; override;
      procedure DrawMarker (ACanvas : ISKCanvas; P : TPointD; Size : Single; LPaint : ISKPaint);
      procedure Draw(const ACanvas: ISkCanvas; const AMapper: TPlotMapper);
      function AddXY (X, Y : Double) : Integer; overload;
      // Adds a point AND records ATag against its index; recover it later with SourceTag.
      function AddXY (X, Y : Double; ATag : Integer) : Integer; overload;
      // The tag stored for the point at AIndex, or -1 if that point wasn't tagged.
      function SourceTag (AIndex : Integer) : Integer;
      function Clone : TPlotSeries;

      // JSON persistence. SaveToJson returns a new object the caller owns;
      // LoadFromJson overwrites this series' styling and replaces its data
      // points.  Enum values are stored as ordinals.  Missing keys keep the
      // current value so older/newer files load gracefully.
      function  SaveToJson : TJSONObject;
      procedure LoadFromJson (const Obj : TJSONObject);

      // Styling-only counterparts. SaveStyleToJson emits every styling field
      // but no data points; LoadStyleFromJson applies those fields and leaves
      // Data untouched.  SaveToJson / LoadFromJson are implemented on top of
      // these (styling + a 'data' array).
      function  SaveStyleToJson : TJSONObject;
      procedure LoadStyleFromJson (const Obj : TJSONObject);
  published
      property Name: String read FName write FName;
      property XLabel: String read FXLabel write FXLabel;
      property YLabel: String read FYLabel write FYLabel;
      property LineColor: TAlphaColor read FLineColor write FLineColor;
      property LineWidth: Single read FLinewidth write FLineWidth;
      property LineVisible : Boolean read FLineVisible write FLineVisible;
      property LineStyle : TLineStyle read FLineStyle write FLineStyle;

      // Marker Styling
      property MarkerSize: Single read FMarkerSize write FMarkerSize;
      property MarkerFillColor: TAlphaColor read FMarkerFillColor write FMarkerFillColor;
      property MarkerStrokeColor: TAlphaColor read FMarkerStrokeColor write FMarkerStrokeColor;
      property MarkerStrokeWidth: Single read FMarkerStrokeWidth write FMarkerStrokeWidth;
      property MarkerShape : TMarkerShape read FMarkerShape write FMarkerShape;
      property MarkerVisible : Boolean read FMarkerVisible write FMarkerVisible;

      property Visible: Boolean read FVisible write FVisible;

      // Controls whether this series appears in the legend, independently of
      // Visible. Setting Visible := False hides the curve entirely; setting
      // ShowInLegend := False keeps the curve on the chart but drops its
      // legend entry. Used to collapse the several runs of a bifurcation
      // branch (all sharing one name/style) down to a single legend line.
      property ShowInLegend: Boolean read FShowInLegend write FShowInLegend;
  end;

 const
    MarkerShapeNames: array[TMarkerShape] of string = (
      'Point',
      'Square',
      'Circle',
      'Cross',
      'Times',
      'Diamond',
      'Triangle'
  );

    LineStyleNames: array[TLineStyle] of string = (
      'Solid',
      'Dash-Dash',
      'Dot-Dot'
  );

  function MarkerStrToMarkerShape (MarkerStr : String) : TMarkerShape;

implementation

// uPlotDefaults is listed here, in the implementation uses, so that
// uPlotSeries itself remains free of JSON plumbing and the circular-
// reference risk is avoided (uPlotDefaults uses uPlotSeries for the
// TMarkerShape / TLineStyle types only).
uses System.Math, uPlotDefaults, uPlotJsonUtils;


function MarkerStrToMarkerShape (MarkerStr : String) : TMarkerShape;
begin
  // Match against the canonical names in MarkerShapeNames so every
  // TMarkerShape value is covered.  Comparison is case-insensitive and
  // ignores surrounding whitespace.  Unrecognised input falls back to
  // symCircle so the function always returns a defined value.
  MarkerStr := Trim (MarkerStr);
  for var Shape := Low (TMarkerShape) to High (TMarkerShape) do
      if SameText (MarkerStr, MarkerShapeNames[Shape]) then
         Exit (Shape);
  Result := symCircle;
end;

constructor TPlotSeries.Create(const AName: string; AStrokeColor: TAlphaColor; ShowMarkers : Boolean = True);
begin
  inherited Create;

  FName       := AName;
  SeriesKind := skSimulation;  // Default

  FVisible := True;
  FShowInLegend := True;

  // Line styling � values come from the global PlotDefaults record.
  // PlotDefaults is initialised from the built-in constants at unit
  // start, and may be overridden by loading a JSON file before the
  // first series is created.
  FLineColor   := AStrokeColor;           // color always comes from the caller
  FLineWidth   := PlotDefaults.LineWidth;
  FLineVisible := True;
  FLineStyle   := PlotDefaults.LineStyle;

  // Marker styling
  MarkerVisible     := ShowMarkers;
  MarkerSize        := PlotDefaults.MarkerSize;
  MarkerFillColor   := PlotDefaults.MarkerFillColor;
  MarkerStrokeColor := AStrokeColor;    // stroke color tracks the series color
  MarkerStrokeWidth := PlotDefaults.MarkerStrokeWidth;
  MarkerShape       := PlotDefaults.MarkerShape;

  Data := TDataList.Create;
  FSourceTags := TDictionary<Integer, Integer>.Create;
  Tag := 0;
end;

destructor TPlotSeries.Destroy;
begin
  FSourceTags.Free;
  Data.Free;
  inherited Destroy;
end;


procedure TPlotSeries.DrawMarker (ACanvas : ISKCanvas; P : TPointD; Size : Single; LPaint : ISKPaint);
var R : TRectF;
    Radius : Single;
    LPathBuilder : ISkPathBuilder;
    LPath: ISkPath;
    HOffSet, VOffSet : Single;
begin
   case MarkerShape of
         symCircle :
            begin
            // Draw Fill
            LPaint.Style := TSkPaintStyle.Fill;
            LPaint.Color := MarkerFillColor;
            ACanvas.DrawCircle(P.X, P.Y, Size, LPaint);

            // Draw Stroke (Outline)
            LPaint.Style := TSkPaintStyle.Stroke;
            LPaint.Color := MarkerStrokeColor;
            ACanvas.DrawCircle(P.X, P.Y, Size, LPaint);
            end;

        symSquare :
            begin
            // Draw Fill
            Size := Size*1.5;
            R.Left := P.X - Size/2;
            R.Right := P.X + Size/2;
            R.Top := P.Y - Size/2;
            R.Bottom := P.Y + Size/2;

            LPaint.Style := TSkPaintStyle.Fill;
            LPaint.Color := MarkerFillColor;
            ACanvas.DrawRect(R, LPaint);

            // Draw Stroke (Outline)
            LPaint.Style := TSkPaintStyle.Stroke;
            LPaint.Color := MarkerStrokeColor;
            ACanvas.DrawRect(R, LPaint);
            end;

        symCross :
            begin
            Radius := 1.7*(Size/2);
            LPaint.StrokeWidth := 2;
            LPaint.Color := MarkerStrokeColor;
            ACanvas.DrawLine(P.X - Radius, P.Y, P.X + Radius, P.Y, LPaint);
            ACanvas.DrawLine(P.X, P.Y - Radius, P.X, P.Y + Radius, LPaint);
            end;

        symTimes :
            begin
            var Offset := ((3.75*Size/2) / 2) * 0.70710678;
            LPaint.StrokeWidth := 2;
            LPaint.Color := MarkerStrokeColor;
            ACanvas.DrawLine(P.X - Offset, P.Y - Offset, P.X + Offset, P.Y + Offset, LPaint);
            ACanvas.DrawLine(P.X - Offset, P.Y + Offset, P.X + Offset, P.Y - Offset, LPaint);
            end;

        symDiamond :
            begin
            Radius := 2.2*(Size/2);
            LPathBuilder := TSkPathBuilder.Create;
            LPathBuilder.MoveTo(P.X, P.Y - Radius);       // Start at Top
            LPathBuilder.LineTo(P.X + Radius, P.Y);       // Line to Right
            LPathBuilder.LineTo(P.X, P.Y + Radius);       // Line to Bottom
            LPathBuilder.LineTo(P.X - Radius, P.Y);       // Line to Left
            LPathBuilder.Close;                       // Close the path loop
            LPath := LPathBuilder.Detach;

            LPaint.Style := TSkPaintStyle.Fill;
            LPaint.Color := MarkerFillColor;
            ACanvas.DrawPath(LPath, LPaint);

            LPaint.Style := TSkPaintStyle.Stroke;
            LPaint.Color := MarkerStrokeColor;
            ACanvas.DrawPath(LPath, LPaint);
            end;

        symPoint :
            begin
            LPaint.Style := TSkPaintStyle.Fill;
            LPaint.Color := MarkerFillColor;
            ACanvas.DrawCircle(P.X, P.Y, 2, LPaint);
            end;

        symTriangle :
            begin
            Radius := 2.4*(Size/2);
            HOffset := Radius * 0.8660254; // Horizontal spread from center
            VOffset := Radius * 0.5;       // Vertical drop below center
            LPathBuilder := TSkPathBuilder.Create;
            LPathBuilder.MoveTo(P.X, P.Y - Radius);             // Top Vertex
            LPathBuilder.LineTo(P.X + HOffset, P.Y + VOffset);   // Bottom-Right Vertex
            LPathBuilder.LineTo(P.X - HOffset, P.Y + VOffset);   // Bottom-Left Vertex
            LPathBuilder.Close;                              // Closes back to Top                      // Close the path loop
            LPath := LPathBuilder.Detach;

            LPaint.Style := TSkPaintStyle.Fill;
            LPaint.Color := MarkerFillColor;
            LPaint.StrokeJoin := TSkStrokeJoin.Miter;
            ACanvas.DrawPath(LPath, LPaint);

            LPaint.Style := TSkPaintStyle.Stroke;
            LPaint.Color := MarkerStrokeColor;
            ACanvas.DrawPath(LPath, LPaint);
            end;
   end;
end;


procedure TPlotSeries.Draw(const ACanvas: ISkCanvas; const AMapper: TPlotMapper);
var
  LPaint: ISkPaint;
  I: Integer;
  P1, P2: TPointD;
  LIntervals : TArray<single>;
begin
  if not FVisible then Exit;

  // Nothing to draw at all. Note we do NOT require >= 2 points here: the
  // line loop below (0 .. Count-2) naturally draws nothing for a single
  // point, but the marker loop (0 .. Count-1) must still render it. A
  // one-point series (e.g. a single Hopf bifurcation with no folds) is a
  // valid marker-only plot and used to vanish under a "< 2" guard while
  // still getting a legend entry.
  if Data.Count < 1 then Exit;

  LPaint := TSkPaint.Create;
  LPaint.AntiAlias := True;

  // 1. DRAW THE LINE as a SINGLE path (moveTo/lineTo), stroked once. Drawing segment-by-segment
  // (the old way) reset the dash pattern every segment -- so dense curves rendered near-solid --
  // and doubled a round cap at every vertex, fuzzing the line. A path fixes both: real joins and
  // a dash pattern that runs along the whole line. NaN or log-excluded points lift the pen so a
  // series can still hold several disconnected runs.
  if LineVisible and (Data.Count >= 2) then
  begin
    LPaint.Style := TSkPaintStyle.Stroke;
    LPaint.Color := LineColor;
    LPaint.StrokeWidth := LineWidth;
    LPaint.StrokeCap := TSkStrokeCap.Round;
    LPaint.StrokeJoin := TSkStrokeJoin.Round;

    case LineStyle of
      TLineStyle.ltDashDash: LPaint.PathEffect := TSkPathEffect.MakeDash([3 * LineWidth, 2.5 * LineWidth], 0);
      TLineStyle.ltDotDot:   LPaint.PathEffect := TSkPathEffect.MakeDash([LineWidth, 2.5 * LineWidth], 0);
    else
      LPaint.PathEffect := nil;
    end;

    var LBuilder: ISkPathBuilder := TSkPathBuilder.Create;
    var PenDown := False;
    for I := 0 to Data.Count - 1 do
    begin
      if IsNan(Data[I].X) or IsNan(Data[I].Y)
         or (AMapper.LogX and (Data[I].X <= 0))
         or (AMapper.LogY and (Data[I].Y <= 0)) then
      begin
        PenDown := False;   // pen-lift: the next valid point starts a fresh sub-path
        Continue;
      end;
      P1 := AMapper.MapPoint(Data[I]);
      if PenDown then
        LBuilder.LineTo(P1.X, P1.Y)
      else
      begin
        LBuilder.MoveTo(P1.X, P1.Y);
        PenDown := True;
      end;
    end;
    ACanvas.DrawPath(LBuilder.Detach, LPaint);
    LPaint.PathEffect := nil;
  end;

  // 2. DRAW THE MARKERS
  if MarkerVisible then
    begin
    for I := 0 to Data.Count - 1 do
    begin
      // A NaN point is a pen-lift with no marker to draw; skip it.
      if IsNan(Data[I].X) or IsNan(Data[I].Y) then Continue;

      // Same log-mode exclusion as the line loop.
      if AMapper.LogX and (Data[I].X <= 0) then Continue;
      if AMapper.LogY and (Data[I].Y <= 0) then Continue;

      P1 := AMapper.MapPoint(Data[I]);

      LPaint.StrokeWidth := MarkerStrokeWidth;
      DrawMarker (ACanvas, P1, MarkerSize, LPaint);
    end;
    end;
end;


function TPlotSeries.AddXY (X, Y : Double) : Integer;
begin
  Result := Data.Add(TPointD.Create (X, Y));
end;

function TPlotSeries.AddXY (X, Y : Double; ATag : Integer) : Integer;
begin
  Result := Data.Add(TPointD.Create (X, Y));
  FSourceTags.AddOrSetValue (Result, ATag);
end;

function TPlotSeries.SourceTag (AIndex : Integer) : Integer;
begin
  if not FSourceTags.TryGetValue (AIndex, Result) then
    Result := -1;
end;


function TPlotSeries.Clone : TPlotSeries;
var
  I : Integer;
begin
  // Use the existing constructor to get a properly initialised instance,
  // then overwrite every field so the clone is independent of PlotDefaults
  // and reflects this series' current state exactly.
  Result := TPlotSeries.Create(Name, LineColor, MarkerVisible);

  Result.SeriesKind    := SeriesKind;
  Result.SeriesId      := SeriesId;
  Result.Tag           := Tag;
  Result.FVisible      := FVisible;
  Result.FShowInLegend := FShowInLegend;

  // Line styling
  Result.LineColor   := LineColor;
  Result.LineWidth   := LineWidth;
  Result.LineVisible := LineVisible;
  Result.LineStyle   := LineStyle;

  // Marker styling
  Result.MarkerSize        := MarkerSize;
  Result.MarkerFillColor   := MarkerFillColor;
  Result.MarkerStrokeColor := MarkerStrokeColor;
  Result.MarkerStrokeWidth := MarkerStrokeWidth;
  Result.MarkerShape       := MarkerShape;
  Result.MarkerVisible     := MarkerVisible;

  // Deep copy the data points. The constructor already created an empty
  // TDataList, so we just need to fill it. Capacity hint avoids repeated
  // reallocation for large series.
  Result.Data.Capacity := Data.Count;
  for I := 0 to Data.Count - 1 do
    Result.Data.Add(Data[I]);

  for var Pair in FSourceTags do
    Result.FSourceTags.AddOrSetValue(Pair.Key, Pair.Value);
end;


function TPlotSeries.SaveStyleToJson : TJSONObject;
begin
  Result := TJSONObject.Create;

  JPutStr  (Result, 'name',          Name);
  JPutInt  (Result, 'seriesKind',    Ord (SeriesKind));
  JPutStr  (Result, 'seriesId',      SeriesId);
  JPutBool (Result, 'visible',       FVisible);
  JPutBool (Result, 'showInLegend',  FShowInLegend);

  JPutColor(Result, 'lineColor',     LineColor);
  JPutFloat(Result, 'lineWidth',     LineWidth);
  JPutBool (Result, 'lineVisible',   LineVisible);
  JPutInt  (Result, 'lineStyle',     Ord (LineStyle));

  JPutFloat(Result, 'markerSize',        MarkerSize);
  JPutColor(Result, 'markerFillColor',   MarkerFillColor);
  JPutColor(Result, 'markerStrokeColor', MarkerStrokeColor);
  JPutFloat(Result, 'markerStrokeWidth', MarkerStrokeWidth);
  JPutInt  (Result, 'markerShape',       Ord (MarkerShape));
  JPutBool (Result, 'markerVisible',     MarkerVisible);
end;


procedure TPlotSeries.LoadStyleFromJson (const Obj : TJSONObject);
begin
  if Obj = nil then Exit;

  Name          := JStr  (Obj, 'name',          Name);
  SeriesKind    := TSeriesKind (JInt (Obj, 'seriesKind', Ord (SeriesKind)));
  SeriesId      := JStr  (Obj, 'seriesId',      SeriesId);
  FVisible      := JBool (Obj, 'seriesVisible', Visible);
  FShowInLegend := JBool (Obj, 'showInLegend',  FShowInLegend);

  LineColor   := JColor (Obj, 'lineColor',   LineColor);
  LineWidth   := JFloat (Obj, 'lineWidth',   LineWidth);
  LineVisible := JBool  (Obj, 'lineVisible', LineVisible);
  LineStyle   := TLineStyle (JInt (Obj, 'lineStyle', Ord (LineStyle)));

  MarkerSize        := JFloat (Obj, 'markerSize',        MarkerSize);
  MarkerFillColor   := JColor (Obj, 'markerFillColor',   MarkerFillColor);
  MarkerStrokeColor := JColor (Obj, 'markerStrokeColor', MarkerStrokeColor);
  MarkerStrokeWidth := JFloat (Obj, 'markerStrokeWidth', MarkerStrokeWidth);
  MarkerShape       := TMarkerShape (JInt (Obj, 'markerShape', Ord (MarkerShape)));
  MarkerVisible     := JBool  (Obj, 'markerVisible',     MarkerVisible);
end;


function TPlotSeries.SaveToJson : TJSONObject;
var
  Arr, Pt : TJSONArray;
  I : Integer;
begin
  // Styling first, then append the data points as an array of [x, y] pairs.
  Result := SaveStyleToJson;

  Arr := TJSONArray.Create;
  for I := 0 to Data.Count - 1 do
    begin
    Pt := TJSONArray.Create;
    Pt.Add (Double (Data[I].X));
    Pt.Add (Double (Data[I].Y));
    Arr.AddElement (Pt);
    end;
  Result.AddPair ('data', Arr);
end;


procedure TPlotSeries.LoadFromJson (const Obj : TJSONObject);
var
  V, PtV : TJSONValue;
  Pt : TJSONArray;
begin
  if Obj = nil then Exit;

  LoadStyleFromJson (Obj);

  // Replace the data points.
  Data.Clear;
  V := Obj.GetValue ('data');
  if V is TJSONArray then
    for PtV in TJSONArray (V) do
      if (PtV is TJSONArray) and (TJSONArray (PtV).Count >= 2) then
        begin
        Pt := TJSONArray (PtV);
        if (Pt.Items[0] is TJSONNumber) and (Pt.Items[1] is TJSONNumber) then
          AddXY (TJSONNumber (Pt.Items[0]).AsDouble,
                 TJSONNumber (Pt.Items[1]).AsDouble);
        end;
end;


end.
