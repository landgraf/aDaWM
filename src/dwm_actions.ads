with Dwm_Types;

--  Port of the Arg-taking user commands from dwm.c -- the functions
--  bound to keys/buttons in Dwm_Bindings (focusmon, focusstack,
--  incnmaster, killclient, movemouse, quit, resizemouse, setlayout,
--  setmfact, spawn, tag, tagmon, togglebar, togglefloating,
--  toggletag, toggleview, view, zoom). Each has the Dwm_Types.Key_Func
--  signature so it can be stored directly in a Key/Button binding.
package Dwm_Actions is

   --  Selects the monitor A.I steps away from the current one
   --  (Dwm_Monitors.Dir_To_Mon) and focuses it (focusmon()). No-op if
   --  there is only one monitor.
   procedure Focus_Mon (A : Dwm_Types.Arg);

   --  Focuses the next (A.I > 0) or previous visible client in the
   --  selected monitor's client list, wrapping around (focusstack()).
   --  No-op if the selected client is fullscreen and Config.Lock_Full_Screen.
   procedure Focus_Stack (A : Dwm_Types.Arg);

   --  Adds A.I to the selected monitor's master-area client count,
   --  floored at 0, and re-arranges (incnmaster()).
   procedure Inc_Nmaster (A : Dwm_Types.Arg);

   --  Closes the selected client: politely, via WM_DELETE_WINDOW if
   --  the client supports it, otherwise forcibly via XKillClient
   --  (killclient()). A is unused.
   procedure Kill_Client (A : Dwm_Types.Arg);

   --  Interactively drags the selected client with the pointer until
   --  button release, snapping to screen edges within Config.Snap
   --  pixels and auto-floating a tiled client that's dragged more than
   --  that far (movemouse()). A is unused.
   procedure Move_Mouse (A : Dwm_Types.Arg);

   --  Stops the main event loop, causing Dwm_Main.Run to return and
   --  Cleanup to run (quit()). A is unused.
   procedure Quit (A : Dwm_Types.Arg);

   --  Interactively resizes the selected client from its bottom-right
   --  corner with the pointer until button release, with the same
   --  snap-to-floating behavior as Move_Mouse (resizemouse()). A is
   --  unused.
   procedure Resize_Mouse (A : Dwm_Types.Arg);

   --  Switches the selected monitor to layout A.Lt (or toggles back to
   --  the previously active one, if A.Lt is null or already active)
   --  and re-arranges (setlayout()).
   procedure Set_Layout (A : Dwm_Types.Arg);

   --  Adjusts the selected monitor's master-area size factor by A.F
   --  (or sets it absolutely, if A.F >= 1.0), clamped to
   --  [0.05, 0.95], and re-arranges (setmfact()). No-op under a
   --  non-tiling layout.
   procedure Set_Mfact (A : Dwm_Types.Arg);

   --  Forks and execs the command in A.Cmd (e.g. Config.Dmenu_Cmd/
   --  Term_Cmd), detaching it from dwm's process group first (spawn()).
   --  If A.Cmd is Config.Dmenu_Cmd specifically, patches its "-m"
   --  argument to the selected monitor's number first, matching
   --  dwm.c's dmenumon[] hack.
   procedure Spawn (A : Dwm_Types.Arg);

   --  Moves the selected client to exactly the tag set in A.Ui
   --  (masked to the configured tag count) and re-arranges (tag()).
   --  No-op if A.Ui has no bits in the valid tag range.
   procedure Tag (A : Dwm_Types.Arg);

   --  Moves the selected client to the monitor A.I steps away
   --  (Dwm_Monitors.Dir_To_Mon) via Dwm_Clients.Send_Mon (tagmon()).
   --  No-op if there is only one monitor.
   procedure Tag_Mon (A : Dwm_Types.Arg);

   --  Toggles whether the selected monitor's bar is shown and
   --  re-arranges (togglebar()). A is unused.
   procedure Toggle_Bar (A : Dwm_Types.Arg);

   --  Toggles the selected client between floating and tiled (unless
   --  it is fullscreen or size-fixed) and re-arranges
   --  (togglefloating()). A is unused.
   procedure Toggle_Floating (A : Dwm_Types.Arg);

   --  XORs the tags in A.Ui into the selected client's tag set (moving
   --  it onto/off those tags) and re-arranges, unless that would leave
   --  it with no tags at all (toggletag()).
   procedure Toggle_Tag (A : Dwm_Types.Arg);

   --  XORs the tags in A.Ui into the selected monitor's viewed tag
   --  set and re-arranges, unless that would leave nothing visible
   --  (toggleview()).
   procedure Toggle_View (A : Dwm_Types.Arg);

   --  Switches the selected monitor to view exactly the tags in A.Ui
   --  (or just re-selects the alternate tag-set slot, if A.Ui has no
   --  valid tag bits) and re-arranges (view()).
   procedure View (A : Dwm_Types.Arg);

   --  Promotes the selected tiled client to the master area: if it's
   --  already the first tiled client, promotes the next one instead
   --  (zoom()). No-op under a non-tiling layout or on a floating
   --  client. A is unused.
   procedure Zoom (A : Dwm_Types.Arg);

end Dwm_Actions;
