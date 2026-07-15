with Dwm_Clients;
with Dwm_Monitors;
with Dwm_Types;
with Xlib_Thin;

--  Port of dwm.c's X event handlers (minus configurerequest/maprequest,
--  which live in Dwm_Clients, and expose, which lives in Dwm_Monitors
--  -- see their header comments for why) plus the `handler[]`
--  dispatch table used by Dwm_Main.Run.
package Dwm_Events is

   --  Handles a ButtonPress: figures out what was clicked (a tag, the
   --  layout symbol, the status text, a client's titlebar area, or a
   --  client window) and its Click_Kind, focusing the client/monitor
   --  under the pointer first if needed, then runs every matching
   --  binding in Dwm_State.Buttons (buttonpress()).
   procedure Button_Press (Event : access Xlib_Thin.XEvent);

   --  Handles a ClientMessage: applies a _NET_WM_STATE fullscreen
   --  toggle/set/unset, or marks the sender urgent if it requested
   --  _NET_ACTIVE_WINDOW while not already selected (clientmessage()).
   procedure Client_Message (Event : access Xlib_Thin.XEvent);

   --  Handles a ConfigureNotify on the root window: on an actual size
   --  change (or Dwm_Monitors.Update_Geom reporting one), resizes the
   --  drawing context and bars, resizes any fullscreen clients to
   --  match, and re-arranges (configurenotify()).
   procedure Configure_Notify (Event : access Xlib_Thin.XEvent);

   --  Handles a DestroyNotify: unmanages the destroyed window's client,
   --  if it was managed (destroynotify()).
   procedure Destroy_Notify (Event : access Xlib_Thin.XEvent);

   --  Handles an EnterNotify (pointer entered a window): switches the
   --  selected monitor if the pointer entered a different one, then
   --  focuses the client under the pointer (enternotify()). Ignores
   --  synthetic/inferior-detail crossings on non-root windows, per
   --  dwm's usual focus-follows-mouse filtering.
   procedure Enter_Notify (Event : access Xlib_Thin.XEvent);

   --  Handles a FocusIn on a window other than the selected client:
   --  re-asserts X input focus onto the selected client, working
   --  around clients that (mis)grab focus for themselves (focusin()).
   procedure Focus_In (Event : access Xlib_Thin.XEvent);

   --  Handles a KeyPress: translates the keycode to a keysym and runs
   --  every matching binding in Dwm_State.Keys (keypress()).
   procedure Key_Press (Event : access Xlib_Thin.XEvent);

   --  Handles a MappingNotify: refreshes Xlib's cached keyboard
   --  mapping and, if the keyboard mapping itself (not just modifiers)
   --  changed, re-grabs all keybindings (mappingnotify()).
   procedure Mapping_Notify (Event : access Xlib_Thin.XEvent);

   --  Handles a MotionNotify on the root window: switches the selected
   --  monitor when the pointer crosses into a different one
   --  (motionnotify()); this is what makes focus-follows-mouse work
   --  across monitor boundaries even with no window under the pointer.
   procedure Motion_Notify (Event : access Xlib_Thin.XEvent);

   --  Handles a PropertyNotify: reacts to the root window's name
   --  changing (refreshes the status text) or, for a managed client,
   --  to its transient-for/size-hints/WM_HINTS/name/window-type
   --  properties changing (propertynotify()).
   procedure Property_Notify (Event : access Xlib_Thin.XEvent);

   --  Handles an UnmapNotify: marks the client withdrawn if this was a
   --  synthetic unmap (the client is still there, just requested to be
   --  hidden), or unmanages it otherwise (unmapnotify()).
   procedure Unmap_Notify (Event : access Xlib_Thin.XEvent);

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
