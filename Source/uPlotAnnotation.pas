unit uPlotAnnotation;

// ---------------------------------------------------------------------------
//  uPlotAnnotation
//
//  A text label anchored to a DATA coordinate but offset by a fixed number of
//  SCREEN PIXELS. This is what keeps a label ("LP1", "H1", "BP2" — the
//  AUTO / XPPAUT / MatCont / PyDSTool convention) glued to a special point
//  through resize and rescale while preserving a constant visual gap: the
//  anchor tracks the data through the mapper, the offset stays in pixels so
//  the gap does not grow or shrink with zoom.
//
//  A TPlotAnnotation is deliberately NOT a series: it carries no line/marker
//  data, never contributes to autoscale bounds, and never appears in the
//  legend. The owning control keeps them in an Annotations collection and
//  draws them on top of the series.
//
//  Persistence mirrors the rest of the component: SaveToJson emits every
//  field, LoadFromJson applies them with the current value as the fallback so
//  older/newer files load gracefully.
// ---------------------------------------------------------------------------

interface

uses
  System.Types,
  System.UITypes,
  System.JSON,
  Generics.Collections,
  Skia,
  uPlotMapper;

type
  // 9-way alignment of the label box relative to the (anchor + pixel offset)
  // reference point. The named corner/edge of the box is placed at the
  // reference point; e.g. aaBottomLeft puts the box's bottom-left there so the
  // text sits up-and-right of the point.
  TAnnotationAlign = (
    aaTopLeft,    aaTopCenter,    aaTopRight,
    aaMiddleLeft, aaMiddleCenter, aaMiddleRight,
    aaBottomLeft, aaBottomCenter, aaBottomRight);

  TPlotAnnotation = class
  private
    FText: string;
    FAnchor: TPointD;            // anchor in DATA coordinates
    FOffsetX, FOffsetY: Single;  // offset in SCREEN PIXELS (X right, Y down)
    FAlign: TAnnotationAlign;

    FFontSize:  Single;
    FFontColor: TAlphaColor;

    FBackgroundVisible: Boolean;
    FBackgroundColor:   TAlphaColor;
    FBorderVisible:     Boolean;
    FBorderColor:       TAlphaColor;
    FBorderWidth:       Single;
    FPadding:           Single;

    FLeaderVisible: Boolean;     // thin line from the label back to the anchor
    FLeaderColor:   TAlphaColor;
    FLeaderWidth:   Single;

    FVisible: Boolean;
  public
    constructor Create(const AText: string; const AAnchorX, AAnchorY: Double);

    function  Clone: TPlotAnnotation;
    procedure Draw(const ACanvas: ISkCanvas; const AMapper: TPlotMapper);

    function  SaveToJson: TJSONObject;
    procedure LoadFromJson(const Obj: TJSONObject);

    property Text: string read FText write FText;
    property Anchor: TPointD read FAnchor write FAnchor;
    property OffsetX: Single read FOffsetX write FOffsetX;
    property OffsetY: Single read FOffsetY write FOffsetY;
    property Align: TAnnotationAlign read FAlign write FAlign;

    property FontSize:  Single      read FFontSize  write FFontSize;
    property FontColor: TAlphaColor read FFontColor write FFontColor;

    property BackgroundVisible: Boolean     read FBackgroundVisible write FBackgroundVisible;
    property BackgroundColor:   TAlphaColor read FBackgroundColor   write FBackgroundColor;
    property BorderVisible:     Boolean     read FBorderVisible     write FBorderVisible;
    property BorderColor:       TAlphaColor read FBorderColor       write FBorderColor;
    property BorderWidth:       Single      read FBorderWidth       write FBorderWidth;
    property Padding:           Single      read FPadding           write FPadding;

    property LeaderVisible: Boolean     read FLeaderVisible write FLeaderVisible;
    property LeaderColor:   TAlphaColor read FLeaderColor   write FLeaderColor;
    property LeaderWidth:   Single      read FLeaderWidth   write FLeaderWidth;

    property Visible: Boolean read FVisible write FVisible;
  end;

  // Owns its annotations; freeing the list (or removing an item) frees it.
  TPlotAnnotationList = class(TObjectList<TPlotAnnotation>);

implementation

uses
  System.Math,
  uPlotJsonUtils;

constructor TPlotAnnotation.Create(const AText: string; const AAnchorX, AAnchorY: Double);
begin
  inherited Create;

  FText   := AText;
  FAnchor := TPointD.Create(AAnchorX, AAnchorY);

  // Default offset places the label a few pixels up-and-right of the point,
  // the usual position for a bifurcation label. aaBottomLeft means the box's
  // bottom-left corner sits at the reference point, so text grows up-right.
  FOffsetX := 6;
  FOffsetY := -8;
  FAlign   := aaBottomLeft;

  FFontSize  := 12;
  FFontColor := TAlphaColors.Black;

  // Background/border default OFF (a bare label). Callers labelling points
  // that sit on top of a curve turn BackgroundVisible on for legibility.
  FBackgroundVisible := False;
  FBackgroundColor   := TAlphaColors.White;
  FBorderVisible     := False;
  FBorderColor       := TAlphaColors.Gray;
  FBorderWidth       := 1.0;
  FPadding           := 3.0;

  FLeaderVisible := False;
  FLeaderColor   := TAlphaColors.Gray;
  FLeaderWidth   := 1.0;

  FVisible := True;
end;

function TPlotAnnotation.Clone: TPlotAnnotation;
begin
  Result := TPlotAnnotation.Create(FText, FAnchor.X, FAnchor.Y);

  Result.FOffsetX := FOffsetX;
  Result.FOffsetY := FOffsetY;
  Result.FAlign   := FAlign;

  Result.FFontSize  := FFontSize;
  Result.FFontColor := FFontColor;

  Result.FBackgroundVisible := FBackgroundVisible;
  Result.FBackgroundColor   := FBackgroundColor;
  Result.FBorderVisible     := FBorderVisible;
  Result.FBorderColor       := FBorderColor;
  Result.FBorderWidth       := FBorderWidth;
  Result.FPadding           := FPadding;

  Result.FLeaderVisible := FLeaderVisible;
  Result.FLeaderColor   := FLeaderColor;
  Result.FLeaderWidth   := FLeaderWidth;

  Result.FVisible := FVisible;
end;

procedure TPlotAnnotation.Draw(const ACanvas: ISkCanvas; const AMapper: TPlotMapper);
var
  LFont:  ISkFont;
  LPaint: ISkPaint;
  AnchorX, AnchorY: Single;   // anchor mapped to pixels
  RefX, RefY:       Single;   // anchor + pixel offset
  TextW, Ascent, Descent, TextH: Single;
  BoxL, BoxT:  Single;        // content box top-left
  BgRect:      TRectF;        // padded box (background / border)
  BaseX, BaseY: Single;       // text baseline origin
begin
  if not FVisible then Exit;
  if FText = '' then Exit;

  // Anchor: data -> pixels through the same mapper the series use, so the
  // label tracks its data point across every rescale/resize. The offset is
  // then added in pixels, giving a gap that stays constant with zoom.
  AnchorX := AMapper.MapX(FAnchor.X);
  AnchorY := AMapper.MapY(FAnchor.Y);
  RefX    := AnchorX + FOffsetX;
  RefY    := AnchorY + FOffsetY;

  LFont := TSkFont.Create(nil, FFontSize);
  TextW := LFont.MeasureText(FText);

  // Approximate vertical extent from the em size. This avoids depending on the
  // ISkFont metrics API and is accurate enough to size the background box and
  // place the baseline.
  Ascent  := FFontSize * 0.80;   // baseline up to top of glyphs
  Descent := FFontSize * 0.20;   // baseline down to bottom of glyphs
  TextH   := Ascent + Descent;

  // Content box left edge from the horizontal component of the alignment.
  case FAlign of
    aaTopLeft, aaMiddleLeft, aaBottomLeft:
      BoxL := RefX;
    aaTopCenter, aaMiddleCenter, aaBottomCenter:
      BoxL := RefX - TextW / 2;
  else
    BoxL := RefX - TextW;        // right column
  end;

  // Content box top edge from the vertical component of the alignment.
  case FAlign of
    aaTopLeft, aaTopCenter, aaTopRight:
      BoxT := RefY;
    aaMiddleLeft, aaMiddleCenter, aaMiddleRight:
      BoxT := RefY - TextH / 2;
  else
    BoxT := RefY - TextH;        // bottom row
  end;

  BgRect := TRectF.Create(BoxL, BoxT, BoxL + TextW, BoxT + TextH);
  BgRect.Inflate(FPadding, FPadding);

  LPaint := TSkPaint.Create;
  LPaint.AntiAlias := True;

  // Leader first, so the box (if any) paints over the line's end.
  if FLeaderVisible then
  begin
    LPaint.Style       := TSkPaintStyle.Stroke;
    LPaint.Color       := FLeaderColor;
    LPaint.StrokeWidth := FLeaderWidth;
    ACanvas.DrawLine(AnchorX, AnchorY, RefX, RefY, LPaint);
    // Mark the exact anchored data point with a small dot.
    LPaint.Style := TSkPaintStyle.Fill;
    ACanvas.DrawCircle(AnchorX, AnchorY, Max(1.5, FLeaderWidth + 0.5), LPaint);
  end;

  if FBackgroundVisible then
  begin
    LPaint.Style := TSkPaintStyle.Fill;
    LPaint.Color := FBackgroundColor;
    ACanvas.DrawRect(BgRect, LPaint);
  end;

  if FBorderVisible then
  begin
    LPaint.Style       := TSkPaintStyle.Stroke;
    LPaint.Color       := FBorderColor;
    LPaint.StrokeWidth := FBorderWidth;
    ACanvas.DrawRect(BgRect, LPaint);
  end;

  // Text. DrawSimpleText takes the baseline origin, so drop from the box top
  // by the ascent.
  LPaint.Style := TSkPaintStyle.Fill;
  LPaint.Color := FFontColor;
  BaseX := BoxL;
  BaseY := BoxT + Ascent;
  ACanvas.DrawSimpleText(FText, BaseX, BaseY, LFont, LPaint);
end;

function TPlotAnnotation.SaveToJson: TJSONObject;
begin
  Result := TJSONObject.Create;

  JPutStr  (Result, 'text',    FText);
  JPutFloat(Result, 'anchorX', FAnchor.X);
  JPutFloat(Result, 'anchorY', FAnchor.Y);
  JPutFloat(Result, 'offsetX', FOffsetX);
  JPutFloat(Result, 'offsetY', FOffsetY);
  JPutInt  (Result, 'align',   Ord(FAlign));

  JPutFloat(Result, 'fontSize',  FFontSize);
  JPutColor(Result, 'fontColor', FFontColor);

  JPutBool (Result, 'backgroundVisible', FBackgroundVisible);
  JPutColor(Result, 'backgroundColor',   FBackgroundColor);
  JPutBool (Result, 'borderVisible',     FBorderVisible);
  JPutColor(Result, 'borderColor',       FBorderColor);
  JPutFloat(Result, 'borderWidth',       FBorderWidth);
  JPutFloat(Result, 'padding',           FPadding);

  JPutBool (Result, 'leaderVisible', FLeaderVisible);
  JPutColor(Result, 'leaderColor',   FLeaderColor);
  JPutFloat(Result, 'leaderWidth',   FLeaderWidth);

  JPutBool (Result, 'visible', FVisible);
end;

procedure TPlotAnnotation.LoadFromJson(const Obj: TJSONObject);
begin
  if Obj = nil then Exit;

  FText     := JStr  (Obj, 'text',    FText);
  FAnchor.X := JFloat (Obj, 'anchorX', FAnchor.X);
  FAnchor.Y := JFloat (Obj, 'anchorY', FAnchor.Y);
  FOffsetX  := JFloat (Obj, 'offsetX', FOffsetX);
  FOffsetY  := JFloat (Obj, 'offsetY', FOffsetY);
  FAlign    := TAnnotationAlign(JInt(Obj, 'align', Ord(FAlign)));

  FFontSize  := JFloat (Obj, 'fontSize',  FFontSize);
  FFontColor := JColor (Obj, 'fontColor', FFontColor);

  FBackgroundVisible := JBool  (Obj, 'backgroundVisible', FBackgroundVisible);
  FBackgroundColor   := JColor (Obj, 'backgroundColor',   FBackgroundColor);
  FBorderVisible     := JBool  (Obj, 'borderVisible',     FBorderVisible);
  FBorderColor       := JColor (Obj, 'borderColor',       FBorderColor);
  FBorderWidth       := JFloat (Obj, 'borderWidth',       FBorderWidth);
  FPadding           := JFloat (Obj, 'padding',           FPadding);

  FLeaderVisible := JBool  (Obj, 'leaderVisible', FLeaderVisible);
  FLeaderColor   := JColor (Obj, 'leaderColor',   FLeaderColor);
  FLeaderWidth   := JFloat (Obj, 'leaderWidth',   FLeaderWidth);

  FVisible := JBool (Obj, 'visible', FVisible);
end;

end.
