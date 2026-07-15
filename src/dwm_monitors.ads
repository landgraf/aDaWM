with Dwm_Types;
with Xlib_Thin;

--  Port of the monitor-geometry parts of dwm.c: createmon/cleanupmon,
--  updategeom (including the Xinerama path), recttomon/dirtomon/
--  wintomon, updatebarpos.
package Dwm_Monitors is

   --  Allocates a new Monitor with Config's default mfact/nmaster/
   --  showbar/topbar and the default layout pair from
   --  Dwm_State.Default_Layout (createmon()).
   function Create_Mon return Dwm_Types.Monitor_Access;

   --  Unlinks Monitor from Dwm_State.Monitors, destroys its bar
   --  window, and frees it (cleanupmon()). Callers are responsible
   --  for having already moved/removed its clients.
   procedure Cleanup_Mon (Monitor : in Dwm_Types.Monitor_Access);

   --  Returns the monitor after (Direction > 0) or before
   --  (Direction <= 0) the selected one in Dwm_State.Monitors' ring,
   --  wrapping around (dirtomon()); used by Dwm_Actions.Focus_Mon/
   --  Tag_Mon.
   function Dir_To_Mon (Direction : in Integer) return Dwm_Types.Monitor_Access;

   --  Returns the monitor whose work area overlaps the Pos_X, Pos_Y,
   --  Width, Height rectangle the most, defaulting to the selected
   --  monitor if none overlap it at all (recttomon()); used to figure
   --  out which monitor a client was dragged/resized onto.
   function Rect_To_Mon (Pos_X, Pos_Y, Width, Height : in Integer) return Dwm_Types.Monitor_Access;

   --  Returns the monitor owning window Window: the one under the
   --  pointer if Window is the root window, the one whose bar window
   --  Window is, the owning monitor of the client Window belongs to,
   --  or the selected monitor as a last resort (wintomon()).
   function Win_To_Mon (Window : in Xlib_Thin.Window) return Dwm_Types.Monitor_Access;

   --  Recomputes Monitor's window-area geometry (Work_X/Work_Y/
   --  Work_Width/Work_Height) and bar y-position from its screen
   --  geometry and Show_Bar/Top_Bar settings (updatebarpos()).
   procedure Update_Bar_Pos (Monitor : in Dwm_Types.Monitor_Access);

   --  Reconciles Dwm_State.Monitors with the current screen layout: if
   --  Xinerama is active, creates/updates/removes monitors to match
   --  its reported heads (migrating clients off any removed monitor);
   --  otherwise ensures a single monitor spans the whole screen
   --  (updategeom()). Sets Dirty True if anything actually changed, so
   --  callers know whether to re-arrange. A procedure, not a function,
   --  since it mutates Dwm_State's monitor list as its main effect.
   procedure Update_Geom (Dirty : out Boolean);

   --  Handles an Expose event: redraws the bar of the monitor owning
   --  the exposed window, once the last Expose in a batch arrives
   --  (expose()). Lives here (not Dwm_Events) because it needs
   --  Win_To_Mon, and Dwm_Actions.Move_Mouse/Resize_Mouse must pump it
   --  during their drag loops without depending on Dwm_Events.
   procedure Expose (Event : access Xlib_Thin.XEvent);

end Dwm_Monitors;
