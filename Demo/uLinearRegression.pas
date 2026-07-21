unit uLinearRegression;

interface

Uses Classes, SysUtils, uPlotSeries;

procedure CalculateLinearRegression(Series : TPlotSeries; out Slope, Intercept: Double);

implementation

type
  TDoubleArray = array of Double;

procedure CalculateLinearRegression(Series : TPlotSeries; out Slope, Intercept: Double);
var
  n: Integer;
  sumX, sumY, sumXY, sumX2: Double;
  i: Integer;
begin
  n := Series.Data.Count;
  if n = 0 then
    raise Exception.Create('Data arrays must be non-empty.');

  sumX := 0;
  sumY := 0;
  sumXY := 0;
  sumX2 := 0;

  for i := 0 to n - 1 do
  begin
    sumX := sumX + Series.Data[i].X;
    sumY := sumY + Series.Data[i].Y;
    sumXY := sumXY + (Series.Data[i].X * Series.Data[i].Y);
    sumX2 := sumX2 + (Series.Data[i].X * Series.Data[i].X);
  end;

  // Formula for Slope (m)
  Slope := (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);

  // Formula for Intercept (b)
  Intercept := (sumY - Slope * sumX) / n;
end;

end.
