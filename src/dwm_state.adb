package body Dwm_State is

   Stext_Var : Dwm_Types.Client_Name_Strings.Bounded_String :=
     Dwm_Types.Client_Name_Strings.Null_Bounded_String;

   Screen_Var : Xlib_Thin.C_Int := 0;
   Screen_Width_Var, Screen_Height_Var : Integer := 0;
   Bar_Height_Var     : Natural := 0;
   Left_Right_Pad_Var : Natural := 0;

   Num_Lock_Mask_Var : Xlib_Thin.C_UInt := 0;
   Running_Var : Boolean := True;

   Wm_Atom_Var  : array (Wm_Atom_Kind) of Xlib_Thin.Atom := (others => Xlib_Thin.None);
   Net_Atom_Var : Net_Atom_Array := (others => Xlib_Thin.None);
   Cursors_Var : array (Cursor_Kind) of Drw.Cursor_Access := (others => null);
   Scheme_Var  : array (Dwm_Types.Scheme_Kind) of Dwm_Types.Color_Scheme_Access := (others => null);

   Default_Layout_Var : Dwm_Types.Layout_Pair := (others => null);

   Keys_Var    : Dwm_Types.Key_Array_Access := null;
   Buttons_Var : Dwm_Types.Button_Array_Access := null;

   Display_Var : Xlib_Thin.Display := null;
   Drw_Ctx_Var : Drw.Context_Access := null;

   Monitors_Var, Selected_Monitor_Var : Dwm_Types.Monitor_Access := null;
   Root_Var, Wm_Check_Window_Var : Xlib_Thin.Window := Xlib_Thin.None;

   X_Error_Xlib_Var : Xlib_Thin.XErrorHandler := null;

   --------------------------------------------------------------------
   --  Subprogram bodies (alphabetical order; -gnatyo)                --
   --------------------------------------------------------------------

   function Get_Bar_Height return Natural is (Bar_Height_Var);
   procedure Set_Bar_Height (Value : in Natural) is
   begin
      Bar_Height_Var := Value;
   end Set_Bar_Height;

   function Get_Buttons return Dwm_Types.Button_Array_Access is (Buttons_Var);
   procedure Set_Buttons (Value : in Dwm_Types.Button_Array_Access) is
   begin
      Buttons_Var := Value;
   end Set_Buttons;

   function Get_Cursor (Kind : in Cursor_Kind) return Drw.Cursor_Access is (Cursors_Var (Kind));
   procedure Set_Cursor (Kind : in Cursor_Kind; Value : in Drw.Cursor_Access) is
   begin
      Cursors_Var (Kind) := Value;
   end Set_Cursor;

   function Get_Default_Layout return Dwm_Types.Layout_Pair is (Default_Layout_Var);
   procedure Set_Default_Layout (Value : in Dwm_Types.Layout_Pair) is
   begin
      Default_Layout_Var := Value;
   end Set_Default_Layout;

   function Get_Display return Xlib_Thin.Display is (Display_Var);
   procedure Set_Display (Value : in Xlib_Thin.Display) is
   begin
      Display_Var := Value;
   end Set_Display;

   function Get_Drw_Ctx return Drw.Context_Access is (Drw_Ctx_Var);
   procedure Set_Drw_Ctx (Value : in Drw.Context_Access) is
   begin
      Drw_Ctx_Var := Value;
   end Set_Drw_Ctx;

   function Get_Keys return Dwm_Types.Key_Array_Access is (Keys_Var);
   procedure Set_Keys (Value : in Dwm_Types.Key_Array_Access) is
   begin
      Keys_Var := Value;
   end Set_Keys;

   function Get_Left_Right_Pad return Natural is (Left_Right_Pad_Var);
   procedure Set_Left_Right_Pad (Value : in Natural) is
   begin
      Left_Right_Pad_Var := Value;
   end Set_Left_Right_Pad;

   function Get_Monitors return Dwm_Types.Monitor_Access is (Monitors_Var);
   procedure Set_Monitors (Value : in Dwm_Types.Monitor_Access) is
   begin
      Monitors_Var := Value;
   end Set_Monitors;

   function Get_All_Net_Atoms return Net_Atom_Array is (Net_Atom_Var);

   function Get_Net_Atom (Kind : in Net_Atom_Kind) return Xlib_Thin.Atom is (Net_Atom_Var (Kind));
   procedure Set_Net_Atom (Kind : in Net_Atom_Kind; Value : in Xlib_Thin.Atom) is
   begin
      Net_Atom_Var (Kind) := Value;
   end Set_Net_Atom;

   function Get_Num_Lock_Mask return Xlib_Thin.C_UInt is (Num_Lock_Mask_Var);
   procedure Set_Num_Lock_Mask (Value : in Xlib_Thin.C_UInt) is
   begin
      Num_Lock_Mask_Var := Value;
   end Set_Num_Lock_Mask;

   function Get_Root return Xlib_Thin.Window is (Root_Var);
   procedure Set_Root (Value : in Xlib_Thin.Window) is
   begin
      Root_Var := Value;
   end Set_Root;

   function Get_Running return Boolean is (Running_Var);
   procedure Set_Running (Value : in Boolean) is
   begin
      Running_Var := Value;
   end Set_Running;

   function Get_Scheme (Kind : in Dwm_Types.Scheme_Kind) return Dwm_Types.Color_Scheme_Access is
     (Scheme_Var (Kind));
   procedure Set_Scheme (Kind : in Dwm_Types.Scheme_Kind; Value : in Dwm_Types.Color_Scheme_Access) is
   begin
      Scheme_Var (Kind) := Value;
   end Set_Scheme;

   function Get_Screen return Xlib_Thin.C_Int is (Screen_Var);
   procedure Set_Screen (Value : in Xlib_Thin.C_Int) is
   begin
      Screen_Var := Value;
   end Set_Screen;

   function Get_Screen_Height return Integer is (Screen_Height_Var);
   procedure Set_Screen_Height (Value : in Integer) is
   begin
      Screen_Height_Var := Value;
   end Set_Screen_Height;

   function Get_Screen_Width return Integer is (Screen_Width_Var);
   procedure Set_Screen_Width (Value : in Integer) is
   begin
      Screen_Width_Var := Value;
   end Set_Screen_Width;

   function Get_Selected_Monitor return Dwm_Types.Monitor_Access is (Selected_Monitor_Var);
   procedure Set_Selected_Monitor (Value : in Dwm_Types.Monitor_Access) is
   begin
      Selected_Monitor_Var := Value;
   end Set_Selected_Monitor;

   function Get_Stext return Dwm_Types.Client_Name_Strings.Bounded_String is (Stext_Var);
   procedure Set_Stext (Value : in Dwm_Types.Client_Name_Strings.Bounded_String) is
   begin
      Stext_Var := Value;
   end Set_Stext;

   function Get_Wm_Atom (Kind : in Wm_Atom_Kind) return Xlib_Thin.Atom is (Wm_Atom_Var (Kind));
   procedure Set_Wm_Atom (Kind : in Wm_Atom_Kind; Value : in Xlib_Thin.Atom) is
   begin
      Wm_Atom_Var (Kind) := Value;
   end Set_Wm_Atom;

   function Get_Wm_Check_Window return Xlib_Thin.Window is (Wm_Check_Window_Var);
   procedure Set_Wm_Check_Window (Value : in Xlib_Thin.Window) is
   begin
      Wm_Check_Window_Var := Value;
   end Set_Wm_Check_Window;

   function Get_X_Error_Xlib return Xlib_Thin.XErrorHandler is (X_Error_Xlib_Var);
   procedure Set_X_Error_Xlib (Value : in Xlib_Thin.XErrorHandler) is
   begin
      X_Error_Xlib_Var := Value;
   end Set_X_Error_Xlib;

end Dwm_State;
