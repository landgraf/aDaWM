with Dwm_Types;

--  Port of the Arg-taking user commands from dwm.c -- the functions
--  bound to keys/buttons in Dwm_Bindings (focusmon, focusstack,
--  incnmaster, killclient, movemouse, quit, resizemouse, setlayout,
--  setmfact, spawn, tag, tagmon, togglebar, togglefloating,
--  toggletag, toggleview, view, zoom). Each has the Dwm_Types.Key_Func
--  signature so it can be stored directly in a Key/Button binding.
package Dwm_Actions is

   procedure Focusmon (A : Dwm_Types.Arg);
   procedure Focusstack (A : Dwm_Types.Arg);
   procedure Incnmaster (A : Dwm_Types.Arg);
   procedure Killclient (A : Dwm_Types.Arg);
   procedure Movemouse (A : Dwm_Types.Arg);
   procedure Quit (A : Dwm_Types.Arg);
   procedure Resizemouse (A : Dwm_Types.Arg);
   procedure Setlayout (A : Dwm_Types.Arg);
   procedure Setmfact (A : Dwm_Types.Arg);
   procedure Spawn (A : Dwm_Types.Arg);
   procedure Tag (A : Dwm_Types.Arg);
   procedure Tagmon (A : Dwm_Types.Arg);
   procedure Togglebar (A : Dwm_Types.Arg);
   procedure Togglefloating (A : Dwm_Types.Arg);
   procedure Toggletag (A : Dwm_Types.Arg);
   procedure Toggleview (A : Dwm_Types.Arg);
   procedure View (A : Dwm_Types.Arg);
   procedure Zoom (A : Dwm_Types.Arg);

end Dwm_Actions;
