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
--  Monitor.Lt, so it never needs to name Dwm_Layouts.Tile/Monocle at
--  compile time, whereas Dwm_Layouts genuinely needs Nexttiled/Resize
--  from here. Keeping arrange on this side of the boundary keeps the
--  dependency one-directional (Dwm_Layouts -> Dwm_Clients).
package Dwm_Clients is

   procedure Applyrules (C : Dwm_Types.Client_Access);

   function Applysizehints
     (C : Dwm_Types.Client_Access; X, Y, W, H : in out Integer; Interact : Boolean) return Boolean;

   procedure Arrange (M : Dwm_Types.Monitor_Access);  --  M = null means "all monitors"
   procedure Arrangemon (M : Dwm_Types.Monitor_Access);

   procedure Attach (C : Dwm_Types.Client_Access);
   procedure Attachstack (C : Dwm_Types.Client_Access);
   procedure Detach (C : Dwm_Types.Client_Access);
   procedure Detachstack (C : Dwm_Types.Client_Access);

   procedure Configure (C : Dwm_Types.Client_Access);

   procedure Focus (C : Dwm_Types.Client_Access);
   procedure Unfocus (C : Dwm_Types.Client_Access; Setfocus : Boolean);
   procedure Setfocus (C : Dwm_Types.Client_Access);
   procedure Grabbuttons (C : Dwm_Types.Client_Access; Focused : Boolean);
   procedure Grabkeys;
   procedure Updatenumlockmask;

   procedure Manage (Win : Xlib_Thin.Window; Wa : Xlib_Thin.XWindowAttributes);
   procedure Unmanage (C : Dwm_Types.Client_Access; Destroyed : Boolean);

   --  configurerequest/maprequest event handlers. They live here (not
   --  Dwm_Events) because Dwm_Actions.Movemouse/Resizemouse must pump
   --  them (along with Dwm_Monitors.Expose) during the drag loop, and
   --  Dwm_Events itself depends on Dwm_Clients already, so keeping
   --  them here lets both call in without Dwm_Actions needing
   --  Dwm_Events (which would cycle back through Dwm_Bindings).
   procedure Configurerequest (Ev : access Xlib_Thin.XEvent);
   procedure Maprequest (Ev : access Xlib_Thin.XEvent);

   --  X error handlers. xerror is dwm's permanent handler (installed by
   --  Dwm_Main once checkotherwm succeeds); xerrordummy/xerrorstart are
   --  swapped in temporarily around operations expected to race
   --  (killclient, unmanage) or during the other-WM startup probe.
   --  They live here (not Dwm_Main) because Dwm_Clients itself needs to
   --  install xerrordummy around unmanage()'s teardown.
   function Xerror (Disp : Xlib_Thin.Display; Event : access Xlib_Thin.XErrorEvent) return Xlib_Thin.C_Int
     with Convention => C;
   function Xerrordummy
     (Disp : Xlib_Thin.Display; Event : access Xlib_Thin.XErrorEvent) return Xlib_Thin.C_Int
     with Convention => C;
   function Xerrorstart
     (Disp : Xlib_Thin.Display; Event : access Xlib_Thin.XErrorEvent) return Xlib_Thin.C_Int
     with Convention => C;

   function Nexttiled (C : Dwm_Types.Client_Access) return Dwm_Types.Client_Access;
   procedure Pop (C : Dwm_Types.Client_Access);

   procedure Resize (C : Dwm_Types.Client_Access; X, Y, W, H : Integer; Interact : Boolean);
   procedure Resizeclient (C : Dwm_Types.Client_Access; X, Y, W, H : Integer);
   procedure Restack (M : Dwm_Types.Monitor_Access);

   procedure Sendmon (C : Dwm_Types.Client_Access; M : Dwm_Types.Monitor_Access);
   procedure Setclientstate (C : Dwm_Types.Client_Access; State : Long_Integer);
   procedure Setfullscreen (C : Dwm_Types.Client_Access; Fullscreen : Boolean);
   procedure Seturgent (C : Dwm_Types.Client_Access; Urg : Boolean);
   procedure Showhide (C : Dwm_Types.Client_Access);

   function Sendevent (C : Dwm_Types.Client_Access; Proto : Xlib_Thin.Atom) return Boolean;

   procedure Updateclientlist;
   procedure Updatesizehints (C : Dwm_Types.Client_Access);
   procedure Updatetitle (C : Dwm_Types.Client_Access);
   procedure Updatewindowtype (C : Dwm_Types.Client_Access);
   procedure Updatewmhints (C : Dwm_Types.Client_Access);

   function Wintoclient (Win : Xlib_Thin.Window) return Dwm_Types.Client_Access;

end Dwm_Clients;
