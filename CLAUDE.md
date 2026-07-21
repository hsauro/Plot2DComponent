# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Delphi **FireMonkey (FMX)** 2D plotting component for RAD Studio (Win64). The core
control is `TSkPlotPaintBox`, a `TSkPaintBox` descendant that renders charts with the
**Skia** backend (`ISkCanvas`). It is shipped as installable design-time/run-time
packages plus a demo app.

## Building & running

There is no command-line build, lint, or test setup — this is a RAD Studio IDE project.
Build with `msbuild` or the IDE.

- **Project group:** `Package/PlotProjectGroup.groupproj` (loads both packages + demo).
- **Run-time package:** `Package/PlotRuntimePackage.dproj` (`{$RUNONLY}`) — all the actual code.
- **Design-time package:** `Package/PlotDesignTimePackage.dproj` (`{$DESIGNONLY}`) — only
  `SkPlotPaintBoxRegister.pas`, which `RegisterComponents('ComponentLibrary', [TSkPlotPaintBox])`.
  Install this package in the IDE to get the component on the palette.
- **Demo app:** `Demo/TestPlotProject.dproj` (Win64). Must set `GlobalUseSkia := True`
  before `Application.Initialize` (see `Demo/TestPlotProject.dpr`).

Build/dependency notes:
- Requires the **Skia** packages (`Skia.Package.FMX`, `Skia.Package.RTL`) — Skia must be
  enabled in the project (`GlobalUseSkia`).
- Requires an external package **`LabelTrackBarRuntime`** (`LabelTrackBarRuntime.dcp`) that
  supplies `TLabelledTrackBar`. `Source/uLabelledTrackBar.pas` is the source of that
  control kept in-tree; the editor form (`ufPlotEditor`) consumes the compiled package.
- `__history/` and `__recovery/` are IDE backup folders — ignore them. `*.dcu`, `Win64/`
  output, and `.~N~` files are build/backup artifacts, not source.

### Command-line build with rsvars.bat

`msbuild` needs the Embarcadero environment (Delphi compiler path, `BDS`, `FrameworkDir`,
etc.). `rsvars.bat` sets those variables. This project is compiled with **Delphi 13
(Florence)** = BDS `37.0` — use that install:

```
C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat
```

(Ignore the `ProjectVersion 20.3` in the `.dproj` — it is stale metadata and does **not**
reflect the compiler actually used.)

From a plain `cmd.exe` (rsvars.bat is a Windows batch file — call it from cmd, not Git Bash):
```cmd
call "C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat"
msbuild Package\PlotProjectGroup.groupproj /t:Build /p:Config=Debug /p:Platform=Win64
```

Build a single project instead of the whole group:
```cmd
msbuild Package\PlotRuntimePackage.dproj    /t:Build /p:Config=Debug /p:Platform=Win64
msbuild Package\PlotDesignTimePackage.dproj /t:Build /p:Config=Debug /p:Platform=Win64
msbuild Demo\TestPlotProject.dproj          /t:Build /p:Config=Debug /p:Platform=Win64
```

**Driving the build from Claude Code's tools:** the `Bash` tool (Git Bash) drops `cmd /c`
into an interactive shell instead of running the command, so rsvars + msbuild fail there.
Use the **PowerShell** tool with a batch wrapper instead — put the `call rsvars.bat` +
`msbuild` lines in a `.bat` file and run it:
```powershell
& cmd /c "path\to\build_demo.bat"
```
A verified working build script (exits 0, links `Demo\Win64\Debug\TestPlotProject.exe`):
```bat
@echo off
call "C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat"
cd /d "D:\Documents\Embarcadero\Studio\Projects\fmx\PlottingComponent"
msbuild Demo\TestPlotProject.dproj /t:Build /p:Config=Debug /p:Platform=Win64 /nologo /v:minimal
echo EXITCODE=%ERRORLEVEL%
```

Notes:
- `/t:Build` (or `/t:Make` for incremental), `/t:Clean` to clean. `Config` is `Debug` or
  `Release`; `Platform` is `Win64`.
- The run-time package must build before the design-time package (the latter `requires`
  it); the `.groupproj` already encodes that order, so prefer building the group.
- Other installed Studio versions on this machine: `22.0` (11 Alexandria), `23.0`
  (12 Athens). Stick with `37.0` to match the compiler the project is actually built with.

## Architecture

Everything compiled into the component lives in `Source/` and is listed in
`Package/PlotRuntimePackage.dpk`. The design separates **the control**, **the data model**,
**coordinate math**, **styling defaults**, and **the property editor**:

- **`SkPlotPaintBox.pas`** (~2000 lines, the heart of the project) — `TSkPlotPaintBox` plus
  the published styling sub-objects (`TAxisLimits`, `TAxisStyle`, `TGridStyle`,
  `TLegendStyle`, `TTextProperty`). Owns the series list, performs all rendering in
  `Draw` → `RenderChart` → `DrawGrid`/`DrawLegend`/series draw, auto/manual axis scaling,
  legend dragging (mouse handlers), and export (`ExportToPng`, `ExportToPdf`, `ExportCSV*`).
  Public API for adding data: `AddSeries`, `LoadData` (from CSV), `ClearSeries`,
  `ClearNamedSeries`, `ReloadDefaults`.
  - **`OnPointPicked(Sender, Series, Index, DataX, DataY)`** — fires on a left-click that
    lands within `PickTolerance` pixels (default 8) of a stored data point, handing back
    that point's **exact** double value (e.g. a fold's `B = 24.384900179508524`) rather than
    the cursor's world position like `OnReportCoordinates`. `FindNearestPoint` does the
    pixel-space search over visible series, skipping NaN pen-lifts.
  - **`ZoomPanEnabled`** (default `False`) — activatable interaction: mouse-wheel zoom about
    the cursor, left-drag pan, double-click (or `ResetZoom`) to restore autoscale. Off by
    default so plain plots are unaffected. When on, it writes an explicit view window
    (`FViewRect`, data coords) that `RenderChart` uses **verbatim** — bypassing autoscale,
    manual `AxisLimits`, and the 5% padding, preserving deep-zoom precision. Zoom/pan math
    works in **pixel space** (unmapping through the mapper), so log axes come out right for
    free. A left press is a pan *candidate* until it crosses a 3px threshold; a press that
    stays under it is a click and fires `OnPointPicked` on mouse-up — so picking and panning
    coexist.
- **`uPlotSeries.pas`** — `TPlotSeries` (one X/Y curve: `Data: TList<TPointD>` — **double
  precision**, line + marker styling, `Draw`) and `TPlotSeriesList`. A series knows how to
  draw itself given a `TPlotMapper`. Two bifurcation-oriented behaviours in `Draw`: a point
  with a **NaN** coordinate is a pen-lift that breaks the polyline (matplotlib/gnuplot
  convention — one series can hold several disconnected runs), and a single-point series
  still renders its marker (the guard is `Count < 1`, not `< 2`). `ShowInLegend: Boolean`
  keeps a curve on the chart but out of the legend, independently of `Visible`.
- **`uPlotAnnotation.pas`** — `TPlotAnnotation` + `TPlotAnnotationList`. A text label
  anchored in **data** coordinates but offset in **screen pixels**, so it stays glued to a
  point (e.g. `LP1`/`H1`/`BP2`) through resize/rescale with a constant visual gap. Carries
  font, optional background fill + border, optional leader line, 9-way alignment
  (`TAnnotationAlign`), `Visible`, and JSON persistence. Never contributes to autoscale and
  never appears in the legend. The control owns them via its `Annotations` collection; add
  with `AddAnnotation(text, x, y)` (returns the object for tuning), clear with
  `ClearAnnotations`. Drawn on top of series, under the legend.
- **`uPlotMapper.pas`** — `TPlotMapper` record: pure data↔pixel coordinate transform
  (`MapX/MapY`/`UnmapX/UnmapY`), including log-scale handling. Holds `DataRect`/`PixelRect`/
  `LogX`/`LogY`. **`DataRect` is `TRectD` (double)** so deep zoom survives; **`PixelRect`
  stays `TRectF` (single)** because pixels — and the Skia canvas API — are single. Defines
  `TPointD`/`TRectD` (used across the data model). This is the single source of truth for
  axis inversion (data min → pixel bottom) and log mapping.
- **`uPlotDefaults.pas`** — global `PlotDefaults` record + `TPlotDefaultsLoader` that loads
  series styling defaults from a JSON file (schema documented in the unit header).
  `TPlotSeries.Create` reads `PlotDefaults` for its initial styling. Set
  `TSkPlotPaintBox.DefaultsFile` (or call `ReloadDefaults`) **before** adding series.
- **`uColorManager.pas`** — `TColorManager` static class; `TColorManager.NextColor` cycles
  a fixed palette so successive series get distinct colors. `ResetCycle` to restart.
- **`uCSVReaderForPlotter.pas`** — CSV parser used by `LoadData`. Supports an error-bar
  extension (`value [+e,-e]` in brackets) and `NA` missing-data markers.
- **`uMathParser.pas`** — small expression parser (for function-defined series).
- **`ufPlotEditor.pas` / `.fmx`** — `TFrmPlotEditor`, a tabbed dialog for editing chart /
  axis / series / legend properties at run time. Depends on `TLabelledTrackBar`.

### Key relationships / gotchas
- Styling sub-objects (`TAxisStyle`, `TGridStyle`, `TAxisLimits`) are `TPersistent` with an
  `OnChange` event; the control wires these to `*Changed` handlers that trigger a repaint.
  When adding a styling property, follow the existing setter → `Changed` → redraw pattern.
- `uPlotDefaults` uses `uPlotSeries` (for `TMarkerShape`/`TLineStyle` enums); to avoid a
  circular reference, `uPlotSeries` only references `uPlotDefaults` in its **implementation**
  `uses`. Preserve that split.
- The live CSV path is `uCSVReaderForPlotter` (used by `LoadData`).
- **Double precision:** the data model (`TPointD`, `DataRect`, `TAxisLimits`, and the
  `MinX/MaxX/…` accumulators in `CalculateDataBounds`) is `Double` end to end; only pixel
  space (`PixelRect`, draw-call coordinates) is `Single`. Keep it that way — a stray `Single`
  in the bounds/mapping path re-truncates and breaks deep zoom.
- **Autoscale skips NaN** (`CalculateDataBounds` ignores any point with a NaN coord) so the
  pen-lift separators never poison the range. `Draw` applies the same NaN rule.
- **Adding a source unit requires two edits:** list it in both
  `Package/PlotRuntimePackage.dpk` (`contains`) **and** `PlotRuntimePackage.dproj`
  (`<DCCReference>`). msbuild builds from the `.dproj` list; the IDE reads the `.dpk`.

### Typical usage (from the demo)
```pascal
Plot.LoadData('linear.csv', True, True, False).Free;   // line + markers, don't clear
ps := TPlotSeries.Create('Fitted', claBlue, False);    // no markers
ps.AddXY(x, y);
Plot.AddSeries(ps);
```
