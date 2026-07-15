with Dwm_Clients;
with Dwm_Monitors;
with Dwm_Types;
with Xlib_Thin;

--  Port of dwm.c's X event handlers (minus configurerequest/maprequest,
--  which live in Dwm_Clients, and expose, which lives in Dwm_Monitors
--  -- see their header comments for why) plus the `handler[]`
--  dispatch table used by Dwm_Main.Run.
package Dwm_Events is

   procedure Button_Press (Ev : access Xlib_Thin.XEvent);
   procedure Client_Message (Ev : access Xlib_Thin.XEvent);
   procedure Configure_Notify (Ev : access Xlib_Thin.XEvent);
   procedure Destroy_Notify (Ev : access Xlib_Thin.XEvent);
   procedure Enter_Notify (Ev : access Xlib_Thin.XEvent);
   procedure Focus_In (Ev : access Xlib_Thin.XEvent);
   procedure Key_Press (Ev : access Xlib_Thin.XEvent);
   procedure Mapping_Notify (Ev : access Xlib_Thin.XEvent);
   procedure Motion_Notify (Ev : access Xlib_Thin.XEvent);
   procedure Property_Notify (Ev : access Xlib_Thin.XEvent);
   procedure Unmap_Notify (Ev : access Xlib_Thin.XEvent);

   --  Dispatch table indexed by X event type (dwm.c's handler[LASTEvent]);
   --  entries for event types dwm doesn't handle are null.
   type Handler_Table is array (0 .. Xlib_Thin.LASTEvent - 1) of Dwm_Types.Event_Handler;

   Handler : constant Handler_Table :=
     (Xlib_Thin.ButtonPress => Button_Press'Access,
      Xlib_Thin.ClientMessage => Client_Message'Access,
      Xlib_Thin.ConfigureRequest => Dwm_Clients.Configure_Request'Access,
      Xlib_Thin.ConfigureNotify => Configure_Notify'Access,
      Xlib_Thin.DestroyNotify => Destroy_Notify'Access,
      Xlib_Thin.EnterNotify => Enter_Notify'Access,
      Xlib_Thin.Expose => Dwm_Monitors.Expose'Access,
      Xlib_Thin.FocusIn => Focus_In'Access,
      Xlib_Thin.KeyPress => Key_Press'Access,
      Xlib_Thin.MappingNotify => Mapping_Notify'Access,
      Xlib_Thin.MapRequest => Dwm_Clients.Map_Request'Access,
      Xlib_Thin.MotionNotify => Motion_Notify'Access,
      Xlib_Thin.PropertyNotify => Property_Notify'Access,
      Xlib_Thin.UnmapNotify => Unmap_Notify'Access,
      others => null);

end Dwm_Events;
