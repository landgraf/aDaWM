with Drw;
with Dwm_Types;
with Xlib_Thin;

--  The Ada analogue of dwm.c's static globals near the top of the file.
package Dwm_State is

   Version : constant String := "6.8";
   Broken  : constant String := "broken";

   Stext : Dwm_Types.Client_Name_Strings.Bounded_String :=
     Dwm_Types.Client_Name_Strings.Null_Bounded_String;

   Screen : Xlib_Thin.C_Int := 0;
   Screen_Width, Screen_Height : Integer := 0;
   Bar_Height     : Natural := 0;
   Left_Right_Pad : Natural := 0;

   Num_Lock_Mask : Xlib_Thin.C_UInt := 0;
   Running     : Boolean := True;

   type Wm_Atom_Kind is (WM_Protocols, WM_Delete, WM_State, WM_Take_Focus);
   type Net_Atom_Kind is
     (Net_Supported, Net_WM_Name, Net_WM_State, Net_WM_Check, Net_WM_Fullscreen,
      Net_Active_Window, Net_WM_Window_Type, Net_WM_Window_Type_Dialog, Net_Client_List);
   type Cursor_Kind is (Cursor_Normal, Cursor_Resize, Cursor_Move);

   Wm_Atom  : array (Wm_Atom_Kind) of Xlib_Thin.Atom := (others => Xlib_Thin.None);
   Net_Atom : array (Net_Atom_Kind) of Xlib_Thin.Atom := (others => Xlib_Thin.None);
   Cursors : array (Cursor_Kind) of Drw.Cursor_Access := (others => null);
   Scheme  : array (Dwm_Types.Scheme_Kind) of Dwm_Types.Color_Scheme_Access := (others => null);

   --  The default layout pair new monitors are created with (set once
   --  from Dwm_Bindings.Layouts by Dwm_Main.Setup before the first
   --  call to Dwm_Monitors.Update_Geom); this indirection is what lets
   --  Dwm_Monitors avoid depending on Dwm_Bindings (which itself
   --  depends, transitively, on Dwm_Monitors via Dwm_Actions).
   Default_Layout : Dwm_Types.Layout_Pair := (others => null);

   --  Same indirection, for the same reason, as Default_Layout:
   --  Dwm_Clients needs the Keys/Buttons arrays (for grabkeys/
   --  grabbuttons) but can't depend on Dwm_Bindings (which depends on
   --  Dwm_Clients via Dwm_Actions). Dwm_Main.Setup wires these in
   --  before grabkeys() or any client is grabbed.
   Keys    : Dwm_Types.Key_Array_Access := null;
   Buttons : Dwm_Types.Button_Array_Access := null;

   Display : Xlib_Thin.Display := null;
   Drw_Ctx : Drw.Context_Access := null;

   Monitors, Selected_Monitor : Dwm_Types.Monitor_Access := null;
   Root, Wm_Check_Window : Xlib_Thin.Window := Xlib_Thin.None;

   X_Error_Xlib : Xlib_Thin.XErrorHandler := null;

end Dwm_State;
