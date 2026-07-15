with Dwm_Types;
with Xlib_Thin;

--  Port of config.def.h: the user-tunable constants dwm is customized
--  by editing (and recompiling), same philosophy as the C original.
--  The Keys/Buttons/Layouts arrays that wire these values to action
--  procedures live in Dwm_Bindings instead of here: those procedures
--  (Dwm_Actions, Dwm_Layouts) themselves depend on WM state that is
--  configured from values in this package, so putting the callback
--  wiring here too would make Config depend on its own dependents.
--  Dwm_Bindings is the composition root that closes that loop, playing
--  the part config.h plays in the C build (included last, after every
--  function it references has already been declared).
package Config is

   --  appearance
   Border_Px  : constant := 1;
   Snap      : constant := 32;
   Show_Bar   : constant Boolean := True;
   Top_Bar    : constant Boolean := True;

   Font_Name       : aliased constant String := "Hack Nerd Font Mono:size=16";
   Font_Name_Emoji : aliased constant String := "Noto Color Emoji:size=16";
   Fonts : constant Dwm_Types.Command := (Font_Name'Access, Font_Name_Emoji'Access);

   Col_Gray1 : aliased constant String := "#222222";
   Col_Gray2 : aliased constant String := "#444444";
   Col_Gray3 : aliased constant String := "#bbbbbb";
   Col_Gray4 : aliased constant String := "#eeeeee";
   Col_Cyan  : aliased constant String := "#005577";

   type Scheme_Colors is array (Dwm_Types.Scheme_Kind) of Dwm_Types.Color_Name_Triple;

   Colors : constant Scheme_Colors :=
     (Dwm_Types.Scheme_Norm =>
        (Dwm_Types.Col_Fg => Col_Gray3'Access,
         Dwm_Types.Col_Bg => Col_Gray1'Access,
         Dwm_Types.Col_Border => Col_Gray2'Access),
      Dwm_Types.Scheme_Sel =>
        (Dwm_Types.Col_Fg => Col_Gray4'Access,
         Dwm_Types.Col_Bg => Col_Cyan'Access,
         Dwm_Types.Col_Border => Col_Cyan'Access));

   --  tagging
   Tag_1 : aliased constant String := "1";
   Tag_2 : aliased constant String := "2";
   Tag_3 : aliased constant String := "3";
   Tag_4 : aliased constant String := "4";
   Tag_5 : aliased constant String := "5";
   Tag_6 : aliased constant String := "6";
   Tag_7 : aliased constant String := "7";
   Tag_8 : aliased constant String := "8";
   Tag_9 : aliased constant String := "9";

   type Tag_Name_Array is array (Positive range <>) of access constant String;

   Tags : constant Tag_Name_Array :=
     (Tag_1'Access, Tag_2'Access, Tag_3'Access, Tag_4'Access, Tag_5'Access,
      Tag_6'Access, Tag_7'Access, Tag_8'Access, Tag_9'Access);

   --  xprop(1): WM_CLASS(STRING) = instance, class; WM_NAME(STRING) = title
   Gimp_Class : aliased constant String := "Gimp";
   Firefox_Class : aliased constant String := "Firefox";

   Rules : constant Dwm_Types.Rule_Array :=
     ((Class => Gimp_Class'Access, Instance => null, Title => null,
       Tags => 0, Is_Floating => True, Monitor => -1),
      (Class => Firefox_Class'Access, Instance => null, Title => null,
       Tags => 256, Is_Floating => False, Monitor => -1));

   --  layout(s)
   Master_Factor         : constant Float := 0.55;
   Num_Master       : constant := 1;
   Resize_Hints   : constant Boolean := True;
   Lock_Full_Screen : constant Boolean := True;
   Refresh_Rate   : constant := 120;

   --  key definitions
   Mod_Key : constant Xlib_Thin.C_UInt := Xlib_Thin.Mod1Mask;

   --  commands
   Dmenu_Font_Str : aliased constant String := "monospace:size=10";

   --  Mutable: spawn() overwrites this with the selected monitor's
   --  number before running Dmenu_Cmd, matching dwm's dmenumon[2] hack
   --  for the dmenu_run -m argument.
   Dmenu_Mon_Buf : aliased String := "0";

   Dmenu_Run_Str : aliased constant String := "dmenu_run";
   Dash_M_Str    : aliased constant String := "-m";
   Dash_Fn_Str   : aliased constant String := "-fn";
   Dash_Nb_Str   : aliased constant String := "-nb";
   Dash_Nf_Str   : aliased constant String := "-nf";
   Dash_Sb_Str   : aliased constant String := "-sb";
   Dash_Sf_Str   : aliased constant String := "-sf";

   Dmenu_Cmd : aliased constant Dwm_Types.Command :=
     (Dmenu_Run_Str'Access, Dash_M_Str'Access, Dmenu_Mon_Buf'Access,
      Dash_Fn_Str'Access, Dmenu_Font_Str'Access,
      Dash_Nb_Str'Access, Col_Gray1'Access,
      Dash_Nf_Str'Access, Col_Gray3'Access,
      Dash_Sb_Str'Access, Col_Cyan'Access,
      Dash_Sf_Str'Access, Col_Gray4'Access);

   Term_Str : aliased constant String := "st";
   Term_Cmd : aliased constant Dwm_Types.Command := (1 => Term_Str'Access);

end Config;
