with Drw;
with Dwm_Types;
with Xlib_Thin;

--  The Ada analogue of dwm.c's static globals near the top of the file.
--  Unlike dwm.c's file-static variables (visible only within dwm.c but
--  freely read/written there), every mutable piece of state here is
--  private to the package body and reached only through the Get_*/
--  Set_* subprograms below -- the point being a single, greppable set
--  of places that ever assign each piece of WM-wide state, not runtime
--  protection (dwm is single-threaded; there is no concurrent access
--  to guard against).
package Dwm_State is

   Version : constant String := "6.8";
   Broken  : constant String := "broken";

   type Wm_Atom_Kind is (WM_Protocols, WM_Delete, WM_State, WM_Take_Focus);
   type Net_Atom_Kind is
     (Net_Supported, Net_WM_Name, Net_WM_State, Net_WM_Check, Net_WM_Fullscreen,
      Net_Active_Window, Net_WM_Window_Type, Net_WM_Window_Type_Dialog, Net_Client_List);
   type Cursor_Kind is (Cursor_Normal, Cursor_Resize, Cursor_Move);

   function Get_Stext return Dwm_Types.Client_Name_Strings.Bounded_String;
   procedure Set_Stext (Value : in Dwm_Types.Client_Name_Strings.Bounded_String);

   function Get_Screen return Xlib_Thin.C_Int;
   procedure Set_Screen (Value : in Xlib_Thin.C_Int);

   function Get_Screen_Width return Integer;
   procedure Set_Screen_Width (Value : in Integer);

   function Get_Screen_Height return Integer;
   procedure Set_Screen_Height (Value : in Integer);

   function Get_Bar_Height return Natural;
   procedure Set_Bar_Height (Value : in Natural);

   function Get_Left_Right_Pad return Natural;
   procedure Set_Left_Right_Pad (Value : in Natural);

   function Get_Num_Lock_Mask return Xlib_Thin.C_UInt;
   procedure Set_Num_Lock_Mask (Value : in Xlib_Thin.C_UInt);

   function Get_Running return Boolean;
   procedure Set_Running (Value : in Boolean);

   function Get_Wm_Atom (Kind : in Wm_Atom_Kind) return Xlib_Thin.Atom;
   procedure Set_Wm_Atom (Kind : in Wm_Atom_Kind; Value : in Xlib_Thin.Atom);

   function Get_Net_Atom (Kind : in Net_Atom_Kind) return Xlib_Thin.Atom;
   procedure Set_Net_Atom (Kind : in Net_Atom_Kind; Value : in Xlib_Thin.Atom);

   --  Whole-array snapshot of Net_Atom, for the one place (advertising
   --  _NET_SUPPORTED) that needs to hand X a contiguous block of every
   --  atom at once rather than one at a time.
   type Net_Atom_Array is array (Net_Atom_Kind) of Xlib_Thin.Atom;
   function Get_All_Net_Atoms return Net_Atom_Array;

   function Get_Cursor (Kind : in Cursor_Kind) return Drw.Cursor_Access;
   procedure Set_Cursor (Kind : in Cursor_Kind; Value : in Drw.Cursor_Access);

   function Get_Scheme (Kind : in Dwm_Types.Scheme_Kind) return Dwm_Types.Color_Scheme_Access;
   procedure Set_Scheme (Kind : in Dwm_Types.Scheme_Kind; Value : in Dwm_Types.Color_Scheme_Access);

   --  The default layout pair new monitors are created with (set once
   --  from Dwm_Bindings.Layouts by Dwm_Main.Setup before the first
   --  call to Dwm_Monitors.Update_Geom); this indirection is what lets
   --  Dwm_Monitors avoid depending on Dwm_Bindings (which itself
   --  depends, transitively, on Dwm_Monitors via Dwm_Actions).
   function Get_Default_Layout return Dwm_Types.Layout_Pair;
   procedure Set_Default_Layout (Value : in Dwm_Types.Layout_Pair);

   --  Same indirection, for the same reason, as Default_Layout:
   --  Dwm_Clients needs the Keys/Buttons arrays (for grabkeys/
   --  grabbuttons) but can't depend on Dwm_Bindings (which depends on
   --  Dwm_Clients via Dwm_Actions). Dwm_Main.Setup wires these in
   --  before grabkeys() or any client is grabbed.
   function Get_Keys return Dwm_Types.Key_Array_Access;
   procedure Set_Keys (Value : in Dwm_Types.Key_Array_Access);

   function Get_Buttons return Dwm_Types.Button_Array_Access;
   procedure Set_Buttons (Value : in Dwm_Types.Button_Array_Access);

   function Get_Display return Xlib_Thin.Display;
   procedure Set_Display (Value : in Xlib_Thin.Display);

   function Get_Drw_Ctx return Drw.Context_Access;
   procedure Set_Drw_Ctx (Value : in Drw.Context_Access);

   function Get_Monitors return Dwm_Types.Monitor_Access;
   procedure Set_Monitors (Value : in Dwm_Types.Monitor_Access);

   function Get_Selected_Monitor return Dwm_Types.Monitor_Access;
   procedure Set_Selected_Monitor (Value : in Dwm_Types.Monitor_Access);

   function Get_Root return Xlib_Thin.Window;
   procedure Set_Root (Value : in Xlib_Thin.Window);

   function Get_Wm_Check_Window return Xlib_Thin.Window;
   procedure Set_Wm_Check_Window (Value : in Xlib_Thin.Window);

   function Get_X_Error_Xlib return Xlib_Thin.XErrorHandler;
   procedure Set_X_Error_Xlib (Value : in Xlib_Thin.XErrorHandler);

end Dwm_State;
