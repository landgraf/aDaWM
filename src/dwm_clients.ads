with Dwm_Types;
with Xlib_Thin;

--  Port of the client-lifecycle and arrangement mechanics from dwm.c:
--  applyrules/applysizehints, attach/detach(stack), configure, focus/
--  unfocus, manage/unmanage, resize(client), restack, arrange(mon),
--  showhide, sendmon, plus the small getters (getstate lives in
--  Dwm_Xutil; wintoclient/updatetitle/... stay here since they are
--  Client-shaped). arrange/arrangemon live here too (not in
--  Dwm_Layouts) purely to break a dependency cycle: arrangemon() only
--  ever calls the layout through the function pointer stored in
--  Monitor.Layout, so it never needs to name Dwm_Layouts.Tile/Monocle at
--  compile time, whereas Dwm_Layouts genuinely needs Next_Tiled/Resize
--  from here. Keeping arrange on this side of the boundary keeps the
--  dependency one-directional (Dwm_Layouts -> Dwm_Clients).
package Dwm_Clients is

   use type Dwm_Types.Client_Access;
   use type Dwm_Types.Monitor_Access;

   --  Sets Client's floating flag, tags and monitor from the first
   --  entry in Config.Rules whose class/instance/title all match (or
   --  leaves the tags at the target monitor's current view if no rule
   --  matched anything) (applyrules()). Called once from Manage.
   procedure Apply_Rules (Client : in Dwm_Types.Client_Access);

   --  Result of Apply_Size_Hints: the clamped/rounded geometry, and
   --  whether it differs from Client's current geometry (i.e. whether
   --  Resize should actually apply it).
   type Size_Hint_Result is record
      Pos_X, Pos_Y, Width, Height : Integer;
      Changed : Boolean;
   end record;

   --  Clamps Pos_X, Pos_Y, Width, Height to fit Client's monitor (or
   --  the whole screen, if Interact) and, unless Client is
   --  unconstrained-resize-eligible, rounds Width/Height to Client's
   --  WM size-hint increments/aspect ratio/min/max (applysizehints()).
   --  Every managed Client always has a Monitor (Manage sets it before
   --  the Client is reachable from anywhere else), so the precondition
   --  holds at every real call site; Width/Height are unconditionally
   --  floored to at least 1 pixel internally before anything else, so
   --  the postcondition holds regardless of what was passed in.
   function Apply_Size_Hints
     (Client : in Dwm_Types.Client_Access; Pos_X, Pos_Y, Width, Height : in Integer;
      Interact : in Boolean) return Size_Hint_Result
     with
       Pre  => Client /= null and then Client.Monitor /= null,
       Post => Apply_Size_Hints'Result.Width >= 1 and then Apply_Size_Hints'Result.Height >= 1;

   --  Re-tiles Monitor (or every monitor, if Monitor is null): hides/
   --  shows clients for the current tag view via Show_Hide, then
   --  applies the active layout via Arrange_Mon and restacks
   --  (arrange()).
   procedure Arrange (Monitor : in Dwm_Types.Monitor_Access);  --  null means "all monitors"

   --  Copies the active layout's symbol into Monitor.Lt_Symbol and, if
   --  it has an arrange function, calls it to position Monitor's tiled
   --  clients (arrangemon()).
   procedure Arrange_Mon (Monitor : in Dwm_Types.Monitor_Access);

   --  Prepends Client to its monitor's client list (attach()).
   procedure Attach (Client : in Dwm_Types.Client_Access);

   --  Prepends Client to its monitor's focus-history stack
   --  (attachstack()).
   procedure Attach_Stack (Client : in Dwm_Types.Client_Access);

   --  Removes Client from its monitor's client list (detach()).
   procedure Detach (Client : in Dwm_Types.Client_Access);

   --  Removes Client from its monitor's focus-history stack, and if it
   --  was the selected client, re-selects the next visible client on
   --  the stack (detachstack()).
   procedure Detach_Stack (Client : in Dwm_Types.Client_Access);

   --  Sends Client a synthetic ConfigureNotify reporting its current
   --  geometry, as ICCCM requires whenever a window's size doesn't
   --  change but its border width or stacking might have
   --  (configure()).
   procedure Configure (Client : in Dwm_Types.Client_Access);

   --  Focuses Client (or, if Client is null or not visible, the
   --  topmost visible client on the selected monitor's stack, or no
   --  one): unfocuses the previous selection, raises Client to the
   --  front of the focus stack, updates its border color, and calls
   --  Set_Focus (focus()).
   procedure Focus (Client : in Dwm_Types.Client_Access);

   --  Un-highlights Client's border and, if Clear_Focus, moves X input
   --  focus back to the root window and clears _NET_ACTIVE_WINDOW
   --  (unfocus()).
   procedure Unfocus (Client : in Dwm_Types.Client_Access; Clear_Focus : in Boolean);

   --  Gives Client actual X input focus (unless it is never-focus) and
   --  updates _NET_ACTIVE_WINDOW and WM_TAKE_FOCUS (setfocus()).
   procedure Set_Focus (Client : in Dwm_Types.Client_Access);

   --  Re-grabs Client's mouse buttons per Dwm_State.Buttons: only
   --  modifier-qualified ones while Focused, or all of them
   --  (deferring to click-to-focus) otherwise (grabbuttons()).
   procedure Grab_Buttons (Client : in Dwm_Types.Client_Access; Focused : in Boolean);

   --  Re-grabs every keybinding in Dwm_State.Keys on the root window,
   --  once per Num_Lock_Mask/CapsLock modifier combination
   --  (grabkeys()). Called at startup and on keyboard remapping.
   procedure Grab_Keys;

   --  Recomputes Dwm_State.Num_Lock_Mask by asking the server which
   --  modifier bit Num_Lock is currently bound to (updatenumlockmask());
   --  keyboard layouts can rebind this, so Grab_Buttons/Grab_Keys call
   --  it before grabbing.
   procedure Update_Num_Lock_Mask;

   --  Starts managing a newly mapped (or, at startup scan, already
   --  mapped) window: builds its Client record, applies size hints/
   --  rules/transient-parent inheritance, reparents it into the
   --  layout, and maps and focuses it (manage()).
   procedure Manage (Window : in Xlib_Thin.Window; Attrs : in Xlib_Thin.XWindowAttributes);

   --  Stops managing Client: detaches it, restores its border width
   --  unless Destroyed (the X window is already gone), frees the
   --  Client record, and re-arranges its monitor (unmanage()).
   procedure Unmanage (Client : in Dwm_Types.Client_Access; Destroyed : in Boolean);

   --  configurerequest/maprequest event handlers. They live here (not
   --  Dwm_Events) because Dwm_Actions.Move_Mouse/Resize_Mouse must pump
   --  them (along with Dwm_Monitors.Expose) during the drag loop, and
   --  Dwm_Events itself depends on Dwm_Clients already, so keeping
   --  them here lets both call in without Dwm_Actions needing
   --  Dwm_Events (which would cycle back through Dwm_Bindings).

   --  Handles a ConfigureRequest: applies the client's requested
   --  geometry/border width if it is floating or unlayouted, or just
   --  re-asserts the current geometry otherwise; unmanaged windows are
   --  reconfigured as requested with no further logic (configurerequest()).
   procedure Configure_Request (Event : access Xlib_Thin.XEvent);

   --  Handles a MapRequest: manages the window unless it is
   --  override-redirect or already managed (maprequest()).
   procedure Map_Request (Event : access Xlib_Thin.XEvent);

   --  X error handlers. xerror is dwm's permanent handler (installed by
   --  Dwm_Main once checkotherwm succeeds); xerrordummy/xerrorstart are
   --  swapped in temporarily around operations expected to race
   --  (killclient, unmanage) or during the other-WM startup probe.
   --  They live here (not Dwm_Main) because Dwm_Clients itself needs to
   --  install xerrordummy around unmanage()'s teardown.

   --  dwm's permanent X error handler: silently ignores a short list
   --  of error/request-code combinations known to arise from benign
   --  races (e.g. configuring a window that just got destroyed), and
   --  otherwise delegates to Xlib's own default handler, which may
   --  terminate the process (xerror()).
   function X_Error
     (Display : in Xlib_Thin.Display; Event : access Xlib_Thin.XErrorEvent) return Xlib_Thin.C_Int
     with Convention => C;

   --  Ignores every error; installed around operations (like
   --  Kill_Client, Unmanage) where a race with the window disappearing
   --  is expected and not worth logging (xerrordummy()).
   function X_Error_Dummy
     (Display : in Xlib_Thin.Display; Event : access Xlib_Thin.XErrorEvent) return Xlib_Thin.C_Int
     with Convention => C;

   --  Installed only during Dwm_Main.Check_Other_Wm's startup probe;
   --  any error here means another window manager already owns
   --  SubstructureRedirect, so this dies with an explanatory message
   --  (xerrorstart()).
   function X_Error_Start
     (Display : in Xlib_Thin.Display; Event : access Xlib_Thin.XErrorEvent) return Xlib_Thin.C_Int
     with Convention => C;

   --  Returns Client, or the next client after it (following .Next)
   --  that is tiled (not floating) and visible on the current tag
   --  view, or null if none remain; used to walk just the tiled
   --  clients a layout should place (nexttiled()).
   function Next_Tiled (Client : in Dwm_Types.Client_Access) return Dwm_Types.Client_Access;

   --  Moves Client to the front of its monitor's client list, focuses
   --  it, and re-arranges (pop()); used by Dwm_Actions.Zoom to promote
   --  a client to the master area.
   procedure Pop (Client : in Dwm_Types.Client_Access);

   --  Applies size hints to Pos_X, Pos_Y, Width, Height via
   --  Apply_Size_Hints and, if they changed, resizes Client to the
   --  result (resize()).
   procedure Resize
     (Client : in Dwm_Types.Client_Access; Pos_X, Pos_Y, Width, Height : in Integer; Interact : in Boolean);

   --  Unconditionally moves/resizes Client's X window (and itself) to
   --  Pos_X, Pos_Y, Width, Height, with no size-hint adjustment, then
   --  sends a Configure notification (resizeclient()).
   procedure Resize_Client (Client : in Dwm_Types.Client_Access; Pos_X, Pos_Y, Width, Height : in Integer);

   --  Redraws Monitor's bar, raises its selected client if floating or
   --  unlayouted, and restacks the tiled clients directly below the
   --  bar window in focus-history order (restack()).
   procedure Restack (Monitor : in Dwm_Types.Monitor_Access);

   --  Moves Client to monitor Monitor: detaches and re-attaches it
   --  there with Monitor's current tag set, resizing it to fill
   --  Monitor if fullscreen, then refocuses and re-arranges
   --  (sendmon()). No-op if Client is already on Monitor.
   procedure Send_Mon (Client : in Dwm_Types.Client_Access; Monitor : in Dwm_Types.Monitor_Access);

   --  Sets Client's ICCCM WM_STATE property (e.g. NormalState,
   --  WithdrawnState) (setclientstate()).
   procedure Set_Client_State (Client : in Dwm_Types.Client_Access; State : in Long_Integer);

   --  Enters or leaves fullscreen: saves/restores Client's prior
   --  floating state, border width and geometry, resizes it to/from
   --  covering its whole monitor, and updates
   --  _NET_WM_STATE_FULLSCREEN (setfullscreen()). No-op if Client is
   --  already in the requested state.
   procedure Set_Full_Screen (Client : in Dwm_Types.Client_Access; Fullscreen : in Boolean);

   --  Sets Client's urgency flag and mirrors it into the window's
   --  ICCCM WM_HINTS urgency bit (seturgent()).
   procedure Set_Urgent (Client : in Dwm_Types.Client_Access; Urgent : in Boolean);

   --  Recursively shows (moving to its real position, and resizing if
   --  needed) every visible client in Client's focus-stack chain
   --  top-down, or hides (moving off-screen) every hidden one
   --  bottom-up (showhide()).
   procedure Show_Hide (Client : in Dwm_Types.Client_Access);

   --  Sends Client a ClientMessage invoking WM protocol Proto (e.g.
   --  WM_DELETE_WINDOW) if the client advertises support for it via
   --  WM_PROTOCOLS, setting Sent to whether it was (sendevent()). A
   --  procedure, not a function, since sending the ClientMessage is an
   --  X-server-visible effect, not just a computed value.
   procedure Send_Event (Client : in Dwm_Types.Client_Access; Proto : in Xlib_Thin.Atom; Sent : out Boolean);

   --  Rewrites the root window's _NET_CLIENT_LIST property from
   --  scratch to the windows of every currently managed client
   --  (updateclientlist()).
   procedure Update_Client_List;

   --  Re-reads Client's WM_NORMAL_HINTS (base/min/max size, resize
   --  increments, aspect ratio limits) from the X server and marks
   --  them valid; also recomputes whether Client counts as fixed-size
   --  (updatesizehints()).
   procedure Update_Size_Hints (Client : in Dwm_Types.Client_Access);

   --  Re-reads Client's title from _NET_WM_NAME, falling back to
   --  WM_NAME, or "broken" if neither is set (updatetitle()).
   procedure Update_Title (Client : in Dwm_Types.Client_Access);

   --  Reads Client's _NET_WM_STATE/_NET_WM_WINDOW_TYPE properties and,
   --  if they indicate fullscreen or a dialog window, applies that
   --  (updatewindowtype()).
   procedure Update_Window_Type (Client : in Dwm_Types.Client_Access);

   --  Re-reads Client's ICCCM WM_HINTS: clears urgency if Client is
   --  the selected client (assumed to have just gained the user's
   --  attention), otherwise mirrors the urgency bit onto Client, and
   --  updates Client's never-focus flag (updatewmhints()).
   procedure Update_Wm_Hints (Client : in Dwm_Types.Client_Access);

   --  Finds the managed Client owning window Window, searching every
   --  monitor's client list, or null if Window isn't managed
   --  (wintoclient()).
   function Win_To_Client (Window : in Xlib_Thin.Window) return Dwm_Types.Client_Access;

end Dwm_Clients;
