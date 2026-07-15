with System;
with Interfaces.C;
with Interfaces.C.Strings;
with Xlib_Thin;

--  Thin hand-written Ada binding to the Xft/fontconfig surface drw.c uses
--  (font loading with fallback matching, color allocation, UTF-8 text
--  drawing/measuring). FcPattern/FcCharSet/FcConfig/XftDraw are opaque to
--  dwm and are only ever passed around and null-checked, so each gets
--  its own access-to-null-record type (see Xlib_Thin.Display) instead
--  of a shared System.Address subtype.
package Xft_Thin is

   subtype C_Int    is Interfaces.C.int;
   subtype C_UInt   is Interfaces.C.unsigned;
   subtype C_UChar  is Interfaces.C.unsigned_char;
   subtype C_UShort is Interfaces.C.unsigned_short;
   subtype C_UInt32 is Interfaces.C.unsigned;

   type FcPattern_Object is limited null record;
   type FcPattern is access all FcPattern_Object;

   type FcCharSet_Object is limited null record;
   type FcCharSet is access all FcCharSet_Object;

   type FcConfig_Object is limited null record;
   type FcConfig is access all FcConfig_Object;

   type XftDraw_Object is limited null record;
   type XftDraw is access all XftDraw_Object;

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
      Charset           : FcCharSet := null;
      Pattern           : FcPattern := null;
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

   --  Binds XftColorAllocName(); see man 3 XftColorAllocName.
   function XftColorAllocName
     (Disp   : in Xlib_Thin.Display;
      Vis    : in Xlib_Thin.Visual;
      Cmap   : in Xlib_Thin.Colormap;
      Name   : in Interfaces.C.Strings.chars_ptr;
      Result : access XftColor) return C_Int;
   pragma Import (C, XftColorAllocName, "XftColorAllocName");

   --  Binds XftColorFree(); see man 3 XftColorFree.
   procedure XftColorFree
     (Disp : in Xlib_Thin.Display;
      Vis  : in Xlib_Thin.Visual;
      Cmap : in Xlib_Thin.Colormap;
      Color : access XftColor);
   pragma Import (C, XftColorFree, "XftColorFree");

   --  Binds XftDrawCreate(); see man 3 XftDrawCreate.
   function XftDrawCreate
     (Disp     : in Xlib_Thin.Display;
      Drawable : in Xlib_Thin.Drawable;
      Vis      : in Xlib_Thin.Visual;
      Cmap     : in Xlib_Thin.Colormap) return XftDraw;
   pragma Import (C, XftDrawCreate, "XftDrawCreate");

   --  Binds XftDrawDestroy(); see man 3 XftDrawDestroy.
   procedure XftDrawDestroy (Draw : in XftDraw);
   pragma Import (C, XftDrawDestroy, "XftDrawDestroy");

   --  Binds XftDrawStringUtf8(); see man 3 XftDrawStringUtf8.
   procedure XftDrawStringUtf8
     (Draw   : in XftDraw;
      Color  : access constant XftColor;
      Font   : in XftFont_Access;
      X, Y   : in C_Int;
      Str    : in System.Address;
      Length : in C_Int);
   pragma Import (C, XftDrawStringUtf8, "XftDrawStringUtf8");

   --  Binds XftTextExtentsUtf8(); see man 3 XftTextExtentsUtf8.
   procedure XftTextExtentsUtf8
     (Disp    : in Xlib_Thin.Display;
      Font    : in XftFont_Access;
      Str     : in System.Address;
      Length  : in C_Int;
      Extents : access XGlyphInfo);
   pragma Import (C, XftTextExtentsUtf8, "XftTextExtentsUtf8");

   --  Binds XftCharExists(); see man 3 XftCharExists.
   function XftCharExists
     (Disp : in Xlib_Thin.Display; Font : in XftFont_Access; Ucs4 : in FcChar32) return FcBool;
   pragma Import (C, XftCharExists, "XftCharExists");

   --  Binds XftFontMatch(); see man 3 XftFontMatch.
   function XftFontMatch
     (Disp    : in Xlib_Thin.Display;
      Screen  : in C_Int;
      Pattern : in FcPattern;
      Result  : access FcResult) return FcPattern;
   pragma Import (C, XftFontMatch, "XftFontMatch");

   --  Binds XftFontOpenName(); see man 3 XftFontOpenName.
   function XftFontOpenName
     (Disp : in Xlib_Thin.Display; Screen : in C_Int; Name : in Interfaces.C.Strings.chars_ptr)
      return XftFont_Access;
   pragma Import (C, XftFontOpenName, "XftFontOpenName");

   --  Binds XftFontOpenPattern(); see man 3 XftFontOpenPattern.
   function XftFontOpenPattern
     (Disp : in Xlib_Thin.Display; Pattern : in FcPattern) return XftFont_Access;
   pragma Import (C, XftFontOpenPattern, "XftFontOpenPattern");

   --  Binds XftFontClose(); see man 3 XftFontClose.
   procedure XftFontClose (Disp : in Xlib_Thin.Display; Font : in XftFont_Access);
   pragma Import (C, XftFontClose, "XftFontClose");

   --------------------------------------------------------------------
   --  fontconfig functions                                           --
   --------------------------------------------------------------------

   --  Binds FcNameParse(); see man 3 FcNameParse.
   function FcNameParse (Name : in Interfaces.C.Strings.chars_ptr) return FcPattern;
   pragma Import (C, FcNameParse, "FcNameParse");

   --  Binds FcPatternDestroy(); see man 3 FcPatternDestroy.
   procedure FcPatternDestroy (P : in FcPattern);
   pragma Import (C, FcPatternDestroy, "FcPatternDestroy");

   --  Binds FcPatternDuplicate(); see man 3 FcPatternDuplicate.
   function FcPatternDuplicate (P : in FcPattern) return FcPattern;
   pragma Import (C, FcPatternDuplicate, "FcPatternDuplicate");

   --  Binds FcPatternAddCharSet(); see man 3 FcPatternAddCharSet.
   function FcPatternAddCharSet
     (P : in FcPattern; Object : in Interfaces.C.Strings.chars_ptr; C : in FcCharSet) return FcBool;
   pragma Import (C, FcPatternAddCharSet, "FcPatternAddCharSet");

   --  Binds FcPatternAddBool(); see man 3 FcPatternAddBool.
   function FcPatternAddBool
     (P : in FcPattern; Object : in Interfaces.C.Strings.chars_ptr; B : in FcBool) return FcBool;
   pragma Import (C, FcPatternAddBool, "FcPatternAddBool");

   --  Binds FcConfigSubstitute(); see man 3 FcConfigSubstitute.
   function FcConfigSubstitute (Config : in FcConfig; P : in FcPattern; Kind : in C_Int) return FcBool;
   pragma Import (C, FcConfigSubstitute, "FcConfigSubstitute");
   FcMatchPattern : constant C_Int := 0;

   --  Binds FcDefaultSubstitute(); see man 3 FcDefaultSubstitute.
   procedure FcDefaultSubstitute (Pattern : in FcPattern);
   pragma Import (C, FcDefaultSubstitute, "FcDefaultSubstitute");

   --  Binds FcCharSetCreate(); see man 3 FcCharSetCreate.
   function FcCharSetCreate return FcCharSet;
   pragma Import (C, FcCharSetCreate, "FcCharSetCreate");

   --  Binds FcCharSetAddChar(); see man 3 FcCharSetAddChar.
   function FcCharSetAddChar (Fcs : in FcCharSet; Ucs4 : in FcChar32) return FcBool;
   pragma Import (C, FcCharSetAddChar, "FcCharSetAddChar");

   --  Binds FcCharSetDestroy(); see man 3 FcCharSetDestroy.
   procedure FcCharSetDestroy (Fcs : in FcCharSet);
   pragma Import (C, FcCharSetDestroy, "FcCharSetDestroy");

end Xft_Thin;
