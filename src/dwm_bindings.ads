with Interfaces;
use type Interfaces.Unsigned_32;
with Interfaces.C;
use type Interfaces.C.unsigned;
with Config;
with Dwm_Actions;
with Dwm_Layouts;
with Dwm_Types;
with Keysyms;
with Xlib_Thin;

--  Port of config.def.h's layouts[]/keys[]/buttons[] tables: the
--  composition root that wires Config's tunable data to the action
--  procedures in Dwm_Actions and the layout procedures in
--  Dwm_Layouts, playing the role config.h plays in the C build
--  (included last, after every function it names has already been
--  declared). See Dwm_Clients's header comment and Dwm_State.Keys/
--  Buttons/Default_Layout for why this can't sit any lower in the
--  dependency graph.
package Dwm_Bindings is

   Symbol_Tile     : aliased constant String := "[]=";
   Symbol_Floating : aliased constant String := "><>";
   Symbol_Monocle  : aliased constant String := "[M]";

   Layouts : aliased constant Dwm_Types.Layout_Array :=
     ((Symbol => Symbol_Tile'Access, Arrange => Dwm_Layouts.Tile'Access),
      (Symbol => Symbol_Floating'Access, Arrange => null),
      (Symbol => Symbol_Monocle'Access, Arrange => Dwm_Layouts.Monocle'Access));

   All_Tags : constant Dwm_Types.Tag_Mask := not Dwm_Types.Tag_Mask'(0);

   Mod_Key : Xlib_Thin.C_UInt renames Config.Mod_Key;
   Shift  : constant Xlib_Thin.C_UInt := Xlib_Thin.ShiftMask;
   Ctrl   : constant Xlib_Thin.C_UInt := Xlib_Thin.ControlMask;

   --  The single-bit tag mask for tag index Tag (0-based), e.g.
   --  Tag_Bit (0) selects tag "1". Used throughout the Keys table
   --  below to build each tag's view/toggle-view/tag/toggle-tag
   --  bindings.
   function Tag_Bit (Tag : in Natural) return Dwm_Types.Tag_Mask is (2 ** Tag);

   Keys : aliased constant Dwm_Types.Key_Array :=
     ((Mod_Key, Keysyms.XK_p, Dwm_Actions.Spawn'Access, (Command => Config.Dmenu_Cmd'Access, others => <>)),
      (Mod_Key or Shift, Keysyms.XK_Return, Dwm_Actions.Spawn'Access,
       (Command => Config.Term_Cmd'Access, others => <>)),
      (Mod_Key, Keysyms.XK_b, Dwm_Actions.Toggle_Bar'Access, Dwm_Types.No_Arg),
      (Mod_Key, Keysyms.XK_j, Dwm_Actions.Focus_Stack'Access, (Int_Value => 1, others => <>)),
      (Mod_Key, Keysyms.XK_k, Dwm_Actions.Focus_Stack'Access, (Int_Value => -1, others => <>)),
      (Mod_Key, Keysyms.XK_i, Dwm_Actions.Inc_Nmaster'Access, (Int_Value => 1, others => <>)),
      (Mod_Key, Keysyms.XK_d, Dwm_Actions.Inc_Nmaster'Access, (Int_Value => -1, others => <>)),
      (Mod_Key, Keysyms.XK_h, Dwm_Actions.Set_Mfact'Access, (Float_Value => -0.05, others => <>)),
      (Mod_Key, Keysyms.XK_l, Dwm_Actions.Set_Mfact'Access, (Float_Value => 0.05, others => <>)),
      (Mod_Key, Keysyms.XK_Return, Dwm_Actions.Zoom'Access, Dwm_Types.No_Arg),
      (Mod_Key, Keysyms.XK_Tab, Dwm_Actions.View'Access, Dwm_Types.No_Arg),
      (Mod_Key or Shift, Keysyms.XK_c, Dwm_Actions.Kill_Client'Access, Dwm_Types.No_Arg),
      (Mod_Key, Keysyms.XK_t, Dwm_Actions.Set_Layout'Access, (Layout => Layouts (1)'Access, others => <>)),
      (Mod_Key, Keysyms.XK_f, Dwm_Actions.Set_Layout'Access, (Layout => Layouts (2)'Access, others => <>)),
      (Mod_Key, Keysyms.XK_m, Dwm_Actions.Set_Layout'Access, (Layout => Layouts (3)'Access, others => <>)),
      (Mod_Key, Keysyms.XK_space, Dwm_Actions.Set_Layout'Access, Dwm_Types.No_Arg),
      (Mod_Key or Shift, Keysyms.XK_space, Dwm_Actions.Toggle_Floating'Access, Dwm_Types.No_Arg),
      (Mod_Key, Keysyms.XK_0, Dwm_Actions.View'Access, (Uint_Value => All_Tags, others => <>)),
      (Mod_Key or Shift, Keysyms.XK_0, Dwm_Actions.Tag'Access, (Uint_Value => All_Tags, others => <>)),
      (Mod_Key, Keysyms.XK_comma, Dwm_Actions.Focus_Mon'Access, (Int_Value => -1, others => <>)),
      (Mod_Key, Keysyms.XK_period, Dwm_Actions.Focus_Mon'Access, (Int_Value => 1, others => <>)),
      (Mod_Key or Shift, Keysyms.XK_comma, Dwm_Actions.Tag_Mon'Access, (Int_Value => -1, others => <>)),
      (Mod_Key or Shift, Keysyms.XK_period, Dwm_Actions.Tag_Mon'Access, (Int_Value => 1, others => <>)),

      (Mod_Key, Keysyms.XK_1, Dwm_Actions.View'Access, (Uint_Value => Tag_Bit (0), others => <>)),
      (Mod_Key or Ctrl, Keysyms.XK_1, Dwm_Actions.Toggle_View'Access, (Uint_Value => Tag_Bit (0), others => <>)),
      (Mod_Key or Shift, Keysyms.XK_1, Dwm_Actions.Tag'Access, (Uint_Value => Tag_Bit (0), others => <>)),
      (Mod_Key or Ctrl or Shift, Keysyms.XK_1, Dwm_Actions.Toggle_Tag'Access,
       (Uint_Value => Tag_Bit (0), others => <>)),

      (Mod_Key, Keysyms.XK_2, Dwm_Actions.View'Access, (Uint_Value => Tag_Bit (1), others => <>)),
      (Mod_Key or Ctrl, Keysyms.XK_2, Dwm_Actions.Toggle_View'Access, (Uint_Value => Tag_Bit (1), others => <>)),
      (Mod_Key or Shift, Keysyms.XK_2, Dwm_Actions.Tag'Access, (Uint_Value => Tag_Bit (1), others => <>)),
      (Mod_Key or Ctrl or Shift, Keysyms.XK_2, Dwm_Actions.Toggle_Tag'Access,
       (Uint_Value => Tag_Bit (1), others => <>)),

      (Mod_Key, Keysyms.XK_3, Dwm_Actions.View'Access, (Uint_Value => Tag_Bit (2), others => <>)),
      (Mod_Key or Ctrl, Keysyms.XK_3, Dwm_Actions.Toggle_View'Access, (Uint_Value => Tag_Bit (2), others => <>)),
      (Mod_Key or Shift, Keysyms.XK_3, Dwm_Actions.Tag'Access, (Uint_Value => Tag_Bit (2), others => <>)),
      (Mod_Key or Ctrl or Shift, Keysyms.XK_3, Dwm_Actions.Toggle_Tag'Access,
       (Uint_Value => Tag_Bit (2), others => <>)),

      (Mod_Key, Keysyms.XK_4, Dwm_Actions.View'Access, (Uint_Value => Tag_Bit (3), others => <>)),
      (Mod_Key or Ctrl, Keysyms.XK_4, Dwm_Actions.Toggle_View'Access, (Uint_Value => Tag_Bit (3), others => <>)),
      (Mod_Key or Shift, Keysyms.XK_4, Dwm_Actions.Tag'Access, (Uint_Value => Tag_Bit (3), others => <>)),
      (Mod_Key or Ctrl or Shift, Keysyms.XK_4, Dwm_Actions.Toggle_Tag'Access,
       (Uint_Value => Tag_Bit (3), others => <>)),

      (Mod_Key, Keysyms.XK_5, Dwm_Actions.View'Access, (Uint_Value => Tag_Bit (4), others => <>)),
      (Mod_Key or Ctrl, Keysyms.XK_5, Dwm_Actions.Toggle_View'Access, (Uint_Value => Tag_Bit (4), others => <>)),
      (Mod_Key or Shift, Keysyms.XK_5, Dwm_Actions.Tag'Access, (Uint_Value => Tag_Bit (4), others => <>)),
      (Mod_Key or Ctrl or Shift, Keysyms.XK_5, Dwm_Actions.Toggle_Tag'Access,
       (Uint_Value => Tag_Bit (4), others => <>)),

      (Mod_Key, Keysyms.XK_6, Dwm_Actions.View'Access, (Uint_Value => Tag_Bit (5), others => <>)),
      (Mod_Key or Ctrl, Keysyms.XK_6, Dwm_Actions.Toggle_View'Access, (Uint_Value => Tag_Bit (5), others => <>)),
      (Mod_Key or Shift, Keysyms.XK_6, Dwm_Actions.Tag'Access, (Uint_Value => Tag_Bit (5), others => <>)),
      (Mod_Key or Ctrl or Shift, Keysyms.XK_6, Dwm_Actions.Toggle_Tag'Access,
       (Uint_Value => Tag_Bit (5), others => <>)),

      (Mod_Key, Keysyms.XK_7, Dwm_Actions.View'Access, (Uint_Value => Tag_Bit (6), others => <>)),
      (Mod_Key or Ctrl, Keysyms.XK_7, Dwm_Actions.Toggle_View'Access, (Uint_Value => Tag_Bit (6), others => <>)),
      (Mod_Key or Shift, Keysyms.XK_7, Dwm_Actions.Tag'Access, (Uint_Value => Tag_Bit (6), others => <>)),
      (Mod_Key or Ctrl or Shift, Keysyms.XK_7, Dwm_Actions.Toggle_Tag'Access,
       (Uint_Value => Tag_Bit (6), others => <>)),

      (Mod_Key, Keysyms.XK_8, Dwm_Actions.View'Access, (Uint_Value => Tag_Bit (7), others => <>)),
      (Mod_Key or Ctrl, Keysyms.XK_8, Dwm_Actions.Toggle_View'Access, (Uint_Value => Tag_Bit (7), others => <>)),
      (Mod_Key or Shift, Keysyms.XK_8, Dwm_Actions.Tag'Access, (Uint_Value => Tag_Bit (7), others => <>)),
      (Mod_Key or Ctrl or Shift, Keysyms.XK_8, Dwm_Actions.Toggle_Tag'Access,
       (Uint_Value => Tag_Bit (7), others => <>)),

      (Mod_Key, Keysyms.XK_9, Dwm_Actions.View'Access, (Uint_Value => Tag_Bit (8), others => <>)),
      (Mod_Key or Ctrl, Keysyms.XK_9, Dwm_Actions.Toggle_View'Access, (Uint_Value => Tag_Bit (8), others => <>)),
      (Mod_Key or Shift, Keysyms.XK_9, Dwm_Actions.Tag'Access, (Uint_Value => Tag_Bit (8), others => <>)),
      (Mod_Key or Ctrl or Shift, Keysyms.XK_9, Dwm_Actions.Toggle_Tag'Access,
       (Uint_Value => Tag_Bit (8), others => <>)),

      (Mod_Key or Shift, Keysyms.XK_q, Dwm_Actions.Quit'Access, Dwm_Types.No_Arg));

   Buttons : aliased constant Dwm_Types.Button_Array :=
     ((Dwm_Types.Clk_Lt_Symbol, 0, Xlib_Thin.Button1, Dwm_Actions.Set_Layout'Access, Dwm_Types.No_Arg),
      (Dwm_Types.Clk_Lt_Symbol, 0, Xlib_Thin.Button3, Dwm_Actions.Set_Layout'Access,
       (Layout => Layouts (3)'Access, others => <>)),
      (Dwm_Types.Clk_Win_Title, 0, Xlib_Thin.Button2, Dwm_Actions.Zoom'Access, Dwm_Types.No_Arg),
      (Dwm_Types.Clk_Status_Text, 0, Xlib_Thin.Button2, Dwm_Actions.Spawn'Access,
       (Command => Config.Term_Cmd'Access, others => <>)),
      (Dwm_Types.Clk_Client_Win, Mod_Key, Xlib_Thin.Button1, Dwm_Actions.Move_Mouse'Access, Dwm_Types.No_Arg),
      (Dwm_Types.Clk_Client_Win, Mod_Key, Xlib_Thin.Button2, Dwm_Actions.Toggle_Floating'Access,
       Dwm_Types.No_Arg),
      (Dwm_Types.Clk_Client_Win, Mod_Key, Xlib_Thin.Button3, Dwm_Actions.Resize_Mouse'Access,
       Dwm_Types.No_Arg),
      (Dwm_Types.Clk_Tag_Bar, 0, Xlib_Thin.Button1, Dwm_Actions.View'Access, Dwm_Types.No_Arg),
      (Dwm_Types.Clk_Tag_Bar, 0, Xlib_Thin.Button3, Dwm_Actions.Toggle_View'Access, Dwm_Types.No_Arg),
      (Dwm_Types.Clk_Tag_Bar, Mod_Key, Xlib_Thin.Button1, Dwm_Actions.Tag'Access, Dwm_Types.No_Arg),
      (Dwm_Types.Clk_Tag_Bar, Mod_Key, Xlib_Thin.Button3, Dwm_Actions.Toggle_Tag'Access, Dwm_Types.No_Arg));

end Dwm_Bindings;
