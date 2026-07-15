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

   function Create
     (Disp : Xlib_Thin.Display; Screen : Xlib_Thin.C_Int; Win : Xlib_Thin.Window;
      W, H : Natural) return Context_Access;

   procedure Resize (D : Context_Access; W, H : Natural);
   procedure Free (D : in out Context_Access);

   function Fontset_Create (D : Context_Access; Fonts : Dwm_Types.Command) return Fnt_Access;
   procedure Fontset_Free (Font : in out Fnt_Access);
   function Fontset_Get_Width (D : Context_Access; Txt : String) return Natural;
   function Fontset_Get_Width_Clamp (D : Context_Access; Txt : String; N : Natural) return Natural;
   procedure Font_Get_Exts
     (Font : Fnt_Access; Txt : String; Len : Natural; W : out Natural; H : out Natural);

   procedure Clr_Create (D : Context_Access; Dest : access Xft_Thin.XftColor; Clrname : String);
   procedure Clr_Free (D : Context_Access; C : access Xft_Thin.XftColor);

   function Scm_Create
     (D : Context_Access; Clrnames : Dwm_Types.Color_Name_Triple) return Dwm_Types.Color_Scheme_Access;
   procedure Scm_Free (D : Context_Access; Scm : in out Dwm_Types.Color_Scheme_Access);

   procedure Set_Fontset (D : Context_Access; Set : Fnt_Access);
   procedure Set_Scheme (D : Context_Access; Scm : Dwm_Types.Color_Scheme_Access);

   procedure Rect
     (D : Context_Access; X, Y : Integer; W, H : Natural; Filled, Invert : Integer);

   function Text
     (D : Context_Access; X, Y : Integer; W, H : Natural; Lpad : Natural;
      Txt : String; Invert : Integer) return Integer;

   procedure Map
     (D : Context_Access; Win : Xlib_Thin.Window; X, Y : Integer; W, H : Natural);

   function Cur_Create (D : Context_Access; Shape : Xlib_Thin.C_UInt) return Cur_Access;
   procedure Cur_Free (D : Context_Access; C : in out Cur_Access);

end Drw;
