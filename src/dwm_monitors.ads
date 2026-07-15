with Dwm_Types;
with Xlib_Thin;

--  Port of the monitor-geometry parts of dwm.c: createmon/cleanupmon,
--  updategeom (including the Xinerama path), recttomon/dirtomon/
--  wintomon, updatebarpos.
package Dwm_Monitors is

   --  Allocates a new Monitor with Config's default mfact/nmaster/
   --  showbar/topbar and the default layout pair from
   --  Dwm_State.Default_Lt (createmon()).
   function Create_Mon return Dwm_Types.Monitor_Access;

   --  Unlinks Mon from Dwm_State.Mons, destroys its bar window, and
   --  frees it (cleanupmon()). Callers are responsible for having
   --  already moved/removed its clients.
   procedure Cleanup_Mon (Mon : Dwm_Types.Monitor_Access);

   --  Returns the monitor after (Dir > 0) or before (Dir <= 0) the
   --  selected one in Dwm_State.Mons' ring, wrapping around
   --  (dirtomon()); used by Dwm_Actions.Focus_Mon/Tag_Mon.
   function Dir_To_Mon (Dir : Integer) return Dwm_Types.Monitor_Access;

   --  Returns the monitor whose work area overlaps the X, Y, W, H
   --  rectangle the most, defaulting to the selected monitor if none
   --  overlap it at all (recttomon()); used to figure out which
   --  monitor a client was dragged/resized onto.
   function Rect_To_Mon (X, Y, W, H : Integer) return Dwm_Types.Monitor_Access;

   --  Returns the monitor owning window Win: the one under the
   --  pointer if Win is the root window, the one whose bar window Win
   --  is, the owning monitor of the client Win belongs to, or the
   --  selected monitor as a last resort (wintomon()).
   function Win_To_Mon (Win : Xlib_Thin.Window) return Dwm_Types.Monitor_Access;

   --  Recomputes M's window-area geometry (Wx/Wy/Ww/Wh) and bar
   --  y-position from its screen geometry and Showbar/Topbar settings
   --  (updatebarpos()).
   procedure Update_Bar_Pos (M : Dwm_Types.Monitor_Access);

   --  Reconciles Dwm_State.Mons with the current screen layout: if
   --  Xinerama is active, creates/updates/removes monitors to match
   --  its reported heads (migrating clients off any removed monitor);
   --  otherwise ensures a single monitor spans the whole screen
   --  (updategeom()). Returns True if anything actually changed --
   --  dwm.c's "dirty" -- so callers know whether to re-arrange.
   function Update_Geom return Boolean;

   --  Handles an Expose event: redraws the bar of the monitor owning
   --  the exposed window, once the last Expose in a batch arrives
   --  (expose()). Lives here (not Dwm_Events) because it needs
   --  Win_To_Mon, and Dwm_Actions.Move_Mouse/Resize_Mouse must pump it
   --  during their drag loops without depending on Dwm_Events.
   procedure Expose (Ev : access Xlib_Thin.XEvent);

end Dwm_Monitors;
