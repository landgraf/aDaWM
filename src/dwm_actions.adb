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
   use type Xlib_Thin.Display;
   use type Dwm_Types.Client_Access;
   use type Dwm_Types.Monitor_Access;
   use type Dwm_Types.Layout_Const_Access;
   use type Dwm_Types.Arrange_Func;
   use type Dwm_Types.Tag_Mask;
   use type Dwm_Types.Command_Access;

   Tagmask : constant Dwm_Types.Tag_Mask := 2 ** Config.Tags'Length - 1;

   --  Returns the 1-based tag number of Mask's lowest set bit (dwm.c's
   --  "for (i = 0; !(mask & 1 << i); i++)" bit-scan in view()/
   --  toggleview()), used to turn a single-tag bit mask into a
   --  Per_Tag_State array index. Every call site passes Mask already
   --  ANDed with Tagmask, which is what makes the precondition
   --  provable at each of them: such a value can never have a bit set
   --  past position Config.Tags'Length - 1, safely inside Tag_Slot's
   --  range once shifted up by one.
   function Tag_Index_From_Mask (Mask : in Dwm_Types.Tag_Mask) return Dwm_Types.Tag_Slot
     with
       Pre  => Mask /= 0 and then Mask <= Tagmask,
       Post => Tag_Index_From_Mask'Result in 1 .. Dwm_Types.Max_Tags;

   --------------------------------------------------------------------
   --  fork/exec helpers for Spawn                                    --
   --------------------------------------------------------------------

   function C_Fork return Interfaces.C.int;
   pragma Import (C, C_Fork, "fork");

   function C_Setsid return Interfaces.C.int;
   pragma Import (C, C_Setsid, "setsid");

   function C_Close (Fd : in Interfaces.C.int) return Interfaces.C.int;
   pragma Import (C, C_Close, "close");

   function C_Signal (Signum : in Interfaces.C.int; Handler : in System.Address) return System.Address;
   pragma Import (C, C_Signal, "signal");

   function C_Execvp
     (File : in Interfaces.C.Strings.chars_ptr; Argv : in System.Address) return Interfaces.C.int;
   pragma Import (C, C_Execvp, "execvp");

   SIGCHLD : constant Interfaces.C.int := 17;

   --------------------------------------------------------------------

   Mouse_Mask : constant Xlib_Thin.C_UInt :=
     Xlib_Thin.C_UInt (Xlib_Thin.ButtonPressMask) or Xlib_Thin.C_UInt (Xlib_Thin.ButtonReleaseMask)
       or Xlib_Thin.C_UInt (Xlib_Thin.PointerMotionMask);

   --------------------------------------------------------------------
   --  Subprogram bodies (alphabetical order; -gnatyo)                --
   --------------------------------------------------------------------

   procedure Focus_Mon (Argument : in Dwm_Types.Arg) is
      Monitor : Dwm_Types.Monitor_Access;
   begin
      if Dwm_State.Get_Monitors.Next = null then
         return;
      end if;
      Monitor := Dwm_Monitors.Dir_To_Mon (Argument.Int_Value);
      if Monitor = Dwm_State.Get_Selected_Monitor then
         return;
      end if;
      Dwm_Clients.Unfocus (Dwm_State.Get_Selected_Monitor.Selected_Client, False);
      Dwm_State.Set_Selected_Monitor (Monitor);
      Dwm_Clients.Focus (null);
   end Focus_Mon;

   procedure Focus_Stack (Argument : in Dwm_Types.Arg) is
      Client, Cur : Dwm_Types.Client_Access := null;
   begin
      if Dwm_State.Get_Selected_Monitor.Selected_Client = null
        or else (Dwm_State.Get_Selected_Monitor.Selected_Client.Is_Full_Screen and then Config.Lock_Full_Screen)
      then
         return;
      end if;
      if Argument.Int_Value > 0 then
         Client := Dwm_State.Get_Selected_Monitor.Selected_Client.Next;
         while Client /= null and then not Dwm_Types.Is_Visible (Client) loop
            Client := Client.Next;
         end loop;
         if Client = null then
            Client := Dwm_State.Get_Selected_Monitor.Clients;
            while Client /= null and then not Dwm_Types.Is_Visible (Client) loop
               Client := Client.Next;
            end loop;
         end if;
      else
         Cur := Dwm_State.Get_Selected_Monitor.Clients;
         while Cur /= Dwm_State.Get_Selected_Monitor.Selected_Client loop
            if Dwm_Types.Is_Visible (Cur) then
               Client := Cur;
            end if;
            Cur := Cur.Next;
         end loop;
         if Client = null then
            while Cur /= null loop
               if Dwm_Types.Is_Visible (Cur) then
                  Client := Cur;
               end if;
               Cur := Cur.Next;
            end loop;
         end if;
      end if;
      if Client /= null then
         Dwm_Clients.Focus (Client);
         Dwm_Clients.Restack (Dwm_State.Get_Selected_Monitor);
      end if;
   end Focus_Stack;

   procedure Inc_Nmaster (Argument : in Dwm_Types.Arg) is
      Monitor : constant Dwm_Types.Monitor_Access := Dwm_State.Get_Selected_Monitor;
   begin
      Monitor.Num_Master := Util.Max_Integer (Monitor.Num_Master + Argument.Int_Value, 0);
      Monitor.Per_Tag.Num_Masters (Monitor.Per_Tag.Cur_Tag) := Monitor.Num_Master;
      Dwm_Clients.Arrange (Monitor);
   end Inc_Nmaster;

   procedure Kill_Client (Argument : in Dwm_Types.Arg) is
      pragma Unreferenced (Argument);
      Ignore : Xlib_Thin.C_Int;
      Ignore_Handler : Xlib_Thin.XErrorHandler;
      Ignore_Bool : Boolean;
   begin
      if Dwm_State.Get_Selected_Monitor.Selected_Client = null then
         return;
      end if;
      Dwm_Clients.Send_Event
        (Dwm_State.Get_Selected_Monitor.Selected_Client, Dwm_State.Get_Wm_Atom (Dwm_State.WM_Delete), Ignore_Bool);
      if not Ignore_Bool then
         Ignore := Xlib_Thin.XGrabServer (Dwm_State.Get_Display);
         Ignore_Handler := Xlib_Thin.XSetErrorHandler (Dwm_Clients.X_Error_Dummy'Access);
         Ignore := Xlib_Thin.XSetCloseDownMode (Dwm_State.Get_Display, Xlib_Thin.DestroyAllMode);
         Ignore := Xlib_Thin.XKillClient (Dwm_State.Get_Display, Dwm_State.Get_Selected_Monitor.Selected_Client.Window);
         Ignore := Xlib_Thin.XSync (Dwm_State.Get_Display, 0);
         Ignore_Handler := Xlib_Thin.XSetErrorHandler (Dwm_Clients.X_Error'Access);
         Ignore := Xlib_Thin.XUngrabServer (Dwm_State.Get_Display);
      end if;
   end Kill_Client;

   procedure Move_Mouse (Argument : in Dwm_Types.Arg) is
      pragma Unreferenced (Argument);
      Client : constant Dwm_Types.Client_Access := Dwm_State.Get_Selected_Monitor.Selected_Client;
      Monitor : Dwm_Types.Monitor_Access;
      Root_Ptr : Dwm_Xutil.Root_Ptr_Result;
      Orig_X, Orig_Y, New_X, New_Y : Integer;
      Event : aliased Xlib_Thin.XEvent;
      Any_Event : Xlib_Thin.XAnyEvent with Address => Event'Address;
      pragma Import (Ada, Any_Event);
      Motion_Event : Xlib_Thin.XMotionEvent with Address => Event'Address;
      pragma Import (Ada, Motion_Event);
      Last_Time : Xlib_Thin.Time_T := 0;
      Grab_Result : Xlib_Thin.C_Int;
      Ignore : Xlib_Thin.C_Int;
   begin
      if Client = null or else Client.Is_Full_Screen then
         return;
      end if;
      Dwm_Clients.Restack (Dwm_State.Get_Selected_Monitor);
      Orig_X := Client.Pos_X;
      Orig_Y := Client.Pos_Y;
      Grab_Result := Xlib_Thin.XGrabPointer
        (Dwm_State.Get_Display, Dwm_State.Get_Root, 0, Mouse_Mask, Xlib_Thin.GrabModeAsync, Xlib_Thin.GrabModeAsync,
         Xlib_Thin.None, Dwm_State.Get_Cursor (Dwm_State.Cursor_Move).X_Cursor, Xlib_Thin.Current_Time);
      if Grab_Result /= Xlib_Thin.GrabSuccess then
         return;
      end if;
      Root_Ptr := Dwm_Xutil.Get_Root_Ptr;
      if not Root_Ptr.Found then
         return;
      end if;
      loop
         Ignore := Xlib_Thin.XMaskEvent
           (Dwm_State.Get_Display,
            Xlib_Thin.C_Mask (Mouse_Mask) or Xlib_Thin.ExposureMask or Xlib_Thin.SubstructureRedirectMask,
            Event'Access);
         case Any_Event.Event_Type is
            when Xlib_Thin.ConfigureRequest =>
               Dwm_Clients.Configure_Request (Event'Access);
            when Xlib_Thin.Expose =>
               Dwm_Monitors.Expose (Event'Access);
            when Xlib_Thin.MapRequest =>
               Dwm_Clients.Map_Request (Event'Access);
            when Xlib_Thin.MotionNotify =>
               if (Motion_Event.Evt_Time - Last_Time) <= Xlib_Thin.Time_T (1000 / Config.Refresh_Rate) then
                  goto Continue_Loop;
               end if;
               Last_Time := Motion_Event.Evt_Time;
               New_X := Orig_X + (Integer (Motion_Event.X) - Root_Ptr.Pos_X);
               New_Y := Orig_Y + (Integer (Motion_Event.Y) - Root_Ptr.Pos_Y);
               if abs (Dwm_State.Get_Selected_Monitor.Work_X - New_X) < Config.Snap then
                  New_X := Dwm_State.Get_Selected_Monitor.Work_X;
               elsif abs
                 ((Dwm_State.Get_Selected_Monitor.Work_X + Dwm_State.Get_Selected_Monitor.Work_Width)
                    - (New_X + Dwm_Types.Outer_Width (Client))) < Config.Snap
               then
                  New_X := Dwm_State.Get_Selected_Monitor.Work_X + Dwm_State.Get_Selected_Monitor.Work_Width
                    - Dwm_Types.Outer_Width (Client);
               end if;
               if abs (Dwm_State.Get_Selected_Monitor.Work_Y - New_Y) < Config.Snap then
                  New_Y := Dwm_State.Get_Selected_Monitor.Work_Y;
               elsif abs
                 ((Dwm_State.Get_Selected_Monitor.Work_Y + Dwm_State.Get_Selected_Monitor.Work_Height)
                    - (New_Y + Dwm_Types.Outer_Height (Client))) < Config.Snap
               then
                  New_Y := Dwm_State.Get_Selected_Monitor.Work_Y + Dwm_State.Get_Selected_Monitor.Work_Height
                    - Dwm_Types.Outer_Height (Client);
               end if;
               if not Client.Is_Floating
                 and then Dwm_State.Get_Selected_Monitor.Layout (Dwm_State.Get_Selected_Monitor.Sel_Lt).Arrange /= null
                 and then (abs (New_X - Client.Pos_X) > Config.Snap
                             or else abs (New_Y - Client.Pos_Y) > Config.Snap)
               then
                  Toggle_Floating (Dwm_Types.No_Arg);
               end if;
               if Dwm_State.Get_Selected_Monitor.Layout (Dwm_State.Get_Selected_Monitor.Sel_Lt).Arrange = null
                 or else Client.Is_Floating
               then
                  Dwm_Clients.Resize (Client, New_X, New_Y, Client.Width, Client.Height, True);
               end if;
            when others =>
               null;
         end case;
         <<Continue_Loop>>
         exit when Any_Event.Event_Type = Xlib_Thin.ButtonRelease;
      end loop;
      Ignore := Xlib_Thin.XUngrabPointer (Dwm_State.Get_Display, Xlib_Thin.Current_Time);
      Monitor := Dwm_Monitors.Rect_To_Mon (Client.Pos_X, Client.Pos_Y, Client.Width, Client.Height);
      if Monitor /= Dwm_State.Get_Selected_Monitor then
         Dwm_Clients.Send_Mon (Client, Monitor);
         Dwm_State.Set_Selected_Monitor (Monitor);
         Dwm_Clients.Focus (null);
      end if;
   end Move_Mouse;

   procedure Quit (Argument : in Dwm_Types.Arg) is
      pragma Unreferenced (Argument);
   begin
      Dwm_State.Set_Running (False);
   end Quit;

   procedure Resize_Mouse (Argument : in Dwm_Types.Arg) is
      pragma Unreferenced (Argument);
      Client : constant Dwm_Types.Client_Access := Dwm_State.Get_Selected_Monitor.Selected_Client;
      Monitor : Dwm_Types.Monitor_Access;
      Orig_X, Orig_Y, New_Width, New_Height : Integer;
      Event : aliased Xlib_Thin.XEvent;
      Any_Event : Xlib_Thin.XAnyEvent with Address => Event'Address;
      pragma Import (Ada, Any_Event);
      Motion_Event : Xlib_Thin.XMotionEvent with Address => Event'Address;
      pragma Import (Ada, Motion_Event);
      Last_Time : Xlib_Thin.Time_T := 0;
      Grab_Result : Xlib_Thin.C_Int;
      Ignore : Xlib_Thin.C_Int;
   begin
      if Client = null or else Client.Is_Full_Screen then
         return;
      end if;
      Dwm_Clients.Restack (Dwm_State.Get_Selected_Monitor);
      Orig_X := Client.Pos_X;
      Orig_Y := Client.Pos_Y;
      Grab_Result := Xlib_Thin.XGrabPointer
        (Dwm_State.Get_Display, Dwm_State.Get_Root, 0, Mouse_Mask, Xlib_Thin.GrabModeAsync, Xlib_Thin.GrabModeAsync,
         Xlib_Thin.None, Dwm_State.Get_Cursor (Dwm_State.Cursor_Resize).X_Cursor, Xlib_Thin.Current_Time);
      if Grab_Result /= Xlib_Thin.GrabSuccess then
         return;
      end if;
      Ignore := Xlib_Thin.XWarpPointer
        (Dwm_State.Get_Display, Xlib_Thin.None, Client.Window, 0, 0, 0, 0,
         Xlib_Thin.C_Int (Client.Width + Client.Border_Width - 1),
         Xlib_Thin.C_Int (Client.Height + Client.Border_Width - 1));
      loop
         Ignore := Xlib_Thin.XMaskEvent
           (Dwm_State.Get_Display,
            Xlib_Thin.C_Mask (Mouse_Mask) or Xlib_Thin.ExposureMask or Xlib_Thin.SubstructureRedirectMask,
            Event'Access);
         case Any_Event.Event_Type is
            when Xlib_Thin.ConfigureRequest =>
               Dwm_Clients.Configure_Request (Event'Access);
            when Xlib_Thin.Expose =>
               Dwm_Monitors.Expose (Event'Access);
            when Xlib_Thin.MapRequest =>
               Dwm_Clients.Map_Request (Event'Access);
            when Xlib_Thin.MotionNotify =>
               if (Motion_Event.Evt_Time - Last_Time) <= Xlib_Thin.Time_T (1000 / Config.Refresh_Rate) then
                  goto Continue_Loop;
               end if;
               Last_Time := Motion_Event.Evt_Time;
               New_Width := Util.Max_Integer (Integer (Motion_Event.X) - Orig_X - 2 * Client.Border_Width + 1, 1);
               New_Height := Util.Max_Integer (Integer (Motion_Event.Y) - Orig_Y - 2 * Client.Border_Width + 1, 1);
               if Client.Monitor.Work_X + New_Width >= Dwm_State.Get_Selected_Monitor.Work_X
                 and then Client.Monitor.Work_X + New_Width
                   <= Dwm_State.Get_Selected_Monitor.Work_X + Dwm_State.Get_Selected_Monitor.Work_Width
                 and then Client.Monitor.Work_Y + New_Height >= Dwm_State.Get_Selected_Monitor.Work_Y
                 and then Client.Monitor.Work_Y + New_Height
                   <= Dwm_State.Get_Selected_Monitor.Work_Y + Dwm_State.Get_Selected_Monitor.Work_Height
               then
                  if not Client.Is_Floating
                    and then Dwm_State.Get_Selected_Monitor.Layout
                               (Dwm_State.Get_Selected_Monitor.Sel_Lt).Arrange /= null
                    and then (abs (New_Width - Client.Width) > Config.Snap
                                or else abs (New_Height - Client.Height) > Config.Snap)
                  then
                     Toggle_Floating (Dwm_Types.No_Arg);
                  end if;
               end if;
               if Dwm_State.Get_Selected_Monitor.Layout (Dwm_State.Get_Selected_Monitor.Sel_Lt).Arrange = null
                 or else Client.Is_Floating
               then
                  Dwm_Clients.Resize (Client, Client.Pos_X, Client.Pos_Y, New_Width, New_Height, True);
               end if;
            when others =>
               null;
         end case;
         <<Continue_Loop>>
         exit when Any_Event.Event_Type = Xlib_Thin.ButtonRelease;
      end loop;
      Ignore := Xlib_Thin.XWarpPointer
        (Dwm_State.Get_Display, Xlib_Thin.None, Client.Window, 0, 0, 0, 0,
         Xlib_Thin.C_Int (Client.Width + Client.Border_Width - 1),
         Xlib_Thin.C_Int (Client.Height + Client.Border_Width - 1));
      Ignore := Xlib_Thin.XUngrabPointer (Dwm_State.Get_Display, Xlib_Thin.Current_Time);
      while Xlib_Thin.XCheckMaskEvent (Dwm_State.Get_Display, Xlib_Thin.EnterWindowMask, Event'Access) /= 0 loop
         null;
      end loop;
      Monitor := Dwm_Monitors.Rect_To_Mon (Client.Pos_X, Client.Pos_Y, Client.Width, Client.Height);
      if Monitor /= Dwm_State.Get_Selected_Monitor then
         Dwm_Clients.Send_Mon (Client, Monitor);
         Dwm_State.Set_Selected_Monitor (Monitor);
         Dwm_Clients.Focus (null);
      end if;
   end Resize_Mouse;

   procedure Set_Layout (Argument : in Dwm_Types.Arg) is
      Monitor : constant Dwm_Types.Monitor_Access := Dwm_State.Get_Selected_Monitor;
   begin
      if Argument.Layout = null or else Argument.Layout /= Monitor.Layout (Monitor.Sel_Lt) then
         Monitor.Sel_Lt := 1 - Monitor.Sel_Lt;
         Monitor.Per_Tag.Sel_Layouts (Monitor.Per_Tag.Cur_Tag) := Monitor.Sel_Lt;
      end if;
      if Argument.Layout /= null then
         Monitor.Layout (Monitor.Sel_Lt) := Argument.Layout;
         Monitor.Per_Tag.Layouts (Monitor.Per_Tag.Cur_Tag) (Monitor.Sel_Lt) := Argument.Layout;
      end if;
      Monitor.Lt_Symbol := Dwm_Types.Lt_Symbol_Strings.To_Bounded_String
        (Monitor.Layout (Monitor.Sel_Lt).Symbol.all, Ada.Strings.Right);
      if Monitor.Selected_Client /= null then
         Dwm_Clients.Arrange (Monitor);
      else
         Dwm_Bar.Draw_Bar (Monitor);
      end if;
   end Set_Layout;

   procedure Set_Mfact (Argument : in Dwm_Types.Arg) is
      Monitor : constant Dwm_Types.Monitor_Access := Dwm_State.Get_Selected_Monitor;
      New_Factor : Float;
   begin
      if Monitor.Layout (Monitor.Sel_Lt).Arrange = null then
         return;
      end if;
      New_Factor := (if Argument.Float_Value < 1.0
            then Argument.Float_Value + Monitor.Master_Factor
            else Argument.Float_Value - 1.0);
      if New_Factor < 0.05 or else New_Factor > 0.95 then
         return;
      end if;
      Monitor.Master_Factor := New_Factor;
      Monitor.Per_Tag.Master_Factors (Monitor.Per_Tag.Cur_Tag) := New_Factor;
      Dwm_Clients.Arrange (Monitor);
   end Set_Mfact;

   procedure Spawn (Argument : in Dwm_Types.Arg) is
      Pid : Interfaces.C.int;
      Ignore : Interfaces.C.int;
      Ignore_Addr : System.Address;
   begin
      if Argument.Command = Config.Dmenu_Cmd'Access then
         Config.Dmenu_Mon_Buf (1) := Character'Val (Character'Pos ('0') + Dwm_State.Get_Selected_Monitor.Number);
      end if;
      Pid := C_Fork;
      if Pid = 0 then
         if Dwm_State.Get_Display /= null then
            Ignore := C_Close (Xlib_Thin.XConnectionNumber (Dwm_State.Get_Display));
         end if;
         Ignore := C_Setsid;
         Ignore_Addr := C_Signal (SIGCHLD, System.Null_Address);
         declare
            Arg_Count : constant Natural := Argument.Command'Length;
            Argv : array (0 .. Arg_Count) of aliased Interfaces.C.Strings.chars_ptr;
         begin
            for Idx in Argument.Command'Range loop
               Argv (Idx - Argument.Command'First) := Interfaces.C.Strings.New_String (Argument.Command (Idx).all);
            end loop;
            Argv (Arg_Count) := Interfaces.C.Strings.Null_Ptr;
            Ignore := C_Execvp (Argv (0), Argv (0)'Address);
         end;
         Util.Die
           ("dwm: execvp '" & Argument.Command (Argument.Command'First).all & "' failed:", With_Errno => True);
      end if;
   end Spawn;

   procedure Tag (Argument : in Dwm_Types.Arg) is
   begin
      if Dwm_State.Get_Selected_Monitor.Selected_Client /= null and then (Argument.Uint_Value and Tagmask) /= 0 then
         Dwm_State.Get_Selected_Monitor.Selected_Client.Tags := Argument.Uint_Value and Tagmask;
         Dwm_Clients.Focus (null);
         Dwm_Clients.Arrange (Dwm_State.Get_Selected_Monitor);
      end if;
   end Tag;

   function Tag_Index_From_Mask (Mask : in Dwm_Types.Tag_Mask) return Dwm_Types.Tag_Slot is
   begin
      for Idx in 0 .. Dwm_Types.Max_Tags - 1 loop
         if (Mask and 2 ** Idx) /= 0 then
            return Idx + 1;
         end if;
      end loop;
      raise Program_Error with "Tag_Index_From_Mask: no bit set within Tagmask";
   end Tag_Index_From_Mask;

   procedure Tag_Mon (Argument : in Dwm_Types.Arg) is
   begin
      if Dwm_State.Get_Selected_Monitor.Selected_Client = null or else Dwm_State.Get_Monitors.Next = null then
         return;
      end if;
      Dwm_Clients.Send_Mon
        (Dwm_State.Get_Selected_Monitor.Selected_Client, Dwm_Monitors.Dir_To_Mon (Argument.Int_Value));
   end Tag_Mon;

   procedure Toggle_Bar (Argument : in Dwm_Types.Arg) is
      pragma Unreferenced (Argument);
      Monitor : constant Dwm_Types.Monitor_Access := Dwm_State.Get_Selected_Monitor;
      Ignore : Xlib_Thin.C_Int;
   begin
      Monitor.Show_Bar := not Monitor.Show_Bar;
      Monitor.Per_Tag.Show_Bars (Monitor.Per_Tag.Cur_Tag) := Monitor.Show_Bar;
      Dwm_Monitors.Update_Bar_Pos (Monitor);
      Ignore := Xlib_Thin.XMoveResizeWindow
        (Dwm_State.Get_Display, Monitor.Bar_Window,
         Xlib_Thin.C_Int (Monitor.Work_X), Xlib_Thin.C_Int (Monitor.Bar_Y),
         Xlib_Thin.C_UInt (Monitor.Work_Width), Xlib_Thin.C_UInt (Dwm_State.Get_Bar_Height));
      Dwm_Clients.Arrange (Monitor);
   end Toggle_Bar;

   procedure Toggle_Floating (Argument : in Dwm_Types.Arg) is
      pragma Unreferenced (Argument);
   begin
      if Dwm_State.Get_Selected_Monitor.Selected_Client = null then
         return;
      end if;
      if Dwm_State.Get_Selected_Monitor.Selected_Client.Is_Full_Screen then
         return;
      end if;
      Dwm_State.Get_Selected_Monitor.Selected_Client.Is_Floating :=
        not Dwm_State.Get_Selected_Monitor.Selected_Client.Is_Floating
        or else Dwm_State.Get_Selected_Monitor.Selected_Client.Is_Fixed;
      if Dwm_State.Get_Selected_Monitor.Selected_Client.Is_Floating then
         Dwm_Clients.Resize
           (Dwm_State.Get_Selected_Monitor.Selected_Client,
            Dwm_State.Get_Selected_Monitor.Selected_Client.Pos_X, Dwm_State.Get_Selected_Monitor.Selected_Client.Pos_Y,
            Dwm_State.Get_Selected_Monitor.Selected_Client.Width, Dwm_State.Get_Selected_Monitor.Selected_Client.Height,
            False);
      end if;
      Dwm_Clients.Arrange (Dwm_State.Get_Selected_Monitor);
   end Toggle_Floating;

   procedure Toggle_Tag (Argument : in Dwm_Types.Arg) is
      New_Tags : Dwm_Types.Tag_Mask;
   begin
      if Dwm_State.Get_Selected_Monitor.Selected_Client = null then
         return;
      end if;
      New_Tags := Dwm_State.Get_Selected_Monitor.Selected_Client.Tags xor (Argument.Uint_Value and Tagmask);
      if New_Tags /= 0 then
         Dwm_State.Get_Selected_Monitor.Selected_Client.Tags := New_Tags;
         Dwm_Clients.Focus (null);
         Dwm_Clients.Arrange (Dwm_State.Get_Selected_Monitor);
      end if;
   end Toggle_Tag;

   procedure Toggle_View (Argument : in Dwm_Types.Arg) is
      Monitor : constant Dwm_Types.Monitor_Access := Dwm_State.Get_Selected_Monitor;
      New_Tag_Set : constant Dwm_Types.Tag_Mask :=
        Monitor.Tag_Set (Monitor.Sel_Tags) xor (Argument.Uint_Value and Tagmask);
   begin
      if New_Tag_Set /= 0 then
         Monitor.Tag_Set (Monitor.Sel_Tags) := New_Tag_Set;

         if New_Tag_Set = not Dwm_Types.Tag_Mask'(0) then
            Monitor.Per_Tag.Prev_Tag := Monitor.Per_Tag.Cur_Tag;
            Monitor.Per_Tag.Cur_Tag := 0;
         end if;

         --  Test if the user did not select the same tag (skipped
         --  when Cur_Tag is 0, i.e. just switched to viewing all tags
         --  above: dwm.c's equivalent check shifts by Cur_Tag - 1,
         --  which is undefined behavior in C when Cur_Tag is 0, but
         --  empirically leaves Cur_Tag at 0 on common platforms --
         --  this reproduces that same outcome without relying on an
         --  out-of-range shift).
         if Monitor.Per_Tag.Cur_Tag /= 0
           and then (New_Tag_Set and 2 ** (Monitor.Per_Tag.Cur_Tag - 1)) = 0
         then
            Monitor.Per_Tag.Prev_Tag := Monitor.Per_Tag.Cur_Tag;
            Monitor.Per_Tag.Cur_Tag := Tag_Index_From_Mask (New_Tag_Set);
         end if;

         Monitor.Num_Master := Monitor.Per_Tag.Num_Masters (Monitor.Per_Tag.Cur_Tag);
         Monitor.Master_Factor := Monitor.Per_Tag.Master_Factors (Monitor.Per_Tag.Cur_Tag);
         Monitor.Sel_Lt := Monitor.Per_Tag.Sel_Layouts (Monitor.Per_Tag.Cur_Tag);
         Monitor.Layout (Monitor.Sel_Lt) := Monitor.Per_Tag.Layouts (Monitor.Per_Tag.Cur_Tag) (Monitor.Sel_Lt);
         Monitor.Layout (1 - Monitor.Sel_Lt) :=
           Monitor.Per_Tag.Layouts (Monitor.Per_Tag.Cur_Tag) (1 - Monitor.Sel_Lt);

         if Monitor.Show_Bar /= Monitor.Per_Tag.Show_Bars (Monitor.Per_Tag.Cur_Tag) then
            Toggle_Bar (Dwm_Types.No_Arg);
         end if;

         Dwm_Clients.Focus (null);
         Dwm_Clients.Arrange (Monitor);
      end if;
   end Toggle_View;

   procedure View (Argument : in Dwm_Types.Arg) is
      Monitor : constant Dwm_Types.Monitor_Access := Dwm_State.Get_Selected_Monitor;
      Tmp_Tag : Dwm_Types.Tag_Slot;
   begin
      if (Argument.Uint_Value and Tagmask) = Monitor.Tag_Set (Monitor.Sel_Tags) then
         return;
      end if;
      Monitor.Sel_Tags := 1 - Monitor.Sel_Tags;
      if (Argument.Uint_Value and Tagmask) /= 0 then
         Monitor.Tag_Set (Monitor.Sel_Tags) := Argument.Uint_Value and Tagmask;
         Monitor.Per_Tag.Prev_Tag := Monitor.Per_Tag.Cur_Tag;

         if Argument.Uint_Value = not Dwm_Types.Tag_Mask'(0) then
            Monitor.Per_Tag.Cur_Tag := 0;
         else
            Monitor.Per_Tag.Cur_Tag := Tag_Index_From_Mask (Argument.Uint_Value and Tagmask);
         end if;
      else
         Tmp_Tag := Monitor.Per_Tag.Prev_Tag;
         Monitor.Per_Tag.Prev_Tag := Monitor.Per_Tag.Cur_Tag;
         Monitor.Per_Tag.Cur_Tag := Tmp_Tag;
      end if;

      Monitor.Num_Master := Monitor.Per_Tag.Num_Masters (Monitor.Per_Tag.Cur_Tag);
      Monitor.Master_Factor := Monitor.Per_Tag.Master_Factors (Monitor.Per_Tag.Cur_Tag);
      Monitor.Sel_Lt := Monitor.Per_Tag.Sel_Layouts (Monitor.Per_Tag.Cur_Tag);
      Monitor.Layout (Monitor.Sel_Lt) := Monitor.Per_Tag.Layouts (Monitor.Per_Tag.Cur_Tag) (Monitor.Sel_Lt);
      Monitor.Layout (1 - Monitor.Sel_Lt) :=
        Monitor.Per_Tag.Layouts (Monitor.Per_Tag.Cur_Tag) (1 - Monitor.Sel_Lt);

      if Monitor.Show_Bar /= Monitor.Per_Tag.Show_Bars (Monitor.Per_Tag.Cur_Tag) then
         Toggle_Bar (Dwm_Types.No_Arg);
      end if;

      Dwm_Clients.Focus (null);
      Dwm_Clients.Arrange (Monitor);
   end View;

   procedure Zoom (Argument : in Dwm_Types.Arg) is
      pragma Unreferenced (Argument);
      Client : Dwm_Types.Client_Access := Dwm_State.Get_Selected_Monitor.Selected_Client;
   begin
      if Dwm_State.Get_Selected_Monitor.Layout (Dwm_State.Get_Selected_Monitor.Sel_Lt).Arrange = null
        or else Client = null or else Client.Is_Floating
      then
         return;
      end if;
      if Client = Dwm_Clients.Next_Tiled (Dwm_State.Get_Selected_Monitor.Clients) then
         Client := Dwm_Clients.Next_Tiled (Client.Next);
         if Client = null then
            return;
         end if;
      end if;
      Dwm_Clients.Pop (Client);
   end Zoom;

end Dwm_Actions;
