with Dwm_Clients;
with Dwm_Monitors;
with Dwm_Types;
with Xlib_Thin;

--  Port of dwm.c's X event handlers (minus configurerequest/maprequest,
--  which live in Dwm_Clients, and expose, which lives in Dwm_Monitors
--  -- see their header comments for why) plus the `handler[]`
--  dispatch table used by Dwm_Main.Run.
package Dwm_Events is

   procedure Buttonpress (Ev : access Xlib_Thin.XEvent);
   procedure Clientmessage (Ev : access Xlib_Thin.XEvent);
   procedure Configurenotify (Ev : access Xlib_Thin.XEvent);
   procedure Destroynotify (Ev : access Xlib_Thin.XEvent);
   procedure Enternotify (Ev : access Xlib_Thin.XEvent);
   procedure Focusin (Ev : access Xlib_Thin.XEvent);
   procedure Keypress (Ev : access Xlib_Thin.XEvent);
   procedure Mappingnotify (Ev : access Xlib_Thin.XEvent);
   procedure Motionnotify (Ev : access Xlib_Thin.XEvent);
   procedure Propertynotify (Ev : access Xlib_Thin.XEvent);
   procedure Unmapnotify (Ev : access Xlib_Thin.XEvent);

   --  Dispatch table indexed by X event type (dwm.c's handler[LASTEvent]);
   --  entries for event types dwm doesn't handle are null.
   type Handler_Table is array (0 .. Xlib_Thin.LASTEvent - 1) of Dwm_Types.Event_Handler;

   Handler : constant Handler_Table :=
     (Xlib_Thin.ButtonPress => Buttonpress'Access,
      Xlib_Thin.ClientMessage => Clientmessage'Access,
      Xlib_Thin.ConfigureRequest => Dwm_Clients.Configurerequest'Access,
      Xlib_Thin.ConfigureNotify => Configurenotify'Access,
      Xlib_Thin.DestroyNotify => Destroynotify'Access,
      Xlib_Thin.EnterNotify => Enternotify'Access,
      Xlib_Thin.Expose => Dwm_Monitors.Expose'Access,
      Xlib_Thin.FocusIn => Focusin'Access,
      Xlib_Thin.KeyPress => Keypress'Access,
      Xlib_Thin.MappingNotify => Mappingnotify'Access,
      Xlib_Thin.MapRequest => Dwm_Clients.Maprequest'Access,
      Xlib_Thin.MotionNotify => Motionnotify'Access,
      Xlib_Thin.PropertyNotify => Propertynotify'Access,
      Xlib_Thin.UnmapNotify => Unmapnotify'Access,
      others => null);

end Dwm_Events;
