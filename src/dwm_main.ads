--  Port of dwm.c's checkotherwm/setup/scan/run/cleanup and main().
package Dwm_Main is

   --  Verifies no other window manager already owns
   --  SubstructureRedirect on the root window, dying via
   --  Dwm_Clients.X_Error_Start if one does (checkotherwm()).
   procedure Check_Other_Wm;

   --  One-time startup: reaps inherited zombies, creates the drawing
   --  context and loads the configured fonts, runs the first
   --  Dwm_Monitors.Update_Geom, interns the EWMH/ICCCM atoms this
   --  window manager uses, creates cursors and allocates the
   --  configured color schemes, creates the bars, sets up the EWMH
   --  supporting-WM-check window and root window properties/event
   --  mask, and grabs the configured keybindings (setup()).
   procedure Setup;

   --  Adopts every pre-existing top-level window that is already
   --  mapped or iconic at startup, transient windows last so their
   --  parent is already managed (scan()).
   procedure Scan;

   --  The main event loop: repeatedly fetches the next X event and
   --  dispatches it through the Handler table until
   --  Dwm_State.Running goes False (run()).
   procedure Run;

   --  Shutdown: unmanages every client on every monitor, ungrabs all
   --  keys, tears down every monitor/cursor/color scheme and the
   --  drawing context, and clears _NET_ACTIVE_WINDOW (cleanup()).
   procedure Cleanup;

   --  The dwm executable's entry point (mirrors C's main()); called
   --  from src/main.adb.
   procedure Main;

end Dwm_Main;
