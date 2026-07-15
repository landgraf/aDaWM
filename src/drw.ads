with Dwm_Types;
with Xft_Thin;
with Xlib_Thin;

--  Port of drw.h/drw.c: the drawable/fontset/colorscheme/cursor
--  abstraction dwm's bar rendering is built on.
package Drw is

   type Cur is record
      Cursor : Xlib_Thin.Cursor;
   end record;
   type Cur_Access is access all Cur;

   type Fnt;
   type Fnt_Access is access all Fnt;
   type Fnt is record
      Disp    : Xlib_Thin.Display;
      H       : Natural := 0;
      Xfont   : Xft_Thin.XftFont_Access;
      Pattern : Xft_Thin.FcPattern;
      Next    : Fnt_Access;
   end record;

   type Context is record
      W, H     : Natural := 0;
      Disp     : Xlib_Thin.Display;
      Screen   : Xlib_Thin.C_Int := 0;
      Root     : Xlib_Thin.Window := Xlib_Thin.None;
      Drawable : Xlib_Thin.Drawable := Xlib_Thin.None;
      Gc       : Xlib_Thin.GC;
      Scheme   : Dwm_Types.Color_Scheme_Access;
      Fonts    : Fnt_Access;
   end record;
   type Context_Access is access all Context;

   --  Creates a drawing context backed by a W x H pixmap on Win's
   --  screen (drw_create()). Called once at startup with the root
   --  window and full screen size.
   function Create
     (Disp : Xlib_Thin.Display; Screen : Xlib_Thin.C_Int; Win : Xlib_Thin.Window;
      W, H : Natural) return Context_Access;

   --  Reallocates D's backing pixmap to W x H (drw_resize()), e.g.
   --  when the screen geometry changes.
   procedure Resize (D : Context_Access; W, H : Natural);

   --  Releases D's pixmap, GC and fontset, then frees D itself and
   --  sets it to null (drw_free()).
   procedure Free (D : in out Context_Access);

   --  Loads each font name in Fonts (first match wins per glyph,
   --  falling back through the list) and returns the resulting linked
   --  fontset, also storing it as D.Fonts (drw_fontset_create()).
   --  Returns null if none of the fonts could be loaded.
   function Fontset_Create (D : Context_Access; Fonts : Dwm_Types.Command) return Fnt_Access;

   --  Recursively closes and frees every font in Font's chain
   --  (drw_fontset_free()).
   procedure Fontset_Free (Font : in out Fnt_Access);

   --  Pixel width Txt would render at using D's current fontset
   --  (drw_fontset_getwidth(): Text() in measure-only mode).
   function Fontset_Get_Width (D : Context_Access; Txt : String) return Natural;

   --  Like Fontset_Get_Width, but never returns more than N
   --  (drw_fontset_getwidth_clamp()).
   function Fontset_Get_Width_Clamp (D : Context_Access; Txt : String; N : Natural) return Natural;

   --  Pixel width/height of the first Len bytes of Txt when rendered
   --  in Font alone, via XftTextExtentsUtf8 (drw_font_getexts()).
   procedure Font_Get_Exts
     (Font : Fnt_Access; Txt : String; Len : Natural; W : out Natural; H : out Natural);

   --  Allocates the X color named Clrname (e.g. "#222222") into Dest
   --  (drw_clr_create()); dies via Util.Die if allocation fails.
   procedure Clr_Create (D : Context_Access; Dest : access Xft_Thin.XftColor; Clrname : String);

   --  Releases a color allocated by Clr_Create (drw_clr_free()).
   procedure Clr_Free (D : Context_Access; C : access Xft_Thin.XftColor);

   --  Allocates the three colors in Clrnames (fg, bg, border) into a
   --  new Color_Scheme (drw_scm_create()).
   function Scm_Create
     (D : Context_Access; Clrnames : Dwm_Types.Color_Name_Triple) return Dwm_Types.Color_Scheme_Access;

   --  Releases every color in Scm, then frees Scm itself and sets it
   --  to null (drw_scm_free()).
   procedure Scm_Free (D : Context_Access; Scm : in out Dwm_Types.Color_Scheme_Access);

   --  Points D at a different loaded fontset without recreating it
   --  (drw_setfontset()).
   procedure Set_Fontset (D : Context_Access; Set : Fnt_Access);

   --  Selects the color scheme subsequent Rect/Text calls draw with
   --  (drw_setscheme()).
   procedure Set_Scheme (D : Context_Access; Scm : Dwm_Types.Color_Scheme_Access);

   --  Draws a W x H rectangle at (X, Y) into D's pixmap: filled or
   --  outlined per Filled, in the foreground or background color of
   --  D's current scheme per Invert (drw_rect()).
   procedure Rect
     (D : Context_Access; X, Y : Integer; W, H : Natural; Filled, Invert : Integer);

   --  Renders Txt (UTF-8, with font-fallback matching and "..."
   --  truncation) left-padded by Lpad into the W x H box at (X, Y),
   --  swapping foreground/background per Invert; returns the pixel
   --  position just past the drawn text (drw_text()). If X, Y, W and H
   --  are all zero, nothing is drawn and Invert instead acts as an
   --  optional width clamp -- this is how Fontset_Get_Width(_Clamp)
   --  measure text without rendering it.
   function Text
     (D : Context_Access; X, Y : Integer; W, H : Natural; Lpad : Natural;
      Txt : String; Invert : Integer) return Integer;

   --  Copies the W x H region at (X, Y) from D's pixmap onto Win, e.g.
   --  to blit a freshly drawn bar onto its window (drw_map()).
   procedure Map
     (D : Context_Access; Win : Xlib_Thin.Window; X, Y : Integer; W, H : Natural);

   --  Creates an X cursor of the given font-cursor Shape (an XC_*
   --  constant), e.g. Xlib_Thin.XC_left_ptr (drw_cur_create()).
   function Cur_Create (D : Context_Access; Shape : Xlib_Thin.C_UInt) return Cur_Access;

   --  Releases a cursor created by Cur_Create and sets it to null
   --  (drw_cur_free()).
   procedure Cur_Free (D : Context_Access; C : in out Cur_Access);

end Drw;
