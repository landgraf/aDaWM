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
--  Buttons/Default_Lt for why this can't sit any lower in the
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

   Modkey : Xlib_Thin.C_UInt renames Config.Modkey;
   Shift  : constant Xlib_Thin.C_UInt := Xlib_Thin.ShiftMask;
   Ctrl   : constant Xlib_Thin.C_UInt := Xlib_Thin.ControlMask;

   function Tagbit (Tag : Natural) return Dwm_Types.Tag_Mask is (2 ** Tag);

   Keys : aliased constant Dwm_Types.Key_Array :=
     ((Modkey, Keysyms.XK_p, Dwm_Actions.Spawn'Access, (Cmd => Config.Dmenu_Cmd'Access, others => <>)),
      (Modkey or Shift, Keysyms.XK_Return, Dwm_Actions.Spawn'Access,
       (Cmd => Config.Term_Cmd'Access, others => <>)),
      (Modkey, Keysyms.XK_b, Dwm_Actions.Togglebar'Access, Dwm_Types.No_Arg),
      (Modkey, Keysyms.XK_j, Dwm_Actions.Focusstack'Access, (I => 1, others => <>)),
      (Modkey, Keysyms.XK_k, Dwm_Actions.Focusstack'Access, (I => -1, others => <>)),
      (Modkey, Keysyms.XK_i, Dwm_Actions.Incnmaster'Access, (I => 1, others => <>)),
      (Modkey, Keysyms.XK_d, Dwm_Actions.Incnmaster'Access, (I => -1, others => <>)),
      (Modkey, Keysyms.XK_h, Dwm_Actions.Setmfact'Access, (F => -0.05, others => <>)),
      (Modkey, Keysyms.XK_l, Dwm_Actions.Setmfact'Access, (F => 0.05, others => <>)),
      (Modkey, Keysyms.XK_Return, Dwm_Actions.Zoom'Access, Dwm_Types.No_Arg),
      (Modkey, Keysyms.XK_Tab, Dwm_Actions.View'Access, Dwm_Types.No_Arg),
      (Modkey or Shift, Keysyms.XK_c, Dwm_Actions.Killclient'Access, Dwm_Types.No_Arg),
      (Modkey, Keysyms.XK_t, Dwm_Actions.Setlayout'Access, (Lt => Layouts (1)'Access, others => <>)),
      (Modkey, Keysyms.XK_f, Dwm_Actions.Setlayout'Access, (Lt => Layouts (2)'Access, others => <>)),
      (Modkey, Keysyms.XK_m, Dwm_Actions.Setlayout'Access, (Lt => Layouts (3)'Access, others => <>)),
      (Modkey, Keysyms.XK_space, Dwm_Actions.Setlayout'Access, Dwm_Types.No_Arg),
      (Modkey or Shift, Keysyms.XK_space, Dwm_Actions.Togglefloating'Access, Dwm_Types.No_Arg),
      (Modkey, Keysyms.XK_0, Dwm_Actions.View'Access, (Ui => All_Tags, others => <>)),
      (Modkey or Shift, Keysyms.XK_0, Dwm_Actions.Tag'Access, (Ui => All_Tags, others => <>)),
      (Modkey, Keysyms.XK_comma, Dwm_Actions.Focusmon'Access, (I => -1, others => <>)),
      (Modkey, Keysyms.XK_period, Dwm_Actions.Focusmon'Access, (I => 1, others => <>)),
      (Modkey or Shift, Keysyms.XK_comma, Dwm_Actions.Tagmon'Access, (I => -1, others => <>)),
      (Modkey or Shift, Keysyms.XK_period, Dwm_Actions.Tagmon'Access, (I => 1, others => <>)),

      (Modkey, Keysyms.XK_1, Dwm_Actions.View'Access, (Ui => Tagbit (0), others => <>)),
      (Modkey or Ctrl, Keysyms.XK_1, Dwm_Actions.Toggleview'Access, (Ui => Tagbit (0), others => <>)),
      (Modkey or Shift, Keysyms.XK_1, Dwm_Actions.Tag'Access, (Ui => Tagbit (0), others => <>)),
      (Modkey or Ctrl or Shift, Keysyms.XK_1, Dwm_Actions.Toggletag'Access,
       (Ui => Tagbit (0), others => <>)),

      (Modkey, Keysyms.XK_2, Dwm_Actions.View'Access, (Ui => Tagbit (1), others => <>)),
      (Modkey or Ctrl, Keysyms.XK_2, Dwm_Actions.Toggleview'Access, (Ui => Tagbit (1), others => <>)),
      (Modkey or Shift, Keysyms.XK_2, Dwm_Actions.Tag'Access, (Ui => Tagbit (1), others => <>)),
      (Modkey or Ctrl or Shift, Keysyms.XK_2, Dwm_Actions.Toggletag'Access,
       (Ui => Tagbit (1), others => <>)),

      (Modkey, Keysyms.XK_3, Dwm_Actions.View'Access, (Ui => Tagbit (2), others => <>)),
      (Modkey or Ctrl, Keysyms.XK_3, Dwm_Actions.Toggleview'Access, (Ui => Tagbit (2), others => <>)),
      (Modkey or Shift, Keysyms.XK_3, Dwm_Actions.Tag'Access, (Ui => Tagbit (2), others => <>)),
      (Modkey or Ctrl or Shift, Keysyms.XK_3, Dwm_Actions.Toggletag'Access,
       (Ui => Tagbit (2), others => <>)),

      (Modkey, Keysyms.XK_4, Dwm_Actions.View'Access, (Ui => Tagbit (3), others => <>)),
      (Modkey or Ctrl, Keysyms.XK_4, Dwm_Actions.Toggleview'Access, (Ui => Tagbit (3), others => <>)),
      (Modkey or Shift, Keysyms.XK_4, Dwm_Actions.Tag'Access, (Ui => Tagbit (3), others => <>)),
      (Modkey or Ctrl or Shift, Keysyms.XK_4, Dwm_Actions.Toggletag'Access,
       (Ui => Tagbit (3), others => <>)),

      (Modkey, Keysyms.XK_5, Dwm_Actions.View'Access, (Ui => Tagbit (4), others => <>)),
      (Modkey or Ctrl, Keysyms.XK_5, Dwm_Actions.Toggleview'Access, (Ui => Tagbit (4), others => <>)),
      (Modkey or Shift, Keysyms.XK_5, Dwm_Actions.Tag'Access, (Ui => Tagbit (4), others => <>)),
      (Modkey or Ctrl or Shift, Keysyms.XK_5, Dwm_Actions.Toggletag'Access,
       (Ui => Tagbit (4), others => <>)),

      (Modkey, Keysyms.XK_6, Dwm_Actions.View'Access, (Ui => Tagbit (5), others => <>)),
      (Modkey or Ctrl, Keysyms.XK_6, Dwm_Actions.Toggleview'Access, (Ui => Tagbit (5), others => <>)),
      (Modkey or Shift, Keysyms.XK_6, Dwm_Actions.Tag'Access, (Ui => Tagbit (5), others => <>)),
      (Modkey or Ctrl or Shift, Keysyms.XK_6, Dwm_Actions.Toggletag'Access,
       (Ui => Tagbit (5), others => <>)),

      (Modkey, Keysyms.XK_7, Dwm_Actions.View'Access, (Ui => Tagbit (6), others => <>)),
      (Modkey or Ctrl, Keysyms.XK_7, Dwm_Actions.Toggleview'Access, (Ui => Tagbit (6), others => <>)),
      (Modkey or Shift, Keysyms.XK_7, Dwm_Actions.Tag'Access, (Ui => Tagbit (6), others => <>)),
      (Modkey or Ctrl or Shift, Keysyms.XK_7, Dwm_Actions.Toggletag'Access,
       (Ui => Tagbit (6), others => <>)),

      (Modkey, Keysyms.XK_8, Dwm_Actions.View'Access, (Ui => Tagbit (7), others => <>)),
      (Modkey or Ctrl, Keysyms.XK_8, Dwm_Actions.Toggleview'Access, (Ui => Tagbit (7), others => <>)),
      (Modkey or Shift, Keysyms.XK_8, Dwm_Actions.Tag'Access, (Ui => Tagbit (7), others => <>)),
      (Modkey or Ctrl or Shift, Keysyms.XK_8, Dwm_Actions.Toggletag'Access,
       (Ui => Tagbit (7), others => <>)),

      (Modkey, Keysyms.XK_9, Dwm_Actions.View'Access, (Ui => Tagbit (8), others => <>)),
      (Modkey or Ctrl, Keysyms.XK_9, Dwm_Actions.Toggleview'Access, (Ui => Tagbit (8), others => <>)),
      (Modkey or Shift, Keysyms.XK_9, Dwm_Actions.Tag'Access, (Ui => Tagbit (8), others => <>)),
      (Modkey or Ctrl or Shift, Keysyms.XK_9, Dwm_Actions.Toggletag'Access,
       (Ui => Tagbit (8), others => <>)),

      (Modkey or Shift, Keysyms.XK_q, Dwm_Actions.Quit'Access, Dwm_Types.No_Arg));

   Buttons : aliased constant Dwm_Types.Button_Array :=
     ((Dwm_Types.Clk_Lt_Symbol, 0, Xlib_Thin.Button1, Dwm_Actions.Setlayout'Access, Dwm_Types.No_Arg),
      (Dwm_Types.Clk_Lt_Symbol, 0, Xlib_Thin.Button3, Dwm_Actions.Setlayout'Access,
       (Lt => Layouts (3)'Access, others => <>)),
      (Dwm_Types.Clk_Win_Title, 0, Xlib_Thin.Button2, Dwm_Actions.Zoom'Access, Dwm_Types.No_Arg),
      (Dwm_Types.Clk_Status_Text, 0, Xlib_Thin.Button2, Dwm_Actions.Spawn'Access,
       (Cmd => Config.Term_Cmd'Access, others => <>)),
      (Dwm_Types.Clk_Client_Win, Modkey, Xlib_Thin.Button1, Dwm_Actions.Movemouse'Access, Dwm_Types.No_Arg),
      (Dwm_Types.Clk_Client_Win, Modkey, Xlib_Thin.Button2, Dwm_Actions.Togglefloating'Access,
       Dwm_Types.No_Arg),
      (Dwm_Types.Clk_Client_Win, Modkey, Xlib_Thin.Button3, Dwm_Actions.Resizemouse'Access,
       Dwm_Types.No_Arg),
      (Dwm_Types.Clk_Tag_Bar, 0, Xlib_Thin.Button1, Dwm_Actions.View'Access, Dwm_Types.No_Arg),
      (Dwm_Types.Clk_Tag_Bar, 0, Xlib_Thin.Button3, Dwm_Actions.Toggleview'Access, Dwm_Types.No_Arg),
      (Dwm_Types.Clk_Tag_Bar, Modkey, Xlib_Thin.Button1, Dwm_Actions.Tag'Access, Dwm_Types.No_Arg),
      (Dwm_Types.Clk_Tag_Bar, Modkey, Xlib_Thin.Button3, Dwm_Actions.Toggletag'Access, Dwm_Types.No_Arg));

end Dwm_Bindings;
