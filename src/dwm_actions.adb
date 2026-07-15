with Ada.Strings;
with Interfaces.C;
with Interfaces.C.Strings;
with System;
with Config;
with Dwm_Bar;
with Dwm_Clients;
with Dwm_Monitors;
with Dwm_State;
with Dwm_Xutil;
with Util;
with Xlib_Thin;

package body Dwm_Actions is

   use type Xlib_Thin.C_Int;
   use type Xlib_Thin.C_UInt;
   use type Xlib_Thin.C_Mask;
   use type Xlib_Thin.XID;
   use type System.Address;
   use type Dwm_Types.Client_Access;
   use type Dwm_Types.Monitor_Access;
   use type Dwm_Types.Layout_Const_Access;
   use type Dwm_Types.Arrange_Func;
   use type Dwm_Types.Tag_Mask;
   use type Dwm_Types.Command_Access;

   Tagmask : constant Dwm_Types.Tag_Mask := 2 ** Config.Tags'Length - 1;

   --------------------------------------------------------------------
   --  fork/exec helpers for Spawn                                    --
   --------------------------------------------------------------------

   function C_Fork return Interfaces.C.int;
   pragma Import (C, C_Fork, "fork");

   function C_Setsid return Interfaces.C.int;
   pragma Import (C, C_Setsid, "setsid");

   function C_Close (Fd : Interfaces.C.int) return Interfaces.C.int;
   pragma Import (C, C_Close, "close");

   function C_Signal (Signum : Interfaces.C.int; Handler : System.Address) return System.Address;
   pragma Import (C, C_Signal, "signal");

   function C_Execvp
     (File : Interfaces.C.Strings.chars_ptr; Argv : System.Address) return Interfaces.C.int;
   pragma Import (C, C_Execvp, "execvp");

   SIGCHLD : constant Interfaces.C.int := 17;

   --------------------------------------------------------------------

   Mouse_Mask : constant Xlib_Thin.C_UInt :=
     Xlib_Thin.C_UInt (Xlib_Thin.ButtonPressMask) or Xlib_Thin.C_UInt (Xlib_Thin.ButtonReleaseMask)
       or Xlib_Thin.C_UInt (Xlib_Thin.PointerMotionMask);

   --------------------------------------------------------------------
   --  Subprogram bodies (alphabetical order; -gnatyo)                --
   --------------------------------------------------------------------

   procedure Focusmon (A : Dwm_Types.Arg) is
      M : Dwm_Types.Monitor_Access;
   begin
      if Dwm_State.Mons.Next = null then
         return;
      end if;
      M := Dwm_Monitors.Dirtomon (A.I);
      if M = Dwm_State.Selmon then
         return;
      end if;
      Dwm_Clients.Unfocus (Dwm_State.Selmon.Sel, False);
      Dwm_State.Selmon := M;
      Dwm_Clients.Focus (null);
   end Focusmon;

   procedure Focusstack (A : Dwm_Types.Arg) is
      C, I : Dwm_Types.Client_Access := null;
   begin
      if Dwm_State.Selmon.Sel = null
        or else (Dwm_State.Selmon.Sel.Isfullscreen and then Config.Lockfullscreen)
      then
         return;
      end if;
      if A.I > 0 then
         C := Dwm_State.Selmon.Sel.Next;
         while C /= null and then not Dwm_Types.Is_Visible (C) loop
            C := C.Next;
         end loop;
         if C = null then
            C := Dwm_State.Selmon.Clients;
            while C /= null and then not Dwm_Types.Is_Visible (C) loop
               C := C.Next;
            end loop;
         end if;
      else
         I := Dwm_State.Selmon.Clients;
         while I /= Dwm_State.Selmon.Sel loop
            if Dwm_Types.Is_Visible (I) then
               C := I;
            end if;
            I := I.Next;
         end loop;
         if C = null then
            while I /= null loop
               if Dwm_Types.Is_Visible (I) then
                  C := I;
               end if;
               I := I.Next;
            end loop;
         end if;
      end if;
      if C /= null then
         Dwm_Clients.Focus (C);
         Dwm_Clients.Restack (Dwm_State.Selmon);
      end if;
   end Focusstack;

   procedure Incnmaster (A : Dwm_Types.Arg) is
   begin
      Dwm_State.Selmon.Nmaster := Util.Max_Integer (Dwm_State.Selmon.Nmaster + A.I, 0);
      Dwm_Clients.Arrange (Dwm_State.Selmon);
   end Incnmaster;

   procedure Killclient (A : Dwm_Types.Arg) is
      pragma Unreferenced (A);
      Ignore : Xlib_Thin.C_Int;
      Ignore_Handler : Xlib_Thin.XErrorHandler;
      Ignore_Bool : Boolean;
   begin
      if Dwm_State.Selmon.Sel = null then
         return;
      end if;
      Ignore_Bool := Dwm_Clients.Sendevent (Dwm_State.Selmon.Sel, Dwm_State.Wmatom (Dwm_State.WM_Delete));
      if not Ignore_Bool then
         Ignore := Xlib_Thin.XGrabServer (Dwm_State.Dpy);
         Ignore_Handler := Xlib_Thin.XSetErrorHandler (Dwm_Clients.Xerrordummy'Access);
         Ignore := Xlib_Thin.XSetCloseDownMode (Dwm_State.Dpy, Xlib_Thin.DestroyAllMode);
         Ignore := Xlib_Thin.XKillClient (Dwm_State.Dpy, Dwm_State.Selmon.Sel.Win);
         Ignore := Xlib_Thin.XSync (Dwm_State.Dpy, 0);
         Ignore_Handler := Xlib_Thin.XSetErrorHandler (Dwm_Clients.Xerror'Access);
         Ignore := Xlib_Thin.XUngrabServer (Dwm_State.Dpy);
      end if;
   end Killclient;

   procedure Movemouse (A : Dwm_Types.Arg) is
      pragma Unreferenced (A);
      C : constant Dwm_Types.Client_Access := Dwm_State.Selmon.Sel;
      M : Dwm_Types.Monitor_Access;
      X, Y, Ocx, Ocy, Nx, Ny : Integer;
      Ev : aliased Xlib_Thin.XEvent;
      Any : Xlib_Thin.XAnyEvent with Address => Ev'Address;
      pragma Import (Ada, Any);
      Motion : Xlib_Thin.XMotionEvent with Address => Ev'Address;
      pragma Import (Ada, Motion);
      Lasttime : Xlib_Thin.Time_T := 0;
      Grab_Result : Xlib_Thin.C_Int;
      Ignore : Xlib_Thin.C_Int;
   begin
      if C = null or else C.Isfullscreen then
         return;
      end if;
      Dwm_Clients.Restack (Dwm_State.Selmon);
      Ocx := C.X;
      Ocy := C.Y;
      Grab_Result := Xlib_Thin.XGrabPointer
        (Dwm_State.Dpy, Dwm_State.Root, 0, Mouse_Mask, Xlib_Thin.GrabModeAsync, Xlib_Thin.GrabModeAsync,
         Xlib_Thin.None, Dwm_State.Cursors (Dwm_State.Cur_Move).Cursor, Xlib_Thin.Current_Time);
      if Grab_Result /= Xlib_Thin.GrabSuccess then
         return;
      end if;
      if not Dwm_Xutil.Getrootptr (X, Y) then
         return;
      end if;
      loop
         Ignore := Xlib_Thin.XMaskEvent
           (Dwm_State.Dpy,
            Xlib_Thin.C_Mask (Mouse_Mask) or Xlib_Thin.ExposureMask or Xlib_Thin.SubstructureRedirectMask,
            Ev'Access);
         case Any.Event_Type is
            when Xlib_Thin.ConfigureRequest =>
               Dwm_Clients.Configurerequest (Ev'Access);
            when Xlib_Thin.Expose =>
               Dwm_Monitors.Expose (Ev'Access);
            when Xlib_Thin.MapRequest =>
               Dwm_Clients.Maprequest (Ev'Access);
            when Xlib_Thin.MotionNotify =>
               if (Motion.Evt_Time - Lasttime) <= Xlib_Thin.Time_T (1000 / Config.Refreshrate) then
                  goto Continue_Loop;
               end if;
               Lasttime := Motion.Evt_Time;
               Nx := Ocx + (Integer (Motion.X) - X);
               Ny := Ocy + (Integer (Motion.Y) - Y);
               if abs (Dwm_State.Selmon.Wx - Nx) < Config.Snap then
                  Nx := Dwm_State.Selmon.Wx;
               elsif abs ((Dwm_State.Selmon.Wx + Dwm_State.Selmon.Ww) - (Nx + Dwm_Types.Width (C)))
                     < Config.Snap
               then
                  Nx := Dwm_State.Selmon.Wx + Dwm_State.Selmon.Ww - Dwm_Types.Width (C);
               end if;
               if abs (Dwm_State.Selmon.Wy - Ny) < Config.Snap then
                  Ny := Dwm_State.Selmon.Wy;
               elsif abs ((Dwm_State.Selmon.Wy + Dwm_State.Selmon.Wh) - (Ny + Dwm_Types.Height (C)))
                     < Config.Snap
               then
                  Ny := Dwm_State.Selmon.Wy + Dwm_State.Selmon.Wh - Dwm_Types.Height (C);
               end if;
               if not C.Isfloating and then Dwm_State.Selmon.Lt (Dwm_State.Selmon.Sellt).Arrange /= null
                 and then (abs (Nx - C.X) > Config.Snap or else abs (Ny - C.Y) > Config.Snap)
               then
                  Togglefloating (Dwm_Types.No_Arg);
               end if;
               if Dwm_State.Selmon.Lt (Dwm_State.Selmon.Sellt).Arrange = null or else C.Isfloating then
                  Dwm_Clients.Resize (C, Nx, Ny, C.W, C.H, True);
               end if;
            when others =>
               null;
         end case;
         <<Continue_Loop>>
         exit when Any.Event_Type = Xlib_Thin.ButtonRelease;
      end loop;
      Ignore := Xlib_Thin.XUngrabPointer (Dwm_State.Dpy, Xlib_Thin.Current_Time);
      M := Dwm_Monitors.Recttomon (C.X, C.Y, C.W, C.H);
      if M /= Dwm_State.Selmon then
         Dwm_Clients.Sendmon (C, M);
         Dwm_State.Selmon := M;
         Dwm_Clients.Focus (null);
      end if;
   end Movemouse;

   procedure Quit (A : Dwm_Types.Arg) is
      pragma Unreferenced (A);
   begin
      Dwm_State.Running := False;
   end Quit;

   procedure Resizemouse (A : Dwm_Types.Arg) is
      pragma Unreferenced (A);
      C : constant Dwm_Types.Client_Access := Dwm_State.Selmon.Sel;
      M : Dwm_Types.Monitor_Access;
      Ocx, Ocy, Nw, Nh : Integer;
      Ev : aliased Xlib_Thin.XEvent;
      Any : Xlib_Thin.XAnyEvent with Address => Ev'Address;
      pragma Import (Ada, Any);
      Motion : Xlib_Thin.XMotionEvent with Address => Ev'Address;
      pragma Import (Ada, Motion);
      Lasttime : Xlib_Thin.Time_T := 0;
      Grab_Result : Xlib_Thin.C_Int;
      Ignore : Xlib_Thin.C_Int;
   begin
      if C = null or else C.Isfullscreen then
         return;
      end if;
      Dwm_Clients.Restack (Dwm_State.Selmon);
      Ocx := C.X;
      Ocy := C.Y;
      Grab_Result := Xlib_Thin.XGrabPointer
        (Dwm_State.Dpy, Dwm_State.Root, 0, Mouse_Mask, Xlib_Thin.GrabModeAsync, Xlib_Thin.GrabModeAsync,
         Xlib_Thin.None, Dwm_State.Cursors (Dwm_State.Cur_Resize).Cursor, Xlib_Thin.Current_Time);
      if Grab_Result /= Xlib_Thin.GrabSuccess then
         return;
      end if;
      Ignore := Xlib_Thin.XWarpPointer
        (Dwm_State.Dpy, Xlib_Thin.None, C.Win, 0, 0, 0, 0,
         Xlib_Thin.C_Int (C.W + C.Bw - 1), Xlib_Thin.C_Int (C.H + C.Bw - 1));
      loop
         Ignore := Xlib_Thin.XMaskEvent
           (Dwm_State.Dpy,
            Xlib_Thin.C_Mask (Mouse_Mask) or Xlib_Thin.ExposureMask or Xlib_Thin.SubstructureRedirectMask,
            Ev'Access);
         case Any.Event_Type is
            when Xlib_Thin.ConfigureRequest =>
               Dwm_Clients.Configurerequest (Ev'Access);
            when Xlib_Thin.Expose =>
               Dwm_Monitors.Expose (Ev'Access);
            when Xlib_Thin.MapRequest =>
               Dwm_Clients.Maprequest (Ev'Access);
            when Xlib_Thin.MotionNotify =>
               if (Motion.Evt_Time - Lasttime) <= Xlib_Thin.Time_T (1000 / Config.Refreshrate) then
                  goto Continue_Loop;
               end if;
               Lasttime := Motion.Evt_Time;
               Nw := Util.Max_Integer (Integer (Motion.X) - Ocx - 2 * C.Bw + 1, 1);
               Nh := Util.Max_Integer (Integer (Motion.Y) - Ocy - 2 * C.Bw + 1, 1);
               if C.Mon.Wx + Nw >= Dwm_State.Selmon.Wx and then C.Mon.Wx + Nw <= Dwm_State.Selmon.Wx
                    + Dwm_State.Selmon.Ww
                 and then C.Mon.Wy + Nh >= Dwm_State.Selmon.Wy
                 and then C.Mon.Wy + Nh <= Dwm_State.Selmon.Wy + Dwm_State.Selmon.Wh
               then
                  if not C.Isfloating and then Dwm_State.Selmon.Lt (Dwm_State.Selmon.Sellt).Arrange /= null
                    and then (abs (Nw - C.W) > Config.Snap or else abs (Nh - C.H) > Config.Snap)
                  then
                     Togglefloating (Dwm_Types.No_Arg);
                  end if;
               end if;
               if Dwm_State.Selmon.Lt (Dwm_State.Selmon.Sellt).Arrange = null or else C.Isfloating then
                  Dwm_Clients.Resize (C, C.X, C.Y, Nw, Nh, True);
               end if;
            when others =>
               null;
         end case;
         <<Continue_Loop>>
         exit when Any.Event_Type = Xlib_Thin.ButtonRelease;
      end loop;
      Ignore := Xlib_Thin.XWarpPointer
        (Dwm_State.Dpy, Xlib_Thin.None, C.Win, 0, 0, 0, 0,
         Xlib_Thin.C_Int (C.W + C.Bw - 1), Xlib_Thin.C_Int (C.H + C.Bw - 1));
      Ignore := Xlib_Thin.XUngrabPointer (Dwm_State.Dpy, Xlib_Thin.Current_Time);
      while Xlib_Thin.XCheckMaskEvent (Dwm_State.Dpy, Xlib_Thin.EnterWindowMask, Ev'Access) /= 0 loop
         null;
      end loop;
      M := Dwm_Monitors.Recttomon (C.X, C.Y, C.W, C.H);
      if M /= Dwm_State.Selmon then
         Dwm_Clients.Sendmon (C, M);
         Dwm_State.Selmon := M;
         Dwm_Clients.Focus (null);
      end if;
   end Resizemouse;

   procedure Setlayout (A : Dwm_Types.Arg) is
   begin
      if A.Lt = null or else A.Lt /= Dwm_State.Selmon.Lt (Dwm_State.Selmon.Sellt) then
         Dwm_State.Selmon.Sellt := 1 - Dwm_State.Selmon.Sellt;
      end if;
      if A.Lt /= null then
         Dwm_State.Selmon.Lt (Dwm_State.Selmon.Sellt) := A.Lt;
      end if;
      Dwm_State.Selmon.Ltsymbol := Dwm_Types.Lt_Symbol_Strings.To_Bounded_String
        (Dwm_State.Selmon.Lt (Dwm_State.Selmon.Sellt).Symbol.all, Ada.Strings.Right);
      if Dwm_State.Selmon.Sel /= null then
         Dwm_Clients.Arrange (Dwm_State.Selmon);
      else
         Dwm_Bar.Drawbar (Dwm_State.Selmon);
      end if;
   end Setlayout;

   procedure Setmfact (A : Dwm_Types.Arg) is
      F : Float;
   begin
      if Dwm_State.Selmon.Lt (Dwm_State.Selmon.Sellt).Arrange = null then
         return;
      end if;
      F := (if A.F < 1.0 then A.F + Dwm_State.Selmon.Mfact else A.F - 1.0);
      if F < 0.05 or else F > 0.95 then
         return;
      end if;
      Dwm_State.Selmon.Mfact := F;
      Dwm_Clients.Arrange (Dwm_State.Selmon);
   end Setmfact;

   procedure Spawn (A : Dwm_Types.Arg) is
      Pid : Interfaces.C.int;
      Ignore : Interfaces.C.int;
      Ignore_Addr : System.Address;
   begin
      if A.Cmd = Config.Dmenu_Cmd'Access then
         Config.Dmenu_Mon_Buf (1) := Character'Val (Character'Pos ('0') + Dwm_State.Selmon.Num);
      end if;
      Pid := C_Fork;
      if Pid = 0 then
         if Dwm_State.Dpy /= System.Null_Address then
            Ignore := C_Close (Xlib_Thin.XConnectionNumber (Dwm_State.Dpy));
         end if;
         Ignore := C_Setsid;
         Ignore_Addr := C_Signal (SIGCHLD, System.Null_Address);
         declare
            N : constant Natural := A.Cmd'Length;
            Argv : array (0 .. N) of aliased Interfaces.C.Strings.chars_ptr;
         begin
            for I in A.Cmd'Range loop
               Argv (I - A.Cmd'First) := Interfaces.C.Strings.New_String (A.Cmd (I).all);
            end loop;
            Argv (N) := Interfaces.C.Strings.Null_Ptr;
            Ignore := C_Execvp (Argv (0), Argv (0)'Address);
         end;
         Util.Die ("dwm: execvp '" & A.Cmd (A.Cmd'First).all & "' failed:", With_Errno => True);
      end if;
   end Spawn;

   procedure Tag (A : Dwm_Types.Arg) is
   begin
      if Dwm_State.Selmon.Sel /= null and then (A.Ui and Tagmask) /= 0 then
         Dwm_State.Selmon.Sel.Tags := A.Ui and Tagmask;
         Dwm_Clients.Focus (null);
         Dwm_Clients.Arrange (Dwm_State.Selmon);
      end if;
   end Tag;

   procedure Tagmon (A : Dwm_Types.Arg) is
   begin
      if Dwm_State.Selmon.Sel = null or else Dwm_State.Mons.Next = null then
         return;
      end if;
      Dwm_Clients.Sendmon (Dwm_State.Selmon.Sel, Dwm_Monitors.Dirtomon (A.I));
   end Tagmon;

   procedure Togglebar (A : Dwm_Types.Arg) is
      pragma Unreferenced (A);
      Ignore : Xlib_Thin.C_Int;
   begin
      Dwm_State.Selmon.Showbar := not Dwm_State.Selmon.Showbar;
      Dwm_Monitors.Updatebarpos (Dwm_State.Selmon);
      Ignore := Xlib_Thin.XMoveResizeWindow
        (Dwm_State.Dpy, Dwm_State.Selmon.Barwin, Xlib_Thin.C_Int (Dwm_State.Selmon.Wx),
         Xlib_Thin.C_Int (Dwm_State.Selmon.By), Xlib_Thin.C_UInt (Dwm_State.Selmon.Ww),
         Xlib_Thin.C_UInt (Dwm_State.Bh));
      Dwm_Clients.Arrange (Dwm_State.Selmon);
   end Togglebar;

   procedure Togglefloating (A : Dwm_Types.Arg) is
      pragma Unreferenced (A);
   begin
      if Dwm_State.Selmon.Sel = null then
         return;
      end if;
      if Dwm_State.Selmon.Sel.Isfullscreen then
         return;
      end if;
      Dwm_State.Selmon.Sel.Isfloating :=
        not Dwm_State.Selmon.Sel.Isfloating or else Dwm_State.Selmon.Sel.Isfixed;
      if Dwm_State.Selmon.Sel.Isfloating then
         Dwm_Clients.Resize
           (Dwm_State.Selmon.Sel, Dwm_State.Selmon.Sel.X, Dwm_State.Selmon.Sel.Y,
            Dwm_State.Selmon.Sel.W, Dwm_State.Selmon.Sel.H, False);
      end if;
      Dwm_Clients.Arrange (Dwm_State.Selmon);
   end Togglefloating;

   procedure Toggletag (A : Dwm_Types.Arg) is
      Newtags : Dwm_Types.Tag_Mask;
   begin
      if Dwm_State.Selmon.Sel = null then
         return;
      end if;
      Newtags := Dwm_State.Selmon.Sel.Tags xor (A.Ui and Tagmask);
      if Newtags /= 0 then
         Dwm_State.Selmon.Sel.Tags := Newtags;
         Dwm_Clients.Focus (null);
         Dwm_Clients.Arrange (Dwm_State.Selmon);
      end if;
   end Toggletag;

   procedure Toggleview (A : Dwm_Types.Arg) is
      Newtagset : constant Dwm_Types.Tag_Mask :=
        Dwm_State.Selmon.Tagset (Dwm_State.Selmon.Seltags) xor (A.Ui and Tagmask);
   begin
      if Newtagset /= 0 then
         Dwm_State.Selmon.Tagset (Dwm_State.Selmon.Seltags) := Newtagset;
         Dwm_Clients.Focus (null);
         Dwm_Clients.Arrange (Dwm_State.Selmon);
      end if;
   end Toggleview;

   procedure View (A : Dwm_Types.Arg) is
   begin
      if (A.Ui and Tagmask) = Dwm_State.Selmon.Tagset (Dwm_State.Selmon.Seltags) then
         return;
      end if;
      Dwm_State.Selmon.Seltags := 1 - Dwm_State.Selmon.Seltags;
      if (A.Ui and Tagmask) /= 0 then
         Dwm_State.Selmon.Tagset (Dwm_State.Selmon.Seltags) := A.Ui and Tagmask;
      end if;
      Dwm_Clients.Focus (null);
      Dwm_Clients.Arrange (Dwm_State.Selmon);
   end View;

   procedure Zoom (A : Dwm_Types.Arg) is
      pragma Unreferenced (A);
      C : Dwm_Types.Client_Access := Dwm_State.Selmon.Sel;
   begin
      if Dwm_State.Selmon.Lt (Dwm_State.Selmon.Sellt).Arrange = null or else C = null or else C.Isfloating
      then
         return;
      end if;
      if C = Dwm_Clients.Nexttiled (Dwm_State.Selmon.Clients) then
         C := Dwm_Clients.Nexttiled (C.Next);
         if C = null then
            return;
         end if;
      end if;
      Dwm_Clients.Pop (C);
   end Zoom;

end Dwm_Actions;
