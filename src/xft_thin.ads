with System;
with Interfaces.C;
with Interfaces.C.Strings;
with Xlib_Thin;

--  Thin hand-written Ada binding to the Xft/fontconfig surface drw.c uses
--  (font loading with fallback matching, color allocation, UTF-8 text
--  drawing/measuring). FcPattern/FcCharSet/FcConfig/XftDraw are opaque to
--  dwm and are only ever passed around, so they stay as System.Address.
package Xft_Thin is

   subtype C_Int    is Interfaces.C.int;
   subtype C_UInt   is Interfaces.C.unsigned;
   subtype C_UChar  is Interfaces.C.unsigned_char;
   subtype C_UShort is Interfaces.C.unsigned_short;
   subtype C_UInt32 is Interfaces.C.unsigned;

   subtype FcPattern is System.Address;
   subtype FcCharSet is System.Address;
   subtype FcConfig  is System.Address;
   subtype XftDraw   is System.Address;

   subtype FcChar8  is C_UChar;
   subtype FcChar32 is C_UInt32;
   subtype FcBool   is C_Int;
   subtype FcResult is C_Int;

   FcTrue : constant FcBool := 1;

   --  fontconfig object-name string constants (FC_CHARSET / FC_SCALABLE),
   --  allocated once for the process lifetime.
   FC_CHARSET  : constant Interfaces.C.Strings.chars_ptr :=
     Interfaces.C.Strings.New_String ("charset");
   FC_SCALABLE : constant Interfaces.C.Strings.chars_ptr :=
     Interfaces.C.Strings.New_String ("scalable");

   type XftFont is record
      Ascent            : C_Int := 0;
      Descent           : C_Int := 0;
      Height            : C_Int := 0;
      Max_Advance_Width : C_Int := 0;
      Charset           : FcCharSet := System.Null_Address;
      Pattern           : FcPattern := System.Null_Address;
   end record
     with Convention => C;
   type XftFont_Access is access all XftFont;

   type XRenderColor is record
      Red, Green, Blue, Alpha : C_UShort := 0;
   end record
     with Convention => C;

   type XftColor is record
      Pixel : Xlib_Thin.C_ULong := 0;
      Color : XRenderColor;
   end record
     with Convention => C;
   type XftColor_Access is access all XftColor;

   type XGlyphInfo is record
      Width, Height : C_UShort := 0;
      X, Y          : Interfaces.C.short := 0;
      X_Off, Y_Off  : Interfaces.C.short := 0;
   end record
     with Convention => C;

   --------------------------------------------------------------------
   --  Xft functions                                                  --
   --------------------------------------------------------------------

   function XftColorAllocName
     (Disp   : Xlib_Thin.Display;
      Vis    : Xlib_Thin.Visual;
      Cmap   : Xlib_Thin.Colormap;
      Name   : Interfaces.C.Strings.chars_ptr;
      Result : access XftColor) return C_Int;
   pragma Import (C, XftColorAllocName, "XftColorAllocName");

   procedure XftColorFree
     (Disp : Xlib_Thin.Display;
      Vis  : Xlib_Thin.Visual;
      Cmap : Xlib_Thin.Colormap;
      Color : access XftColor);
   pragma Import (C, XftColorFree, "XftColorFree");

   function XftDrawCreate
     (Disp     : Xlib_Thin.Display;
      Drawable : Xlib_Thin.Drawable;
      Vis      : Xlib_Thin.Visual;
      Cmap     : Xlib_Thin.Colormap) return XftDraw;
   pragma Import (C, XftDrawCreate, "XftDrawCreate");

   procedure XftDrawDestroy (Draw : XftDraw);
   pragma Import (C, XftDrawDestroy, "XftDrawDestroy");

   procedure XftDrawStringUtf8
     (Draw   : XftDraw;
      Color  : access constant XftColor;
      Font   : XftFont_Access;
      X, Y   : C_Int;
      Str    : System.Address;
      Length : C_Int);
   pragma Import (C, XftDrawStringUtf8, "XftDrawStringUtf8");

   procedure XftTextExtentsUtf8
     (Disp    : Xlib_Thin.Display;
      Font    : XftFont_Access;
      Str     : System.Address;
      Length  : C_Int;
      Extents : access XGlyphInfo);
   pragma Import (C, XftTextExtentsUtf8, "XftTextExtentsUtf8");

   function XftCharExists
     (Disp : Xlib_Thin.Display; Font : XftFont_Access; Ucs4 : FcChar32) return FcBool;
   pragma Import (C, XftCharExists, "XftCharExists");

   function XftFontMatch
     (Disp    : Xlib_Thin.Display;
      Screen  : C_Int;
      Pattern : FcPattern;
      Result  : access FcResult) return FcPattern;
   pragma Import (C, XftFontMatch, "XftFontMatch");

   function XftFontOpenName
     (Disp : Xlib_Thin.Display; Screen : C_Int; Name : Interfaces.C.Strings.chars_ptr)
      return XftFont_Access;
   pragma Import (C, XftFontOpenName, "XftFontOpenName");

   function XftFontOpenPattern
     (Disp : Xlib_Thin.Display; Pattern : FcPattern) return XftFont_Access;
   pragma Import (C, XftFontOpenPattern, "XftFontOpenPattern");

   procedure XftFontClose (Disp : Xlib_Thin.Display; Font : XftFont_Access);
   pragma Import (C, XftFontClose, "XftFontClose");

   --------------------------------------------------------------------
   --  fontconfig functions                                           --
   --------------------------------------------------------------------

   function FcNameParse (Name : Interfaces.C.Strings.chars_ptr) return FcPattern;
   pragma Import (C, FcNameParse, "FcNameParse");

   procedure FcPatternDestroy (P : FcPattern);
   pragma Import (C, FcPatternDestroy, "FcPatternDestroy");

   function FcPatternDuplicate (P : FcPattern) return FcPattern;
   pragma Import (C, FcPatternDuplicate, "FcPatternDuplicate");

   function FcPatternAddCharSet
     (P : FcPattern; Object : Interfaces.C.Strings.chars_ptr; C : FcCharSet) return FcBool;
   pragma Import (C, FcPatternAddCharSet, "FcPatternAddCharSet");

   function FcPatternAddBool
     (P : FcPattern; Object : Interfaces.C.Strings.chars_ptr; B : FcBool) return FcBool;
   pragma Import (C, FcPatternAddBool, "FcPatternAddBool");

   function FcConfigSubstitute (Config : FcConfig; P : FcPattern; Kind : C_Int) return FcBool;
   pragma Import (C, FcConfigSubstitute, "FcConfigSubstitute");
   FcMatchPattern : constant C_Int := 0;

   procedure FcDefaultSubstitute (Pattern : FcPattern);
   pragma Import (C, FcDefaultSubstitute, "FcDefaultSubstitute");

   function FcCharSetCreate return FcCharSet;
   pragma Import (C, FcCharSetCreate, "FcCharSetCreate");

   function FcCharSetAddChar (Fcs : FcCharSet; Ucs4 : FcChar32) return FcBool;
   pragma Import (C, FcCharSetAddChar, "FcCharSetAddChar");

   procedure FcCharSetDestroy (Fcs : FcCharSet);
   pragma Import (C, FcCharSetDestroy, "FcCharSetDestroy");

end Xft_Thin;
