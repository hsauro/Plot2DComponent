unit SkPlotPaintBox;

interface

uses
  System.SysUtils,
  System.StrUtils,
  System.Classes,
  System.Rtti,
  System.JSON,
  Generics.Collections,
  Types,
  System.UIConsts,
  System.UITypes,
  FMX.Types,
  FMX.Menus,
  FMX.Controls,
  FMX.Forms,
  FMX.Platform,
  FMX.Graphics,
  Skia,
  FMX.Skia,
  uCSVReaderForPlotter,
  uColorManager,
  uPlotSeries,
  uPlotMapper,
  uPlotAnnotation,
  uPlotDefaults;

type
  TOnReportCoordinates = procedure(mousex, mousey, Worldx, Worldy : single) of object;

  // Fired when the user clicks near an actual data point (within PickTolerance
  // pixels). Unlike OnReportCoordinates — which reports the cursor's world
  // position — this hands back the *exact* stored data value of the closest
  // point, so a click near a fold on a bifurcation diagram yields e.g.
  // B = 24.384900179508524 rather than whatever pixel the cursor was over.
  // Series is the owning curve, Index is the point's position in Series.Data,
  // and DataX/DataY are its full double-precision coordinates.
  TOnPointPicked = procedure(Sender: TObject; Series: TPlotSeries; Index: Integer;
                             DataX, DataY: Double) of object;

  // Drawing of tick mark options
  TTickmarkDrawing = (tmOut, tmIn, tmBoth);

  // -----------------------------------------------------------------------
  //  TAxisLimits — manual axis range override
  // -----------------------------------------------------------------------
  TAxisLimits = class(TPersistent)
  private
    FOnChange: TNotifyEvent;
    FMinX, FMaxX: Double;
    FMinY, FMaxY: Double;
    procedure SetMinX(const Value: Double);
    procedure SetMaxX(const Value: Double);
    procedure SetMinY(const Value: Double);
    procedure SetMaxY(const Value: Double);
  protected
    procedure Changed; virtual;
  public
    constructor Create;
    procedure Assign(Source: TPersistent); override;
    function  SaveToJson: TJSONObject;
    procedure LoadFromJson(const Obj: TJSONObject);
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  published
    property MinX: Double read FMinX write SetMinX;
    property MaxX: Double read FMaxX write SetMaxX;
    property MinY: Double read FMinY write SetMinY;
    property MaxY: Double read FMaxY write SetMaxY;
  end;

  // -----------------------------------------------------------------------
  //  TAxisStyle — Things like tick styling
  // -----------------------------------------------------------------------
  TAxisStyle = class (TPersistent)
     private
      FOnChange: TNotifyEvent;

      FLogX,  FLogY:     Boolean;
      FXMajorTicksVisible : Boolean;
      FXMinorTicksVisible : Boolean;
      FYMajorTicksVisible : Boolean;
      FYMinorTicksVisible : Boolean;

      FXMajorTickLength: Single;
      FXMinorTickLength: Single;
      FYMajorTickLength: Single;
      FYMinorTickLength: Single;

      FXTickDrawing : TTickmarkDrawing;
      FYTickDrawing : TTickmarkDrawing;

      procedure SetLogX(Value: Boolean);
      procedure SetLogY(Value: Boolean);

      procedure SetXMajorTicksVisible (Value : Boolean);
      procedure SetXMinorTicksVisible (Value : Boolean);
      procedure SetYMajorTicksVisible (Value : Boolean);
      procedure SetYMinorTicksVisible (Value : Boolean);

      procedure SetXMajorTickLength(Value: Single);
      procedure SetXMinorTickLength(Value: Single);
      procedure SetYMajorTickLength(Value: Single);
      procedure SetYMinorTickLength(Value: Single);

      procedure SetXTickDrawing (Value : TTickmarkDrawing);
      procedure SetYTickDrawing (Value : TTickmarkDrawing);

     protected
      procedure Changed; virtual;
     public
      property OnChange: TNotifyEvent read FOnChange write FOnChange;
      constructor Create;
      procedure Assign(Source: TPersistent); override;
      function  SaveToJson: TJSONObject;
      procedure LoadFromJson(const Obj: TJSONObject);
     published
      property LogX: Boolean read FLogX write SetLogX;
      property LogY: Boolean read FLogY write SetLogY;
      property XMajorTicksVisible: Boolean read FXMajorTicksVisible write SetXMajorTicksVisible default True;
      property XMinorTicksVisible: Boolean read FXMinorTicksVisible write SetXMinorTicksVisible default True;
      property YMajorTicksVisible: Boolean read FYMajorTicksVisible write SetYMajorTicksVisible default True;
      property YMinorTicksVisible: Boolean read FYMinorTicksVisible write SetYMinorTicksVisible default True;

      property XMajorTickLength: Single read FXMajorTickLength write SetXMajorTickLength;
      property XMinorTickLength: Single read FXMinorTickLength write SetXMinorTickLength;
      property YMajorTickLength: Single read FYMajorTickLength write SetYMajorTickLength;
      property YMinorTickLength: Single read FYMinorTickLength write SetYMinorTickLength;

      property XTickDrawing: TTickmarkDrawing read FXTickDrawing write SetXTickDrawing default tmOut;
      property YTickDrawing: TTickmarkDrawing read FYTickDrawing write SetYTickDrawing default tmOut;
  end;

  // -----------------------------------------------------------------------
  //  TTextProperty — title / label text with styling
  // -----------------------------------------------------------------------
  TTextProperty = class(TPersistent)
  private
    FText:     String;
    FVisible:  Boolean;
    FColor:    TAlphaColor;
    FFontSize: Single;

    procedure SetFontSize (Size : Single);
  public
    constructor Create(AText: String; AFontSize : Single);
    function  SaveToJson: TJSONObject;
    procedure LoadFromJson(const Obj: TJSONObject);
  published
    property Text:     String      read FText     write FText;
    property Visible:  Boolean     read FVisible  write FVisible;
    property Color:    TAlphaColor read FColor    write FColor;
    property FontSize: Single      read FFontSize write SetFontSize;
  end;

  // -----------------------------------------------------------------------
  //  TGridStyle — all grid rendering preferences, split by axis
  // -----------------------------------------------------------------------
  TGridStyle = class(TPersistent)
  private
    FOnChange: TNotifyEvent;

    FXMajorVisible: Boolean;
    FYMajorVisible: Boolean;
    FXMinorVisible: Boolean;
    FYMinorVisible: Boolean;

    FXMajorColor: TAlphaColor;
    FYMajorColor: TAlphaColor;
    FXMinorColor: TAlphaColor;
    FYMinorColor: TAlphaColor;

    FXMajorWidth: Single;
    FYMajorWidth: Single;
    FXMinorWidth: Single;
    FYMinorWidth: Single;

    FXMinorDivisions: Integer;
    FYMinorDivisions: Integer;

    FXMajorDivisions: Integer;
    FYMajorDivisions: Integer;

    procedure SetXMajorVisible(Value: Boolean);
    procedure SetYMajorVisible(Value: Boolean);
    procedure SetXMinorVisible(Value: Boolean);
    procedure SetYMinorVisible(Value: Boolean);
    procedure SetXMajorColor(Value: TAlphaColor);
    procedure SetYMajorColor(Value: TAlphaColor);
    procedure SetXMinorColor(Value: TAlphaColor);
    procedure SetYMinorColor(Value: TAlphaColor);
    procedure SetXMajorWidth(Value: Single);
    procedure SetYMajorWidth(Value: Single);
    procedure SetXMinorWidth(Value: Single);
    procedure SetYMinorWidth(Value: Single);
    procedure SetXMinorDivisions(Value: Integer);
    procedure SetYMinorDivisions(Value: Integer);
    procedure SetXMajorDivisions(Value: Integer);
    procedure SetYMajorDivisions(Value: Integer);
  protected
    procedure Changed; virtual;
  public
    constructor Create;
    function  SaveToJson: TJSONObject;
    procedure LoadFromJson(const Obj: TJSONObject);
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  published
    property XMajorVisible: Boolean    read FXMajorVisible write SetXMajorVisible;
    property YMajorVisible: Boolean    read FYMajorVisible write SetYMajorVisible;
    property XMinorVisible: Boolean    read FXMinorVisible write SetXMinorVisible;
    property YMinorVisible: Boolean    read FYMinorVisible write SetYMinorVisible;
    property XMajorColor:   TAlphaColor read FXMajorColor  write SetXMajorColor;
    property YMajorColor:   TAlphaColor read FYMajorColor  write SetYMajorColor;
    property XMinorColor:   TAlphaColor read FXMinorColor  write SetXMinorColor;
    property YMinorColor:   TAlphaColor read FYMinorColor  write SetYMinorColor;
    property XMajorWidth:   Single      read FXMajorWidth  write SetXMajorWidth;
    property YMajorWidth:   Single      read FYMajorWidth  write SetYMajorWidth;
    property XMinorWidth:   Single      read FXMinorWidth  write SetXMinorWidth;
    property YMinorWidth:   Single      read FYMinorWidth  write SetYMinorWidth;
    property XMinorDivisions: Integer   read FXMinorDivisions write SetXMinorDivisions;
    property YMinorDivisions: Integer   read FYMinorDivisions write SetYMinorDivisions;
    property XMajorDivisions: Integer   read FXMajorDivisions write SetXMajorDivisions;
    property YMajorDivisions: Integer   read FYMajorDivisions write SetYMajorDivisions;
  end;

  // -----------------------------------------------------------------------
  //  TLegendStyle — all legend rendering preferences
  // -----------------------------------------------------------------------
  TLegendLocation = (llTopRight, llTopLeft, llBottomRight, llBottomLeft);

  TLegendStyle = class(TPersistent)
  private
    FVisible:           Boolean;
    FBorderVisible:     Boolean;
    FBorderColor:       TAlphaColor;
    FBorderWidth:       Single;
    FBackgroundColor:   TAlphaColor;
    FBackgroundOpacity: Single;
    FLocation:          TLegendLocation;
  public
    constructor Create;
    function  SaveToJson: TJSONObject;
    procedure LoadFromJson(const Obj: TJSONObject);
  published
    property Visible:           Boolean         read FVisible           write FVisible;
    property BorderVisible:     Boolean         read FBorderVisible     write FBorderVisible;
    property BorderColor:       TAlphaColor     read FBorderColor       write FBorderColor;
    property BorderWidth:       Single          read FBorderWidth       write FBorderWidth;
    property BackgroundColor:   TAlphaColor     read FBackgroundColor   write FBackgroundColor;
    property BackgroundOpacity: Single          read FBackgroundOpacity write FBackgroundOpacity;
    property Location:          TLegendLocation read FLocation          write FLocation;
  end;

  // -----------------------------------------------------------------------
  //  TSkPlotPaintBox — the chart component
  // -----------------------------------------------------------------------
  TPlotSeriesList = class (TObjectList<TPlotSeries>)
       function Find (Name : string; Out Index : Integer) : Boolean;
  end;

  // -----------------------------------------------------------------------
  //  TPlotSettings — an opaque, in-memory snapshot of a plot's styling
  //  (no data points). Produced and consumed only by TSkPlotPaintBox via
  //  its named settings store; callers never construct or free it directly.
  //  Internally it just holds the styling JSON the component knows how to
  //  read back.
  // -----------------------------------------------------------------------
  TPlotSettings = class
  private
    FJson: TJSONObject;   // owned; the captured styling
  public
    constructor Create(AJson: TJSONObject);   // takes ownership of AJson
    destructor  Destroy; override;
  end;

  TSkPlotPaintBox = class(TSkPaintBox)
  private
    FSubAxisProperty:  TAxisLimits;
    FAxisStyle:        TAxisStyle;
    FSeriesList:       TPlotSeriesList;
    FAnnotations:      TPlotAnnotationList;
    FGridStyle:        TGridStyle;
    FLegendStyle:      TLegendStyle;

    FAutoX, FAutoY:    Boolean;
    FOriginOnAxis:     Boolean;

    FChartTitle: TTextProperty;
    FXAxisTitle: TTextProperty;
    FYAxisTitle: TTextProperty;

    FXAxisFontSize  : Single;
    FYAxisFontSize  : Single;

    FPlotAreaColor:     TAlphaColor;
    FPlotBorderColor:   TAlphaColor;
    FPlotBorderWidth:   Single;
    FPlotBorderVisible: Boolean;

    FBackgroundColor : TAlphaColor;

    FOnReportCoordinates : TOnReportCoordinates;
    FOnPointPicked       : TOnPointPicked;
    FPickTolerance       : Single;   // pixel radius for the nearest-point pick

    FLastMapper:  TPlotMapper;
    FHasMapper:   Boolean;

    // Interactive zoom / pan. Off by default — a plain data plot doesn't need
    // it, but a bifurcation diagram benefits from scrolling into a fold.
    // When ZoomPanEnabled is True, the wheel zooms around the cursor, a plain
    // left-drag pans, and a Shift+left-drag rubber-bands a zoom rectangle; all
    // write an explicit view window (FViewRect, in data coordinates) that
    // overrides autoscale / manual limits until ResetZoom.
    FZoomPanEnabled:   Boolean;
    FViewRect:         TRectD;     // active view window (data coords)
    FHasViewOverride:  Boolean;    // FViewRect is in force
    FLastMousePos:     TPointF;    // cursor pos (wheel gives no coordinates)
    // Left-button pan tracking, kept separate from the legend drag.
    FPanCandidate:     Boolean;    // left button down over the plot area
    FPanning:          Boolean;    // movement passed the drag threshold
    FDidPan:           Boolean;    // this press produced a pan (suppress pick)
    FPanStartPos:      TPointF;    // cursor pos when the button went down
    FPanStartMapper:   TPlotMapper; // mapper snapshot at press (drift-free pan)
    // Shift + left-drag rubber-band box zoom — a trackpad-friendly alternative
    // to the wheel. Active only between MouseDown and MouseUp; on release the
    // boxed region becomes the new view window (same FViewRect override path).
    FBoxZooming:       Boolean;    // a box-zoom drag is in progress
    FBoxZoomStart:     TPointF;    // press position (pixels)
    FBoxZoomCur:       TPointF;    // current cursor position (pixels)
    FBoxZoomMapper:    TPlotMapper; // mapper snapshot at press (pixel -> data)

    FPaintBoxMenu: TPopupMenu;

    // Legend drag support
    FLegendOffset:      TPointF;   // cumulative drag offset from anchor position
    FLegendRect:        TRectF;    // last-drawn legend rect, used for hit-testing
    FDraggingLegend:    Boolean;
    FLegendDragStart:   TPointF;   // mouse position when drag began
    FLegendOffsetStart: TPointF;   // FLegendOffset value when drag began

    // Series defaults
    FDefaultsFile: String;

    // In-memory named settings store (styling snapshots, no data). Owns the
    // TPlotSettings values and frees them on destroy / removal.
    FSettingsStore: TObjectDictionary<string, TPlotSettings>;

    procedure SetDefaultsFile(const Value: String);
    // Build a styling-only snapshot of the current plot state.
    function  CaptureStylingJson: TJSONObject;
    // Apply a styling-only snapshot; per-series styling is matched by Name.
    procedure ApplyStylingJson(const Root: TJSONObject);

    procedure DoExportPDF (Sender : TObject);
    procedure DoExportPNG (Sender : TObject);
    procedure DoCopyImageToClipboard (Sender: TObject);

    procedure SetAxisStyleProperty(Value: TAxisStyle);

    procedure SetSubAxisProperty(Value: TAxisLimits);
    procedure SubMaxXChanged(Sender: TObject);
    procedure AxisStyleChanged(Sender: TObject);
    procedure GridStyleChanged(Sender: TObject);

    function GetSceneScale: Single;

    procedure DrawLegend(const ACanvas: ISkCanvas; const AMapper: TPlotMapper);
    procedure DrawAnnotations(const ACanvas: ISkCanvas; const AMapper: TPlotMapper);
    procedure DrawGrid(const ACanvas: ISkCanvas; const AMapper: TPlotMapper;
                       ABorderColor: TAlphaColor; ABorderWidth: Single;
                       ABorderVisible: Boolean);
    function  GetEffectiveDataBounds: TRectD;
    function  CalculateDataBounds: TRectD;
    // Find the data point closest (in pixels) to (APixelX, APixelY). Returns
    // True and fills the out params when a point lies within PickTolerance;
    // False otherwise. Skips invisible series and NaN pen-lift separators.
    function  FindNearestPoint(APixelX, APixelY: Single; out ASeries: TPlotSeries;
                               out AIndex: Integer; out ADataX, ADataY: Double): Boolean;
    procedure SetZoomPanEnabled(Value: Boolean);
    // Zoom the current view by AFactor (<1 zooms in) about pixel (ACx, ACy),
    // seeding the view window from the last-drawn mapper if none is active.
    procedure ZoomAboutPixel(ACx, ACy, AFactor: Single);
    // Draw the live rubber-band rectangle while a Shift+drag box zoom is active.
    procedure DrawZoomBox(const ACanvas: ISkCanvas);
    procedure RenderChart(const ACanvas: ISkCanvas; const ADest: TRectF);
  protected
    procedure Draw(const ACanvas: ISkCanvas; const ADest: TRectF;
                   const AOpacity: Single); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Single); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure MouseUp  (Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure MouseWheel(Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean); override;
    procedure DblClick; override;
  public
    procedure AddSeries(NewSeries: TPlotSeries);
    procedure ClearSeries;

    // Data-anchored text annotations (e.g. bifurcation labels LP1/H1/BP2).
    // AddAnnotation creates a label anchored to (AX, AY) in data coordinates,
    // adds it to the Annotations collection, triggers a redraw, and returns
    // the new object so the caller can tune its offset/style. The collection
    // owns every annotation and frees them on ClearAnnotations / destroy.
    function  AddAnnotation(const AText: string; AX, AY: Double): TPlotAnnotation;
    procedure ClearAnnotations;
    procedure SetOriginOnAxis(Value: Boolean);

    // Drop any interactive zoom/pan view window and return to the normal
    // autoscale / manual-limits behaviour. Also bound to a double-click while
    // ZoomPanEnabled. Safe to call when no override is active.
    procedure ResetZoom;
    procedure ExportToPng(FileName: String; ScaleFactor: Single);
    procedure ExportToPdf(FileName: String);
    procedure ResetLegendPosition;
    procedure ClearSeriesKind (SeriesKind : TSeriesKind);

    // Reload series styling defaults from DefaultsFile (or built-ins if the
    // file cannot be found).  Call this before adding series to the chart.
    procedure ReloadDefaults;

    // Save the entire plot — every styling sub-object plus all series and
    // their data points — to a JSON file, and restore it again.  LoadPlotFromFile
    // replaces the current series and overwrites all settings; keys absent from
    // the file keep their current value.
    procedure SavePlotToFile(const FileName: String);
    procedure LoadPlotFromFile(const FileName: String);

    // In-memory settings store. Lets a host application snapshot the current
    // plot styling (colours, axis / grid / legend style, limits, titles and
    // per-series appearance — but NOT the data points) under a string key,
    // then restore it later. Typical use: one key per analysis, so switching
    // analyses and returning brings back the styling the user last set.
    //
    // The component owns every snapshot and frees them all on destroy; the
    // caller only ever passes keys, never object references.
    //   SaveSettings    - capture current styling under Key (overwrites Key).
    //   RestoreSettings - re-apply Key's styling; False if Key is unknown.
    //   HasSettings     - True if Key exists.
    //   DeleteSettings  - drop one key (no error if absent).
    //   ClearAllSettings- drop every stored snapshot.
    //   SettingsKeys    - all keys currently stored.
    procedure SaveSettings(const Key: string);
    function  RestoreSettings(const Key: string): Boolean;
    function  HasSettings(const Key: string): Boolean;
    procedure DeleteSettings(const Key: string);
    procedure ClearAllSettings;
    function  SettingsKeys: TArray<string>;
  published
    constructor Create(AOwner: TComponent); override;
    destructor  Destroy; override;

    function LoadData(const FileName: String; LineVisible : Boolean; MarkerVisible: Boolean; ClearSeries : Boolean; ClearDataKinds : Boolean) : TStringList;
    procedure ExportCSV(FileName: String; SharedXColumn: Boolean = True);
    procedure ExportCSVSeries(Directory: String);
    function ExportCSVSeriesAsString (const ADecimalPlaces: Integer; MinColumnWidth : Integer = 12) : String;

    property OnReportCoordinates : TOnReportCoordinates read FOnReportCoordinates write FOnReportCoordinates;

    // Fired on a left-click that lands within PickTolerance pixels of a stored
    // data point. Reports the exact data value of the nearest point.
    property OnPointPicked : TOnPointPicked read FOnPointPicked write FOnPointPicked;
    // Pixel radius used to decide whether a click counts as a pick. Default 8.
    property PickTolerance : Single read FPickTolerance write FPickTolerance;

    // Enable interactive zoom (mouse wheel, about the cursor) and pan
    // (left-drag). Off by default. Double-click resets to autoscale. Turning
    // this off also clears any active zoom/pan view window.
    property ZoomPanEnabled : Boolean read FZoomPanEnabled write SetZoomPanEnabled default False;

    property AxisLimits: TAxisLimits read FSubAxisProperty write SetSubAxisProperty;
    property AxisStyle: TAxisStyle read FAxisStyle write SetAxisStyleProperty;
    property GridStyle:      TGridStyle   read FGridStyle;
    property LegendStyle:    TLegendStyle read FLegendStyle;

    property AutoXScaling: Boolean read FAutoX write FAutoX;
    property AutoYScaling: Boolean read FAutoY write FAutoY;

    property ChartTitle: TTextProperty read FChartTitle write FChartTitle;
    property XAxisTitle: TTextProperty read FXAxisTitle write FXAxisTitle;
    property YAxisTitle: TTextProperty read FYAxisTitle write FYAxisTitle;

    property XAxisFontSize: Single read FXAxisFontSize write FXAxisFontSize;
    property YAxisFontSize: Single read FYAxisFontSize write FYAxisFontSize;

    property OriginOnAxis: Boolean read FOriginOnAxis write SetOriginOnAxis;

    property PlotAreaColor:     TAlphaColor read FPlotAreaColor     write FPlotAreaColor;
    property PlotBorderColor:   TAlphaColor read FPlotBorderColor   write FPlotBorderColor;
    property PlotBorderWidth:   Single      read FPlotBorderWidth   write FPlotBorderWidth;
    property PlotBorderVisible: Boolean     read FPlotBorderVisible write FPlotBorderVisible;
    property BackGroundColor:   TAlphaColor read FBackgroundColor   write FBackgroundColor;

    property Series: TPlotSeriesList read FSeriesList;
    property Annotations: TPlotAnnotationList read FAnnotations;

    // Path to a JSON file that overrides the default series styling.
    // Setting this property immediately reloads the defaults.
    property DefaultsFile: String read FDefaultsFile write SetDefaultsFile;
  end;

  const
  TickDrawingNames: array[TTickmarkDrawing] of string = (
      'Draw Out',
      'Draw In',
      'Draw Both ways'
  );

implementation

uses FMX.Dialogs, Math, System.IOUtils, uPlotJsonUtils;

// -----------------------------------------------------------------------
//  Utility
// -----------------------------------------------------------------------

function CalculateNiceStep(ARange: Double; ATargetSteps: Integer): Double;
var
  RawStep, Exponent, Fraction: Double;
begin
  if ARange <= 0 then Exit(1.0);
  RawStep  := ARange / ATargetSteps;
  Exponent := Floor(Log10(RawStep));
  Fraction := RawStep / Power(10, Exponent);
  if      Fraction < 1.5 then Fraction := 1
  else if Fraction < 3   then Fraction := 2
  else if Fraction < 7   then Fraction := 5
  else                        Fraction := 10;
  Result := Fraction * Power(10, Exponent);
end;

// -----------------------------------------------------------------------
//  Series List
// -----------------------------------------------------------------------

function TPlotSeriesList.Find (Name : string; out Index : Integer) : Boolean;
begin
  for var i := 0 to Count - 1 do
      if SameText (Items[i].Name, Name) then
         begin
         Index := i;
         Exit (True);
         end;
  Exit(False)
end;

// -----------------------------------------------------------------------
//  TTextProperty
// -----------------------------------------------------------------------

constructor TTextProperty.Create(AText: String; AFontSize : Single);
begin
  inherited Create;
  FText     := AText;
  FVisible  := True;
  FColor    := claBlack;
  FFontSize := AFontSize;
end;

procedure TTextProperty.SetFontSize (Size : Single);
begin
  FFontSize := Size;
end;

function TTextProperty.SaveToJson: TJSONObject;
begin
  Result := TJSONObject.Create;
  JPutStr  (Result, 'text',     FText);
  JPutBool (Result, 'visible',  FVisible);
  JPutColor(Result, 'color',    FColor);
  JPutFloat(Result, 'fontSize', FFontSize);
end;

procedure TTextProperty.LoadFromJson(const Obj: TJSONObject);
begin
  if Obj = nil then Exit;
  FText     := JStr  (Obj, 'text',     FText);
  FVisible  := JBool (Obj, 'visible',  FVisible);
  FColor    := JColor(Obj, 'color',    FColor);
  FFontSize := JFloat(Obj, 'fontSize', FFontSize);
end;

// -----------------------------------------------------------------------
//  TAxisLimits
// -----------------------------------------------------------------------

constructor TAxisLimits.Create;
begin
  inherited Create;
  // Default manual axis window; overridden once data is loaded or the
  // user sets explicit limits.
  FMinX := 0.0;  FMaxX := 1.0;
  FMinY := 0.0;  FMaxY := 1.0;
end;

procedure TAxisLimits.Changed;
begin
  if Assigned(FOnChange) then FOnChange(Self);
end;

procedure TAxisLimits.SetMinX(const Value: Double);
begin
  if FMinX <> Value then begin FMinX := Value; Changed; end;
end;

procedure TAxisLimits.SetMaxX(const Value: Double);
begin
  if FMaxX <> Value then begin FMaxX := Value; Changed; end;
end;

procedure TAxisLimits.SetMinY(const Value: Double);
begin
  if FMinY <> Value then begin FMinY := Value; Changed; end;
end;

procedure TAxisLimits.SetMaxY(const Value: Double);
begin
  if FMaxY <> Value then begin FMaxY := Value; Changed; end;
end;

procedure TAxisLimits.Assign(Source: TPersistent);
begin
  if Source is TAxisLimits then
  begin
    FMinX := TAxisLimits(Source).FMinX;
    FMaxX := TAxisLimits(Source).FMaxX;
    FMinY := TAxisLimits(Source).FMinY;
    FMaxY := TAxisLimits(Source).FMaxY;
    Changed;
  end
  else
    inherited Assign(Source);   // raises the standard "cannot assign" error
end;

function TAxisLimits.SaveToJson: TJSONObject;
begin
  Result := TJSONObject.Create;
  JPutFloat(Result, 'minX', FMinX);
  JPutFloat(Result, 'maxX', FMaxX);
  JPutFloat(Result, 'minY', FMinY);
  JPutFloat(Result, 'maxY', FMaxY);
end;

procedure TAxisLimits.LoadFromJson(const Obj: TJSONObject);
begin
  if Obj = nil then Exit;
  FMinX := JFloat(Obj, 'minX', FMinX);
  FMaxX := JFloat(Obj, 'maxX', FMaxX);
  FMinY := JFloat(Obj, 'minY', FMinY);
  FMaxY := JFloat(Obj, 'maxY', FMaxY);
  Changed;
end;

// -----------------------------------------------------------------------
//  TAxisStyle
// -----------------------------------------------------------------------


constructor TAxisStyle.Create;
begin
  inherited Create;
  FLogX  := False;
  FLogY  := False;
  FXMajorTicksVisible := True;
  FXMinorTicksVisible := True;
  FYMajorTicksVisible := True;
  FYMinorTicksVisible := True;

  FXMajorTickLength := 8;
  FXMinorTickLength := 5;
  FYMajorTickLength := 8;
  FYMinorTickLength := 5;

  FXTickDrawing := tmOut;
  FYTickDrawing := tmOut;
end;


procedure TAxisStyle.Assign(Source: TPersistent);
begin
  if Source is TAxisStyle then
  begin
    FLogX               := TAxisStyle(Source).FLogX;
    FLogY               := TAxisStyle(Source).FLogY;
    FXMajorTicksVisible := TAxisStyle(Source).FXMajorTicksVisible;
    FXMinorTicksVisible := TAxisStyle(Source).FXMinorTicksVisible;
    FYMajorTicksVisible := TAxisStyle(Source).FYMajorTicksVisible;
    FYMinorTicksVisible := TAxisStyle(Source).FYMinorTicksVisible;
    FXMajorTickLength   := TAxisStyle(Source).FXMajorTickLength;
    FXMinorTickLength   := TAxisStyle(Source).FXMinorTickLength;
    FYMajorTickLength   := TAxisStyle(Source).FYMajorTickLength;
    FYMinorTickLength   := TAxisStyle(Source).FYMinorTickLength;
    FXTickDrawing       := TAxisStyle(Source).FXTickDrawing;
    FYTickDrawing       := TAxisStyle(Source).FYTickDrawing;
    Changed;
  end
  else
    inherited Assign(Source);   // raises the standard "cannot assign" error
end;

function TAxisStyle.SaveToJson: TJSONObject;
begin
  Result := TJSONObject.Create;
  JPutBool (Result, 'logX',               FLogX);
  JPutBool (Result, 'logY',               FLogY);
  JPutBool (Result, 'xMajorTicksVisible', FXMajorTicksVisible);
  JPutBool (Result, 'xMinorTicksVisible', FXMinorTicksVisible);
  JPutBool (Result, 'yMajorTicksVisible', FYMajorTicksVisible);
  JPutBool (Result, 'yMinorTicksVisible', FYMinorTicksVisible);
  JPutFloat(Result, 'xMajorTickLength',   FXMajorTickLength);
  JPutFloat(Result, 'xMinorTickLength',   FXMinorTickLength);
  JPutFloat(Result, 'yMajorTickLength',   FYMajorTickLength);
  JPutFloat(Result, 'yMinorTickLength',   FYMinorTickLength);
  JPutInt  (Result, 'xTickDrawing',       Ord(FXTickDrawing));
  JPutInt  (Result, 'yTickDrawing',       Ord(FYTickDrawing));
end;

procedure TAxisStyle.LoadFromJson(const Obj: TJSONObject);
begin
  if Obj = nil then Exit;
  FLogX               := JBool (Obj, 'logX',               FLogX);
  FLogY               := JBool (Obj, 'logY',               FLogY);
  FXMajorTicksVisible := JBool (Obj, 'xMajorTicksVisible', FXMajorTicksVisible);
  FXMinorTicksVisible := JBool (Obj, 'xMinorTicksVisible', FXMinorTicksVisible);
  FYMajorTicksVisible := JBool (Obj, 'yMajorTicksVisible', FYMajorTicksVisible);
  FYMinorTicksVisible := JBool (Obj, 'yMinorTicksVisible', FYMinorTicksVisible);
  FXMajorTickLength   := JFloat(Obj, 'xMajorTickLength',   FXMajorTickLength);
  FXMinorTickLength   := JFloat(Obj, 'xMinorTickLength',   FXMinorTickLength);
  FYMajorTickLength   := JFloat(Obj, 'yMajorTickLength',   FYMajorTickLength);
  FYMinorTickLength   := JFloat(Obj, 'yMinorTickLength',   FYMinorTickLength);
  FXTickDrawing       := TTickmarkDrawing(JInt(Obj, 'xTickDrawing', Ord(FXTickDrawing)));
  FYTickDrawing       := TTickmarkDrawing(JInt(Obj, 'yTickDrawing', Ord(FYTickDrawing)));
  Changed;
end;

procedure TAxisStyle.Changed;
begin
  if Assigned(FOnChange) then FOnChange(Self);
end;

procedure TAxisStyle.SetLogX(Value: Boolean);
begin
  if FLogX <> Value then begin FLogX := Value; Changed; end;
end;

procedure TAxisStyle.SetLogY(Value: Boolean);
begin
  if FLogY <> Value then begin FLogY := Value; Changed; end;
end;


procedure TAxisStyle.SetXMajorTicksVisible (Value : Boolean);
begin
  if FXMajorTicksVisible <> Value then begin FXMajorTicksVisible := Value; Changed; end;
end;


procedure TAxisStyle.SetXMinorTicksVisible (Value : Boolean);
begin
  if FXMinorTicksVisible <> Value then begin FXMinorTicksVisible := Value; Changed; end;
end;


procedure TAxisStyle.SetYMajorTicksVisible (Value : Boolean);
begin
  if FYMajorTicksVisible <> Value then begin FYMajorTicksVisible := Value; Changed; end;
end;


procedure TAxisStyle.SetYMinorTicksVisible (Value : Boolean);
begin
  if FYMinorTicksVisible <> Value then begin FYMinorTicksVisible := Value; Changed; end;
end;

procedure TAxisStyle.SetXMajorTickLength(Value: Single);
begin
  if (FXMajorTickLength <> Value) and (Value >= 0) then
  begin FXMajorTickLength := Value; Changed; end;
end;

procedure TAxisStyle.SetXMinorTickLength(Value: Single);
begin
  if (FXMinorTickLength <> Value) and (Value >= 0) then
  begin FXMinorTickLength := Value; Changed; end;
end;

procedure TAxisStyle.SetYMajorTickLength(Value: Single);
begin
  if (FYMajorTickLength <> Value) and (Value >= 0) then
  begin FYMajorTickLength := Value; Changed; end;
end;

procedure TAxisStyle.SetYMinorTickLength(Value: Single);
begin
  if (FYMinorTickLength <> Value) and (Value >= 0) then
  begin FYMinorTickLength := Value; Changed; end;
end;


procedure TAxisStyle.SetXTickDrawing (Value : TTickmarkDrawing);
begin
  if FXTickDrawing <> Value then
     begin FXTickDrawing := Value; Changed; end
end;


procedure TAxisStyle.SetYTickDrawing (Value : TTickmarkDrawing);
begin
  if FYTickDrawing <> Value then
     begin FYTickDrawing := Value; Changed; end
end;

// -----------------------------------------------------------------------
//  TGridStyle
// -----------------------------------------------------------------------

constructor TGridStyle.Create;
begin
  inherited Create;
  FXMajorVisible := True;
  FYMajorVisible := True;
  FXMinorVisible := False;
  FYMinorVisible := False;
  FXMajorColor   := TAlphaColors.Gray;
  FYMajorColor   := TAlphaColors.Gray;
  FXMinorColor   := TAlphaColorRec.LightGrey;
  FYMinorColor   := TAlphaColorRec.LightGrey;
  FXMajorWidth   := 1.0;
  FYMajorWidth   := 1.0;
  FXMinorWidth   := 0.5;
  FYMinorWidth   := 0.5;
  FXMinorDivisions := 5;
  FYMinorDivisions := 5;
  FXMajorDivisions := 5;
  FYMajorDivisions := 5;
end;

procedure TGridStyle.Changed;
begin
  if Assigned(FOnChange) then FOnChange(Self);
end;

function TGridStyle.SaveToJson: TJSONObject;
begin
  Result := TJSONObject.Create;
  JPutBool (Result, 'xMajorVisible',   FXMajorVisible);
  JPutBool (Result, 'yMajorVisible',   FYMajorVisible);
  JPutBool (Result, 'xMinorVisible',   FXMinorVisible);
  JPutBool (Result, 'yMinorVisible',   FYMinorVisible);
  JPutColor(Result, 'xMajorColor',     FXMajorColor);
  JPutColor(Result, 'yMajorColor',     FYMajorColor);
  JPutColor(Result, 'xMinorColor',     FXMinorColor);
  JPutColor(Result, 'yMinorColor',     FYMinorColor);
  JPutFloat(Result, 'xMajorWidth',     FXMajorWidth);
  JPutFloat(Result, 'yMajorWidth',     FYMajorWidth);
  JPutFloat(Result, 'xMinorWidth',     FXMinorWidth);
  JPutFloat(Result, 'yMinorWidth',     FYMinorWidth);
  JPutInt  (Result, 'xMinorDivisions', FXMinorDivisions);
  JPutInt  (Result, 'yMinorDivisions', FYMinorDivisions);
  JPutInt  (Result, 'xMajorDivisions', FXMajorDivisions);
  JPutInt  (Result, 'yMajorDivisions', FYMajorDivisions);
end;

procedure TGridStyle.LoadFromJson(const Obj: TJSONObject);
begin
  if Obj = nil then Exit;
  FXMajorVisible   := JBool (Obj, 'xMajorVisible',   FXMajorVisible);
  FYMajorVisible   := JBool (Obj, 'yMajorVisible',   FYMajorVisible);
  FXMinorVisible   := JBool (Obj, 'xMinorVisible',   FXMinorVisible);
  FYMinorVisible   := JBool (Obj, 'yMinorVisible',   FYMinorVisible);
  FXMajorColor     := JColor(Obj, 'xMajorColor',     FXMajorColor);
  FYMajorColor     := JColor(Obj, 'yMajorColor',     FYMajorColor);
  FXMinorColor     := JColor(Obj, 'xMinorColor',     FXMinorColor);
  FYMinorColor     := JColor(Obj, 'yMinorColor',     FYMinorColor);
  FXMajorWidth     := JFloat(Obj, 'xMajorWidth',     FXMajorWidth);
  FYMajorWidth     := JFloat(Obj, 'yMajorWidth',     FYMajorWidth);
  FXMinorWidth     := JFloat(Obj, 'xMinorWidth',     FXMinorWidth);
  FYMinorWidth     := JFloat(Obj, 'yMinorWidth',     FYMinorWidth);
  FXMinorDivisions := JInt  (Obj, 'xMinorDivisions', FXMinorDivisions);
  FYMinorDivisions := JInt  (Obj, 'yMinorDivisions', FYMinorDivisions);
  FXMajorDivisions := JInt  (Obj, 'xMajorDivisions', FXMajorDivisions);
  FYMajorDivisions := JInt  (Obj, 'yMajorDivisions', FYMajorDivisions);
  Changed;
end;

procedure TGridStyle.SetXMajorVisible(Value: Boolean);
begin
  if FXMajorVisible <> Value then begin FXMajorVisible := Value; Changed; end;
end;

procedure TGridStyle.SetYMajorVisible(Value: Boolean);
begin
  if FYMajorVisible <> Value then begin FYMajorVisible := Value; Changed; end;
end;

procedure TGridStyle.SetXMinorVisible(Value: Boolean);
begin
  if FXMinorVisible <> Value then begin FXMinorVisible := Value; Changed; end;
end;

procedure TGridStyle.SetYMinorVisible(Value: Boolean);
begin
  if FYMinorVisible <> Value then begin FYMinorVisible := Value; Changed; end;
end;

procedure TGridStyle.SetXMajorColor(Value: TAlphaColor);
begin
  if FXMajorColor <> Value then begin FXMajorColor := Value; Changed; end;
end;

procedure TGridStyle.SetYMajorColor(Value: TAlphaColor);
begin
  if FYMajorColor <> Value then begin FYMajorColor := Value; Changed; end;
end;

procedure TGridStyle.SetXMinorColor(Value: TAlphaColor);
begin
  if FXMinorColor <> Value then begin FXMinorColor := Value; Changed; end;
end;

procedure TGridStyle.SetYMinorColor(Value: TAlphaColor);
begin
  if FYMinorColor <> Value then begin FYMinorColor := Value; Changed; end;
end;

procedure TGridStyle.SetXMajorWidth(Value: Single);
begin
  if FXMajorWidth <> Value then begin FXMajorWidth := Value; Changed; end;
end;

procedure TGridStyle.SetYMajorWidth(Value: Single);
begin
  if FYMajorWidth <> Value then begin FYMajorWidth := Value; Changed; end;
end;

procedure TGridStyle.SetXMinorWidth(Value: Single);
begin
  if FXMinorWidth <> Value then begin FXMinorWidth := Value; Changed; end;
end;

procedure TGridStyle.SetYMinorWidth(Value: Single);
begin
  if FYMinorWidth <> Value then begin FYMinorWidth := Value; Changed; end;
end;

procedure TGridStyle.SetXMinorDivisions(Value: Integer);
begin
  if (FXMinorDivisions <> Value) and (Value >= 2) then
  begin
    FXMinorDivisions := Value;
    Changed;
  end;
end;

procedure TGridStyle.SetYMinorDivisions(Value: Integer);
begin
  if (FYMinorDivisions <> Value) and (Value >= 2) then
  begin
    FYMinorDivisions := Value;
    Changed;
  end;
end;

procedure TGridStyle.SetXMajorDivisions(Value: Integer);
begin
  if (FXMajorDivisions <> Value) and (Value >= 1) then
  begin
    FXMajorDivisions := Value;
    Changed;
  end;
end;

procedure TGridStyle.SetYMajorDivisions(Value: Integer);
begin
  if (FYMajorDivisions <> Value) and (Value >= 1) then
  begin
    FYMajorDivisions := Value;
    Changed;
  end;
end;

// -----------------------------------------------------------------------
//  TLegendStyle
// -----------------------------------------------------------------------

constructor TLegendStyle.Create;
begin
  inherited Create;
  FVisible           := True;
  FBorderVisible     := True;
  FBorderColor       := TAlphaColors.Black;
  FBorderWidth       := 1.0;
  FBackgroundColor   := TAlphaColors.White;
  FBackgroundOpacity := 0.86;
  FLocation          := llTopRight;
end;

function TLegendStyle.SaveToJson: TJSONObject;
begin
  Result := TJSONObject.Create;
  JPutBool (Result, 'visible',           FVisible);
  JPutBool (Result, 'borderVisible',     FBorderVisible);
  JPutColor(Result, 'borderColor',       FBorderColor);
  JPutFloat(Result, 'borderWidth',       FBorderWidth);
  JPutColor(Result, 'backgroundColor',   FBackgroundColor);
  JPutFloat(Result, 'backgroundOpacity', FBackgroundOpacity);
  JPutInt  (Result, 'location',          Ord(FLocation));
end;

procedure TLegendStyle.LoadFromJson(const Obj: TJSONObject);
begin
  if Obj = nil then Exit;
  FVisible           := JBool (Obj, 'visible',           FVisible);
  FBorderVisible     := JBool (Obj, 'borderVisible',     FBorderVisible);
  FBorderColor       := JColor(Obj, 'borderColor',       FBorderColor);
  FBorderWidth       := JFloat(Obj, 'borderWidth',       FBorderWidth);
  FBackgroundColor   := JColor(Obj, 'backgroundColor',   FBackgroundColor);
  FBackgroundOpacity := JFloat(Obj, 'backgroundOpacity', FBackgroundOpacity);
  FLocation          := TLegendLocation(JInt(Obj, 'location', Ord(FLocation)));
end;

// -----------------------------------------------------------------------
//  TSkPlotPaintBox
// -----------------------------------------------------------------------

constructor TSkPlotPaintBox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  HitTest := True;

  FSubAxisProperty := TAxisLimits.Create;
  FSubAxisProperty.OnChange := SubMaxXChanged;

  FXAxisFontSize  := 14;
  FYAxisFontSize  := 14;

  FGridStyle := TGridStyle.Create;
  FGridStyle.OnChange := GridStyleChanged;

  FAxisStyle := TAxisStyle.Create;
  FAxisStyle.OnChange := AxisStyleChanged;

  FLegendStyle := TLegendStyle.Create;

  FPickTolerance := 8;

  FSeriesList := TPlotSeriesList.Create;
  FAnnotations := TPlotAnnotationList.Create;   // owns its annotations

  FChartTitle := TTextProperty.Create('Data Plot', 16);
  FXAxisTitle := TTextProperty.Create('X Axis', 14);
  FYAxisTitle := TTextProperty.Create('Y Axis', 14);

  Self.Width  := 600;
  Self.Height := 300;

  FAutoX := True;
  FAutoY := True;
  FOriginOnAxis := False;

  FPlotAreaColor     := TAlphaColors.White;
  FPlotBorderColor   := TAlphaColors.Black;
  FPlotBorderWidth   := 1.5;
  FPlotBorderVisible := True;
  FBackgroundColor   := TAlphaColors.White;

  // Legend drag initialisation
  FLegendOffset      := TPointF.Zero;
  FLegendRect        := TRectF.Empty;
  FDraggingLegend    := False;
  FLegendDragStart   := TPointF.Zero;
  FLegendOffsetStart := TPointF.Zero;

  // Defaults file — empty means use built-in values only
  FDefaultsFile := '';

  // Named settings store; doOwnsValues so freeing the dictionary (or removing
  // a key) frees the associated TPlotSettings snapshot.
  FSettingsStore := TObjectDictionary<string, TPlotSettings>.Create([doOwnsValues]);

  SetOriginOnAxis(True);
end;

destructor TSkPlotPaintBox.Destroy;
begin
  FSubAxisProperty.Free;
  FAxisStyle.Free;
  FGridStyle.Free;
  FLegendStyle.Free;
  FSeriesList.Free;
  FAnnotations.Free;
  FChartTitle.Free;
  FXAxisTitle.Free;
  FYAxisTitle.Free;
  FSettingsStore.Free;   // doOwnsValues frees every stored TPlotSettings
  inherited Destroy;
end;

//procedure TSkPlotPaintBox.Draw(const ACanvas: ISkCanvas; const ADest: TRectF;
//                                const AOpacity: Single);
//begin
//  inherited Draw(ACanvas, ADest, AOpacity);
//  RenderChart(ACanvas, ADest);
//end;

function TSkPlotPaintBox.GetSceneScale: Single;
begin
  if Scene <> nil then
    Result := Scene.GetSceneScale
  else
    Result := 1.0;
end;

procedure TSkPlotPaintBox.Draw(const ACanvas: ISkCanvas; const ADest: TRectF;
                                const AOpacity: Single);
var
  LSurface: ISkSurface;
  LImage:   ISkImage;
  LScale:   Single;
  PW, PH:   Integer;       { physical pixels }
begin
  inherited Draw(ACanvas, ADest, AOpacity);

  LScale := GetSceneScale;
  PW := Round(ADest.Width  * LScale);
  PH := Round(ADest.Height * LScale);
  if (PW <= 0) or (PH <= 0) then Exit;

  LSurface := TSkSurface.MakeRaster(PW, PH);
  if LSurface = nil then
  begin
    RenderChart(ACanvas, ADest);
    if FBoxZooming then
      DrawZoomBox(ACanvas);
    Exit;
  end;

  { Scale the offscreen canvas so RenderChart can draw in logical units
    (its existing coordinate system) but the result lands at physical
    resolution. Same trick ExportToPng uses with ScaleFactor. }
  LSurface.Canvas.Scale(LScale, LScale);
  RenderChart(LSurface.Canvas, TRectF.Create(0, 0, ADest.Width, ADest.Height));

  // Rubber-band overlay is drawn in the same logical coordinate space as the
  // chart (the surface canvas is scaled), so the raw mouse pixels line up.
  if FBoxZooming then
    DrawZoomBox(LSurface.Canvas);

  LImage := LSurface.MakeImageSnapshot;
  if LImage <> nil then
    { Destination rect is in logical points — same as ADest. The image is
      at physical pixel resolution. CoreAnimation maps physical pixels of
      the image to physical pixels of the backing store 1:1. No sampling. }
    ACanvas.DrawImageRect(LImage,
                          TRectF.Create(0, 0, PW, PH),       { source: full image, physical }
                          ADest,                              { dest: logical points }
                          TSkSamplingOptions.Create(TSkFilterMode.Nearest,
                                                    TSkMipmapMode.None));
end;


procedure TSkPlotpaintBox.ClearSeriesKind (SeriesKind : TSeriesKind);
begin
  { Remove any previous simulation series. }
  for var i := Series.Count - 1 downto 0 do
    if Series[i].SeriesKind = SeriesKind then
      Series.Delete(i);
end;


procedure TSkPlotPaintBox.SetAxisStyleProperty(Value: TAxisStyle);
begin
  FAxisStyle.Assign(Value);
end;

procedure TSkPlotPaintBox.SetSubAxisProperty(Value: TAxisLimits);
begin
  FSubAxisProperty.Assign(Value);
end;

procedure TSkPlotPaintBox.SubMaxXChanged(Sender: TObject);
begin
  Redraw;
end;

procedure TSkPlotPaintBox.AxisStyleChanged(Sender: TObject);
begin
  Redraw;
end;

procedure TSkPlotPaintBox.GridStyleChanged(Sender: TObject);
begin
  Redraw;
end;

procedure TSkPlotPaintBox.SetOriginOnAxis(Value: Boolean);
begin
  if FOriginOnAxis <> Value then begin FOriginOnAxis := Value; Redraw; end;
end;

procedure TSkPlotPaintBox.AddSeries(NewSeries: TPlotSeries);
begin
  FSeriesList.Add(NewSeries);
end;

procedure TSkPlotPaintBox.ClearSeries;
begin
  FSeriesList.Clear;
end;

function TSkPlotPaintBox.AddAnnotation(const AText: string; AX, AY: Double): TPlotAnnotation;
begin
  Result := TPlotAnnotation.Create(AText, AX, AY);
  FAnnotations.Add(Result);
  Redraw;
end;

procedure TSkPlotPaintBox.ClearAnnotations;
begin
  FAnnotations.Clear;
  Redraw;
end;

procedure TSkPlotPaintBox.ResetLegendPosition;
begin
  FLegendOffset := TPointF.Zero;
  Redraw;
end;

procedure TSkPlotPaintBox.ReloadDefaults;
begin
  // Always start from the built-in values so a missing key in the JSON
  // file does not inherit a stale value from a previous load.
  TPlotDefaultsLoader.ResetToBuiltIn;

  if FDefaultsFile <> '' then
    TPlotDefaultsLoader.LoadFromFile(FDefaultsFile);
  // Existing series are unaffected; the new defaults apply to any
  // series created after this call.
end;

procedure TSkPlotPaintBox.SavePlotToFile(const FileName: String);
var
  Root, Chart, Legend: TJSONObject;
  Arr: TJSONArray;
  S: TPlotSeries;
  A: TPlotAnnotation;
begin
  Root := TJSONObject.Create;
  try
    JPutInt(Root, 'version', 1);

    // Chart-level settings that live directly on the component.
    Chart := TJSONObject.Create;
    Chart.AddPair('title',      FChartTitle.SaveToJson);
    Chart.AddPair('xAxisTitle', FXAxisTitle.SaveToJson);
    Chart.AddPair('yAxisTitle', FYAxisTitle.SaveToJson);
    JPutFloat(Chart, 'xAxisFontSize',     FXAxisFontSize);
    JPutFloat(Chart, 'yAxisFontSize',     FYAxisFontSize);
    JPutBool (Chart, 'autoXScaling',      FAutoX);
    JPutBool (Chart, 'autoYScaling',      FAutoY);
    JPutBool (Chart, 'originOnAxis',      FOriginOnAxis);
    JPutColor(Chart, 'plotAreaColor',     FPlotAreaColor);
    JPutColor(Chart, 'plotBorderColor',   FPlotBorderColor);
    JPutFloat(Chart, 'plotBorderWidth',   FPlotBorderWidth);
    JPutBool (Chart, 'plotBorderVisible', FPlotBorderVisible);
    JPutColor(Chart, 'backgroundColor',   FBackgroundColor);
    Root.AddPair('chart', Chart);

    // Styling sub-objects each serialise themselves.
    Root.AddPair('axisLimits',  FSubAxisProperty.SaveToJson);
    Root.AddPair('axisStyle',   FAxisStyle.SaveToJson);
    Root.AddPair('gridStyle',   FGridStyle.SaveToJson);

    // The legend's manual drag offset is component state rather than part
    // of TLegendStyle, but it reads naturally alongside the legend styling,
    // so store it in the same object.
    Legend := FLegendStyle.SaveToJson;
    JPutFloat(Legend, 'offsetX', FLegendOffset.X);
    JPutFloat(Legend, 'offsetY', FLegendOffset.Y);
    Root.AddPair('legendStyle', Legend);

    // Every series with its data.
    Arr := TJSONArray.Create;
    for S in FSeriesList do
      Arr.AddElement(S.SaveToJson);
    Root.AddPair('series', Arr);

    // Data-anchored text annotations.
    Arr := TJSONArray.Create;
    for A in FAnnotations do
      Arr.AddElement(A.SaveToJson);
    Root.AddPair('annotations', Arr);

    TFile.WriteAllText(FileName, Root.Format(2));
  finally
    Root.Free;
  end;
end;

procedure TSkPlotPaintBox.LoadPlotFromFile(const FileName: String);
var
  Root:      TJSONObject;
  JSON, V, SV: TJSONValue;
  Chart:     TJSONObject;
  NewSeries: TPlotSeries;
  NewAnnotation: TPlotAnnotation;
begin
  if not TFile.Exists(FileName) then
    raise Exception.CreateFmt('Plot file not found: %s', [FileName]);

  JSON := TJSONObject.ParseJSONValue(TFile.ReadAllText(FileName));
  if not (JSON is TJSONObject) then
  begin
    JSON.Free;   // nil-safe
    raise Exception.CreateFmt('Invalid plot file: %s', [FileName]);
  end;

  Root := TJSONObject(JSON);
  try
    // Chart-level settings.
    V := Root.GetValue('chart');
    if V is TJSONObject then
    begin
      Chart := TJSONObject(V);
      if Chart.GetValue('title') is TJSONObject then
        FChartTitle.LoadFromJson(TJSONObject(Chart.GetValue('title')));
      if Chart.GetValue('xAxisTitle') is TJSONObject then
        FXAxisTitle.LoadFromJson(TJSONObject(Chart.GetValue('xAxisTitle')));
      if Chart.GetValue('yAxisTitle') is TJSONObject then
        FYAxisTitle.LoadFromJson(TJSONObject(Chart.GetValue('yAxisTitle')));
      FXAxisFontSize     := JFloat(Chart, 'xAxisFontSize',     FXAxisFontSize);
      FYAxisFontSize     := JFloat(Chart, 'yAxisFontSize',     FYAxisFontSize);
      FAutoX             := JBool (Chart, 'autoXScaling',      FAutoX);
      FAutoY             := JBool (Chart, 'autoYScaling',      FAutoY);
      FOriginOnAxis      := JBool (Chart, 'originOnAxis',      FOriginOnAxis);
      FPlotAreaColor     := JColor(Chart, 'plotAreaColor',     FPlotAreaColor);
      FPlotBorderColor   := JColor(Chart, 'plotBorderColor',   FPlotBorderColor);
      FPlotBorderWidth   := JFloat(Chart, 'plotBorderWidth',   FPlotBorderWidth);
      FPlotBorderVisible := JBool (Chart, 'plotBorderVisible', FPlotBorderVisible);
      FBackgroundColor   := JColor(Chart, 'backgroundColor',   FBackgroundColor);
    end;

    V := Root.GetValue('axisLimits');
    if V is TJSONObject then FSubAxisProperty.LoadFromJson(TJSONObject(V));
    V := Root.GetValue('axisStyle');
    if V is TJSONObject then FAxisStyle.LoadFromJson(TJSONObject(V));
    V := Root.GetValue('gridStyle');
    if V is TJSONObject then FGridStyle.LoadFromJson(TJSONObject(V));
    V := Root.GetValue('legendStyle');
    if V is TJSONObject then
    begin
      FLegendStyle.LoadFromJson(TJSONObject(V));
      FLegendOffset := TPointF.Create(
        JFloat(TJSONObject(V), 'offsetX', FLegendOffset.X),
        JFloat(TJSONObject(V), 'offsetY', FLegendOffset.Y));
    end;

    // Series replace whatever is currently loaded.
    FSeriesList.Clear;
    V := Root.GetValue('series');
    if V is TJSONArray then
      for SV in TJSONArray(V) do
        if SV is TJSONObject then
        begin
          NewSeries := TPlotSeries.Create('', TAlphaColors.Black);
          NewSeries.LoadFromJson(TJSONObject(SV));
          FSeriesList.Add(NewSeries);
        end;

    // Annotations likewise replace the current set. Absent from older files
    // simply leaves the collection empty.
    FAnnotations.Clear;
    V := Root.GetValue('annotations');
    if V is TJSONArray then
      for SV in TJSONArray(V) do
        if SV is TJSONObject then
        begin
          NewAnnotation := TPlotAnnotation.Create('', 0, 0);
          NewAnnotation.LoadFromJson(TJSONObject(SV));
          FAnnotations.Add(NewAnnotation);
        end;
  finally
    Root.Free;
  end;

  Redraw;
end;

// -----------------------------------------------------------------------
//  TPlotSettings
// -----------------------------------------------------------------------
constructor TPlotSettings.Create(AJson: TJSONObject);
begin
  inherited Create;
  FJson := AJson;   // takes ownership
end;

destructor TPlotSettings.Destroy;
begin
  FJson.Free;
  inherited Destroy;
end;

// -----------------------------------------------------------------------
//  In-memory settings store
// -----------------------------------------------------------------------

// Build a styling-only snapshot: the same chart / axis / grid / legend
// sub-objects that SavePlotToFile writes, but series are stored as a
// name-keyed styling map with NO data points, so restoring re-skins the
// current series without touching their data.
function TSkPlotPaintBox.CaptureStylingJson: TJSONObject;
var
  Chart, Legend, SeriesMap: TJSONObject;
  S: TPlotSeries;
begin
  Result := TJSONObject.Create;
  JPutInt(Result, 'version', 1);

  Chart := TJSONObject.Create;
  Chart.AddPair('title',      FChartTitle.SaveToJson);
  Chart.AddPair('xAxisTitle', FXAxisTitle.SaveToJson);
  Chart.AddPair('yAxisTitle', FYAxisTitle.SaveToJson);
  JPutFloat(Chart, 'xAxisFontSize',     FXAxisFontSize);
  JPutFloat(Chart, 'yAxisFontSize',     FYAxisFontSize);
  JPutBool (Chart, 'autoXScaling',      FAutoX);
  JPutBool (Chart, 'autoYScaling',      FAutoY);
  JPutBool (Chart, 'originOnAxis',      FOriginOnAxis);
  JPutColor(Chart, 'plotAreaColor',     FPlotAreaColor);
  JPutColor(Chart, 'plotBorderColor',   FPlotBorderColor);
  JPutFloat(Chart, 'plotBorderWidth',   FPlotBorderWidth);
  JPutBool (Chart, 'plotBorderVisible', FPlotBorderVisible);
  JPutColor(Chart, 'backgroundColor',   FBackgroundColor);
  Result.AddPair('chart', Chart);

  Result.AddPair('axisLimits', FSubAxisProperty.SaveToJson);
  Result.AddPair('axisStyle',  FAxisStyle.SaveToJson);
  Result.AddPair('gridStyle',  FGridStyle.SaveToJson);

  Legend := FLegendStyle.SaveToJson;
  JPutFloat(Legend, 'offsetX', FLegendOffset.X);
  JPutFloat(Legend, 'offsetY', FLegendOffset.Y);
  Result.AddPair('legendStyle', Legend);

  // Per-series styling keyed by series Name (no data). If two series share a
  // name the later one wins on restore, which is acceptable for styling.
  SeriesMap := TJSONObject.Create;
  for S in FSeriesList do
    SeriesMap.AddPair(S.Name, S.SaveStyleToJson);
  Result.AddPair('seriesStyles', SeriesMap);
end;

// Apply a styling-only snapshot produced by CaptureStylingJson. Component
// level styling is overwritten; per-series styling is matched by Name —
// series absent from the snapshot are left as-is, snapshot entries with no
// matching series are ignored.
procedure TSkPlotPaintBox.ApplyStylingJson(const Root: TJSONObject);
var
  V: TJSONValue;
  Chart, SeriesMap: TJSONObject;
  Pair: TJSONPair;
  S: TPlotSeries;
  Idx: Integer;
begin
  if Root = nil then Exit;

  V := Root.GetValue('chart');
  if V is TJSONObject then
  begin
    Chart := TJSONObject(V);
    if Chart.GetValue('title') is TJSONObject then
      FChartTitle.LoadFromJson(TJSONObject(Chart.GetValue('title')));
    if Chart.GetValue('xAxisTitle') is TJSONObject then
      FXAxisTitle.LoadFromJson(TJSONObject(Chart.GetValue('xAxisTitle')));
    if Chart.GetValue('yAxisTitle') is TJSONObject then
      FYAxisTitle.LoadFromJson(TJSONObject(Chart.GetValue('yAxisTitle')));
    FXAxisFontSize     := JFloat(Chart, 'xAxisFontSize',     FXAxisFontSize);
    FYAxisFontSize     := JFloat(Chart, 'yAxisFontSize',     FYAxisFontSize);
    FAutoX             := JBool (Chart, 'autoXScaling',      FAutoX);
    FAutoY             := JBool (Chart, 'autoYScaling',      FAutoY);
    FOriginOnAxis      := JBool (Chart, 'originOnAxis',      FOriginOnAxis);
    FPlotAreaColor     := JColor(Chart, 'plotAreaColor',     FPlotAreaColor);
    FPlotBorderColor   := JColor(Chart, 'plotBorderColor',   FPlotBorderColor);
    FPlotBorderWidth   := JFloat(Chart, 'plotBorderWidth',   FPlotBorderWidth);
    FPlotBorderVisible := JBool (Chart, 'plotBorderVisible', FPlotBorderVisible);
    FBackgroundColor   := JColor(Chart, 'backgroundColor',   FBackgroundColor);
  end;

  V := Root.GetValue('axisLimits');
  if V is TJSONObject then FSubAxisProperty.LoadFromJson(TJSONObject(V));
  V := Root.GetValue('axisStyle');
  if V is TJSONObject then FAxisStyle.LoadFromJson(TJSONObject(V));
  V := Root.GetValue('gridStyle');
  if V is TJSONObject then FGridStyle.LoadFromJson(TJSONObject(V));
  V := Root.GetValue('legendStyle');
  if V is TJSONObject then
  begin
    FLegendStyle.LoadFromJson(TJSONObject(V));
    FLegendOffset := TPointF.Create(
      JFloat(TJSONObject(V), 'offsetX', FLegendOffset.X),
      JFloat(TJSONObject(V), 'offsetY', FLegendOffset.Y));
  end;

  // Per-series styling, matched by Name.
  V := Root.GetValue('seriesStyles');
  if V is TJSONObject then
  begin
    SeriesMap := TJSONObject(V);
    for Pair in SeriesMap do
      if (Pair.JsonValue is TJSONObject) and
         FSeriesList.Find(Pair.JsonString.Value, Idx) then
      begin
        S := FSeriesList[Idx];
        S.LoadStyleFromJson(TJSONObject(Pair.JsonValue));
      end;
  end;
end;

procedure TSkPlotPaintBox.SaveSettings(const Key: string);
begin
  // AddOrSetValue frees the previous snapshot (doOwnsValues) before storing
  // the new one, so re-saving a key never leaks.
  FSettingsStore.AddOrSetValue(Key, TPlotSettings.Create(CaptureStylingJson));
end;

function TSkPlotPaintBox.RestoreSettings(const Key: string): Boolean;
var
  Settings: TPlotSettings;
begin
  Result := FSettingsStore.TryGetValue(Key, Settings);
  if Result then
  begin
    ApplyStylingJson(Settings.FJson);
    Redraw;
  end;
end;

function TSkPlotPaintBox.HasSettings(const Key: string): Boolean;
begin
  Result := FSettingsStore.ContainsKey(Key);
end;

procedure TSkPlotPaintBox.DeleteSettings(const Key: string);
begin
  FSettingsStore.Remove(Key);   // frees the snapshot; no error if absent
end;

procedure TSkPlotPaintBox.ClearAllSettings;
begin
  FSettingsStore.Clear;
end;

function TSkPlotPaintBox.SettingsKeys: TArray<string>;
begin
  Result := FSettingsStore.Keys.ToArray;
end;

procedure TSkPlotPaintBox.SetDefaultsFile(const Value: String);
begin
  if FDefaultsFile <> Value then
  begin
    FDefaultsFile := Value;
    ReloadDefaults;
  end;
end;

procedure TSkPlotPaintBox.ExportToPng(FileName: String; ScaleFactor: Single);
var
  LSurface: ISkSurface;
  LCanvas:  ISkCanvas;
  LImage:   ISkImage;
begin
  LSurface := TSkSurface.MakeRaster(Round(Width * ScaleFactor),
                                    Round(Height * ScaleFactor));
  if LSurface = nil then Exit;
  LCanvas := LSurface.Canvas;
  LCanvas.Scale(ScaleFactor, ScaleFactor);
  RenderChart(LCanvas, TRectF.Create(0, 0, Width, Height));
  LImage := LSurface.MakeImageSnapshot;
  if LImage <> nil then
    LImage.EncodeToFile(FileName);
end;


procedure TSkPlotPaintBox.ExportToPdf(FileName: String);
var
  LDocument: ISkDocument;
  LCanvas:   ISkCanvas;
  LStream:   TStream;
begin
  LStream := TFileStream.Create(FileName, fmCreate);
  try
    LDocument := TSkDocument.MakePDF(LStream);
    LCanvas   := LDocument.BeginPage(Width, Height);
    try
      RenderChart(LCanvas, TRectF.Create(0, 0, Width, Height));
    finally
      LDocument.EndPage;
    end;
    LDocument.Close;
    //ShowMessage('PDF exported successfully to ' + FileName);
  finally
    LStream.Free;
  end;
end;


procedure TSkPlotPaintBox.DoExportPDF (Sender : TObject);
var
  SaveDialog: TSaveDialog;
  FileName:   String;
begin
  SaveDialog := TSaveDialog.Create(Self);
  try
    SaveDialog.Title      := 'Export Chart as PDF';
    SaveDialog.Filter     := 'PDF Files (*.pdf)|*.pdf|All Files (*.*)|*.*';
    SaveDialog.DefaultExt := 'pdf';
    SaveDialog.FileName   := 'chart.pdf';
    SaveDialog.Options    := SaveDialog.Options + [TOpenOption.ofOverwritePrompt];

    if SaveDialog.Execute then
    begin
      FileName := SaveDialog.FileName;
      if TPath.GetExtension(FileName) = '' then
        FileName := FileName + '.pdf';
      ExportToPdf(FileName);
    end;
  finally
    SaveDialog.Free;
  end;
end;

procedure TSkPlotPaintBox.DoExportPNG (Sender : TObject);
var
  SaveDialog: TSaveDialog;
  FileName:   String;
begin
  SaveDialog := TSaveDialog.Create(Self);
  try
    SaveDialog.Title      := 'Export Chart as PNG';
    SaveDialog.Filter     := 'PNG Files (*.png)|*.png|All Files (*.*)|*.*';
    SaveDialog.DefaultExt := 'png';
    SaveDialog.FileName   := 'chart.png';
    SaveDialog.Options    := SaveDialog.Options + [TOpenOption.ofOverwritePrompt];

    if SaveDialog.Execute then
    begin
      FileName := SaveDialog.FileName;
      if TPath.GetExtension(FileName) = '' then
        FileName := FileName + '.png';
      ExportToPng(FileName, 4.0);
    end;
  finally
    SaveDialog.Free;
  end;
end;

procedure TSkPlotPaintBox.DoCopyImageToClipboard (Sender: TObject);
var
  LSurface: ISkSurface;
  LCanvas:  ISkCanvas;
  LImage:   ISkImage;
  ScaleFactor : Single;
  FmxBitmap: TBitmap;
  ClipboardService: IFMXClipboardService;
begin
  ScaleFactor := 2;
  LSurface := TSkSurface.MakeRaster(Round(Width * ScaleFactor),
                                    Round(Height * ScaleFactor));
  if LSurface = nil then Exit;
  LCanvas := LSurface.Canvas;
  LCanvas.Scale(ScaleFactor, ScaleFactor);
  RenderChart(LCanvas, TRectF.Create(0, 0, Width, Height));
  LImage := LSurface.MakeImageSnapshot;

  if LImage <> nil then
  begin
    // 1. Convert the Skia image into an FMX TBitmap
    FmxBitmap := SkImageToBitmap(LImage);
    try
      // 2. Request the system clipboard service from FireMonkey
      if TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, ClipboardService) then
      begin
        // 3. Send the image to the OS clipboard wrapper using a TValue wrapper
        ClipboardService.SetClipboard(TValue.From<TBitmap>(FmxBitmap));
      end;
    finally
      // 4. Free the temporary FMX bitmap wrapper
      FmxBitmap.Free;
    end;
  end;
end;

function TSkPlotPaintBox.LoadData(const FileName: String; LineVisible : Boolean; MarkerVisible: Boolean; ClearSeries : Boolean; ClearDataKinds : Boolean) : TStringList;
var
  CSV:  TCSV;
  i, j: Integer;
  ps:   TPlotSeries;
begin
  CSV := TCSV.Create(nil);
  try
    CSV.ReadCSV(FileName);
    if ClearDataKinds then
       ClearSeriesKind(skData);

    if ClearSeries then
       FSeriesList.Clear;

    Result := TStringList.Create;
    if CSV.Cols < 2 then
       raise Exception.CreateFmt('CSV Data must have more than one column: %s', [FileName]);

    for i := 1 to CSV.Cols - 1 do
    begin
      // If the name of the x axis in the loaded data is the same
      // as an existing simulation data series, then set the color to
      // the simulation data series.

      ps := TPlotSeries.Create(CSV.header[i], TColorManager.NextColor);
      ps.XLabel := CSV.header[0];
      ps.YLabel := CSV.header[i];

      Result.AddObject(CSV.header[i], ps);
      // Try and match the columns labels, if they match set the same color to the points
      for j:= 0 to Series.Count - 1 do
          if (Series[j].SeriesKind = skSimulation) and (Series[j].YLabel = ps.YLabel) then
             begin
             ps.MarkerFillColor := Series[j].LineColor;
             ps.MarkerStrokeColor := Series[j].LineColor;
             ps.MarkerSize := 4.0;
             break;
             end;

      ps.LineVisible := LineVisible;
      ps.MarkerVisible := MarkerVisible;
      for j := 0 to CSV.Rows - 1 do
        ps.AddXY(CSV.data[j, 0].number, CSV.data[j, i].number);
      FSeriesList.Add(ps);
    end;
    Redraw;
  finally
    CSV.Free;
  end;
end;


function StrToFloatLocale(const S: string): Double;
var
  FS: TFormatSettings;
begin
  FS := TFormatSettings.Create('en-US');
  Result := StrToFloat(S, FS);
end;


function FloatToStrLocale(Value: Double; DecimalPlaces: Integer = 5): string;
var
  FS: TFormatSettings;
  AbsVal: Double;
begin
  FS := TFormatSettings.Create('en-US');
  AbsVal := Abs(Value);

  // Logic: Use standard for "normal" numbers, Scientific for extremes
  if (AbsVal > 0) and ((AbsVal < 0.001) or (AbsVal >= 1000000)) then
    Result := FormatFloat('0.' + StringOfChar('0', DecimalPlaces) + 'E+00', Value, FS)
  else
    Result := FormatFloat('0.' + StringOfChar('0', DecimalPlaces), Value, FS);
end;



// Format a single tick-label value for an axis.
// AStep is the spacing between major ticks; it sets the number of decimals
// needed so two adjacent labels look different. Values that are very small
// or very large fall back to scientific notation.
function FormatAxisLabel(Value, AStep: Double): string;
var
  AbsVal, AbsStep: Double;
  Decimals:       Integer;
begin
  AbsVal  := Abs(Value);
  AbsStep := Abs(AStep);

  // Treat near-zero as exact zero so we don't print "1.00E-17" at the origin.
  if (AbsStep > 0) and (AbsVal < AbsStep * 1e-9) then
    Exit('0');

  // Use scientific notation when the magnitude (or the step) is tiny or huge.
  // The step matters too: a range like 0.001..0.005 needs scientific even
  // though 0.005 itself isn't astronomically small.
  if ((AbsVal > 0) and ((AbsVal < 1e-3) or (AbsVal >= 1e6))) or
     ((AbsStep > 0) and ((AbsStep < 1e-3) or (AbsStep >= 1e6))) then
  begin
    Result := FloatToStrF(Value, ffExponent, 3, 2);
    Exit;
  end;

  // Linear regime: pick enough decimals to distinguish adjacent ticks.
  if AbsStep >= 1 then
    Decimals := 0
  else if AbsStep > 0 then
    Decimals := Max(0, -Floor(Log10(AbsStep)))
  else
    Decimals := 2;

  if Decimals = 0 then
    Result := FormatFloat('0', Value)
  else
    Result := FormatFloat('0.' + StringOfChar('0', Decimals), Value);
end;


procedure TSkPlotPaintBox.ExportCSV(FileName: String; SharedXColumn: Boolean = True);
var
  SL      : TStringList;
  Header  : string;
  Row     : string;
  I, J    : Integer;
  Series  : TPlotSeries;
  NumRows : Integer;
begin
  if (FSeriesList = nil) or (FSeriesList.Count = 0) then
    Exit;

  SL := TStringList.Create;
  try
    if SharedXColumn then
      begin
        // --- Shared X column: time, S1, S2, ... ---
        Header := 'time';
        for I := 0 to FSeriesList.Count - 1 do
          Header := Header + ',' + FSeriesList[I].Name;
        SL.Add(Header);

        NumRows := 0;
        for I := 0 to FSeriesList.Count - 1 do
          if FSeriesList[I].Data.Count > NumRows then
            NumRows := FSeriesList[I].Data.Count;

        for J := 0 to NumRows - 1 do
          begin
            // X comes from the first series that has data at row J
            Row := '';
            for I := 0 to FSeriesList.Count - 1 do
              if J < FSeriesList[I].Data.Count then
                begin
                  Row := FloatToStrLocale(FSeriesList[I].Data[J].X);
                  Break;
                end;
            for I := 0 to FSeriesList.Count - 1 do
              begin
                Series := FSeriesList[I];
                if J < Series.Data.Count then
                  Row := Row + ',' + FloatToStrLocale(Series.Data[J].Y)
                else
                  Row := Row + ',';
              end;
            SL.Add(Row);
          end;
      end
    else
      begin
        // --- Paired X columns: time_S1, S1, time_S2, S2, ... ---
        Header := '';
        for I := 0 to FSeriesList.Count - 1 do
          begin
            if I > 0 then Header := Header + ',';
            Header := Header + 'time_' + FSeriesList[I].Name + ',' + FSeriesList[I].Name;
          end;
        SL.Add(Header);

        NumRows := 0;
        for I := 0 to FSeriesList.Count - 1 do
          if FSeriesList[I].Data.Count > NumRows then
            NumRows := FSeriesList[I].Data.Count;

        for J := 0 to NumRows - 1 do
          begin
            Row := '';
            for I := 0 to FSeriesList.Count - 1 do
              begin
                if I > 0 then Row := Row + ',';
                Series := FSeriesList[I];
                if J < Series.Data.Count then
                  Row := Row + FloatToStrLocale(Series.Data[J].X) + ',' +
                               FloatToStrLocale(Series.Data[J].Y)
                else
                  Row := Row + ',';
              end;
            SL.Add(Row);
          end;
      end;

    SL.SaveToFile(FileName);
  finally
    SL.Free;
  end;
end;


procedure TSkPlotPaintBox.ExportCSVSeries(Directory: String);
var
  I    : Integer;
  SL   : TStringList;
  J    : Integer;
  Series : TPlotSeries;
  FileName : String;
begin
  if (FSeriesList = nil) or (FSeriesList.Count = 0) then Exit;

  SL := TStringList.Create;
  try
    for I := 0 to FSeriesList.Count - 1 do
    begin
      Series := FSeriesList[I];
      SL.Clear;
      SL.Add('time,' + Series.Name);
      for J := 0 to Series.Data.Count - 1 do
        SL.Add(FloatToStr(Series.Data[J].X) + ',' + FloatToStr(Series.Data[J].Y));
      FileName := IncludeTrailingPathDelimiter(Directory) + Series.Name + '.csv';
      SL.SaveToFile(FileName);
    end;
  finally
    SL.Free;
  end;
end;


function TSkPlotPaintBox.ExportCSVSeriesAsString(const ADecimalPlaces: Integer; MinColumnWidth : Integer = 12): String;
var
  I, J: Integer;
  SL: TStringList;
  ColWidths: TArray<Integer>;
  FormattedVal: String;
  RowStr: String;
begin
  if (FSeriesList = nil) or (FSeriesList.Count = 0) then Exit;

  SetLength(ColWidths, FSeriesList.Count + 1);
  for I := 0 to High(ColWidths) do ColWidths[I] := MinColumnWidth;

  // 1. PRE-SCAN: Only find max width, but keep it reasonable
  for I := 0 to FSeriesList.Count - 1 do
  begin
    if Length(FSeriesList[I].Name) > ColWidths[I+1] then
      ColWidths[I+1] := Length(FSeriesList[I].Name);

    for J := 0 to FSeriesList[I].Data.Count - 1 do
    begin
      FormattedVal := FloatToStrLocale(FSeriesList[I].Data[J].Y, ADecimalPlaces);
      if Length(FormattedVal) > ColWidths[I+1] then
        ColWidths[I+1] := Length(FormattedVal);
    end;
  end;

  // 2. BUILD
  SL := TStringList.Create;
  try
    // Header
    RowStr := 'time'.PadLeft(ColWidths[0]);
    for I := 0 to FSeriesList.Count - 1 do
      RowStr := RowStr + ',' + FSeriesList[I].Name.PadLeft(ColWidths[I+1]);
    SL.Add(RowStr);

    // Rows
    for J := 0 to FSeriesList[0].Data.Count - 1 do
    begin
      RowStr := FloatToStrLocale(FSeriesList[0].Data[J].X, ADecimalPlaces).PadLeft(ColWidths[0]);
      for I := 0 to FSeriesList.Count - 1 do
      begin
        if J < FSeriesList[I].Data.Count then
          FormattedVal := FloatToStrLocale(FSeriesList[I].Data[J].Y, ADecimalPlaces)
        else
          FormattedVal := '';
        RowStr := RowStr + ',' + FormattedVal.PadLeft(ColWidths[I+1]);
      end;
      SL.Add(RowStr);
    end;
    Result := SL.Text;
  finally
    SL.Free;
  end;
end;





// -----------------------------------------------------------------------
//  DrawLegend
// -----------------------------------------------------------------------

// Returns AColor with its alpha channel replaced by AOpacity (0.0–1.0).
function BlendOpacity(AColor: TAlphaColor; AOpacity: Single): TAlphaColor;
var
  Alpha: Byte;
begin
  Alpha  := Round(EnsureRange(AOpacity, 0.0, 1.0) * 255);
  Result := (TAlphaColor(Alpha) shl 24) or (AColor and $00FFFFFF);
end;

procedure TSkPlotPaintBox.DrawLegend(const ACanvas: ISkCanvas;
                                     const AMapper: TPlotMapper);
var
  LPaint, LTextPaint: ISkPaint;
  LFont:       ISkFont;
  LegendRect:  TRectF;
  I:           Integer;
  ItemY, MaxWidth: Single;
  LegendWidth, LegendHeight: Single;
  Series: TPlotSeries;
  P1: TPointD;
  BgColor: TAlphaColor;
  NumberOfSeries, SeriesCount : Integer;
  LIntervals: TArray<Single>;
begin
  if not FLegendStyle.Visible then Exit;
  if FSeriesList.Count = 0 then Exit;

  LTextPaint := TSkPaint.Create(TSkPaintStyle.Fill);
  LTextPaint.Color := TAlphaColors.Black;
  LFont := TSkFont.Create(nil, 12);

  LPaint := TSkPaint.Create(TSkPaintStyle.Stroke);
  LPaint.AntiAlias := True;

  // Measure the widest label to size the box
  MaxWidth := 0;
  for Series in FSeriesList do
    if Series.Visible and Series.ShowInLegend then
       MaxWidth := Max(MaxWidth, LFont.MeasureText(Series.Name));

  LegendWidth  := MaxWidth + 70;
  // Count how many series are visible, determines legend height
  NumberOfSeries := 0;
  for Series in FSeriesList do
      if Series.Visible and Series.ShowInLegend then
         Inc (NumberOfSeries);

  LegendHeight := NumberOfSeries * 22 + 10;
  LegendRect   := TRectF.Create(0, 0, LegendWidth, LegendHeight);

  // Position according to FLegendStyle.Location
  case FLegendStyle.Location of
    llTopRight:
      LegendRect.Offset(AMapper.PixelRect.Right  - LegendWidth  - 15,
                        AMapper.PixelRect.Top    + 15);
    llTopLeft:
      LegendRect.Offset(AMapper.PixelRect.Left   + 15,
                        AMapper.PixelRect.Top    + 15);
    llBottomRight:
      LegendRect.Offset(AMapper.PixelRect.Right  - LegendWidth  - 15,
                        AMapper.PixelRect.Bottom - LegendHeight - 15);
    llBottomLeft:
      LegendRect.Offset(AMapper.PixelRect.Left   + 15,
                        AMapper.PixelRect.Bottom - LegendHeight - 15);
  end;

  // Apply the user drag offset, then cache the rect for hit-testing
  LegendRect.Offset(FLegendOffset.X, FLegendOffset.Y);
  FLegendRect := LegendRect;

  // Background fill
  BgColor := BlendOpacity(FLegendStyle.BackgroundColor,
                           FLegendStyle.BackgroundOpacity);
  LPaint.Style := TSkPaintStyle.Fill;
  LPaint.Color := BgColor;
  ACanvas.DrawRect(LegendRect, LPaint);

  // Border
  if FLegendStyle.BorderVisible then
  begin
    LPaint.Style       := TSkPaintStyle.Stroke;
    LPaint.Color       := FLegendStyle.BorderColor;
    LPaint.StrokeWidth := FLegendStyle.BorderWidth;
    ACanvas.DrawRect(LegendRect, LPaint);
  end;

  // Series entries
  SeriesCount := 0;
  for I := 0 to FSeriesList.Count - 1 do
  begin
    Series := FSeriesList[I];
    if Series.Visible and Series.ShowInLegend then
       begin
       ItemY  := LegendRect.Top + 20 + (SeriesCount * 22);
       Inc (SeriesCount);

    if Series.LineVisible then
       begin
       LPaint.Style       := TSkPaintStyle.Stroke;
       LPaint.Color       := Series.LineColor;
       LPaint.StrokeWidth := 2.0;
       LPaint.StrokeCap := TSkStrokeCap.Round;

       if Series.LineStyle <> TLineStyle.ltSolid  then
          begin
          case Series.LineStyle of
             TLineStyle.ltDashDash: LIntervals := [5, 5, 5, 5];
             TLineStyle.ltDotDot:  LIntervals := [3, 3, 3, 3];
          end;
          LPaint.StrokeCap := TSkStrokeCap.Round;
          LPaint.StrokeJoin := TSkStrokeJoin.Round;
          LPaint.PathEffect := TSkPathEffect.MakeDash(LIntervals, 0);
          end;

       ACanvas.DrawLine(LegendRect.Left + 15, ItemY - 4,
                       LegendRect.Left + 45, ItemY - 4, LPaint);
       end;
       LPaint.PathEffect := nil;

    if Series.MarkerVisible then
    begin
      P1 := TPointD.Create(LegendRect.Left + 30, ItemY - 4);
      LPaint.StrokeWidth := 1;
      Series.DrawMarker (ACanvas, P1, 3.5, LPaint);
    end;

    ACanvas.DrawSimpleText(Series.Name, LegendRect.Left + 55, ItemY,
                           LFont, LTextPaint);
       end;
  end;
end;

// -----------------------------------------------------------------------
//  DrawAnnotations
// -----------------------------------------------------------------------

procedure TSkPlotPaintBox.DrawAnnotations(const ACanvas: ISkCanvas;
                                          const AMapper: TPlotMapper);
var
  Annot: TPlotAnnotation;
begin
  if FAnnotations = nil then Exit;
  // Each annotation maps its own data-space anchor to pixels and offsets in
  // screen space; nothing here contributes to autoscale or the legend.
  for Annot in FAnnotations do
    Annot.Draw(ACanvas, AMapper);
end;

// -----------------------------------------------------------------------
//  DrawGrid
// -----------------------------------------------------------------------

procedure TSkPlotPaintBox.DrawGrid(const ACanvas: ISkCanvas;
                                   const AMapper: TPlotMapper;
                                   ABorderColor: TAlphaColor;
                                   ABorderWidth: Single;
                                   ABorderVisible: Boolean);
var
  LXMajorPaint, LYMajorPaint: ISkPaint;
  LXMinorPaint, LYMinorPaint: ISkPaint;
  LTickPaint, LTextPaint:     ISkPaint;
  LFont, LTitleFont:          ISkFont;
  LX, LY, TextWidth, TitleWidth: Single;
  ValX, ValY, StepX, StepY, MinorVal: Double;
  MinorStepX, MinorStepY, MinorValX, MinorValY: Double;
  LabelText: string;
  K: Integer;
begin
  // X major grid (dashed vertical lines)
  LXMajorPaint := TSkPaint.Create(TSkPaintStyle.Stroke);
  LXMajorPaint.Color       := FGridStyle.XMajorColor;
  LXMajorPaint.StrokeWidth := FGridStyle.XMajorWidth;
  LXMajorPaint.PathEffect  := TSkPathEffect.MakeDash([4, 4], 0);

  // Y major grid (dashed horizontal lines)
  LYMajorPaint := TSkPaint.Create(TSkPaintStyle.Stroke);
  LYMajorPaint.Color       := FGridStyle.YMajorColor;
  LYMajorPaint.StrokeWidth := FGridStyle.YMajorWidth;
  LYMajorPaint.PathEffect  := TSkPathEffect.MakeDash([4, 4], 0);

  // X minor grid
  LXMinorPaint := TSkPaint.Create(TSkPaintStyle.Stroke);
  LXMinorPaint.Color       := FGridStyle.XMinorColor;
  LXMinorPaint.StrokeWidth := FGridStyle.XMinorWidth;
  LXMinorPaint.AntiAlias   := True;

  // Y minor grid
  LYMinorPaint := TSkPaint.Create(TSkPaintStyle.Stroke);
  LYMinorPaint.Color       := FGridStyle.YMinorColor;
  LYMinorPaint.StrokeWidth := FGridStyle.YMinorWidth;
  LYMinorPaint.AntiAlias   := True;

  // Axis lines, tick marks, and border
  LTickPaint := TSkPaint.Create(TSkPaintStyle.Stroke);
  LTickPaint.Color       := ABorderColor;
  LTickPaint.StrokeWidth := ABorderWidth;
  LTickPaint.AntiAlias   := True;

  LTextPaint := TSkPaint.Create(TSkPaintStyle.Fill);
  LTextPaint.Color     := TAlphaColors.Black;
  LTextPaint.AntiAlias := True;

  LFont      := TSkFont.Create(nil, 14);
  LTitleFont := TSkFont.Create(TSkTypeface.MakeDefault, 16);

  // -----------------------------------------------------------------------
  //  X-AXIS
  // -----------------------------------------------------------------------
  if AMapper.LogX then
    begin
      var LogLeft  := Log10(Max(1e-9, AMapper.DataRect.Left));
      var LogRight := Log10(Max(1e-9, AMapper.DataRect.Right));
      var NumDecades := Max(1, Ceil(LogRight - LogLeft));
      var DecadeStride := Max(1, Round(NumDecades / Max(1, FGridStyle.XMajorDivisions)));
      var DecadeFactor := Power(10, DecadeStride);

      ValX := Power(10, Floor(LogLeft));
      while (ValX <= AMapper.DataRect.Right) and (ValX > 0) do
      begin
        // Minor ticks (decade subdivisions) only meaningful when stride = 1
        if DecadeStride = 1 then
        begin
          for K := 2 to 9 do
          begin
            MinorVal := ValX * K;
            if (MinorVal > AMapper.DataRect.Left) and
               (MinorVal <= AMapper.DataRect.Right) then
            begin
              LX := AMapper.MapX(MinorVal);
              if FGridStyle.XMinorVisible then
                ACanvas.DrawLine(LX, AMapper.PixelRect.Top,
                                 LX, AMapper.PixelRect.Bottom, LXMinorPaint);
              if FAxisStyle.XMinorTicksVisible then
                 begin
                 case FAxisStyle.FXTickDrawing of
                   tmIn: ACanvas.DrawLine(LX, AMapper.PixelRect.Bottom, LX, AMapper.PixelRect.Bottom - FAxisStyle.XMinorTickLength, LTickPaint);
                   tmOut: ACanvas.DrawLine(LX, AMapper.PixelRect.Bottom, LX, AMapper.PixelRect.Bottom + FAxisStyle.XMinorTickLength, LTickPaint);
                   tmBoth: begin
                           ACanvas.DrawLine(LX, AMapper.PixelRect.Bottom, LX, AMapper.PixelRect.Bottom + FAxisStyle.XMinorTickLength, LTickPaint);
                           ACanvas.DrawLine(LX, AMapper.PixelRect.Bottom, LX, AMapper.PixelRect.Bottom - FAxisStyle.XMinorTickLength, LTickPaint);
                           end;
                   end;
                 end;
            end;
          end;
        end;

        if ValX >= AMapper.DataRect.Left then
        begin
          LX := AMapper.MapX(ValX);
          if FGridStyle.XMajorVisible then
            ACanvas.DrawLine(LX, AMapper.PixelRect.Top,
                            LX, AMapper.PixelRect.Bottom, LXMajorPaint);
          if AxisStyle.XMajorTicksVisible then
             begin
             case FAxisStyle.FXTickDrawing of
               tmIn: ACanvas.DrawLine(LX, AMapper.PixelRect.Bottom, LX, AMapper.PixelRect.Bottom - FAxisStyle.XMinorTickLength, LTickPaint);
               tmOut: ACanvas.DrawLine(LX, AMapper.PixelRect.Bottom, LX, AMapper.PixelRect.Bottom + FAxisStyle.XMinorTickLength, LTickPaint);
               tmBoth: begin
                       ACanvas.DrawLine(LX, AMapper.PixelRect.Bottom, LX, AMapper.PixelRect.Bottom + FAxisStyle.XMinorTickLength, LTickPaint);
                       ACanvas.DrawLine(LX, AMapper.PixelRect.Bottom, LX, AMapper.PixelRect.Bottom - FAxisStyle.XMinorTickLength, LTickPaint);
                       end;
             end;
             end;
          LabelText := FormatAxisLabel(ValX, ValX);
          LFont.Size := XAxisFontSize;
          TextWidth := LFont.MeasureText(LabelText);
          ACanvas.DrawSimpleText(LabelText, LX - (TextWidth / 2),
                                 AMapper.PixelRect.Bottom + FAxisStyle.XMajorTickLength + 14, LFont, LTextPaint);
        end;
        ValX := ValX * DecadeFactor;
      end;
    end
  else
  begin
    // Linear X — minor lines first so major lines paint over them
    StepX := CalculateNiceStep(AMapper.DataRect.Width, FGridStyle.XMajorDivisions);

    if (FGridStyle.XMinorDivisions > 1) then
    begin
      MinorStepX := StepX / FGridStyle.XMinorDivisions;
      MinorValX  := Ceil(AMapper.DataRect.Left / MinorStepX) * MinorStepX;
      while MinorValX <= AMapper.DataRect.Right do
      begin
        if Abs(MinorValX / StepX - Round(MinorValX / StepX)) > 1e-9 then
        begin
          LX := AMapper.MapX(MinorValX);
          if  FGridStyle.XMinorVisible then
             ACanvas.DrawLine(LX, AMapper.PixelRect.Top,
                           LX, AMapper.PixelRect.Bottom, LXMinorPaint);
          if FAxisStyle.FXMinorTicksVisible then
            begin
            case FAxisStyle.FXTickDrawing of
               tmIn: ACanvas.DrawLine(LX, AMapper.PixelRect.Bottom, LX, AMapper.PixelRect.Bottom - FAxisStyle.XMinorTickLength, LTickPaint);
               tmOut: ACanvas.DrawLine(LX, AMapper.PixelRect.Bottom, LX, AMapper.PixelRect.Bottom + FAxisStyle.XMinorTickLength, LTickPaint);
               tmBoth: begin
                       ACanvas.DrawLine(LX, AMapper.PixelRect.Bottom, LX, AMapper.PixelRect.Bottom + FAxisStyle.XMinorTickLength, LTickPaint);
                       ACanvas.DrawLine(LX, AMapper.PixelRect.Bottom, LX, AMapper.PixelRect.Bottom - FAxisStyle.XMinorTickLength, LTickPaint)
                       end;
            end;
            end;
        end;
        MinorValX := MinorValX + MinorStepX;
      end;
    end;

    ValX := Ceil(AMapper.DataRect.Left / StepX) * StepX;
    while ValX <= AMapper.DataRect.Right do
    begin
      LX := AMapper.MapX(ValX);
      if FGridStyle.XMajorVisible then
        ACanvas.DrawLine(LX, AMapper.PixelRect.Top,
                         LX, AMapper.PixelRect.Bottom, LXMajorPaint);
      if FAxisStyle.FXMajorTicksVisible then
         begin
          case FAxisStyle.FXTickDrawing of
             tmIn: ACanvas.DrawLine(LX, AMapper.PixelRect.Bottom, LX, AMapper.PixelRect.Bottom - FAxisStyle.XMajorTickLength, LTickPaint);
             tmOut: ACanvas.DrawLine(LX, AMapper.PixelRect.Bottom, LX, AMapper.PixelRect.Bottom + FAxisStyle.XMajorTickLength, LTickPaint);
             tmBoth: begin
                     ACanvas.DrawLine(LX, AMapper.PixelRect.Bottom, LX, AMapper.PixelRect.Bottom + FAxisStyle.XMajorTickLength, LTickPaint);
                     ACanvas.DrawLine(LX, AMapper.PixelRect.Bottom, LX, AMapper.PixelRect.Bottom - FAxisStyle.XMajorTickLength, LTickPaint)
                     end;
          end;
          end;
      LabelText := FormatAxisLabel(ValX, StepX);
      LFont.Size := XAxisFontSize;
      TextWidth := LFont.MeasureText(LabelText);
      ACanvas.DrawSimpleText(LabelText, LX - (TextWidth / 2),
                             AMapper.PixelRect.Bottom + FAxisStyle.XMajorTickLength + 14, LFont, LTextPaint);
      ValX := ValX + StepX;
    end;
  end;

  // -----------------------------------------------------------------------
  //  Y-AXIS
  // -----------------------------------------------------------------------
  if AMapper.LogY then
    begin
      var LogTop    := Log10(Max(1e-9, AMapper.DataRect.Top));
      var LogBottom := Log10(Max(1e-9, AMapper.DataRect.Bottom));
      var NumDecades := Max(1, Ceil(LogBottom - LogTop));
      var DecadeStride := Max(1, Round(NumDecades / Max(1, FGridStyle.YMajorDivisions)));
      var DecadeFactor := Power(10, DecadeStride);

      ValY := Power(10, Floor(LogTop));
      while (ValY <= AMapper.DataRect.Bottom) and (ValY > 0) do
      begin
        if DecadeStride = 1 then
        begin
          for K := 2 to 9 do
          begin
            MinorVal := ValY * K;
            if (MinorVal > AMapper.DataRect.Top) and
               (MinorVal <= AMapper.DataRect.Bottom) then
            begin
              LY := AMapper.MapY(MinorVal);
              if FGridStyle.YMinorVisible then
                ACanvas.DrawLine(AMapper.PixelRect.Left, LY,
                                 AMapper.PixelRect.Right, LY, LYMinorPaint);
              if FAxisStyle.FYMinorTicksVisible then
                 begin
                 case FAxisStyle.FYTickDrawing of
                  tmIn: ACanvas.DrawLine(AMapper.PixelRect.Left + FAxisStyle.YMinorTickLength, LY, AMapper.PixelRect.Left, LY, LTickPaint);
                  tmOut: ACanvas.DrawLine(AMapper.PixelRect.Left - FAxisStyle.YMinorTickLength, LY, AMapper.PixelRect.Left, LY, LTickPaint);
                  tmBoth: begin
                          ACanvas.DrawLine(AMapper.PixelRect.Left - FAxisStyle.YMinorTickLength, LY, AMapper.PixelRect.Left, LY, LTickPaint);
                          ACanvas.DrawLine(AMapper.PixelRect.Left + FAxisStyle.YMinorTickLength, LY, AMapper.PixelRect.Left, LY, LTickPaint);
                          end;
                 end;
                 end;
            end;
          end;
        end;

        if ValY >= AMapper.DataRect.Top then
        begin
          LY := AMapper.MapY(ValY);
          if FGridStyle.YMajorVisible then
            ACanvas.DrawLine(AMapper.PixelRect.Left, LY,
                             AMapper.PixelRect.Right, LY, LYMajorPaint);
          if FAxisStyle.FYMajorTicksVisible then
            begin
            case FAxisStyle.FYTickDrawing of
              tmIn:  ACanvas.DrawLine(AMapper.PixelRect.Left + FAxisStyle.YMajorTickLength, LY, AMapper.PixelRect.Left, LY, LTickPaint);
              tmOut: ACanvas.DrawLine(AMapper.PixelRect.Left - FAxisStyle.YMajorTickLength, LY, AMapper.PixelRect.Left, LY, LTickPaint);
              tmBoth: begin
                      ACanvas.DrawLine(AMapper.PixelRect.Left - FAxisStyle.YMajorTickLength, LY, AMapper.PixelRect.Left, LY, LTickPaint);
                      ACanvas.DrawLine(AMapper.PixelRect.Left + FAxisStyle.YMajorTickLength, LY, AMapper.PixelRect.Left, LY, LTickPaint)
                      end;
              end;
            end;
          LabelText := FormatAxisLabel(ValY, ValY);
          LFont.Size := YAxisFontSize;
          TextWidth := LFont.MeasureText(LabelText);
          ACanvas.DrawSimpleText(LabelText,
                                 AMapper.PixelRect.Left - FAxisStyle.YMajorTickLength - 4 - TextWidth,
                                 LY + 4, LFont, LTextPaint);
        end;
        ValY := ValY * DecadeFactor;
      end;
    end
  else
  begin
    // Linear Y — minor lines first
    StepY := CalculateNiceStep(AMapper.DataRect.Height, FGridStyle.YMajorDivisions);

    if FGridStyle.YMinorDivisions > 1 then
    begin
      MinorStepY := StepY / FGridStyle.YMinorDivisions;
      MinorValY  := Ceil(AMapper.DataRect.Top / MinorStepY) * MinorStepY;
      while MinorValY <= AMapper.DataRect.Bottom do
      begin
        if Abs(MinorValY / StepY - Round(MinorValY / StepY)) > 1e-9 then
        begin
          LY := AMapper.MapY(MinorValY);
          if FGridStyle.YMinorVisible then
             ACanvas.DrawLine(AMapper.PixelRect.Left, LY,
                           AMapper.PixelRect.Right, LY, LYMinorPaint);
          if FAxisStyle.FYMinorTicksVisible then
             begin
             case FAxisStyle.FYTickDrawing of
              tmIn: ACanvas.DrawLine(AMapper.PixelRect.Left + FAxisStyle.YMinorTickLength, LY, AMapper.PixelRect.Left, LY, LTickPaint);
              tmOut: ACanvas.DrawLine(AMapper.PixelRect.Left - FAxisStyle.YMinorTickLength, LY, AMapper.PixelRect.Left, LY, LTickPaint);
              tmBoth: begin
                      ACanvas.DrawLine(AMapper.PixelRect.Left - FAxisStyle.YMinorTickLength, LY, AMapper.PixelRect.Left, LY, LTickPaint);
                      ACanvas.DrawLine(AMapper.PixelRect.Left + FAxisStyle.YMinorTickLength, LY, AMapper.PixelRect.Left, LY, LTickPaint);
                      end;
             end;
             end;
        end;
        MinorValY := MinorValY + MinorStepY;
      end;
    end;

    ValY := Ceil(AMapper.DataRect.Top / StepY) * StepY;
    while ValY <= AMapper.DataRect.Bottom do
    begin
      LY := AMapper.MapY(ValY);
      if FGridStyle.YMajorVisible then
        ACanvas.DrawLine(AMapper.PixelRect.Left, LY,
                         AMapper.PixelRect.Right, LY, LYMajorPaint);
      if FAxisStyle.FYMajorTicksVisible then
         begin
         case FAxisStyle.FYTickDrawing of
              tmIn: ACanvas.DrawLine(AMapper.PixelRect.Left + FAxisStyle.YMajorTickLength, LY, AMapper.PixelRect.Left, LY, LTickPaint);
              tmOut:ACanvas.DrawLine(AMapper.PixelRect.Left - FAxisStyle.YMajorTickLength, LY, AMapper.PixelRect.Left, LY, LTickPaint);
              tmBoth: begin
                      ACanvas.DrawLine(AMapper.PixelRect.Left - FAxisStyle.YMajorTickLength, LY, AMapper.PixelRect.Left, LY, LTickPaint);
                      ACanvas.DrawLine(AMapper.PixelRect.Left + FAxisStyle.YMajorTickLength, LY, AMapper.PixelRect.Left, LY, LTickPaint);
                      end;
         end;
         end;
      LabelText := FormatAxisLabel(ValY, StepY);
      LFont.Size := YAxisFontSize;
      TextWidth := LFont.MeasureText(LabelText);
      ACanvas.DrawSimpleText(LabelText,
                             AMapper.PixelRect.Left - FAxisStyle.YMajorTickLength - 4 - TextWidth,
                             LY + 4, LFont, LTextPaint);
      ValY := ValY + StepY;
    end;
  end;

  // -----------------------------------------------------------------------
  //  AXES AND BORDER
  // -----------------------------------------------------------------------

  // Left edge = Y axis — always visible
  ACanvas.DrawLine(AMapper.PixelRect.Left, AMapper.PixelRect.Top,
                   AMapper.PixelRect.Left, AMapper.PixelRect.Bottom, LTickPaint);

  // Bottom edge = X axis — always visible
  ACanvas.DrawLine(AMapper.PixelRect.Left,  AMapper.PixelRect.Bottom,
                   AMapper.PixelRect.Right, AMapper.PixelRect.Bottom, LTickPaint);

  // Top and right edges — optional border
  if ABorderVisible then
  begin
    ACanvas.DrawLine(AMapper.PixelRect.Left,  AMapper.PixelRect.Top,
                     AMapper.PixelRect.Right, AMapper.PixelRect.Top, LTickPaint);
    ACanvas.DrawLine(AMapper.PixelRect.Right, AMapper.PixelRect.Top,
                     AMapper.PixelRect.Right, AMapper.PixelRect.Bottom, LTickPaint);
  end;

  // -----------------------------------------------------------------------
  //  TITLES
  // -----------------------------------------------------------------------

  if FChartTitle.Visible then
  begin
    LTextPaint.Color := FChartTitle.Color;
    LTitleFont.Size  := FChartTitle.FontSize;
    TitleWidth := LTitleFont.MeasureText(FChartTitle.Text);
    ACanvas.DrawSimpleText(FChartTitle.Text,
                           AMapper.PixelRect.CenterPoint.X - (TitleWidth / 2),
                           AMapper.PixelRect.Top - 40,
                           LTitleFont, LTextPaint);
  end;

  if FXAxisTitle.Visible then
  begin
    LTextPaint.Color := FXAxisTitle.Color;
    LFont.Size       := FXAxisTitle.FontSize;
    TitleWidth := LFont.MeasureText(FXAxisTitle.Text);
    ACanvas.DrawSimpleText(FXAxisTitle.Text,
                           AMapper.PixelRect.CenterPoint.X - (TitleWidth / 2),
                           AMapper.PixelRect.Bottom + 50,
                           LFont, LTextPaint);
  end;

  if FYAxisTitle.Visible then
  begin
    LTextPaint.Color := FYAxisTitle.Color;
    LFont.Size       := FYAxisTitle.FontSize;
    TitleWidth := LFont.MeasureText(FYAxisTitle.Text);
    ACanvas.Save;
    try
      ACanvas.Translate(AMapper.PixelRect.Left - 45,
                        AMapper.PixelRect.CenterPoint.Y + (TitleWidth / 2));
      ACanvas.Rotate(270);
      ACanvas.DrawSimpleText(FYAxisTitle.Text, 0, 0, LFont, LTextPaint);
    finally
      ACanvas.Restore;
    end;
  end;
end;

// -----------------------------------------------------------------------
//  Data bounds
// -----------------------------------------------------------------------

function TSkPlotPaintBox.CalculateDataBounds: TRectD;
var
  Series: TPlotSeries;
  Point:  TPointD;
  MinX, MaxX, MinY, MaxY: Double;
  FirstPoint: Boolean;
begin
  MinX := 0; MaxX := 0; MinY := 0; MaxY := 0;
  // Default fallback range (also used when log mode hides every point)
  Result.Left := 0; Result.Right := 1; Result.Top := 0; Result.Bottom := 1;
  if (FSeriesList = nil) or (FSeriesList.Count = 0) then Exit;

  FirstPoint := True;
  for Series in FSeriesList do
    for Point in Series.Data do
    begin
      // NaN coordinates are pen-lifts (see TPlotSeries.Draw), not data.
      // They must be ignored here or a single NaN would poison the whole
      // autoscale range (min/max comparisons against NaN are ill-defined).
      if IsNan(Point.X) or IsNan(Point.Y) then Continue;

      // In log mode, points with non-positive coordinates have no
      // representation on the axis and are silently excluded from the
      // bounds calculation. Drawing code applies the same rule so the
      // hidden points never produce visual artifacts.
      if AxisStyle.LogX and (Point.X <= 0) then Continue;
      if AxisStyle.LogY and (Point.Y <= 0) then Continue;

      if FirstPoint then
      begin
        MinX := Point.X; MaxX := Point.X;
        MinY := Point.Y; MaxY := Point.Y;
        FirstPoint := False;
      end
      else
      begin
        if Point.X < MinX then MinX := Point.X;
        if Point.X > MaxX then MaxX := Point.X;
        if Point.Y < MinY then MinY := Point.Y;
        if Point.Y > MaxY then MaxY := Point.Y;
      end;
    end;

  if not FirstPoint then
    begin
    Result.Left := MinX;
    Result.Right := MaxX;
    Result.Top := MinY;
    Result.Bottom := MaxY;
    end;
  // Degenerate LINEAR range: a perfectly flat series (e.g. a time course sitting on a steady
  // state) has MinY = MaxY, giving a zero span that divides by zero in the mapper and hangs the
  // paint. Pad it to a readable non-zero window. Same for a constant-X series.
  if (not AxisStyle.LogY) and (Result.Bottom <= Result.Top) then
  begin
    if Result.Top = 0 then
    begin Result.Top := -1.0; Result.Bottom := 1.0; end
    else
    begin
      var PadY := Abs(Result.Top) * 0.1;
      Result.Top := Result.Top - PadY;
      Result.Bottom := Result.Bottom + PadY;
    end;
  end;
  if (not AxisStyle.LogX) and (Result.Right <= Result.Left) then
  begin
    if Result.Left = 0 then
    begin Result.Left := -1.0; Result.Right := 1.0; end
    else
    begin
      var PadX := Abs(Result.Left) * 0.1;
      Result.Left := Result.Left - PadX;
      Result.Right := Result.Right + PadX;
    end;
  end;

  // Guard against degenerate ranges (single point, or all points filtered
  // out by log-mode exclusion). Use a one-decade window centered on the
  // value so the axis stays readable.
  if AxisStyle.LogX and (Result.Right <= Result.Left) then
  begin
    if Result.Left <= 0 then
    begin
      Result.Left  := 1.0;
      Result.Right := 10.0;
    end
    else
      Result.Right := Result.Left * 10;
  end;

  if AxisStyle.LogY and (Result.Bottom <= Result.Top) then
  begin
    if Result.Top <= 0 then
    begin
      Result.Top    := 1.0;
      Result.Bottom := 10.0;
    end
    else
      Result.Bottom := Result.Top * 10;
  end;
end;

function TSkPlotPaintBox.GetEffectiveDataBounds: TRectD;
begin
  Result := CalculateDataBounds;

  // A NaN on either bound means "leave this side auto-scaled", so a caller can
  // pin just the min or just the max (e.g. only the Y-max box filled in).
  if not FAutoY then
  begin
    if not IsNan(FSubAxisProperty.MinY) then Result.Top    := FSubAxisProperty.MinY;
    if not IsNan(FSubAxisProperty.MaxY) then Result.Bottom := FSubAxisProperty.MaxY;
  end;

  if not FAutoX then
  begin
    if not IsNan(FSubAxisProperty.MinX) then Result.Left  := FSubAxisProperty.MinX;
    if not IsNan(FSubAxisProperty.MaxX) then Result.Right := FSubAxisProperty.MaxX;
  end;
end;

// -----------------------------------------------------------------------
//  RenderChart
// -----------------------------------------------------------------------

procedure TSkPlotPaintBox.RenderChart(const ACanvas: ISkCanvas;
                                      const ADest: TRectF);
var
  Mapper:    TPlotMapper;
  LPaint:    ISkPaint;
  LMarkerFill, LMarkerStroke: ISkPaint;
  Series:    TPlotSeries;
  RawBounds: TRectD;
  PadX, PadY: Double;
  LogPad: Double;
begin
  // Fill entire paintbox background
  LPaint := TSkPaint.Create;
  LPaint.Color := FBackgroundColor;
  LPaint.Style := TSkPaintStyle.Fill;
  ACanvas.DrawRect(ADest, LPaint);

  ACanvas.Save;
  try
    // An interactive zoom/pan window is the exact data rect to display, so it
    // bypasses the autoscale bounds and the 5% padding applied below.
    if FHasViewOverride then
    begin
      Mapper.DataRect  := FViewRect;
      Mapper.PixelRect := ADest;
      Mapper.PixelRect.Inflate(-80, -70);
      Mapper.LogX := AxisStyle.LogX;
      Mapper.LogY := AxisStyle.LogY;

      LPaint.Style := TSkPaintStyle.Fill;
      LPaint.Color := FPlotAreaColor;
      ACanvas.DrawRect(Mapper.PixelRect, LPaint);

      FLastMapper := Mapper;
      FHasMapper  := True;

      DrawGrid(ACanvas, Mapper, FPlotBorderColor, FPlotBorderWidth, FPlotBorderVisible);

      ACanvas.Save;
      try
        ACanvas.ClipRect(Mapper.PixelRect);
        for Series in FSeriesList do
          Series.Draw(ACanvas, Mapper);
      finally
        ACanvas.Restore;
      end;

      DrawAnnotations(ACanvas, Mapper);
      DrawLegend(ACanvas, Mapper);
      Exit;
    end;

    RawBounds := GetEffectiveDataBounds;
    PadX := RawBounds.Width  * 0.05;
    PadY := RawBounds.Height * 0.05;
    Mapper.DataRect := RawBounds;

    if FOriginOnAxis then
    begin
      if RawBounds.Left >= 0 then
        Mapper.DataRect.Left := Max(0.0, RawBounds.Left - PadX)
      else
        Mapper.DataRect.Left := RawBounds.Left - PadX;

      Mapper.DataRect.Right := RawBounds.Right + PadX;

      if RawBounds.Top >= 0 then
        Mapper.DataRect.Top := Max(0.0, RawBounds.Top - PadY)
      else
        Mapper.DataRect.Top := RawBounds.Top - PadY;

      Mapper.DataRect.Bottom := RawBounds.Bottom + PadY;
    end
    else
      Mapper.DataRect.Inflate(PadX, PadY);

    // Log-space padding overrides the linear padding above. Linear padding
    // on a log axis can drive the lower bound below zero, after which the
    // mapper clamps it to 1e-9 and the axis appears to extend to absurdly
    // small values. A multiplicative pad keeps the visual breathing room
    // proportional in log space.
    if AxisStyle.LogX and (RawBounds.Left > 0) and (RawBounds.Right > RawBounds.Left) then
    begin
      LogPad := 0.05 * (Log10(RawBounds.Right) - Log10(RawBounds.Left));
      Mapper.DataRect.Left  := Power(10, Log10(RawBounds.Left)  - LogPad);
      Mapper.DataRect.Right := Power(10, Log10(RawBounds.Right) + LogPad);
    end;

    if AxisStyle.LogY and (RawBounds.Top > 0) and (RawBounds.Bottom > RawBounds.Top) then
    begin
      LogPad := 0.05 * (Log10(RawBounds.Bottom) - Log10(RawBounds.Top));
      Mapper.DataRect.Top    := Power(10, Log10(RawBounds.Top)    - LogPad);
      Mapper.DataRect.Bottom := Power(10, Log10(RawBounds.Bottom) + LogPad);
    end;

    Mapper.PixelRect := ADest;
    Mapper.PixelRect.Inflate(-80, -70);
    Mapper.LogX := AxisStyle.LogX;
    Mapper.LogY := AxisStyle.LogY;

    // Fill plot area background
    LPaint.Style := TSkPaintStyle.Fill;
    LPaint.Color := FPlotAreaColor;
    ACanvas.DrawRect(Mapper.PixelRect, LPaint);

    FLastMapper := Mapper;
    FHasMapper  := True;

    // Grid, axes, ticks, labels, titles
    DrawGrid(ACanvas, Mapper, FPlotBorderColor, FPlotBorderWidth, FPlotBorderVisible);

    // Series — clipped to plot area
    ACanvas.Save;
    try
      ACanvas.ClipRect(Mapper.PixelRect);
      for Series in FSeriesList do
        Series.Draw(ACanvas, Mapper);
    finally
      ACanvas.Restore;
    end;

    // Marker paints (kept for series compatibility)
    LMarkerFill := TSkPaint.Create(TSkPaintStyle.Fill);
    LMarkerFill.Color     := TAlphaColors.White;
    LMarkerFill.AntiAlias := True;

    LMarkerStroke := TSkPaint.Create(TSkPaintStyle.Stroke);
    LMarkerStroke.Color       := TAlphaColors.Dodgerblue;
    LMarkerStroke.StrokeWidth := 2;
    LMarkerStroke.AntiAlias   := True;

    // Data-anchored labels sit on top of the series but under the legend.
    DrawAnnotations(ACanvas, Mapper);

    DrawLegend(ACanvas, Mapper);

  finally
    ACanvas.Restore;
  end;
end;

// -----------------------------------------------------------------------
//  Mouse handling
// -----------------------------------------------------------------------

function TSkPlotPaintBox.FindNearestPoint(APixelX, APixelY: Single;
  out ASeries: TPlotSeries; out AIndex: Integer;
  out ADataX, ADataY: Double): Boolean;
var
  Series: TPlotSeries;
  I: Integer;
  P: TPointD;
  PixX, PixY, DX, DY, DistSq, BestSq, TolSq: Single;
begin
  Result  := False;
  ASeries := nil;
  AIndex  := -1;
  ADataX  := 0;
  ADataY  := 0;

  if not FHasMapper then
    Exit;

  TolSq  := FPickTolerance * FPickTolerance;
  BestSq := TolSq;

  for Series in FSeriesList do
  begin
    if not Series.Visible then
      Continue;

    for I := 0 to Series.Data.Count - 1 do
    begin
      P := Series.Data[I];
      // NaN coordinates are pen-lift separators, not real points.
      if IsNan(P.X) or IsNan(P.Y) then
        Continue;

      PixX := FLastMapper.MapX(P.X);
      PixY := FLastMapper.MapY(P.Y);

      DX := PixX - APixelX;
      DY := PixY - APixelY;
      DistSq := DX * DX + DY * DY;

      if DistSq <= BestSq then
      begin
        BestSq  := DistSq;
        ASeries := Series;
        AIndex  := I;
        ADataX  := P.X;
        ADataY  := P.Y;
        Result  := True;
      end;
    end;
  end;
end;

procedure TSkPlotPaintBox.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
     Item1, Item2, Item3 : TMenuItem;
     PickSeries : TPlotSeries;
     PickIndex  : Integer;
     PickX, PickY : Double;
begin
  inherited MouseDown(Button, Shift, X, Y);

  if (Button = TMouseButton.mbLeft) and
     FLegendStyle.Visible and
     FLegendRect.Contains(TPointF.Create(X, Y)) then
  begin
    FDraggingLegend    := True;
    FLegendDragStart   := TPointF.Create(X, Y);
    FLegendOffsetStart := FLegendOffset;
    // Capture the mouse so we keep receiving events even if the cursor
    // moves quickly outside the legend bounds
    Capture;
  end
  else if Button = TMouseButton.mbLeft then
  begin
    if FZoomPanEnabled and (ssShift in Shift) and FHasMapper then
    begin
      // Shift held: begin a rubber-band box zoom instead of a pan. The boxed
      // region is unmapped through this press-time mapper in MouseUp.
      FBoxZooming    := True;
      FBoxZoomStart  := TPointF.Create(X, Y);
      FBoxZoomCur    := FBoxZoomStart;
      FBoxZoomMapper := FLastMapper;
      Cursor         := crCross;
      Capture;
    end
    else if FZoomPanEnabled then
    begin
      // Begin a pan candidate. Whether this becomes a pan or a click (which
      // fires the pick, in MouseUp) is decided by the drag threshold in
      // MouseMove, so panning and point-picking can coexist.
      FPanCandidate   := True;
      FPanning        := False;
      FDidPan         := False;
      FPanStartPos    := TPointF.Create(X, Y);
      FPanStartMapper := FLastMapper;
      Capture;
    end
    else if Assigned(FOnPointPicked) then
    begin
      // A left-click that isn't grabbing the legend: report the nearest data
      // point if one lies within PickTolerance pixels of the cursor.
      if FindNearestPoint(X, Y, PickSeries, PickIndex, PickX, PickY) then
        FOnPointPicked(Self, PickSeries, PickIndex, PickX, PickY);
    end;
  end;
  if Button = TMouseButton.mbRight then
     begin
     if FPaintBoxMenu = nil then
        begin
        FPaintBoxMenu := TPopupMenu.Create(Self);
        FPaintBoxMenu.Parent := Self;
        Item1 := TMenuItem.Create(FPaintBoxMenu);
        Item1.Text := 'Copy Image to Clipboard';
        Item1.OnClick := DoCopyImageToClipboard;
        FPaintBoxMenu.AddObject(Item1);
        Item2 := TMenuItem.Create(FPaintBoxMenu);
        Item2.Text := 'Export as PDF';
        Item2.OnClick := DoExportPDF;
        FPaintBoxMenu.AddObject(Item2);
        Item3 := TMenuItem.Create(FPaintBoxMenu);
        Item3.Text := 'Export as PNG';
        Item3.OnClick := DoExportPNG;
        FPaintBoxMenu.AddObject(Item3);
        end;
     FPaintBoxMenu.Popup(Screen.MousePos.X, Screen.MousePos.Y);
     end;
end;

procedure TSkPlotPaintBox.MouseUp(Button: TMouseButton; Shift: TShiftState;
                                  X, Y: Single);
var
  PickSeries : TPlotSeries;
  PickIndex  : Integer;
  PickX, PickY : Double;
  MinPxX, MaxPxX, MinPxY, MaxPxY : Single;
begin
  inherited MouseUp(Button, Shift, X, Y);

  if FDraggingLegend then
  begin
    FDraggingLegend := False;
    ReleaseCapture;
  end;

  if FBoxZooming and (Button = TMouseButton.mbLeft) then
  begin
    FBoxZooming := False;
    ReleaseCapture;
    Cursor := crDefault;

    // Ignore a trivially small box (effectively a Shift-click) rather than
    // zooming to a near-degenerate window. A real drag maps its pixel corners
    // back through the press-time mapper — log axes come out right for free.
    if (Abs(X - FBoxZoomStart.X) > 5) and (Abs(Y - FBoxZoomStart.Y) > 5) and
       (FBoxZoomMapper.PixelRect.Width <> 0) then
    begin
      MinPxX := Min(FBoxZoomStart.X, X);   MaxPxX := Max(FBoxZoomStart.X, X);
      MinPxY := Min(FBoxZoomStart.Y, Y);   MaxPxY := Max(FBoxZoomStart.Y, Y);
      FViewRect.Left   := FBoxZoomMapper.UnmapX(MinPxX);
      FViewRect.Right  := FBoxZoomMapper.UnmapX(MaxPxX);
      FViewRect.Top    := FBoxZoomMapper.UnmapY(MaxPxY);  // pixel bottom -> data min
      FViewRect.Bottom := FBoxZoomMapper.UnmapY(MinPxY);  // pixel top    -> data max
      FHasViewOverride := True;
      Redraw;
    end;
    Exit;
  end;

  if FPanCandidate and (Button = TMouseButton.mbLeft) then
  begin
    FPanCandidate := False;
    FPanning      := False;
    ReleaseCapture;
    Cursor := crDefault;
    // A press that never crossed the drag threshold is a click, so fire the
    // pick just as the non-zoom path does on MouseDown.
    if (not FDidPan) and Assigned(FOnPointPicked) then
      if FindNearestPoint(X, Y, PickSeries, PickIndex, PickX, PickY) then
        FOnPointPicked(Self, PickSeries, PickIndex, PickX, PickY);
  end;
end;

procedure TSkPlotPaintBox.MouseMove(Shift: TShiftState; X, Y: Single);
const
  PanThreshold = 3;   // pixels of movement before a press counts as a pan
var
  WorldX, WorldY: Single;
  DX, DY: Single;
begin
  inherited MouseMove(Shift, X, Y);

  FLastMousePos := TPointF.Create(X, Y);  // wheel zoom needs this

  // A box zoom in progress owns the drag: just grow the rubber band.
  if FBoxZooming then
  begin
    FBoxZoomCur := TPointF.Create(X, Y);
    Cursor      := crCross;
    Redraw;
    Exit;
  end;

  // Active pan takes precedence over everything else.
  if FPanCandidate then
  begin
    DX := X - FPanStartPos.X;
    DY := Y - FPanStartPos.Y;

    if (not FPanning) and ((Abs(DX) > PanThreshold) or (Abs(DY) > PanThreshold)) then
      FPanning := True;

    if FPanning and (FPanStartMapper.PixelRect.Width <> 0) then
    begin
      // Translate the view so the data grabbed at press stays under the
      // cursor. Unmapping shifted pixel positions through the press-time
      // mapper keeps this exact and drift-free (and log-axis correct).
      FViewRect.Left   := FPanStartMapper.UnmapX(FPanStartMapper.PixelRect.Left   - DX);
      FViewRect.Right  := FPanStartMapper.UnmapX(FPanStartMapper.PixelRect.Right  - DX);
      FViewRect.Top    := FPanStartMapper.UnmapY(FPanStartMapper.PixelRect.Bottom - DY);
      FViewRect.Bottom := FPanStartMapper.UnmapY(FPanStartMapper.PixelRect.Top    - DY);
      FHasViewOverride := True;
      FDidPan          := True;
      Cursor           := crSizeAll;
      Redraw;
    end;
    Exit;  // suppress legend cursor / coordinate reporting while panning
  end;

  // Update cursor to signal that the legend is draggable
  if FLegendStyle.Visible and FLegendRect.Contains(TPointF.Create(X, Y)) then
    Cursor := crHandPoint
  else if not FDraggingLegend then
    Cursor := crDefault;

  // Handle active drag
  if FDraggingLegend then
  begin
    FLegendOffset.X := FLegendOffsetStart.X + (X - FLegendDragStart.X);
    FLegendOffset.Y := FLegendOffsetStart.Y + (Y - FLegendDragStart.Y);
    Redraw;
    Exit;  // suppress coordinate reporting while dragging
  end;

  if Assigned(FOnReportCoordinates) and FHasMapper then
  begin
    WorldX := FLastMapper.UnmapX(X);
    WorldY := FLastMapper.UnmapY(Y);
    FOnReportCoordinates(X, Y, WorldX, WorldY);
  end;
end;

procedure TSkPlotPaintBox.MouseWheel(Shift: TShiftState; WheelDelta: Integer;
                                     var Handled: Boolean);
begin
  inherited MouseWheel(Shift, WheelDelta, Handled);
  if Handled or (not FZoomPanEnabled) or (not FHasMapper) then
    Exit;

  // Wheel up (positive delta) zooms in — shrink the window about the cursor.
  if WheelDelta > 0 then
    ZoomAboutPixel(FLastMousePos.X, FLastMousePos.Y, 1 / 1.2)
  else
    ZoomAboutPixel(FLastMousePos.X, FLastMousePos.Y, 1.2);
  Handled := True;
end;

procedure TSkPlotPaintBox.DblClick;
begin
  inherited DblClick;
  // A double-click is the quick way back to the full autoscaled view.
  if FZoomPanEnabled then
    ResetZoom;
end;

procedure TSkPlotPaintBox.ZoomAboutPixel(ACx, ACy, AFactor: Single);
var
  NewL, NewR, NewT, NewB: Single;
begin
  if not FHasMapper then Exit;
  if FLastMapper.PixelRect.Width = 0 then Exit;

  // Scale the plot-edge pixel positions toward the cursor, then read the data
  // values there through the current mapper. Working in pixel space means log
  // axes zoom correctly for free.
  NewL := ACx + (FLastMapper.PixelRect.Left   - ACx) * AFactor;
  NewR := ACx + (FLastMapper.PixelRect.Right  - ACx) * AFactor;
  NewT := ACy + (FLastMapper.PixelRect.Top    - ACy) * AFactor;
  NewB := ACy + (FLastMapper.PixelRect.Bottom - ACy) * AFactor;

  FViewRect.Left   := FLastMapper.UnmapX(NewL);
  FViewRect.Right  := FLastMapper.UnmapX(NewR);
  FViewRect.Top    := FLastMapper.UnmapY(NewB);  // pixel bottom -> data min
  FViewRect.Bottom := FLastMapper.UnmapY(NewT);  // pixel top    -> data max
  FHasViewOverride := True;
  Redraw;
end;

procedure TSkPlotPaintBox.DrawZoomBox(const ACanvas: ISkCanvas);
var
  R:      TRectF;
  LPaint: ISkPaint;
begin
  R := TRectF.Create(FBoxZoomStart.X, FBoxZoomStart.Y, FBoxZoomCur.X, FBoxZoomCur.Y);
  R.NormalizeRect;   // corners may be dragged in any direction

  LPaint := TSkPaint.Create(TSkPaintStyle.Fill);
  LPaint.AntiAlias := True;

  // Translucent fill + solid border, so the boxed region stays readable.
  LPaint.Color := TAlphaColor($303399FF);
  ACanvas.DrawRect(R, LPaint);

  LPaint.Style       := TSkPaintStyle.Stroke;
  LPaint.StrokeWidth := 1;
  LPaint.Color       := TAlphaColor($FF3399FF);
  ACanvas.DrawRect(R, LPaint);
end;

procedure TSkPlotPaintBox.SetZoomPanEnabled(Value: Boolean);
begin
  if FZoomPanEnabled = Value then Exit;
  FZoomPanEnabled := Value;
  // Leaving zoom/pan mode drops any interactive window so the chart returns
  // to its normal autoscale / manual-limits view.
  if not FZoomPanEnabled then
    ResetZoom;
end;

procedure TSkPlotPaintBox.ResetZoom;
begin
  FPanCandidate := False;
  FPanning      := False;
  FBoxZooming   := False;
  if FHasViewOverride then
  begin
    FHasViewOverride := False;
    Redraw;
  end;
end;

end.
