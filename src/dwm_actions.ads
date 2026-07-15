with Dwm_Types;

--  Port of the Arg-taking user commands from dwm.c -- the functions
--  bound to keys/buttons in Dwm_Bindings (focusmon, focusstack,
--  incnmaster, killclient, movemouse, quit, resizemouse, setlayout,
--  setmfact, spawn, tag, tagmon, togglebar, togglefloating,
--  toggletag, toggleview, view, zoom). Each has the Dwm_Types.Key_Func
--  signature so it can be stored directly in a Key/Button binding.
package Dwm_Actions is

   procedure Focus_Mon (A : Dwm_Types.Arg);
   procedure Focus_Stack (A : Dwm_Types.Arg);
   procedure Inc_Nmaster (A : Dwm_Types.Arg);
   procedure Kill_Client (A : Dwm_Types.Arg);
   procedure Move_Mouse (A : Dwm_Types.Arg);
   procedure Quit (A : Dwm_Types.Arg);
   procedure Resize_Mouse (A : Dwm_Types.Arg);
   procedure Set_Layout (A : Dwm_Types.Arg);
   procedure Set_Mfact (A : Dwm_Types.Arg);
   procedure Spawn (A : Dwm_Types.Arg);
   procedure Tag (A : Dwm_Types.Arg);
   procedure Tag_Mon (A : Dwm_Types.Arg);
   procedure Toggle_Bar (A : Dwm_Types.Arg);
   procedure Toggle_Floating (A : Dwm_Types.Arg);
   procedure Toggle_Tag (A : Dwm_Types.Arg);
   procedure Toggle_View (A : Dwm_Types.Arg);
   procedure View (A : Dwm_Types.Arg);
   procedure Zoom (A : Dwm_Types.Arg);

end Dwm_Actions;
