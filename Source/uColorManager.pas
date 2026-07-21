unit uColorManager;

interface

Uses System.UITypes, System.UIConsts, Rtti;

type
  TColorManager = class
  private
    class var FColorIndex: Integer;
    class var FPalette: array of TAlphaColor;
    class function GetNextColor: TAlphaColor; static;
    class procedure InitializePalette; // Sets up the colors once
  public
    class procedure ResetCycle;
    class procedure SetPalette (Index: Integer);
    //class function GenerateRandomAlphaColor(const Mix: TAlphaColor = claWhite): TAlphaColor;
    // A class property does not require an object instance
    class property NextColor: TAlphaColor read GetNextColor;
  end;

implementation


class procedure TColorManager.ResetCycle;
begin
  FColorIndex := 0;
end;

class procedure TColorManager.SetPalette (Index: Integer);
begin

end;

//class function TColorManager.GenerateRandomAlphaColor(const Mix: TAlphaColor = claWhite): TAlphaColor;
//var
//  LColorRec, LMixRec: TAlphaColorRec;
//begin
//  // Extract channels from the Mix color
//  LMixRec := TAlphaColorRec(Mix);
//
//  // Generate random RGB and blend with the Mix color
//  LColorRec.A := 255; // Fully opaque
//  LColorRec.R := (Random(256) + LMixRec.R) div 2;
//  LColorRec.G := (Random(256) + LMixRec.G) div 2; // Fixed: Assigned to LColorRec.G
//  LColorRec.B := (Random(256) + LMixRec.B) div 2;
//
//  Result := LColorRec.Color;
//end;

class procedure TColorManager.InitializePalette;
begin
  if Length(FPalette) = 0 then
  begin
    FColorIndex := 0;
    FPalette := [
      $FFE6194B, // 1. Red
      $FF3CB44B, // 2. Green
      $FF4363D8, // 4. Blue
      $FFF58231, // 5. Orange
      $FF911EB4, // 6. Purple
      $FFF032E6, // 8. Magenta
      $FF800000, // 15. Maroon
      //$FFB8860B, // 3. Gold/Mustard
      $FFBFEF45, // 9. Lime
      $FF42D4F4, // 7. Cyan
      $FF469990, // 11. Teal
      $FF9A6324, // 13. Brown
      $FFAAFFC3, // 16. Mint
      $FF808000, // 17. Olive
      $FFFFD8B1, // 18. Apricot
      $FF000075, // 19. Navy
      $FFDCBEFF, // 12. Lavender
      $FFA9A9A9,  // 20. Grey
      $FFFABED4, // 10. Pink
      $FFFFFAC8 // 14. Beige
    ];
//    FPalette := [
//     $FFE6194B, // 1. Red
//     $FF3CB44B, // 2. Green
//     $FF4363F4, // 4. Blue
//
//      $FF911EB4, // 6. Purple
//      $FFF032E6, // 8. Magenta
//
//    $FF0072B2, // 1. Deep Blue
//    $FFD55E00, // 2. Vermillion/Orange
//    $FF19adb5,// $FF009E73, // 3. Bluish Green
//    $FFCC79A7, // 4. Reddish Purple
//    $FFE69F00, // 5. Light Amber
//    $FF56B4E9, // 6. Sky Blue
//    $FF112244, // 7. Dark Navy (Replaced Charcoal - deep, highly visible anchor)
//    $FFB57C00, // 8. Dark Gold/Ochre (Replaced Yellow - excellent contrast on white)
//    $FF999999, // 9. Medium Gray
//    $FF882255  // 10. Wine Red
//    ];
  end;
end;


class function TColorManager.GetNextColor: TAlphaColor;
begin
  InitializePalette; // Ensure colors exist

  Result := FPalette[FColorIndex];
  FColorIndex := (FColorIndex + 1) mod Length(FPalette);
end;

end.



