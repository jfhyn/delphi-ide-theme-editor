//**************************************************************************************************
//
// Unit Colorizer.Utils
// unit Colorizer.Utils  for the Delphi IDE Colorizer
//
// The contents of this file are subject to the Mozilla Public License Version 1.1 (the "License");
// you may not use this file except in compliance with the License. You may obtain a copy of the
// License at http://www.mozilla.org/MPL/
//
// Software distributed under the License is distributed on an "AS IS" basis, WITHOUT WARRANTY OF
// ANY KIND, either express or implied. See the License for the specific language governing rights
// and limitations under the License.
//
// The Original Code is Colorizer.Utils.pas.
//
// The Initial Developer of the Original Code is Rodrigo Ruz V.
// Portions created by Rodrigo Ruz V. are Copyright (C) 2011-2014 Rodrigo Ruz V.
// All Rights Reserved.
//
//**************************************************************************************************

unit Colorizer.Utils;

interface

{$I ..\Common\Jedi.inc}

uses
 {$IFDEF DELPHIXE2_UP}
 VCL.Themes,
 VCL.Styles,
 {$ENDIF}
 ActnMan,
 ActnColorMaps,
 Windows,
 Graphics,
 Colorizer.Settings,
 ColorXPStyleActnCtrls,
 Classes;

procedure RefreshIDETheme(AColorMap:TCustomActionBarColorMap;AStyle: TActionBarStyle);
procedure LoadSettings(AColorMap:TCustomActionBarColorMap;Settings : TSettings);
procedure ProcessComponent(AColorMap:TCustomActionBarColorMap;AStyle: TActionBarStyle;AComponent: TComponent);
procedure GenerateColorMap(AColorMap:TCustomActionBarColorMap;Color:TColor);{$IF CompilerVersion >= 23}overload;{$IFEND}
{$IFDEF DELPHIXE2_UP}
procedure GenerateColorMap(AColorMap:TCustomActionBarColorMap;Style:TCustomStyleServices);overload;
{$ENDIF}

function  GetBplLocation : string;

 type
   TColorizerLocalSettings = class
   public
    class var ColorMap : TXPColorMap;
    class var HookedWindows : TStringList;
    class var Settings: TSettings;
    class var ImagesGutterChanged : Boolean;
    class var ColorXPStyle: TColorXPStyleActionBars
    end;

implementation

{.$DEFINE DEBUG_MODE}
{.$DEFINE DEBUG_PROFILER}

uses
 {$IFDEF DELPHIXE_UP}
 PlatformDefaultStyleActnCtrls,
 {$ELSE}
 XPStyleActnCtrls,
 {$ENDIF}
 {$IFDEF DELPHIXE2_UP}
 Vcl.Styles.Ext,
 {$ENDIF}
 {$IFDEF DELPHI2009_UP}
 PngImage,
 System.Generics.Collections,
 {$ENDIF}
 {$IFDEF DELPHI2010_UP}
 IOUtils,
 Rtti,
 {$ELSE}
 Variants,
 TypInfo,
 {$ENDIF}
 Types,
 Forms,
 Menus,
 Tabs,
 ComCtrls,
 Controls,
 StdCtrls,
 SysUtils,
 ExtCtrls,
 GraphUtil,
 UxTheme,
 CategoryButtons,
 ImgList,
 ActnCtrls,
 ActnPopup,
 ActnMenus,
 Colorizer.StoreColorMap,
 Dialogs,
 uRttiHelper;


{$IFDEF DEBUG_MODE}
var
  lcomp         : TStringList;
{$ENDIF}


{$IFDEF DEBUG_PROFILER}
var
  lprofiler     : TStringList;
  lpignored     : TStringList;
  lDumped       : TStringList;
{$ENDIF}

{$IFDEF DELPHI2010_UP}
var
  ctx           : TRttiContext;
{$ENDIF}

{$IFDEF DELPHI2009_UP}
var
  ActnStyleList : TDictionary<TActionManager, TActionBarStyle>;
{$ENDIF}


{$IFDEF DEBUG_PROFILER}
procedure DumpType(const QualifiedName:string);
var
  l2 : TStrings;
begin
  l2 := TStringList.Create;
  try
   l2.Text:=DumpTypeDefinition(TRttiContext.Create.FindType(QualifiedName).Handle);
  finally
   l2.SaveToFile(ExtractFilePath(GetBplLocation())+'Galileo\'+QualifiedName+'.pas');
   l2.Free;
  end;
end;

procedure DumpAllTypes;
var
l2 : TStrings;
t  : TRttiType;
begin
  l2 := TStringList.Create;
  try
    for t in TRttiContext.Create.GetTypes do
    if t.IsInstance then
     l2.Add(t.AsInstance.DeclaringUnitName +' '+t.Name);
  finally
   l2.SaveToFile(ExtractFilePath(GetBplLocation())+'Galileo\Types.txt');
   l2.Free;
  end;
end;


procedure DumpComponent(AComponent: TComponent);
var
l2 : TStrings;
begin
  l2 := TStringList.Create;
  try
   l2.Text:=DumpTypeDefinition(AComponent.ClassInfo);
  finally
   l2.SaveToFile(ExtractFilePath(GetBplLocation())+'Galileo\'+AComponent.ClassName+'.pas');
   l2.Free;
  end;
end;
{$ENDIF}


function  GetBplLocation : string;
begin
  SetLength(Result, MAX_PATH);
  GetModuleFileName(HInstance, PChar(Result), MAX_PATH);
  Result:=PChar(Result);
end;

procedure RefreshIDETheme(AColorMap:TCustomActionBarColorMap;AStyle: TActionBarStyle);
var
  index     : Integer;
begin
 {
  if GlobalSettings.EnableDWMColorization and DwmIsEnabled then
   SetCompositionColor(AColorMap.Color);
 }
  for Index := 0 to Screen.FormCount-1 do
  if TColorizerLocalSettings.HookedWindows.IndexOf(Screen.Forms[Index].ClassName)<>-1 then
  begin
   if not (csDesigning in Screen.Forms[Index].ComponentState) then
     ProcessComponent(AColorMap, AStyle, Screen.Forms[Index]);
  end
  {$IFDEF DELPHIXE2_UP}
  else
  if (TColorizerLocalSettings.Settings<>nil) and (TColorizerLocalSettings.Settings.UseVCLStyles) and (csDesigning in Screen.Forms[index].ComponentState) then
    ApplyEmptyVCLStyleHook(Screen.Forms[index].ClassType);
  {$ENDIF}
end;


procedure LoadSettings(AColorMap:TCustomActionBarColorMap;Settings : TSettings);
Var
 ThemeFileName : string;
begin
  if Settings=nil then exit;
  ReadSettings(Settings, ExtractFilePath(GetBplLocation()));
  ThemeFileName:=IncludeTrailingPathDelimiter(ExtractFilePath(GetBplLocation()))+'Themes\'+Settings.ThemeName+'.idetheme';
  if FileExists(ThemeFileName) then
   LoadColorMapFromXmlFile(TXPColorMap(AColorMap), ThemeFileName);
end;


procedure GenerateColorMap(AColorMap:TCustomActionBarColorMap;Color:TColor);
begin
{
+    property ShadowColor default cl3DDkShadow;
+    property Color default clBtnFace;
    property DisabledColor default clGray;
    property DisabledFontColor default clGrayText;
    property DisabledFontShadow default clBtnHighlight;
    property FontColor default clWindowText;
+    property HighlightColor;
    property HotColor default clDefault;
    property HotFontColor default clDefault;
    property MenuColor default clWindow;
+    property FrameTopLeftInner default clWhite;
+    property FrameTopLeftOuter default cXPFrameOuter;
+    property FrameBottomRightInner default clWhite;
+    property FrameBottomRightOuter default cXPFrameOuter;
+    property BtnFrameColor default cXPBtnFrameColor;
+    property BtnSelectedColor default clWhite;
+    property BtnSelectedFont default clWindowText;
+    property SelectedColor default cXPSelectedColor;
+    property SelectedFontColor default clBlack;
    property UnusedColor;
}
  AColorMap.Color                 :=Color;
  AColorMap.ShadowColor           :=GetShadowColor(Color);

  AColorMap.MenuColor             :=GetHighLightColor(Color);
  AColorMap.HighlightColor        :=GetHighLightColor(AColorMap.MenuColor);
  AColorMap.BtnSelectedColor      :=Color;
  AColorMap.BtnSelectedFont       :=AColorMap.FontColor;

  AColorMap.SelectedColor         :=GetHighLightColor(Color,50);
  AColorMap.SelectedFontColor     :=AColorMap.FontColor;

  AColorMap.BtnFrameColor         :=GetShadowColor(Color);
  AColorMap.FrameTopLeftInner     :=GetShadowColor(Color);
  AColorMap.FrameTopLeftOuter     :=AColorMap.FrameTopLeftInner;
  AColorMap.FrameBottomRightInner :=AColorMap.FrameTopLeftInner;
  AColorMap.FrameBottomRightOuter :=AColorMap.FrameTopLeftInner;
end;

{$IFDEF DELPHIXE2_UP}
procedure GenerateColorMap(AColorMap:TCustomActionBarColorMap;Style:TCustomStyleServices);
begin
  AColorMap.Color                 :=Style.GetStyleColor(scPanel);
  AColorMap.ShadowColor           :=GetShadowColor(AColorMap.Color);
  AColorMap.FontColor             :=Style.GetStyleFontColor(sfButtonTextNormal);

  AColorMap.MenuColor             :=AColorMap.Color;
  AColorMap.HighlightColor        :=GetHighLightColor(AColorMap.MenuColor);
  AColorMap.BtnSelectedColor      :=AColorMap.Color;
  AColorMap.BtnSelectedFont       :=AColorMap.FontColor;

  AColorMap.SelectedColor         :=GetHighLightColor(AColorMap.Color,50);
  AColorMap.SelectedFontColor     :=AColorMap.FontColor;

  AColorMap.BtnFrameColor         :=GetShadowColor(AColorMap.Color);
  AColorMap.FrameTopLeftInner     :=GetShadowColor(AColorMap.Color);
  AColorMap.FrameTopLeftOuter     :=AColorMap.FrameTopLeftInner;
  AColorMap.FrameBottomRightInner :=AColorMap.FrameTopLeftInner;
  AColorMap.FrameBottomRightOuter :=AColorMap.FrameTopLeftInner;
end;
{$ENDIF}

//check these windows when an app is debuged
function ProcessDebuggerWindows(AColorMap:TCustomActionBarColorMap;AComponent: TComponent) : Boolean;
const
  NumWin  = 4;
  CompList : array  [0..NumWin-1] of string = ('TDisassemblerView','TRegisterView','TFlagsView','TDumpView');
var
  Index : Integer;
begin
   Result:=False;
  for Index := 0 to NumWin-1 do
    if CompareText(AComponent.ClassName,CompList[Index])=0 then
    begin
      SetRttiPropertyValue(AComponent,'Color',AColorMap.MenuColor);
      Result:=True;
      Break;
    end
end;

function ProcessVclControls(AColorMap:TCustomActionBarColorMap;AComponent: TComponent) : Boolean;
const
  NumWin  = 7;
  CompList : array  [0..NumWin-1] of string = ('TMemo','TListView','TTreeView','TListBox','TCheckListBox','TExplorerCheckListBox','THintListView');
var
  Index : Integer;
begin
   Result:=False;
  for Index := 0 to NumWin-1 do
    if CompareText(AComponent.ClassName,CompList[Index])=0 then
    begin
      SetRttiPropertyValue(AComponent,'Color',AColorMap.HighlightColor);
      SetRttiPropertyValue(AComponent,'Ctl3D',False);
      SetRttiPropertyValue(AComponent,'Font.Color',AColorMap.FontColor);
      Result:=True;
      Break;
    end
end;

//todo color themed tcheckbox , tradiobutton
function ProcessStdVclControls(AColorMap:TCustomActionBarColorMap;AComponent: TComponent) : Boolean;
const
  NumWin  = 2;
  CompList : array  [0..NumWin-1] of string = ('TLabel','TCheckBox');
var
  Index : Integer;
begin
   Result:=False;
  for Index := 0 to NumWin-1 do
    if CompareText(AComponent.ClassName,CompList[Index])=0 then
    begin
      SetRttiPropertyValue(AComponent,'Font.Color',AColorMap.FontColor);
      Result:=True;
      Break;
    end
end;

function ProcessVclGroupControls(AColorMap:TCustomActionBarColorMap;AComponent: TComponent) : Boolean;
const
  NumWin  = 3;
  CompList : array  [0..NumWin-1] of string = ('TGroupBox','TRadioGroup','TPropRadioGroup');
var
  Index : Integer;
begin
   Result:=False;
  for Index := 0 to NumWin-1 do
    if CompareText(AComponent.ClassName,CompList[Index])=0 then
    begin
      SetRttiPropertyValue(AComponent,'Color',AColorMap.HighlightColor);
      SetRttiPropertyValue(AComponent,'Ctl3D',False);
      SetRttiPropertyValue(AComponent,'ParentBackGround',True);
      SetRttiPropertyValue(AComponent,'Font.Color',AColorMap.FontColor);
      Result:=True;
      Break;
    end
end;



Procedure GenIntransparentBitmap(bmp, Intrans: TBitmap);
begin
  Intrans.Assign(bmp);
  Intrans.PixelFormat := pf24bit;
end;



procedure ImageListReplace(LImages : TImageList;Index: Integer;const ResourceName: String);
{$IFDEF DELPHI2009_UP}
var
 LPngImage: TPngImage;
 LBitMap: TBitmap;
{$ENDIF}
begin
{$IFDEF DELPHI2009_UP}
  LPngImage:=TPNGImage.Create;
  try
    LPngImage.LoadFromResourceName(HInstance, ResourceName);
    LBitMap:=TBitmap.Create;
    try
      LPngImage.AssignTo(LBitMap);
      LBitMap.AlphaFormat:=afDefined;
      LImages.Replace(Index, LBitMap, nil);
    finally
      LBitMap.Free;
    end;
  finally
    LPngImage.free;
  end;
{$ENDIF}
end;

procedure ImageListAdd(LImages : TImageList;Index: Integer;const ResourceName: String);
{$IFDEF DELPHI2009_UP}
var
 LPngImage: TPngImage;
 LBitMap: TBitmap;
{$ENDIF}
begin
{$IFDEF DELPHI2009_UP}
  LPngImage:=TPNGImage.Create;
  try
    LPngImage.LoadFromResourceName(HInstance, ResourceName);
    LBitMap:=TBitmap.Create;
    try
      LPngImage.AssignTo(LBitMap);
      LBitMap.AlphaFormat:=afDefined;
      LImages.Add(LBitMap, nil);
    finally
      LBitMap.Free;
    end;
  finally
    LPngImage.free;
  end;
{$ENDIF}
end;

procedure ProcessComponent(AColorMap:TCustomActionBarColorMap;AStyle: TActionBarStyle;AComponent: TComponent);
var
  I              : Integer;
  LPanel         : TPanel;
  LColorMap      : TCustomActionBarColorMap;
  LActionManager : TActionManager;
  LCategoryButtons : TCategoryButtons;
  LImages        : TImageList;
  LForm          : TForm;
begin

 if not Assigned(AComponent) then  exit;
 if not Assigned(AColorMap) then  exit;


{$IFDEF DEBUG_PROFILER}
 lprofiler.Add(Format('%s Processing component %s:%s',[formatdatetime('hh:nn:ss.zzz',Now) ,AComponent.Name,AComponent.ClassName]));
  if lDumped.IndexOf(AComponent.ClassName)=-1 then
  begin
    lDumped.Add(AComponent.ClassName);
    DumpComponent(AComponent);
  end;
{$ENDIF}


{$IFDEF DEBUG_MODE}
 //lcomp.Add(Format('%s : %s',[AComponent.Name,AComponent.ClassName]));
{$ENDIF}


   //todo fix colors
    if AComponent is TCategoryButtons then //Name='TIDECategoryButtons' then
    begin
      LCategoryButtons:=TCategoryButtons(AComponent);
      LCategoryButtons.Color:=AColorMap.MenuColor;
      LCategoryButtons.BackgroundGradientColor:=AColorMap.MenuColor;
      LCategoryButtons.ButtonOptions:=LCategoryButtons.ButtonOptions+[boGradientFill];

      for i := 0 to LCategoryButtons.Categories.Count-1 do
         LCategoryButtons.Categories[i].Color:=AColorMap.Color;

      LCategoryButtons.Font.Color:=AColorMap.FontColor;
    end
    else
    if SameText(AComponent.ClassName, 'TTDStringGrid') then
    begin
      SetRttiPropertyValue(AComponent,'Color',AColorMap.MenuColor);
      SetRttiPropertyValue(AComponent,'Ctl3D',False);
      SetRttiPropertyValue(AComponent,'FixedColor',AColorMap.Color);
      SetRttiPropertyValue(AComponent,'Font.Color',AColorMap.FontColor);
      SetRttiPropertyValue(AComponent,'GradientStartColor',AColorMap.Color);
      SetRttiPropertyValue(AComponent,'GradientEndColor',AColorMap.Color);
    end
    else
    if SameText(AComponent.ClassName, 'THintListView') then
    begin

    end
    else
    if SameText(AComponent.ClassName, 'TPropertySheetControl') then
    begin

    end
    else
    if AComponent is TPopupActionBar then
    begin
      {
      if not Assigned(TPopupActionBar(AComponent).OnGetControlClass) then
      begin
        LObjectList.Add(THelperClass.Create);
        LObjectList[LObjectList.Count-1].PopupMenu:=TPopupActionBar(AComponent).PopupMenu;
        LObjectList[LObjectList.Count-1].ColorMap:=AColorMap;
        TPopupActionBar(AComponent).OnGetControlClass:=LObjectList[LObjectList.Count-1].PopupActionBar1GetControlClass;
        TPopupActionBar(AComponent).OnPopup          :=LObjectList[LObjectList.Count-1].PopupActionBar1Popup;
      end;
      }
          if (TColorizerLocalSettings.Settings.ChangeIconsGutter) and not (TColorizerLocalSettings.ImagesGutterChanged) and SameText('ModuleMenu', AComponent.Name) then
          begin
            LImages:=TImageList(TPopupActionBar(AComponent).Images);
            if (LImages<>nil) and (LImages.Count>=27) then
             begin
              //LImages:=TImageList.Create(nil);
              LImages.Clear;
              {$IF CompilerVersion > 20}
              LImages.ColorDepth:=TColorDepth.cd32Bit;
              {$IFEND}
              LImages.DrawingStyle:=dsNormal;
              LImages.Width:=15;
              LImages.Height:=15;

              for i:= 0 to 26 do
              ImageListAdd(LImages, i, Format('p%.2d',[i]));
                 //  ImageListReplace(LImages, i, Format('p%.2d',[i]));

               TPopupActionBar(AComponent).Images:=LImages;
               TColorizerLocalSettings.ImagesGutterChanged:=True;
             end;
          end;
    end
    else
    if SameText(AComponent.ClassName, 'TEdit') then
    begin
      SetRttiPropertyValue(AComponent,'Color',AColorMap.HighlightColor);
      SetRttiPropertyValue(AComponent,'Font.Color',AColorMap.FontColor);
    end
    else
    if SameText(AComponent.ClassName, 'TPropCheckBox') then
    begin
      SetRttiPropertyValue(AComponent,'Color',AColorMap.HighlightColor);
      SetRttiPropertyValue(AComponent,'Font.Color',AColorMap.FontColor);
    end
    else
    if SameText(AComponent.ClassName ,'TDesktopComboBox') then
    begin
      SetWindowTheme(TWinControl(AComponent).Handle,'','');
      SetRttiPropertyValue(AComponent,'Color',AColorMap.HighlightColor);
      SetRttiPropertyValue(AComponent,'Font.Color',AColorMap.FontColor);
      SetRttiPropertyValue(AComponent,'BevelKind', Integer(bkFlat));
      SetRttiPropertyValue(AComponent,'BevelInner', Integer(bvNone));
    end
    else
    if SameText(AComponent.ClassName, 'TComboBox') then
    begin
      SetRttiPropertyValue(AComponent,'Color',AColorMap.HighlightColor);
      SetRttiPropertyValue(AComponent,'Font.Color',AColorMap.FontColor);
    end
    else
    if AComponent  is TForm then   //check for descendent classes
    begin
      LForm:=TForm(AComponent);
      LForm.Color := AColorMap.Color;
      LForm.Font.Color:=AColorMap.FontColor;    {
       if SameText(AComponent.ClassName, 'TEditWindow') then
       begin
        LImages:=TImageList(GetRttiFieldValue(AComponent, 'SearchBarImages').AsObject);
        for i:=0 to LImages.Count-1 do
          begin
           LbitMap := TBitmap.create;
           try
             LBitMap.PixelFormat := pf32bit;
             LBitMap.AlphaFormat := afIgnored;
             LImages.GetBitmap(i, btBitmap);
             LBitMap.savetofile('C:\Delphi\google-code\DITE\delphi-ide-theme-editor\IDE PlugIn\Images IDE TEditWindow\'+inttostr(i)+'.bmp');
           finally
             LBitMap.Free;
           end;
          end;
       end;
               }
    end
    else
    if SameText(AComponent.ClassName, 'TPanel') then
    begin
      LPanel        :=TPanel(AComponent);
      LPanel.Color  := AColorMap.Color;
      LPanel.Invalidate;
    end
    else
    if SameText(AComponent.ClassName, 'TPageControl') then
    with TPageControl(AComponent) do
    begin
      {
      if OwnerDraw=False then
      begin
        SetWindowTheme(TPageControl(AComponent).Handle,'','');
        OwnerDraw:=True;
        TPageControl(AComponent).OnDrawTab:=Drawer.PageControlDrawTab;
      end;
      }
    end
    else
    if ProcessStdVclControls(AColorMap,AComponent) then
    else
    if ProcessVclControls(AColorMap,AComponent) then
    else
    if ProcessDebuggerWindows(AColorMap,AComponent) then
    else
    if ProcessVclGroupControls(AColorMap,AComponent) then
    else
    if SameText(AComponent.ClassName, 'TInspListBox') then
    begin
      {
       property BackgroundColor: TColor;
       property PropNameColor: TColor;
       property PropValueColor: TColor;
       property EditBackgroundColor: TColor;
       property EditValueColor: TColor;
       property CategoryColor: TColor;
       property GutterColor: TColor;
       property GutterEdgeColor: TColor;
       property ReferenceColor: TColor;
       property SubPropColor: TColor;
       property ReadOnlyColor: TColor;
       property NonDefaultColor: TColor;
       property HighlightColor: TColor;
       property HighlightFontColor: TColor;
      }
      SetRttiPropertyValue(AComponent,'EditBackgroundColor',AColorMap.MenuColor);
      SetRttiPropertyValue(AComponent,'HighlightColor',AColorMap.MenuColor);
      SetRttiPropertyValue(AComponent,'BackgroundColor',AColorMap.Color);
      SetRttiPropertyValue(AComponent,'GutterColor',AColorMap.Color);
      SetRttiPropertyValue(AComponent,'HighlightFontColor',AColorMap.FontColor);
      SetRttiPropertyValue(AComponent,'Font.Color',AColorMap.FontColor);
    end
    else
    if SameText(AComponent.ClassName, 'TRefactoringTree') then
    begin
      SetRttiPropertyValue(AComponent,'Color',AColorMap.MenuColor);
      SetRttiPropertyValue(AComponent,'Font.Color',AColorMap.FontColor);
    end
    else
    if SameText(AComponent.ClassName, 'TStringGrid') then
    begin
      SetRttiPropertyValue(AComponent,'Color',AColorMap.MenuColor);
      SetRttiPropertyValue(AComponent,'FixedColor',AColorMap.Color);
      SetRttiPropertyValue(AComponent,'Font.Color',AColorMap.FontColor);
    end
    else
    if SameText(AComponent.ClassName, 'TBetterHintWindowVirtualDrawTree') then
    begin
      SetRttiPropertyValue(AComponent,'Color',AColorMap.MenuColor);
      SetRttiPropertyValue(AComponent,'Font.Color',AColorMap.FontColor);

       {$IFDEF DELPHIXE2_UP}
        if TColorizerLocalSettings.Settings.UseVCLStyles then
        begin
        //  if not IsStyleHookRegistered(AComponent.ClassType, TTreeViewStyleHook) then
        //   TStyleEngine.RegisterStyleHook(AComponent.ClassType, TTreeViewStyleHook);
        end;
       {$ENDIF}
    end
    else
    if SameText(AComponent.ClassName, 'TVirtualStringTree') then
    begin
      SetRttiPropertyValue(AComponent,'Color',AColorMap.MenuColor);
      SetRttiPropertyValue(AComponent,'Font.Color',AColorMap.FontColor);
      //SetRttiPropertyValue(AComponent,'TreeLineColor',AColorMap.FontColor);
        //  TVTColors
        //	__fastcall TVTColors(TBaseVirtualTree* AOwner);
        //	virtual void __fastcall Assign(Classes::TPersistent* Source);
        //
        //__published:
        //	__property Graphics::TColor BorderColor = {read=GetColor, write=SetColor, index=7, default=-16777201};
        //	__property Graphics::TColor DisabledColor = {read=GetColor, write=SetColor, index=0, default=-16777200};
        //	__property Graphics::TColor DropMarkColor = {read=GetColor, write=SetColor, index=1, default=-16777203};
        //	__property Graphics::TColor DropTargetColor = {read=GetColor, write=SetColor, index=2, default=-16777203};
        //	__property Graphics::TColor DropTargetBorderColor = {read=GetColor, write=SetColor, index=11, default=-16777203};
        //	__property Graphics::TColor FocusedSelectionColor = {read=GetColor, write=SetColor, index=3, default=-16777203};
        //	__property Graphics::TColor FocusedSelectionBorderColor = {read=GetColor, write=SetColor, index=9, default=-16777203};
        //	__property Graphics::TColor GridLineColor = {read=GetColor, write=SetColor, index=4, default=-16777201};
        //	__property Graphics::TColor HeaderHotColor = {read=GetColor, write=SetColor, index=14, default=-16777200};
        //	__property Graphics::TColor HotColor = {read=GetColor, write=SetColor, index=8, default=-16777208};
        //	__property Graphics::TColor SelectionRectangleBlendColor = {read=GetColor, write=SetColor, index=12, default=-16777203};
        //	__property Graphics::TColor SelectionRectangleBorderColor = {read=GetColor, write=SetColor, index=13, default=-16777203};
        //	__property Graphics::TColor TreeLineColor = {read=GetColor, write=SetColor, index=5, default=-16777200};
        //	__property Graphics::TColor UnfocusedSelectionColor = {read=GetColor, write=SetColor, index=6, default=-16777201};
        //	__property Graphics::TColor UnfocusedSelectionBorderColor = {read=GetColor, write=SetColor, index=10, default=-16777201};
       {$IFDEF DELPHIXE2_UP}
        if TColorizerLocalSettings.Settings.UseVCLStyles then
        begin
          if not IsStyleHookRegistered(AComponent.ClassType, TTreeViewStyleHook) then
           TStyleEngine.RegisterStyleHook(AComponent.ClassType, TTreeViewStyleHook);
        end;
       {$ENDIF}
    end
    else
    if SameText(AComponent.ClassName, 'TCodeEditorTabControl') then
    begin
      SetRttiPropertyValue(AComponent,'UnselectedColor',AColorMap.MenuColor);
      SetRttiPropertyValue(AComponent,'SelectedColor',AColorMap.Color);
      SetRttiPropertyValue(AComponent,'BackgroundColor',AColorMap.MenuColor);
      SetRttiPropertyValue(AComponent,'Font.Color',AColorMap.FontColor);
    end
    else
    if SameText(AComponent.ClassName, 'TEditorDockPanel') then
    begin
      SetRttiPropertyValue(AComponent,'Color',AColorMap.Color);
      SetRttiPropertyValue(AComponent,'Font.Color',AColorMap.FontColor);
    end
    else
    if SameText(AComponent.ClassName, 'TGradientButton') then
    begin
      //Glyph:= TBitmap(GetRttiPropertyValue(AComponent,'Glyph').AsObject);
      //Glyph.SaveToFile('C:\Users\Dexter\Desktop\CMMS\Test.bmp');

       SetRttiPropertyValue(AComponent, 'Color', AColorMap.Color);
    end
    else
    if SameText(AComponent.ClassName, 'TScrollerButton') then
    begin

    end
    else
    if SameText(AComponent.ClassName, 'TClosableTabScroller') then
    begin

       SetRttiPropertyValue(AComponent,'CloseButton.BackgroundColor',AColorMap.MenuColor);
       SetRttiPropertyValue(AComponent,'CloseButton.Transparent',False);
       //SetRttiPropertyValue(AComponent,'CloseButton.Flat',True);

       SetRttiPropertyValue(AComponent,'DropDownButton.BackgroundColor',AColorMap.MenuColor);
       SetRttiPropertyValue(AComponent,'DropDownButton.Transparent',False);
       //SetRttiPropertyValue(AComponent,'DropDownButton.Flat',True);

       SetRttiPropertyValue(AComponent,'Brush.Color',AColorMap.Color);
    end
    else
    if SameText(AComponent.ClassName, 'TTabScroller') then
    begin

    end
    else
    if SameText(AComponent.ClassName, 'TEditControl') then   //TODO
    begin
       {$IFDEF DELPHIXE2_UP}
        if TColorizerLocalSettings.Settings.UseVCLStyles then
        begin
          if not IsStyleHookRegistered(AComponent.ClassType, TMemoStyleHook) then
           TStyleEngine.RegisterStyleHook(AComponent.ClassType, TMemoStyleHook);
        end;
       {$ENDIF}
       // Set these properties and Fields has not effect in the gutter color.
       //SetRttiFieldValue(AComponent,'GutterBrush.Color',  clYellow);
       //SetRttiPropertyValue(AComponent,'Brush.Color',  clRed);
       //SetRttiFieldValue(AComponent,'FParentColor',  False);
       //SetRttiFieldValue(AComponent,'FColor',  clYellow);
       //SetRttiFieldValue(AComponent,'CurForeColor',  clYellow);
       //SetRttiFieldValue(AComponent,'CurBackColor',  clRed);
       //ExecMethodRtti(AComponent, 'Invalidate');
    end
    else
    if AComponent is TActionToolBar then
    with TActionToolBar(AComponent) do
    begin
      LColorMap:=TXPColorMap.Create(AComponent);
      LColorMap.Assign(AColorMap);
      LColorMap.OnColorChange:=nil;
      ColorMap:=LColorMap;
    end
    else
    if AComponent is TControlBar then
    with TControlBar(AComponent) do
    begin
      Color := AColorMap.Color;
      DrawingStyle := dsGradient;
      GradientStartColor :=  AColorMap.Color;
      GradientEndColor   :=  AColorMap.Color;
    end
    else
    if SameText(AComponent.ClassName, 'TDockToolBar') then
    begin
      //DumpComponent(AComponent);
      with TToolBar(AComponent) do
      begin
        Color              := AColorMap.Color;
        DrawingStyle       := TTBDrawingStyle(dsGradient);
        GradientStartColor := AColorMap.MenuColor;
        GradientEndColor   := AColorMap.Color;//$00D1B499;
        HotTrackColor      := AColorMap.SelectedColor;
        Font.Color         := AColorMap.FontColor;
        {
        for i:=0 to Images.Count-1 do
          begin
           btBitmap := tbitmap.create;
           try
             btBitmap.PixelFormat := pf32bit;
             btBitmap.AlphaFormat := afIgnored;
             Images.GetBitmap(i,btBitmap);
             btBitmap.savetofile('C:\Delphi\google-code\DITE\delphi-ide-theme-editor\IDE PlugIn\Images IDE\'+inttostr(i)+'.bmp');
           finally
             btBitmap.Free;
           end;
          end;
          }
      end;
    end
    else
    if AComponent is TActionMainMenuBar then
    with TActionMainMenuBar(AComponent) do
    begin
      LColorMap:=TXPColorMap.Create(AComponent);
      LColorMap.Assign(AColorMap);
      LColorMap.OnColorChange:=nil;
      ColorMap:=LColorMap;
      AnimationStyle  := asFade;
      AnimateDuration := 1200;
      Shadows         := True;
      Font.Color      := AColorMap.FontColor;
    end
    else
    if AComponent is TActionManager then
    begin
      LActionManager:=TActionManager(AComponent);
      {$IFDEF DELPHI2009_UP}
      if not ActnStyleList.ContainsKey(LActionManager) then
          ActnStyleList.Add(LActionManager, LActionManager.Style);
      {$ENDIF}
      LActionManager.Style := AStyle;//XPStyle;
    end
    else
    if SameText(AComponent.ClassName, 'TTabSet') then
    with TTabSet(AComponent) do
    begin
      BackgroundColor:=AColorMap.MenuColor;
      SelectedColor  :=AColorMap.Color;
      UnselectedColor:=AColorMap.MenuColor;
      Font.Color    := AColorMap.FontColor;
    end
    else
    if SameText(AComponent.ClassName, 'TIDEGradientTabSet') or SameText(AComponent.ClassName, 'TGradientTabSet') then
    begin
         //DumpType('GDIPlus.GradientDrawer.TGradientTabDrawer');

         SetRttiPropertyValue(AComponent,'TabColors.ActiveStart',AColorMap.Color);
         SetRttiPropertyValue(AComponent,'TabColors.ActiveEnd',AColorMap.Color);
         SetRttiPropertyValue(AComponent,'TabColors.InActiveStart',AColorMap.MenuColor);
         SetRttiPropertyValue(AComponent,'TabColors.InActiveEnd',AColorMap.MenuColor);
         SetRttiPropertyValue(AComponent,'Font.Color',AColorMap.FontColor);

         SetRttiPropertyValue(AComponent,'Brush.Color',AColorMap.Color);

         SetRttiPropertyValue(AComponent,'ParentBackground',False);
       {$IFDEF DELPHIXE2_UP}
        {
        if GlobalSettings.UseVCLStyles then
        begin
          if not IsStyleHookRegistered(AComponent.ClassType, TTabControlStyleHook) then
           TStyleEngine.RegisterStyleHook(AComponent.ClassType, TTabControlStyleHook);
        end;
        }
       {$ENDIF}
    end
    else
    if SameText(AComponent.ClassName, 'TTabSheet')  then
    with TTabSheet(AComponent) do
    begin
       //Color:=AColorMap.Color;
       Font.Color:=AColorMap.FontColor;
    end
    else
    if AComponent is TStatusBar then
    with TStatusBar(AComponent) do
    begin
       //theme is removed to allow paint TStatusBar
       SetWindowTheme(TStatusBar(AComponent).Handle,'','');
       //SizeGrip is removed because can't be painted
       SizeGrip:=False;
       Color := AColorMap.Color;
       //remove the bevels
       for i := 0 to TStatusBar(AComponent).Panels.Count-1 do
        TStatusBar(AComponent).Panels[i].Bevel:=pbNone;

       Font.Color:=AColorMap.FontColor;
    end
    else
    if AComponent is TFrame then
    with TFrame(AComponent) do
    begin
      Color := AColorMap.Color;
      Font.Color:=AColorMap.FontColor;
    end
    else
    begin
      {$IFDEF DEBUG_PROFILER}
        lpignored.Add(Format('%s component %s:%s',[formatdatetime('hh:nn:ss.zzz',Now) ,AComponent.Name,AComponent.ClassName]));
      {$ENDIF}
    end;

    {$IFDEF DEBUG_PROFILER}
      lprofiler.Add(Format('%s End process component %s:%s',[formatdatetime('hh:nn:ss.zzz',Now) ,AComponent.Name,AComponent.ClassName]));
    {$ENDIF}

    for I := 0 to AComponent.ComponentCount - 1 do
    begin
     {$IFDEF DEBUG_MODE}
     //lcomp.Add(Format('     %s : %s',[AComponent.Components[I].Name,AComponent.Components[I].ClassName]));
     {$ENDIF}
     ProcessComponent(AColorMap, ColorXPStyle, AComponent.Components[I]);
    end;
end;


procedure RestoreActnManagerStyles;
var
  LActionManager : TActionManager;
begin
{$IFDEF DELPHI2009_UP}
  if ActnStyleList.Count>0 then
    for LActionManager in ActnStyleList.Keys do   //if Assigned(ActionBarStyles) then
       LActionManager.Style:= ActnStyleList.Items[LActionManager];//ActionBarStyles.Style[ActionBarStyles.IndexOf(DefaultActnBarStyle)];
{$ELSE}
   //TODO

{$ENDIF}
end;

var
 NativeColorMap : TCustomActionBarColorMap;

initialization
  //LObjectList:=TObjectList<THelperClass>.Create;
{$IFDEF DELPHI2009_UP}
  ActnStyleList := TDictionary<TActionManager, TActionBarStyle>.Create;
{$ENDIF}
{$IFDEF DEBUG_PROFILER}
  DumpAllTypes;
{$ENDIF}
  TColorizerLocalSettings.ColorMap      :=nil;
  TColorizerLocalSettings.Settings:=nil;
  TColorizerLocalSettings.ImagesGutterChanged:=False;
  TColorizerLocalSettings.HookedWindows:=TStringList.Create;
  TColorizerLocalSettings.HookedWindows.LoadFromFile(IncludeTrailingPathDelimiter(ExtractFilePath(GetBplLocation))+'HookedWindows.dat');
{$IFDEF DELPHI2010_UP}
  ctx:=TRttiContext.Create;
{$ENDIF}

{$IFDEF DEBUG_PROFILER}
  ShowMessage('warning DEBUG_PROFILER mode Activated');
  lprofiler:=TStringList.Create;
  lpignored:=TStringList.Create;
  lDumped  :=TStringList.Create;
{$ENDIF}

finalization
{$IFDEF DELPHIXE2_UP}
  if TColorizerLocalSettings.Settings.UseVCLStyles then
    if not TStyleManager.ActiveStyle.IsSystemStyle  then
     TStyleManager.SetStyle('Windows');
{$ENDIF}

{$IFDEF DELPHIXE_UP}
  NativeColorMap:=TThemedColorMap.Create(nil);
{$ELSE}
  NativeColorMap:=TStandardColorMap.Create(nil);
{$ENDIF}

  try
  {$IFDEF DELPHIXE_UP}
    RefreshIDETheme(NativeColorMap, PlatformDefaultStyle);
  {$ELSE}
    RefreshIDETheme(NativeColorMap, XPStyle);
  {$ENDIF}
  finally
    NativeColorMap.Free;
  end;

  RestoreActnManagerStyles();
  FreeAndNil(TColorizerLocalSettings.Settings);
{$IFDEF DELPHI2009_UP} //2009
  ActnStyleList.Free;
{$ENDIF}
  TColorizerLocalSettings.HookedWindows.Free;
  TColorizerLocalSettings.HookedWindows:=nil;
{$IFDEF DELPHI2010_UP}
  ctx.Free;
{$ENDIF}

{$IFDEF DEBUG_PROFILER}
  lprofiler.SaveToFile(ExtractFilePath(GetBplLocation())+'Profiler\profiler.txt');
  lprofiler.Free;
  lpignored.SaveToFile(ExtractFilePath(GetBplLocation())+'Profiler\ignored.txt');
  lpignored.Free;
  lDumped.Free;
{$ENDIF}
end.
