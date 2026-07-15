with Dwm_Types;
with Xft_Thin;
with Xlib_Thin;

--  Port of drw.h/drw.c: the drawable/fontset/colorscheme/cursor
--  abstraction dwm's bar rendering is built on.
package Drw is

   type Cursor is record
      X_Cursor : Xlib_Thin.Cursor;
   end record;
   type Cursor_Access is access all Cursor;

   type Font;
   type Font_Access is access all Font;
   type Font is record
      Disp    : Xlib_Thin.Display;
      Height  : Natural := 0;
      Xfont   : Xft_Thin.XftFont_Access;
      Pattern : Xft_Thin.FcPattern;
      Next    : Font_Access;
   end record;

   type Context is record
      Width, Height : Natural := 0;
      Disp     : Xlib_Thin.Display;
      Screen   : Xlib_Thin.C_Int := 0;
      Root     : Xlib_Thin.Window := Xlib_Thin.None;
      Drawable : Xlib_Thin.Drawable := Xlib_Thin.None;
      Gc       : Xlib_Thin.GC;
      Scheme   : Dwm_Types.Color_Scheme_Access;
      Fonts    : Font_Access;
   end record;
   type Context_Access is access all Context;

   --  Creates a drawing context backed by a Width x Height pixmap on
   --  Win's screen (drw_create()). Called once at startup with the
   --  root window and full screen size.
   function Create
     (Disp : in Xlib_Thin.Display; Screen : in Xlib_Thin.C_Int; Win : in Xlib_Thin.Window;
      Width, Height : in Natural) return Context_Access;

   --  Reallocates Drw_Ctx's backing pixmap to Width x Height
   --  (drw_resize()), e.g. when the screen geometry changes.
   procedure Resize (Drw_Ctx : in Context_Access; Width, Height : in Natural);

   --  Releases Drw_Ctx's pixmap, GC and fontset, then frees Drw_Ctx
   --  itself and sets it to null (drw_free()).
   procedure Free (Drw_Ctx : in out Context_Access);

   --  Loads each font name in Fonts (first match wins per glyph,
   --  falling back through the list) and returns the resulting linked
   --  fontset (drw_fontset_create()); the caller is responsible for
   --  storing it as Drw_Ctx.Fonts, which this deliberately does not do
   --  itself (a function should not also mutate a pre-existing object
   --  reached through one of its parameters). Returns null if none of
   --  the fonts could be loaded.
   function Fontset_Create
     (Drw_Ctx : in Context_Access; Fonts : in Dwm_Types.Command) return Font_Access;

   --  Recursively closes and frees every font in Fnt's chain
   --  (drw_fontset_free()).
   procedure Fontset_Free (Fnt : in out Font_Access);

   --  Pixel width Txt would render at using Drw_Ctx's current fontset
   --  into Result (drw_fontset_getwidth(): Text() in measure-only
   --  mode). A procedure, not a function, because measuring can load
   --  and cache a fallback font as a side effect, same as Text.
   procedure Fontset_Get_Width (Drw_Ctx : in Context_Access; Txt : in String; Result : out Natural);

   --  Like Fontset_Get_Width, but Result never exceeds Max_Width
   --  (drw_fontset_getwidth_clamp()).
   procedure Fontset_Get_Width_Clamp
     (Drw_Ctx : in Context_Access; Txt : in String; Max_Width : in Natural; Result : out Natural);

   --  Pixel width/height of the first Len bytes of Txt when rendered
   --  in Fnt alone, via XftTextExtentsUtf8 (drw_font_getexts()).
   procedure Font_Get_Exts
     (Fnt : in Font_Access; Txt : in String; Len : in Natural; Width : out Natural; Height : out Natural);

   --  Allocates the X color named Color_Name (e.g. "#222222") into
   --  Dest (drw_clr_create()); dies via Util.Die if allocation fails.
   procedure Color_Create (Drw_Ctx : in Context_Access; Dest : access Xft_Thin.XftColor; Color_Name : in String);

   --  Releases a color allocated by Color_Create (drw_clr_free()).
   procedure Color_Free (Drw_Ctx : in Context_Access; Color : access Xft_Thin.XftColor);

   --  Allocates the three colors in Color_Names (fg, bg, border) into
   --  a new Color_Scheme (drw_scm_create()).
   function Scheme_Create
     (Drw_Ctx : in Context_Access; Color_Names : in Dwm_Types.Color_Name_Triple)
      return Dwm_Types.Color_Scheme_Access;

   --  Releases every color in Scheme, then frees Scheme itself and
   --  sets it to null (drw_scm_free()).
   procedure Scheme_Free (Drw_Ctx : in Context_Access; Scheme : in out Dwm_Types.Color_Scheme_Access);

   --  Points Drw_Ctx at a different loaded fontset without recreating
   --  it (drw_setfontset()).
   procedure Set_Fontset (Drw_Ctx : in Context_Access; Set : in Font_Access);

   --  Selects the color scheme subsequent Rect/Text calls draw with
   --  (drw_setscheme()).
   procedure Set_Scheme (Drw_Ctx : in Context_Access; Scheme : in Dwm_Types.Color_Scheme_Access);

   --  Draws a Width x Height rectangle at (Pos_X, Pos_Y) into Drw_Ctx's
   --  pixmap: filled or outlined per Filled, in the foreground or
   --  background color of Drw_Ctx's current scheme per Invert
   --  (drw_rect()).
   procedure Rect
     (Drw_Ctx : in Context_Access; Pos_X, Pos_Y : in Integer; Width, Height : in Natural;
      Filled, Invert : in Integer);

   --  Renders Txt (UTF-8, with font-fallback matching and "..."
   --  truncation) left-padded by Left_Pad into the Width x Height box
   --  at (Pos_X, Pos_Y), swapping foreground/background per Invert;
   --  sets Result to the pixel position just past the drawn text
   --  (drw_text()). If Pos_X, Pos_Y, Width and Height are all zero,
   --  nothing is drawn and Invert instead acts as an optional width
   --  clamp -- this is how Fontset_Get_Width(_Clamp) measure text
   --  without rendering it. A procedure, not a function, since
   --  rendering draws to the X server and can load and cache a
   --  fallback font onto Drw_Ctx's fontset as a side effect.
   procedure Text
     (Drw_Ctx : in Context_Access; Pos_X, Pos_Y : in Integer; Width, Height : in Natural; Left_Pad : in Natural;
      Txt : in String; Invert : in Integer; Result : out Integer);

   --  Copies the Width x Height region at (Pos_X, Pos_Y) from Drw_Ctx's
   --  pixmap onto Win, e.g. to blit a freshly drawn bar onto its
   --  window (drw_map()).
   procedure Map
     (Drw_Ctx : in Context_Access; Win : in Xlib_Thin.Window; Pos_X, Pos_Y : in Integer; Width, Height : in Natural);

   --  Creates an X cursor of the given font-cursor Shape (an XC_*
   --  constant), e.g. Xlib_Thin.XC_left_ptr (drw_cur_create()).
   function Cursor_Create (Drw_Ctx : in Context_Access; Shape : in Xlib_Thin.C_UInt) return Cursor_Access;

   --  Releases a cursor created by Cursor_Create and sets it to null
   --  (drw_cur_free()).
   procedure Cursor_Free (Drw_Ctx : in Context_Access; Cursor : in out Cursor_Access);

end Drw;
