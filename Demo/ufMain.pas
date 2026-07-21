unit ufMain;

interface

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.UIConsts,
  System.Classes,
  System.Variants,
  FMX.Types,
  FMX.Controls,
  FMX.Forms,
  FMX.Graphics,
  FMX.Dialogs,
  SkPlotPaintBox,
  Skia, FMX.Skia,
  FMX.Controls.Presentation,
  FMX.StdCtrls,
  uPlotSeries,
  ufPlotEditor,
  System.Generics.Collections,
  uLinearRegression,
  IOUtils,
  uLabelledTrackbar,
  FMX.Layouts,
  FMX.Menus,
  FMX.Memo.Types, FMX.ScrollBox, FMX.Memo;

type
  TfrmMain = class(TForm)
    OpenDialog1: TOpenDialog;
    MainMenu1: TMainMenu;
    mnuFile: TMenuItem;
    mnuEdit: TMenuItem;
    mnuNew: TMenuItem;
    mnuOpen: TMenuItem;
    MenuItem3: TMenuItem;
    mnuPrintPDF: TMenuItem;
    MenuItem4: TMenuItem;
    mnuQuit: TMenuItem;
    SaveDialog1: TSaveDialog;
    mnuTools: TMenuItem;
    Layout2: TLayout;
    Layout3: TLayout;
    Layout1: TLayout;
    btnEditor: TButton;
    btnExportPDF: TButton;
    btnExportToPng: TButton;
    btnDeleteSeries: TButton;
    Label1: TLabel;
    btnLinearReg: TButton;
    LabelledTrackBar1: TLabelledTrackBar;
    btnExportCSV: TButton;
    btnExportToString: TButton;
    StyleBook1: TStyleBook;
    btnLoaddata: TButton;
    btnClear: TButton;
    btnPlotData: TButton;
    btnPlot2: TButton;
    btnSavePlot: TButton;
    btnLoadPlot: TButton;
    Plot: TSkPlotPaintBox;
    btnData3: TButton;
    btnLoadSimData: TButton;
    btnLoadSimExperimentalData: TButton;
    btnSaveSettings: TButton;
    btnRestoreSettings: TButton;
    procedure btnLoaddataClick(Sender: TObject);
    procedure btnPlotDataClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure btnPlot2Click(Sender: TObject);
    procedure btnEditorClick(Sender: TObject);
    procedure btnExportPDFClick(Sender: TObject);
    procedure btnExportToPngClick(Sender: TObject);
    procedure btnDeleteSeriesClick(Sender: TObject);
    procedure btnLinearRegClick(Sender: TObject);
    procedure mnuQuitApplyStyleLookup(Sender: TObject);
    procedure mnuPrintPDFClick(Sender: TObject);
    procedure mnuOpenClick(Sender: TObject);
    procedure btnExportCSVClick(Sender: TObject);
    procedure btnExportToStringClick(Sender: TObject);
    procedure btnClearClick(Sender: TObject);
    procedure btnSavePlotClick(Sender: TObject);
    procedure btnLoadPlotClick(Sender: TObject);
    procedure btnData3Click(Sender: TObject);
    procedure btnLoadSimDataClick(Sender: TObject);
    procedure btnLoadSimExperimentalDataClick(Sender: TObject);
    procedure btnSaveSettingsClick(Sender: TObject);
    procedure btnRestoreSettingsClick(Sender: TObject);
  private
//    { Private declarations }
    // Full path to one of the demo's sample data files. They live in Demo\Data\
    // (tracked in the repository) while the exe runs from Demo\Win64\<Config>\,
    // so resolve them relative to the executable rather than the working
    // directory. Files the demo *writes* still go to the working directory.
    function  DataFile(const AName: string): string;
    procedure PlotBox1ReportCoordinates(mouseX, mouseY, worldX, worldY: Single);
  public
    { Public declarations }
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.fmx}

Uses uColorManager;

function TfrmMain.DataFile(const AName: string): string;
begin
  Result := TPath.GetFullPath(
              TPath.Combine(ExtractFilePath(ParamStr(0)),
                            TPath.Combine('..\..\Data', AName)));
end;

procedure TfrmMain.btnClearClick(Sender: TObject);
begin
  Plot.ClearSeries;
  Plot.Redraw;
end;

procedure TfrmMain.btnSavePlotClick(Sender: TObject);
begin
  SaveDialog1.Filter   := 'Plot files (*.json)|*.json|All files (*.*)|*.*';
  SaveDialog1.DefaultExt := 'json';
  if SaveDialog1.Execute then
     Plot.SavePlotToFile(SaveDialog1.FileName);
end;

procedure TfrmMain.btnLoadPlotClick(Sender: TObject);
begin
  OpenDialog1.Filter := 'Plot files (*.json)|*.json|All files (*.*)|*.*';
  if OpenDialog1.Execute then
     Plot.LoadPlotFromFile(OpenDialog1.FileName);
end;

procedure TfrmMain.btnLoadSimDataClick(Sender: TObject);
begin
  Plot.ClearSeries;
  Plot.LoadData(DataFile('Simdata.csv'), True, False, False, True).Free;
  for var i := 0 to Plot.Series.Count -1 do
      Plot.Series[i].SeriesKind := skSimulation;
end;

// Demonstrates the in-memory settings store. Snapshot the current plot's
// styling under a fixed key. Try it like this:
//   1. Plot some data and tweak colours / axis / legend (e.g. via Edit Plot).
//   2. Click 'Save Settings' to remember that styling.
//   3. Change the styling again (or plot different data with the same series
//      names).
//   4. Click 'Restore Settings' — the saved styling comes back. Note the data
//      itself is never captured, only the appearance.
const
  DemoSettingsKey = 'demo';

procedure TfrmMain.btnSaveSettingsClick(Sender: TObject);
begin
  Plot.SaveSettings(DemoSettingsKey);
  ShowMessage('Current plot styling saved under "' + DemoSettingsKey + '".');
end;

procedure TfrmMain.btnRestoreSettingsClick(Sender: TObject);
begin
  // RestoreSettings repaints automatically when the key exists; it returns
  // False if nothing was saved under the key.
  if not Plot.RestoreSettings(DemoSettingsKey) then
    ShowMessage('No settings have been saved yet - click "Save Settings" first.');
end;

procedure TfrmMain.btnLoadSimExperimentalDataClick(Sender: TObject);
begin
  if OpenDialog1.Execute then
     begin
     Plot.LoadData(OpenDialog1.FileName, False, True, False, True).Free;
     end;
end;

procedure TfrmMain.btnData3Click(Sender: TObject);
var Series : TPlotSeries;
    i, N : Integer;
begin
  Plot.ClearSeries;
  Plot.OriginOnAxis := True;

  N := 20;
  Series := TPlotSeries.Create('y1', TColorManager.NextColor);

  for i := 0 to N - 1 do
      Series.AddXY (i/5, Random);
  Plot.AddSeries(Series);
  Plot.ExportCSV('series1.csv');

  N := 20;
  Series := TPlotSeries.Create('y2', TColorManager.NextColor);
  for i := 0 to N - 1 do
      Series.AddXY (i/5, Random + 1);
  Plot.AddSeries(Series);
    Plot.ExportCSV('series2.csv');

  N := 20;
  Series := TPlotSeries.Create('y3', TColorManager.NextColor);
  for i := 0 to N - 1 do
      Series.AddXY (i/5, Random + 2);
  Plot.AddSeries(Series);
  Plot.ExportCSV('series3.csv');

  Plot.Redraw
end;

procedure TfrmMain.btnDeleteSeriesClick(Sender: TObject);
var FindIndex : Integer;
begin
  if Plot.Series.Find ('y2', FindIndex) then
     Plot.Series.Delete(FindIndex)
  else
     Showmessage ('Series y2 not found');
  Plot.Redraw;
end;

procedure TfrmMain.btnEditorClick(Sender: TObject);
begin
  if not Assigned (frmPlotEditor) then
     frmPlotEditor := TfrmPlotEditor.Create (nil);
  try
     frmPlotEditor.CopyPropertiesToEditor (Plot);
     frmPlotEditor.Show;
     Plot.Redraw;
  finally
  end;
end;

procedure TfrmMain.btnExportCSVClick(Sender: TObject);
begin
  Plot.ExportCSV ('text.csv');
end;

procedure TfrmMain.btnExportPDFClick(Sender: TObject);
begin
  Plot.ExportToPdf('TestPlot.PDF');
end;

procedure TfrmMain.btnExportToPngClick(Sender: TObject);
begin
  Plot.ExportToPng('TestPlot.png', 4.0);
end;

procedure TfrmMain.btnExportToStringClick(Sender: TObject);
begin
   //moText.Text := Plot.ExportCSVSeriesAsString (5);
end;

procedure TfrmMain.btnLinearRegClick(Sender: TObject);
var Slope, Intercept : Double;
    ps : TPlotSeries;
    x1, y1, x2, y2 : Double;
begin
  Plot.LoadData(DataFile('linear.csv'), True, True, False, False).Free;
  CalculateLinearRegression(Plot.Series[0], Slope, Intercept);
  ps := TPlotSeries.Create('Fitted', claBlue, False);
  x1 := Plot.Series[0].Data[0].X;
  y1 := Plot.Series[0].Data[0].X*Slope + Intercept;
  x2 := Plot.Series[0].Data[6].X;
  y2 := Plot.Series[0].Data[6].X*Slope + Intercept;
  ps.AddXY(x1, y1);
  ps.AddXY(x2, y2);
  Plot.AddSeries(ps);
  Plot.Redraw;
end;

procedure TfrmMain.btnLoaddataClick(Sender: TObject);
begin
  if OpenDialog1.Execute then
     begin
     Plot.LoadData(OpenDialog1.FileName, True, True, False, True).Free;
     //showmessage (Plot.ExportCSVSeriesAsString(10, 16))
     end;
end;

procedure TfrmMain.btnPlot2Click(Sender: TObject);
var Series : TPlotSeries;
    i, N : Integer;
begin
  Plot.ClearSeries;
  Plot.OriginOnAxis := True;

  N := 60;
  Series := TPlotSeries.Create('y1', TColorManager.NextColor);

  for i := 0 to N - 1 do
      Series.AddXY (i/5, Random);
  Plot.AddSeries(Series);

  N := 24;
  Series := TPlotSeries.Create('y2', TColorManager.NextColor);
  for i := 0 to N - 1 do
      Series.AddXY (i/2, Random + 1);
  Plot.AddSeries(Series);

  N := 36;
  Series := TPlotSeries.Create('y3', TColorManager.NextColor);
  for i := 0 to N - 1 do
      Series.AddXY (i/3, Random + 2);
  Plot.AddSeries(Series);

  Plot.Redraw;
end;

procedure TfrmMain.btnPlotDataClick(Sender: TObject);
var Series : TPlotSeries;
    i, N : Integer;
begin
  Plot.ClearSeries;
  Plot.OriginOnAxis := True;
  Plot.AutoYScaling := True;

  Plot.GridStyle.XMinorVisible := True;
  Plot.GridStyle.YMinorVisible := True;

  N := 60;
  Series := TPlotSeries.Create('y1', TColorManager.NextColor);

  for i := 0 to N - 1 do
      Series.AddXY (i/5, sin (i/5));
  Plot.AddSeries(Series);

  N := 24;
  Series := TPlotSeries.Create('y2', TColorManager.NextColor);
  Series.MarkerFillColor := claLightblue;

  for i := 0 to N - 1 do
      Series.AddXY (i/2, cos (i/2));
  Plot.AddSeries(Series);

  Plot.LegendStyle.Visible           := True;
  Plot.LegendStyle.Location          := llTopRight;
  Plot.LegendStyle.BorderVisible     := True;
  Plot.LegendStyle.BorderColor       := TAlphaColors.Dimgray;
  Plot.LegendStyle.BorderWidth       := 1.5;
  Plot.LegendStyle.BackgroundColor   := TAlphaColors.Whitesmoke;
  Plot.LegendStyle.BackgroundOpacity := 0.9;

  Plot.Redraw;
end;

procedure TfrmMain.PlotBox1ReportCoordinates(mouseX, mouseY, worldX, worldY: Single);
begin
  Label1.Text := Format('Mouse (%.0f, %.0f)   World (%.4f, %.4f)',
                                  [mouseX, mouseY, worldX, worldY]);
end;

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  //Plot := TSkPlotPaintBox.Create (Self);
  //Plot.Parent := Self;
  //Plot.Width := 350;
  //Plot.Height := 300;
  Plot.OnReportCoordinates := PlotBox1ReportCoordinates;
  Plot.DefaultsFile := DataFile('plot_defaults.json');

  // Create some standard data

end;

procedure TfrmMain.mnuOpenClick(Sender: TObject);
begin
  if OpenDialog1.Execute then
     begin
     Plot.LoadData(OpenDialog1.FileName, True, True, False, True).Free;
     end;
end;

procedure TfrmMain.mnuPrintPDFClick(Sender: TObject);
begin
  if SaveDialog1.Execute then
     Plot.ExportToPDF (SaveDialog1.FileName);
end;

procedure TfrmMain.mnuQuitApplyStyleLookup(Sender: TObject);
begin
   Application.Terminate;
end;

end.
