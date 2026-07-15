with Dwm_Types;
with Xlib_Thin;

--  Port of the monitor-geometry parts of dwm.c: createmon/cleanupmon,
--  updategeom (including the Xinerama path), recttomon/dirtomon/
--  wintomon, updatebarpos.
package Dwm_Monitors is

   function Create_Mon return Dwm_Types.Monitor_Access;
   procedure Cleanup_Mon (Mon : Dwm_Types.Monitor_Access);

   function Dir_To_Mon (Dir : Integer) return Dwm_Types.Monitor_Access;
   function Rect_To_Mon (X, Y, W, H : Integer) return Dwm_Types.Monitor_Access;
   function Win_To_Mon (Win : Xlib_Thin.Window) return Dwm_Types.Monitor_Access;

   procedure Update_Bar_Pos (M : Dwm_Types.Monitor_Access);

   --  Returns True if monitor geometry actually changed (dwm.c's
   --  "dirty" return value).
   function Update_Geom return Boolean;

   --  The expose event handler lives here (not Dwm_Events) because it
   --  needs Win_To_Mon, and Dwm_Actions.Move_Mouse/Resize_Mouse must pump
   --  it during their drag loops without depending on Dwm_Events.
   procedure Expose (Ev : access Xlib_Thin.XEvent);

end Dwm_Monitors;
