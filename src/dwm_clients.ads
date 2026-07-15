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
--  compile time, whereas Dwm_Layouts genuinely needs Next_Tiled/Resize
--  from here. Keeping arrange on this side of the boundary keeps the
--  dependency one-directional (Dwm_Layouts -> Dwm_Clients).
package Dwm_Clients is

   procedure Apply_Rules (C : Dwm_Types.Client_Access);

   function Apply_Size_Hints
     (C : Dwm_Types.Client_Access; X, Y, W, H : in out Integer; Interact : Boolean) return Boolean;

   procedure Arrange (M : Dwm_Types.Monitor_Access);  --  M = null means "all monitors"
   procedure Arrange_Mon (M : Dwm_Types.Monitor_Access);

   procedure Attach (C : Dwm_Types.Client_Access);
   procedure Attach_Stack (C : Dwm_Types.Client_Access);
   procedure Detach (C : Dwm_Types.Client_Access);
   procedure Detach_Stack (C : Dwm_Types.Client_Access);

   procedure Configure (C : Dwm_Types.Client_Access);

   procedure Focus (C : Dwm_Types.Client_Access);
   procedure Unfocus (C : Dwm_Types.Client_Access; Clear_Focus : Boolean);
   procedure Set_Focus (C : Dwm_Types.Client_Access);
   procedure Grab_Buttons (C : Dwm_Types.Client_Access; Focused : Boolean);
   procedure Grab_Keys;
   procedure Update_Num_Lock_Mask;

   procedure Manage (Win : Xlib_Thin.Window; Wa : Xlib_Thin.XWindowAttributes);
   procedure Unmanage (C : Dwm_Types.Client_Access; Destroyed : Boolean);

   --  configurerequest/maprequest event handlers. They live here (not
   --  Dwm_Events) because Dwm_Actions.Move_Mouse/Resize_Mouse must pump
   --  them (along with Dwm_Monitors.Expose) during the drag loop, and
   --  Dwm_Events itself depends on Dwm_Clients already, so keeping
   --  them here lets both call in without Dwm_Actions needing
   --  Dwm_Events (which would cycle back through Dwm_Bindings).
   procedure Configure_Request (Ev : access Xlib_Thin.XEvent);
   procedure Map_Request (Ev : access Xlib_Thin.XEvent);

   --  X error handlers. xerror is dwm's permanent handler (installed by
   --  Dwm_Main once checkotherwm succeeds); xerrordummy/xerrorstart are
   --  swapped in temporarily around operations expected to race
   --  (killclient, unmanage) or during the other-WM startup probe.
   --  They live here (not Dwm_Main) because Dwm_Clients itself needs to
   --  install xerrordummy around unmanage()'s teardown.
   function X_Error (Disp : Xlib_Thin.Display; Event : access Xlib_Thin.XErrorEvent) return Xlib_Thin.C_Int
     with Convention => C;
   function X_Error_Dummy
     (Disp : Xlib_Thin.Display; Event : access Xlib_Thin.XErrorEvent) return Xlib_Thin.C_Int
     with Convention => C;
   function X_Error_Start
     (Disp : Xlib_Thin.Display; Event : access Xlib_Thin.XErrorEvent) return Xlib_Thin.C_Int
     with Convention => C;

   function Next_Tiled (C : Dwm_Types.Client_Access) return Dwm_Types.Client_Access;
   procedure Pop (C : Dwm_Types.Client_Access);

   procedure Resize (C : Dwm_Types.Client_Access; X, Y, W, H : Integer; Interact : Boolean);
   procedure Resize_Client (C : Dwm_Types.Client_Access; X, Y, W, H : Integer);
   procedure Restack (M : Dwm_Types.Monitor_Access);

   procedure Send_Mon (C : Dwm_Types.Client_Access; M : Dwm_Types.Monitor_Access);
   procedure Set_Client_State (C : Dwm_Types.Client_Access; State : Long_Integer);
   procedure Set_Full_Screen (C : Dwm_Types.Client_Access; Fullscreen : Boolean);
   procedure Set_Urgent (C : Dwm_Types.Client_Access; Urg : Boolean);
   procedure Show_Hide (C : Dwm_Types.Client_Access);

   function Send_Event (C : Dwm_Types.Client_Access; Proto : Xlib_Thin.Atom) return Boolean;

   procedure Update_Client_List;
   procedure Update_Size_Hints (C : Dwm_Types.Client_Access);
   procedure Update_Title (C : Dwm_Types.Client_Access);
   procedure Update_Window_Type (C : Dwm_Types.Client_Access);
   procedure Update_Wm_Hints (C : Dwm_Types.Client_Access);

   function Win_To_Client (Win : Xlib_Thin.Window) return Dwm_Types.Client_Access;

end Dwm_Clients;
