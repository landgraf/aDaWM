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

   procedure Focus_Mon (A : Dwm_Types.Arg) is
      M : Dwm_Types.Monitor_Access;
   begin
      if Dwm_State.Mons.Next = null then
         return;
      end if;
      M := Dwm_Monitors.Dir_To_Mon (A.I);
      if M = Dwm_State.Sel_Mon then
         return;
      end if;
      Dwm_Clients.Unfocus (Dwm_State.Sel_Mon.Sel, False);
      Dwm_State.Sel_Mon := M;
      Dwm_Clients.Focus (null);
   end Focus_Mon;

   procedure Focus_Stack (A : Dwm_Types.Arg) is
      C, I : Dwm_Types.Client_Access := null;
   begin
      if Dwm_State.Sel_Mon.Sel = null
        or else (Dwm_State.Sel_Mon.Sel.Is_Full_Screen and then Config.Lock_Full_Screen)
      then
         return;
      end if;
      if A.I > 0 then
         C := Dwm_State.Sel_Mon.Sel.Next;
         while C /= null and then not Dwm_Types.Is_Visible (C) loop
            C := C.Next;
         end loop;
         if C = null then
            C := Dwm_State.Sel_Mon.Clients;
            while C /= null and then not Dwm_Types.Is_Visible (C) loop
               C := C.Next;
            end loop;
         end if;
      else
         I := Dwm_State.Sel_Mon.Clients;
         while I /= Dwm_State.Sel_Mon.Sel loop
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
         Dwm_Clients.Restack (Dwm_State.Sel_Mon);
      end if;
   end Focus_Stack;

   procedure Inc_Nmaster (A : Dwm_Types.Arg) is
   begin
      Dwm_State.Sel_Mon.Nmaster := Util.Max_Integer (Dwm_State.Sel_Mon.Nmaster + A.I, 0);
      Dwm_Clients.Arrange (Dwm_State.Sel_Mon);
   end Inc_Nmaster;

   procedure Kill_Client (A : Dwm_Types.Arg) is
      pragma Unreferenced (A);
      Ignore : Xlib_Thin.C_Int;
      Ignore_Handler : Xlib_Thin.XErrorHandler;
      Ignore_Bool : Boolean;
   begin
      if Dwm_State.Sel_Mon.Sel = null then
         return;
      end if;
      Ignore_Bool := Dwm_Clients.Send_Event (Dwm_State.Sel_Mon.Sel, Dwm_State.Wm_Atom (Dwm_State.WM_Delete));
      if not Ignore_Bool then
         Ignore := Xlib_Thin.XGrabServer (Dwm_State.Dpy);
         Ignore_Handler := Xlib_Thin.XSetErrorHandler (Dwm_Clients.X_Error_Dummy'Access);
         Ignore := Xlib_Thin.XSetCloseDownMode (Dwm_State.Dpy, Xlib_Thin.DestroyAllMode);
         Ignore := Xlib_Thin.XKillClient (Dwm_State.Dpy, Dwm_State.Sel_Mon.Sel.Win);
         Ignore := Xlib_Thin.XSync (Dwm_State.Dpy, 0);
         Ignore_Handler := Xlib_Thin.XSetErrorHandler (Dwm_Clients.X_Error'Access);
         Ignore := Xlib_Thin.XUngrabServer (Dwm_State.Dpy);
      end if;
   end Kill_Client;

   procedure Move_Mouse (A : Dwm_Types.Arg) is
      pragma Unreferenced (A);
      C : constant Dwm_Types.Client_Access := Dwm_State.Sel_Mon.Sel;
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
      if C = null or else C.Is_Full_Screen then
         return;
      end if;
      Dwm_Clients.Restack (Dwm_State.Sel_Mon);
      Ocx := C.X;
      Ocy := C.Y;
      Grab_Result := Xlib_Thin.XGrabPointer
        (Dwm_State.Dpy, Dwm_State.Root, 0, Mouse_Mask, Xlib_Thin.GrabModeAsync, Xlib_Thin.GrabModeAsync,
         Xlib_Thin.None, Dwm_State.Cursors (Dwm_State.Cur_Move).Cursor, Xlib_Thin.Current_Time);
      if Grab_Result /= Xlib_Thin.GrabSuccess then
         return;
      end if;
      if not Dwm_Xutil.Get_Root_Ptr (X, Y) then
         return;
      end if;
      loop
         Ignore := Xlib_Thin.XMaskEvent
           (Dwm_State.Dpy,
            Xlib_Thin.C_Mask (Mouse_Mask) or Xlib_Thin.ExposureMask or Xlib_Thin.SubstructureRedirectMask,
            Ev'Access);
         case Any.Event_Type is
            when Xlib_Thin.ConfigureRequest =>
               Dwm_Clients.Configure_Request (Ev'Access);
            when Xlib_Thin.Expose =>
               Dwm_Monitors.Expose (Ev'Access);
            when Xlib_Thin.MapRequest =>
               Dwm_Clients.Map_Request (Ev'Access);
            when Xlib_Thin.MotionNotify =>
               if (Motion.Evt_Time - Lasttime) <= Xlib_Thin.Time_T (1000 / Config.Refresh_Rate) then
                  goto Continue_Loop;
               end if;
               Lasttime := Motion.Evt_Time;
               Nx := Ocx + (Integer (Motion.X) - X);
               Ny := Ocy + (Integer (Motion.Y) - Y);
               if abs (Dwm_State.Sel_Mon.Wx - Nx) < Config.Snap then
                  Nx := Dwm_State.Sel_Mon.Wx;
               elsif abs ((Dwm_State.Sel_Mon.Wx + Dwm_State.Sel_Mon.Ww) - (Nx + Dwm_Types.Width (C)))
                     < Config.Snap
               then
                  Nx := Dwm_State.Sel_Mon.Wx + Dwm_State.Sel_Mon.Ww - Dwm_Types.Width (C);
               end if;
               if abs (Dwm_State.Sel_Mon.Wy - Ny) < Config.Snap then
                  Ny := Dwm_State.Sel_Mon.Wy;
               elsif abs ((Dwm_State.Sel_Mon.Wy + Dwm_State.Sel_Mon.Wh) - (Ny + Dwm_Types.Height (C)))
                     < Config.Snap
               then
                  Ny := Dwm_State.Sel_Mon.Wy + Dwm_State.Sel_Mon.Wh - Dwm_Types.Height (C);
               end if;
               if not C.Is_Floating and then Dwm_State.Sel_Mon.Lt (Dwm_State.Sel_Mon.Sel_Lt).Arrange /= null
                 and then (abs (Nx - C.X) > Config.Snap or else abs (Ny - C.Y) > Config.Snap)
               then
                  Toggle_Floating (Dwm_Types.No_Arg);
               end if;
               if Dwm_State.Sel_Mon.Lt (Dwm_State.Sel_Mon.Sel_Lt).Arrange = null or else C.Is_Floating then
                  Dwm_Clients.Resize (C, Nx, Ny, C.W, C.H, True);
               end if;
            when others =>
               null;
         end case;
         <<Continue_Loop>>
         exit when Any.Event_Type = Xlib_Thin.ButtonRelease;
      end loop;
      Ignore := Xlib_Thin.XUngrabPointer (Dwm_State.Dpy, Xlib_Thin.Current_Time);
      M := Dwm_Monitors.Rect_To_Mon (C.X, C.Y, C.W, C.H);
      if M /= Dwm_State.Sel_Mon then
         Dwm_Clients.Send_Mon (C, M);
         Dwm_State.Sel_Mon := M;
         Dwm_Clients.Focus (null);
      end if;
   end Move_Mouse;

   procedure Quit (A : Dwm_Types.Arg) is
      pragma Unreferenced (A);
   begin
      Dwm_State.Running := False;
   end Quit;

   procedure Resize_Mouse (A : Dwm_Types.Arg) is
      pragma Unreferenced (A);
      C : constant Dwm_Types.Client_Access := Dwm_State.Sel_Mon.Sel;
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
      if C = null or else C.Is_Full_Screen then
         return;
      end if;
      Dwm_Clients.Restack (Dwm_State.Sel_Mon);
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
               Dwm_Clients.Configure_Request (Ev'Access);
            when Xlib_Thin.Expose =>
               Dwm_Monitors.Expose (Ev'Access);
            when Xlib_Thin.MapRequest =>
               Dwm_Clients.Map_Request (Ev'Access);
            when Xlib_Thin.MotionNotify =>
               if (Motion.Evt_Time - Lasttime) <= Xlib_Thin.Time_T (1000 / Config.Refresh_Rate) then
                  goto Continue_Loop;
               end if;
               Lasttime := Motion.Evt_Time;
               Nw := Util.Max_Integer (Integer (Motion.X) - Ocx - 2 * C.Bw + 1, 1);
               Nh := Util.Max_Integer (Integer (Motion.Y) - Ocy - 2 * C.Bw + 1, 1);
               if C.Mon.Wx + Nw >= Dwm_State.Sel_Mon.Wx and then C.Mon.Wx + Nw <= Dwm_State.Sel_Mon.Wx
                    + Dwm_State.Sel_Mon.Ww
                 and then C.Mon.Wy + Nh >= Dwm_State.Sel_Mon.Wy
                 and then C.Mon.Wy + Nh <= Dwm_State.Sel_Mon.Wy + Dwm_State.Sel_Mon.Wh
               then
                  if not C.Is_Floating and then Dwm_State.Sel_Mon.Lt (Dwm_State.Sel_Mon.Sel_Lt).Arrange /= null
                    and then (abs (Nw - C.W) > Config.Snap or else abs (Nh - C.H) > Config.Snap)
                  then
                     Toggle_Floating (Dwm_Types.No_Arg);
                  end if;
               end if;
               if Dwm_State.Sel_Mon.Lt (Dwm_State.Sel_Mon.Sel_Lt).Arrange = null or else C.Is_Floating then
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
      M := Dwm_Monitors.Rect_To_Mon (C.X, C.Y, C.W, C.H);
      if M /= Dwm_State.Sel_Mon then
         Dwm_Clients.Send_Mon (C, M);
         Dwm_State.Sel_Mon := M;
         Dwm_Clients.Focus (null);
      end if;
   end Resize_Mouse;

   procedure Set_Layout (A : Dwm_Types.Arg) is
   begin
      if A.Lt = null or else A.Lt /= Dwm_State.Sel_Mon.Lt (Dwm_State.Sel_Mon.Sel_Lt) then
         Dwm_State.Sel_Mon.Sel_Lt := 1 - Dwm_State.Sel_Mon.Sel_Lt;
      end if;
      if A.Lt /= null then
         Dwm_State.Sel_Mon.Lt (Dwm_State.Sel_Mon.Sel_Lt) := A.Lt;
      end if;
      Dwm_State.Sel_Mon.Lt_Symbol := Dwm_Types.Lt_Symbol_Strings.To_Bounded_String
        (Dwm_State.Sel_Mon.Lt (Dwm_State.Sel_Mon.Sel_Lt).Symbol.all, Ada.Strings.Right);
      if Dwm_State.Sel_Mon.Sel /= null then
         Dwm_Clients.Arrange (Dwm_State.Sel_Mon);
      else
         Dwm_Bar.Draw_Bar (Dwm_State.Sel_Mon);
      end if;
   end Set_Layout;

   procedure Set_Mfact (A : Dwm_Types.Arg) is
      F : Float;
   begin
      if Dwm_State.Sel_Mon.Lt (Dwm_State.Sel_Mon.Sel_Lt).Arrange = null then
         return;
      end if;
      F := (if A.F < 1.0 then A.F + Dwm_State.Sel_Mon.Mfact else A.F - 1.0);
      if F < 0.05 or else F > 0.95 then
         return;
      end if;
      Dwm_State.Sel_Mon.Mfact := F;
      Dwm_Clients.Arrange (Dwm_State.Sel_Mon);
   end Set_Mfact;

   procedure Spawn (A : Dwm_Types.Arg) is
      Pid : Interfaces.C.int;
      Ignore : Interfaces.C.int;
      Ignore_Addr : System.Address;
   begin
      if A.Cmd = Config.Dmenu_Cmd'Access then
         Config.Dmenu_Mon_Buf (1) := Character'Val (Character'Pos ('0') + Dwm_State.Sel_Mon.Num);
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
      if Dwm_State.Sel_Mon.Sel /= null and then (A.Ui and Tagmask) /= 0 then
         Dwm_State.Sel_Mon.Sel.Tags := A.Ui and Tagmask;
         Dwm_Clients.Focus (null);
         Dwm_Clients.Arrange (Dwm_State.Sel_Mon);
      end if;
   end Tag;

   procedure Tag_Mon (A : Dwm_Types.Arg) is
   begin
      if Dwm_State.Sel_Mon.Sel = null or else Dwm_State.Mons.Next = null then
         return;
      end if;
      Dwm_Clients.Send_Mon (Dwm_State.Sel_Mon.Sel, Dwm_Monitors.Dir_To_Mon (A.I));
   end Tag_Mon;

   procedure Toggle_Bar (A : Dwm_Types.Arg) is
      pragma Unreferenced (A);
      Ignore : Xlib_Thin.C_Int;
   begin
      Dwm_State.Sel_Mon.Show_Bar := not Dwm_State.Sel_Mon.Show_Bar;
      Dwm_Monitors.Update_Bar_Pos (Dwm_State.Sel_Mon);
      Ignore := Xlib_Thin.XMoveResizeWindow
        (Dwm_State.Dpy, Dwm_State.Sel_Mon.Bar_Win, Xlib_Thin.C_Int (Dwm_State.Sel_Mon.Wx),
         Xlib_Thin.C_Int (Dwm_State.Sel_Mon.By), Xlib_Thin.C_UInt (Dwm_State.Sel_Mon.Ww),
         Xlib_Thin.C_UInt (Dwm_State.Bh));
      Dwm_Clients.Arrange (Dwm_State.Sel_Mon);
   end Toggle_Bar;

   procedure Toggle_Floating (A : Dwm_Types.Arg) is
      pragma Unreferenced (A);
   begin
      if Dwm_State.Sel_Mon.Sel = null then
         return;
      end if;
      if Dwm_State.Sel_Mon.Sel.Is_Full_Screen then
         return;
      end if;
      Dwm_State.Sel_Mon.Sel.Is_Floating :=
        not Dwm_State.Sel_Mon.Sel.Is_Floating or else Dwm_State.Sel_Mon.Sel.Is_Fixed;
      if Dwm_State.Sel_Mon.Sel.Is_Floating then
         Dwm_Clients.Resize
           (Dwm_State.Sel_Mon.Sel, Dwm_State.Sel_Mon.Sel.X, Dwm_State.Sel_Mon.Sel.Y,
            Dwm_State.Sel_Mon.Sel.W, Dwm_State.Sel_Mon.Sel.H, False);
      end if;
      Dwm_Clients.Arrange (Dwm_State.Sel_Mon);
   end Toggle_Floating;

   procedure Toggle_Tag (A : Dwm_Types.Arg) is
      Newtags : Dwm_Types.Tag_Mask;
   begin
      if Dwm_State.Sel_Mon.Sel = null then
         return;
      end if;
      Newtags := Dwm_State.Sel_Mon.Sel.Tags xor (A.Ui and Tagmask);
      if Newtags /= 0 then
         Dwm_State.Sel_Mon.Sel.Tags := Newtags;
         Dwm_Clients.Focus (null);
         Dwm_Clients.Arrange (Dwm_State.Sel_Mon);
      end if;
   end Toggle_Tag;

   procedure Toggle_View (A : Dwm_Types.Arg) is
      Newtagset : constant Dwm_Types.Tag_Mask :=
        Dwm_State.Sel_Mon.Tag_Set (Dwm_State.Sel_Mon.Sel_Tags) xor (A.Ui and Tagmask);
   begin
      if Newtagset /= 0 then
         Dwm_State.Sel_Mon.Tag_Set (Dwm_State.Sel_Mon.Sel_Tags) := Newtagset;
         Dwm_Clients.Focus (null);
         Dwm_Clients.Arrange (Dwm_State.Sel_Mon);
      end if;
   end Toggle_View;

   procedure View (A : Dwm_Types.Arg) is
   begin
      if (A.Ui and Tagmask) = Dwm_State.Sel_Mon.Tag_Set (Dwm_State.Sel_Mon.Sel_Tags) then
         return;
      end if;
      Dwm_State.Sel_Mon.Sel_Tags := 1 - Dwm_State.Sel_Mon.Sel_Tags;
      if (A.Ui and Tagmask) /= 0 then
         Dwm_State.Sel_Mon.Tag_Set (Dwm_State.Sel_Mon.Sel_Tags) := A.Ui and Tagmask;
      end if;
      Dwm_Clients.Focus (null);
      Dwm_Clients.Arrange (Dwm_State.Sel_Mon);
   end View;

   procedure Zoom (A : Dwm_Types.Arg) is
      pragma Unreferenced (A);
      C : Dwm_Types.Client_Access := Dwm_State.Sel_Mon.Sel;
   begin
      if Dwm_State.Sel_Mon.Lt (Dwm_State.Sel_Mon.Sel_Lt).Arrange = null or else C = null or else C.Is_Floating
      then
         return;
      end if;
      if C = Dwm_Clients.Next_Tiled (Dwm_State.Sel_Mon.Clients) then
         C := Dwm_Clients.Next_Tiled (C.Next);
         if C = null then
            return;
         end if;
      end if;
      Dwm_Clients.Pop (C);
   end Zoom;

end Dwm_Actions;
