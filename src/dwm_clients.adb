with Ada.Strings.Fixed;
with Ada.Unchecked_Conversion;
with Ada.Unchecked_Deallocation;
with Interfaces.C.Strings;
with System;
with System.Storage_Elements;
with Config;
with Dwm_Bar;
with Dwm_State;
with Dwm_Xutil;
with Keysyms;
with Util;

package body Dwm_Clients is

   use type Xlib_Thin.C_Int;
   use type Xlib_Thin.C_UInt;
   use type Xlib_Thin.C_ULong;
   use type Xlib_Thin.C_UChar;
   use type Xlib_Thin.XID;
   use type Xlib_Thin.KeyCode;
   use type System.Address;
   use type Interfaces.C.Strings.chars_ptr;
   use type Dwm_Types.Client_Access;
   use type Dwm_Types.Monitor_Access;
   use type Dwm_Types.Tag_Mask;
   use type Dwm_Types.Arrange_Func;
   use type Dwm_Types.Click_Kind;
   use type Dwm_Types.Key_Array_Access;
   use type Dwm_Types.Button_Array_Access;

   procedure Free_Client is new Ada.Unchecked_Deallocation (Dwm_Types.Client, Dwm_Types.Client_Access);

   --------------------------------------------------------------------
   --  Small raw-memory helpers for reading X's flat KeyCode/KeySym/  --
   --  Atom arrays (returned as bare addresses by Xlib_Thin), plus a  --
   --  couple of small string/tag-mask helpers. Specs given here      --
   --  (rather than in dwm_clients.ads) since these are private.      --
   --------------------------------------------------------------------

   type Key_Code_Access is access all Xlib_Thin.KeyCode;
   function To_Key_Code_Access is new Ada.Unchecked_Conversion (System.Address, Key_Code_Access);

   function Key_Code_At (Base : System.Address; Index : Natural) return Xlib_Thin.KeyCode;

   type C_Ulong_Access is access all Xlib_Thin.C_ULong;
   function To_C_Ulong_Access is new Ada.Unchecked_Conversion (System.Address, C_Ulong_Access);

   function C_Ulong_At (Base : System.Address; Index : Natural) return Xlib_Thin.C_ULong;

   function To_Address is new Ada.Unchecked_Conversion
     (Interfaces.C.Strings.chars_ptr, System.Address);

   function Contains (Haystack, Needle : String) return Boolean is
     (Ada.Strings.Fixed.Index (Haystack, Needle) > 0);

   Tagmask : constant Dwm_Types.Tag_Mask := 2 ** Config.Tags'Length - 1;

   --------------------------------------------------------------------
   --  Subprogram bodies (alphabetical order; -gnatyo)                --
   --------------------------------------------------------------------

   procedure Apply_Rules (C : Dwm_Types.Client_Access) is
      Ch : aliased Xlib_Thin.XClassHint;
      M  : Dwm_Types.Monitor_Access;
      Ignore : Xlib_Thin.C_Int;
   begin
      C.Is_Floating := False;
      C.Tags := 0;
      Ignore := Xlib_Thin.XGetClassHint (Dwm_State.Dpy, C.Win, Ch'Access);
      declare
         Class_S : constant String :=
           (if Ch.Res_Class /= Interfaces.C.Strings.Null_Ptr
            then Interfaces.C.Strings.Value (Ch.Res_Class) else Dwm_State.Broken);
         Instance_S : constant String :=
           (if Ch.Res_Name /= Interfaces.C.Strings.Null_Ptr
            then Interfaces.C.Strings.Value (Ch.Res_Name) else Dwm_State.Broken);
         Name_S : constant String := Dwm_Types.Client_Name_Strings.To_String (C.Name);
      begin
         for R of Config.Rules loop
            if (R.Title = null or else Contains (Name_S, R.Title.all))
              and then (R.Class = null or else Contains (Class_S, R.Class.all))
              and then (R.Instance = null or else Contains (Instance_S, R.Instance.all))
            then
               C.Is_Floating := R.Is_Floating;
               C.Tags := C.Tags or R.Tags;
               M := Dwm_State.Mons;
               while M /= null and then M.Num /= R.Monitor loop
                  M := M.Next;
               end loop;
               if M /= null then
                  C.Mon := M;
               end if;
            end if;
         end loop;
      end;
      if Ch.Res_Class /= Interfaces.C.Strings.Null_Ptr then
         Ignore := Xlib_Thin.XFree (To_Address (Ch.Res_Class));
      end if;
      if Ch.Res_Name /= Interfaces.C.Strings.Null_Ptr then
         Ignore := Xlib_Thin.XFree (To_Address (Ch.Res_Name));
      end if;
      C.Tags := (if (C.Tags and Tagmask) /= 0
                 then C.Tags and Tagmask
                 else C.Mon.Tag_Set (C.Mon.Sel_Tags));
   end Apply_Rules;

   function Apply_Size_Hints
     (C : Dwm_Types.Client_Access; X, Y, W, H : in out Integer; Interact : Boolean) return Boolean
   is
      M : constant Dwm_Types.Monitor_Access := C.Mon;
      Baseismin : Boolean;
   begin
      W := Util.Max_Integer (1, W);
      H := Util.Max_Integer (1, H);
      if Interact then
         if X > Dwm_State.Sw then
            X := Dwm_State.Sw - Dwm_Types.Width (C);
         end if;
         if Y > Dwm_State.Sh then
            Y := Dwm_State.Sh - Dwm_Types.Height (C);
         end if;
         if X + W + 2 * C.Bw < 0 then
            X := 0;
         end if;
         if Y + H + 2 * C.Bw < 0 then
            Y := 0;
         end if;
      else
         if X >= M.Wx + M.Ww then
            X := M.Wx + M.Ww - Dwm_Types.Width (C);
         end if;
         if Y >= M.Wy + M.Wh then
            Y := M.Wy + M.Wh - Dwm_Types.Height (C);
         end if;
         if X + W + 2 * C.Bw <= M.Wx then
            X := M.Wx;
         end if;
         if Y + H + 2 * C.Bw <= M.Wy then
            Y := M.Wy;
         end if;
      end if;
      if H < Dwm_State.Bh then
         H := Dwm_State.Bh;
      end if;
      if W < Dwm_State.Bh then
         W := Dwm_State.Bh;
      end if;
      if Config.Resize_Hints or else C.Is_Floating or else C.Mon.Lt (C.Mon.Sel_Lt).Arrange = null then
         if not C.Hints_Valid then
            Update_Size_Hints (C);
         end if;
         Baseismin := C.Basew = C.Minw and then C.Baseh = C.Minh;
         if not Baseismin then
            W := W - C.Basew;
            H := H - C.Baseh;
         end if;
         if C.Mina > 0.0 and then C.Maxa > 0.0 then
            if C.Maxa < Float (W) / Float (H) then
               W := Integer (Float (H) * C.Maxa + 0.5);
            elsif C.Mina < Float (H) / Float (W) then
               H := Integer (Float (W) * C.Mina + 0.5);
            end if;
         end if;
         if Baseismin then
            W := W - C.Basew;
            H := H - C.Baseh;
         end if;
         if C.Incw /= 0 then
            W := W - (W rem C.Incw);
         end if;
         if C.Inch /= 0 then
            H := H - (H rem C.Inch);
         end if;
         W := Util.Max_Integer (W + C.Basew, C.Minw);
         H := Util.Max_Integer (H + C.Baseh, C.Minh);
         if C.Maxw /= 0 then
            W := Util.Min_Integer (W, C.Maxw);
         end if;
         if C.Maxh /= 0 then
            H := Util.Min_Integer (H, C.Maxh);
         end if;
      end if;
      return X /= C.X or else Y /= C.Y or else W /= C.W or else H /= C.H;
   end Apply_Size_Hints;

   procedure Arrange (M : Dwm_Types.Monitor_Access) is
      Mm : Dwm_Types.Monitor_Access;
   begin
      if M /= null then
         Show_Hide (M.Stack);
      else
         Mm := Dwm_State.Mons;
         while Mm /= null loop
            Show_Hide (Mm.Stack);
            Mm := Mm.Next;
         end loop;
      end if;
      if M /= null then
         Arrange_Mon (M);
         Restack (M);
      else
         Mm := Dwm_State.Mons;
         while Mm /= null loop
            Arrange_Mon (Mm);
            Mm := Mm.Next;
         end loop;
      end if;
   end Arrange;

   procedure Arrange_Mon (M : Dwm_Types.Monitor_Access) is
   begin
      M.Lt_Symbol := Dwm_Types.Lt_Symbol_Strings.To_Bounded_String
        (M.Lt (M.Sel_Lt).Symbol.all, Ada.Strings.Right);
      if M.Lt (M.Sel_Lt).Arrange /= null then
         M.Lt (M.Sel_Lt).Arrange (M);
      end if;
   end Arrange_Mon;

   procedure Attach (C : Dwm_Types.Client_Access) is
   begin
      C.Next := C.Mon.Clients;
      C.Mon.Clients := C;
   end Attach;

   procedure Attach_Stack (C : Dwm_Types.Client_Access) is
   begin
      C.Snext := C.Mon.Stack;
      C.Mon.Stack := C;
   end Attach_Stack;

   function C_Ulong_At (Base : System.Address; Index : Natural) return Xlib_Thin.C_ULong is
      use type System.Storage_Elements.Storage_Offset;
   begin
      return To_C_Ulong_Access
        (Base + System.Storage_Elements.Storage_Offset (Index * 8)).all;
   end C_Ulong_At;

   procedure Configure (C : Dwm_Types.Client_Access) is
      Ev : aliased Xlib_Thin.XEvent;
      Ce : Xlib_Thin.XConfigureEvent with Address => Ev'Address;
      pragma Import (Ada, Ce);
      Ignore : Xlib_Thin.C_Int;
   begin
      Ce.Event_Type := Xlib_Thin.ConfigureNotify;
      Ce.Disp := Dwm_State.Dpy;
      Ce.Event := C.Win;
      Ce.Win := C.Win;
      Ce.X := Xlib_Thin.C_Int (C.X);
      Ce.Y := Xlib_Thin.C_Int (C.Y);
      Ce.Width := Xlib_Thin.C_Int (C.W);
      Ce.Height := Xlib_Thin.C_Int (C.H);
      Ce.Border_Width := Xlib_Thin.C_Int (C.Bw);
      Ce.Above := Xlib_Thin.None;
      Ce.Override_Redirect := 0;
      Ignore := Xlib_Thin.XSendEvent
        (Dwm_State.Dpy, C.Win, 0, Xlib_Thin.StructureNotifyMask, Ev'Access);
   end Configure;

   procedure Configure_Request (Ev : access Xlib_Thin.XEvent) is
      Cre : Xlib_Thin.XConfigureRequestEvent with Address => Ev.all'Address;
      pragma Import (Ada, Cre);
      C  : Dwm_Types.Client_Access;
      M  : Dwm_Types.Monitor_Access;
      Wc : aliased Xlib_Thin.XWindowChanges;
      Ignore : Xlib_Thin.C_Int;
   begin
      C := Win_To_Client (Cre.Win);
      if C /= null then
         if (Cre.Value_Mask and Xlib_Thin.C_ULong (Xlib_Thin.CWBorderWidth)) /= 0 then
            C.Bw := Integer (Cre.Border_Width);
         elsif C.Is_Floating or else Dwm_State.Sel_Mon.Lt (Dwm_State.Sel_Mon.Sel_Lt).Arrange = null then
            M := C.Mon;
            if (Cre.Value_Mask and Xlib_Thin.C_ULong (Xlib_Thin.CWX)) /= 0 then
               C.Oldx := C.X;
               C.X := M.Mx + Integer (Cre.X);
            end if;
            if (Cre.Value_Mask and Xlib_Thin.C_ULong (Xlib_Thin.CWY)) /= 0 then
               C.Oldy := C.Y;
               C.Y := M.My + Integer (Cre.Y);
            end if;
            if (Cre.Value_Mask and Xlib_Thin.C_ULong (Xlib_Thin.CWWidth)) /= 0 then
               C.Oldw := C.W;
               C.W := Integer (Cre.Width);
            end if;
            if (Cre.Value_Mask and Xlib_Thin.C_ULong (Xlib_Thin.CWHeight)) /= 0 then
               C.Oldh := C.H;
               C.H := Integer (Cre.Height);
            end if;
            if (C.X + C.W) > M.Mx + M.Mw and then C.Is_Floating then
               C.X := M.Mx + (M.Mw / 2 - Dwm_Types.Width (C) / 2);
            end if;
            if (C.Y + C.H) > M.My + M.Mh and then C.Is_Floating then
               C.Y := M.My + (M.Mh / 2 - Dwm_Types.Height (C) / 2);
            end if;
            if (Cre.Value_Mask
                  and (Xlib_Thin.C_ULong (Xlib_Thin.CWX) or Xlib_Thin.C_ULong (Xlib_Thin.CWY))) /= 0
              and then (Cre.Value_Mask
                          and (Xlib_Thin.C_ULong (Xlib_Thin.CWWidth) or Xlib_Thin.C_ULong (Xlib_Thin.CWHeight)))
                        = 0
            then
               Configure (C);
            end if;
            if Dwm_Types.Is_Visible (C) then
               Ignore := Xlib_Thin.XMoveResizeWindow
                 (Dwm_State.Dpy, C.Win, Xlib_Thin.C_Int (C.X), Xlib_Thin.C_Int (C.Y),
                  Xlib_Thin.C_UInt (C.W), Xlib_Thin.C_UInt (C.H));
            end if;
         else
            Configure (C);
         end if;
      else
         Wc.X := Cre.X;
         Wc.Y := Cre.Y;
         Wc.Width := Cre.Width;
         Wc.Height := Cre.Height;
         Wc.Border_Width := Cre.Border_Width;
         Wc.Sibling := Cre.Above;
         Wc.Stack_Mode := Cre.Detail;
         Ignore := Xlib_Thin.XConfigureWindow
           (Dwm_State.Dpy, Cre.Win, Xlib_Thin.C_UInt (Cre.Value_Mask), Wc'Access);
      end if;
      Ignore := Xlib_Thin.XSync (Dwm_State.Dpy, 0);
   end Configure_Request;

   procedure Detach (C : Dwm_Types.Client_Access) is
      Cur, Prev : Dwm_Types.Client_Access := null;
   begin
      Cur := C.Mon.Clients;
      while Cur /= null and then Cur /= C loop
         Prev := Cur;
         Cur := Cur.Next;
      end loop;
      if Prev = null then
         C.Mon.Clients := C.Next;
      else
         Prev.Next := C.Next;
      end if;
   end Detach;

   procedure Detach_Stack (C : Dwm_Types.Client_Access) is
      Cur, Prev, T : Dwm_Types.Client_Access := null;
   begin
      Cur := C.Mon.Stack;
      while Cur /= null and then Cur /= C loop
         Prev := Cur;
         Cur := Cur.Snext;
      end loop;
      if Prev = null then
         C.Mon.Stack := C.Snext;
      else
         Prev.Snext := C.Snext;
      end if;

      if C = C.Mon.Sel then
         T := C.Mon.Stack;
         while T /= null and then not Dwm_Types.Is_Visible (T) loop
            T := T.Snext;
         end loop;
         C.Mon.Sel := T;
      end if;
   end Detach_Stack;

   procedure Focus (C : Dwm_Types.Client_Access) is
      Cc : Dwm_Types.Client_Access := C;
      Ignore : Xlib_Thin.C_Int;
   begin
      if Cc = null or else not Dwm_Types.Is_Visible (Cc) then
         Cc := Dwm_State.Sel_Mon.Stack;
         while Cc /= null and then not Dwm_Types.Is_Visible (Cc) loop
            Cc := Cc.Snext;
         end loop;
      end if;
      if Dwm_State.Sel_Mon.Sel /= null and then Dwm_State.Sel_Mon.Sel /= Cc then
         Unfocus (Dwm_State.Sel_Mon.Sel, False);
      end if;
      if Cc /= null then
         if Cc.Mon /= Dwm_State.Sel_Mon then
            Dwm_State.Sel_Mon := Cc.Mon;
         end if;
         if Cc.Is_Urgent then
            Set_Urgent (Cc, False);
         end if;
         Detach_Stack (Cc);
         Attach_Stack (Cc);
         Grab_Buttons (Cc, True);
         Ignore := Xlib_Thin.XSetWindowBorder
           (Dwm_State.Dpy, Cc.Win, Dwm_State.Scheme (Dwm_Types.Scheme_Sel) (Dwm_Types.Col_Border).Pixel);
         Set_Focus (Cc);
      else
         Ignore := Xlib_Thin.XSetInputFocus
           (Dwm_State.Dpy, Dwm_State.Root, Xlib_Thin.RevertToPointerRoot, Xlib_Thin.Current_Time);
         Ignore := Xlib_Thin.XDeleteProperty
           (Dwm_State.Dpy, Dwm_State.Root, Dwm_State.Net_Atom (Dwm_State.Net_Active_Window));
      end if;
      Dwm_State.Sel_Mon.Sel := Cc;
      Dwm_Bar.Draw_Bars;
   end Focus;

   procedure Grab_Buttons (C : Dwm_Types.Client_Access; Focused : Boolean) is
      Modifiers : constant array (0 .. 3) of Xlib_Thin.C_UInt :=
        (0, Xlib_Thin.LockMask, Dwm_State.Num_Lock_Mask, Dwm_State.Num_Lock_Mask or Xlib_Thin.LockMask);
      Button_Mask : constant Xlib_Thin.C_UInt :=
        Xlib_Thin.C_UInt (Xlib_Thin.ButtonPressMask) or Xlib_Thin.C_UInt (Xlib_Thin.ButtonReleaseMask);
      Ignore : Xlib_Thin.C_Int;
   begin
      Update_Num_Lock_Mask;
      Ignore := Xlib_Thin.XUngrabButton
        (Dwm_State.Dpy, Xlib_Thin.Any_Button, Xlib_Thin.AnyModifier, C.Win);
      if not Focused then
         Ignore := Xlib_Thin.XGrabButton
           (Dwm_State.Dpy, Xlib_Thin.Any_Button, Xlib_Thin.AnyModifier, C.Win, 0,
            Button_Mask, Xlib_Thin.GrabModeSync, Xlib_Thin.GrabModeSync, 0, 0);
      end if;
      if Dwm_State.Buttons /= null then
         for B of Dwm_State.Buttons.all loop
            if B.Click = Dwm_Types.Clk_Client_Win then
               for Mod_Bits of Modifiers loop
                  Ignore := Xlib_Thin.XGrabButton
                    (Dwm_State.Dpy, B.Button, B.Modifier or Mod_Bits, C.Win, 0,
                     Button_Mask, Xlib_Thin.GrabModeAsync, Xlib_Thin.GrabModeSync, 0, 0);
               end loop;
            end if;
         end loop;
      end if;
   end Grab_Buttons;

   procedure Grab_Keys is
      Modifiers : constant array (0 .. 3) of Xlib_Thin.C_UInt :=
        (0, Xlib_Thin.LockMask, Dwm_State.Num_Lock_Mask, Dwm_State.Num_Lock_Mask or Xlib_Thin.LockMask);
      Start_Kc, End_Kc, Skip : aliased Xlib_Thin.C_Int;
      Syms   : System.Address;
      Ignore : Xlib_Thin.C_Int;
   begin
      Update_Num_Lock_Mask;
      Ignore := Xlib_Thin.XUngrabKey
        (Dwm_State.Dpy, Xlib_Thin.Any_Key, Xlib_Thin.AnyModifier, Dwm_State.Root);
      Ignore := Xlib_Thin.XDisplayKeycodes (Dwm_State.Dpy, Start_Kc'Access, End_Kc'Access);
      Syms := Xlib_Thin.XGetKeyboardMapping
        (Dwm_State.Dpy, Xlib_Thin.KeyCode (Start_Kc), End_Kc - Start_Kc + 1, Skip'Access);
      if Syms = System.Null_Address then
         return;
      end if;
      if Dwm_State.Keys /= null then
         for K in Integer (Start_Kc) .. Integer (End_Kc) loop
            for Key_Def of Dwm_State.Keys.all loop
               if Xlib_Thin.KeySym (C_Ulong_At (Syms, (K - Integer (Start_Kc)) * Integer (Skip)))
                 = Key_Def.Sym
               then
                  for Mod_Bits of Modifiers loop
                     Ignore := Xlib_Thin.XGrabKey
                       (Dwm_State.Dpy, Xlib_Thin.C_Int (K), Key_Def.Modifier or Mod_Bits,
                        Dwm_State.Root, 1, Xlib_Thin.GrabModeAsync, Xlib_Thin.GrabModeAsync);
                  end loop;
               end if;
            end loop;
         end loop;
      end if;
      Ignore := Xlib_Thin.XFree (Syms);
   end Grab_Keys;

   function Key_Code_At (Base : System.Address; Index : Natural) return Xlib_Thin.KeyCode is
      use type System.Storage_Elements.Storage_Offset;
   begin
      return To_Key_Code_Access
        (Base + System.Storage_Elements.Storage_Offset (Index)).all;
   end Key_Code_At;

   procedure Manage (Win : Xlib_Thin.Window; Wa : Xlib_Thin.XWindowAttributes) is
      C : constant Dwm_Types.Client_Access := new Dwm_Types.Client;
      T : Dwm_Types.Client_Access := null;
      Trans : aliased Xlib_Thin.Window := Xlib_Thin.None;
      Wc : aliased Xlib_Thin.XWindowChanges;
      Win_Buf : aliased Xlib_Thin.Window;
      Ignore : Xlib_Thin.C_Int;
   begin
      C.Win := Win;
      C.X := Integer (Wa.X);
      C.Oldx := C.X;
      C.Y := Integer (Wa.Y);
      C.Oldy := C.Y;
      C.W := Integer (Wa.Width);
      C.Oldw := C.W;
      C.H := Integer (Wa.Height);
      C.Oldh := C.H;
      C.Oldbw := Integer (Wa.Border_Width);

      Update_Title (C);
      if Xlib_Thin.XGetTransientForHint (Dwm_State.Dpy, Win, Trans'Access) /= 0 then
         T := Win_To_Client (Trans);
      end if;
      if T /= null then
         C.Mon := T.Mon;
         C.Tags := T.Tags;
      else
         C.Mon := Dwm_State.Sel_Mon;
         Apply_Rules (C);
      end if;

      if C.X + Dwm_Types.Width (C) > C.Mon.Wx + C.Mon.Ww then
         C.X := C.Mon.Wx + C.Mon.Ww - Dwm_Types.Width (C);
      end if;
      if C.Y + Dwm_Types.Height (C) > C.Mon.Wy + C.Mon.Wh then
         C.Y := C.Mon.Wy + C.Mon.Wh - Dwm_Types.Height (C);
      end if;
      C.X := Util.Max_Integer (C.X, C.Mon.Wx);
      C.Y := Util.Max_Integer (C.Y, C.Mon.Wy);
      C.Bw := Config.Border_Px;

      Wc.Border_Width := Xlib_Thin.C_Int (C.Bw);
      Ignore := Xlib_Thin.XConfigureWindow (Dwm_State.Dpy, Win, Xlib_Thin.CWBorderWidth, Wc'Access);
      Ignore := Xlib_Thin.XSetWindowBorder
        (Dwm_State.Dpy, Win, Dwm_State.Scheme (Dwm_Types.Scheme_Norm) (Dwm_Types.Col_Border).Pixel);
      Configure (C);
      Update_Window_Type (C);
      Update_Size_Hints (C);
      Update_Wm_Hints (C);
      Ignore := Xlib_Thin.XSelectInput
        (Dwm_State.Dpy, Win,
         Xlib_Thin.EnterWindowMask or Xlib_Thin.FocusChangeMask or Xlib_Thin.PropertyChangeMask
           or Xlib_Thin.StructureNotifyMask);
      Grab_Buttons (C, False);
      if not C.Is_Floating then
         C.Is_Floating := Trans /= Xlib_Thin.None or else C.Is_Fixed;
         C.Old_State := C.Is_Floating;
      end if;
      if C.Is_Floating then
         Ignore := Xlib_Thin.XRaiseWindow (Dwm_State.Dpy, C.Win);
      end if;
      Attach (C);
      Attach_Stack (C);
      Win_Buf := C.Win;
      Ignore := Xlib_Thin.XChangeProperty
        (Dwm_State.Dpy, Dwm_State.Root, Dwm_State.Net_Atom (Dwm_State.Net_Client_List),
         Xlib_Thin.XA_WINDOW, 32, Xlib_Thin.PropModeAppend, Win_Buf'Address, 1);
      Ignore := Xlib_Thin.XMoveResizeWindow
        (Dwm_State.Dpy, C.Win, Xlib_Thin.C_Int (C.X + 2 * Dwm_State.Sw), Xlib_Thin.C_Int (C.Y),
         Xlib_Thin.C_UInt (C.W), Xlib_Thin.C_UInt (C.H));
      Set_Client_State (C, Xlib_Thin.NormalState);
      if C.Mon = Dwm_State.Sel_Mon then
         Unfocus (Dwm_State.Sel_Mon.Sel, False);
      end if;
      C.Mon.Sel := C;
      Arrange (C.Mon);
      Ignore := Xlib_Thin.XMapWindow (Dwm_State.Dpy, C.Win);
      Focus (null);
   end Manage;

   procedure Map_Request (Ev : access Xlib_Thin.XEvent) is
      Mre : Xlib_Thin.XMapRequestEvent with Address => Ev.all'Address;
      pragma Import (Ada, Mre);
      Wa : aliased Xlib_Thin.XWindowAttributes;
      Ok : Xlib_Thin.C_Int;
   begin
      Ok := Xlib_Thin.XGetWindowAttributes (Dwm_State.Dpy, Mre.Win, Wa'Access);
      if Ok = 0 or else Wa.Override_Redirect /= 0 then
         return;
      end if;
      if Win_To_Client (Mre.Win) = null then
         Manage (Mre.Win, Wa);
      end if;
   end Map_Request;

   function Next_Tiled (C : Dwm_Types.Client_Access) return Dwm_Types.Client_Access is
      Cur : Dwm_Types.Client_Access := C;
   begin
      while Cur /= null and then (Cur.Is_Floating or else not Dwm_Types.Is_Visible (Cur)) loop
         Cur := Cur.Next;
      end loop;
      return Cur;
   end Next_Tiled;

   procedure Pop (C : Dwm_Types.Client_Access) is
   begin
      Detach (C);
      Attach (C);
      Focus (C);
      Arrange (C.Mon);
   end Pop;

   procedure Resize (C : Dwm_Types.Client_Access; X, Y, W, H : Integer; Interact : Boolean) is
      Nx : Integer := X;
      Ny : Integer := Y;
      Nw : Integer := W;
      Nh : Integer := H;
   begin
      if Apply_Size_Hints (C, Nx, Ny, Nw, Nh, Interact) then
         Resize_Client (C, Nx, Ny, Nw, Nh);
      end if;
   end Resize;

   procedure Resize_Client (C : Dwm_Types.Client_Access; X, Y, W, H : Integer) is
      Wc : aliased Xlib_Thin.XWindowChanges;
      Ignore : Xlib_Thin.C_Int;
   begin
      C.Oldx := C.X;
      C.X := X;
      C.Oldy := C.Y;
      C.Y := Y;
      C.Oldw := C.W;
      C.W := W;
      C.Oldh := C.H;
      C.H := H;
      Wc.X := Xlib_Thin.C_Int (X);
      Wc.Y := Xlib_Thin.C_Int (Y);
      Wc.Width := Xlib_Thin.C_Int (W);
      Wc.Height := Xlib_Thin.C_Int (H);
      Wc.Border_Width := Xlib_Thin.C_Int (C.Bw);
      Ignore := Xlib_Thin.XConfigureWindow
        (Dwm_State.Dpy, C.Win,
         Xlib_Thin.CWX or Xlib_Thin.CWY or Xlib_Thin.CWWidth or Xlib_Thin.CWHeight
           or Xlib_Thin.CWBorderWidth,
         Wc'Access);
      Configure (C);
      Ignore := Xlib_Thin.XSync (Dwm_State.Dpy, 0);
   end Resize_Client;

   procedure Restack (M : Dwm_Types.Monitor_Access) is
      Wc : aliased Xlib_Thin.XWindowChanges;
      Ev : aliased Xlib_Thin.XEvent;
      C  : Dwm_Types.Client_Access;
      Ignore : Xlib_Thin.C_Int;
   begin
      Dwm_Bar.Draw_Bar (M);
      if M.Sel = null then
         return;
      end if;
      if M.Sel.Is_Floating or else M.Lt (M.Sel_Lt).Arrange = null then
         Ignore := Xlib_Thin.XRaiseWindow (Dwm_State.Dpy, M.Sel.Win);
      end if;
      if M.Lt (M.Sel_Lt).Arrange /= null then
         Wc.Stack_Mode := Xlib_Thin.Below;
         Wc.Sibling := M.Bar_Win;
         C := M.Stack;
         while C /= null loop
            if not C.Is_Floating and then Dwm_Types.Is_Visible (C) then
               Ignore := Xlib_Thin.XConfigureWindow
                 (Dwm_State.Dpy, C.Win, Xlib_Thin.CWSibling or Xlib_Thin.CWStackMode, Wc'Access);
               Wc.Sibling := C.Win;
            end if;
            C := C.Snext;
         end loop;
      end if;
      Ignore := Xlib_Thin.XSync (Dwm_State.Dpy, 0);
      while Xlib_Thin.XCheckMaskEvent (Dwm_State.Dpy, Xlib_Thin.EnterWindowMask, Ev'Access) /= 0 loop
         null;
      end loop;
   end Restack;

   function Send_Event (C : Dwm_Types.Client_Access; Proto : Xlib_Thin.Atom) return Boolean is
      Protocols : aliased System.Address := System.Null_Address;
      N : aliased Xlib_Thin.C_Int;
      Exists : Boolean := False;
      Ev : aliased Xlib_Thin.XEvent;
      Ce : Xlib_Thin.XClientMessageEvent with Address => Ev'Address;
      pragma Import (Ada, Ce);
      Ok : Xlib_Thin.C_Int;
      Ignore : Xlib_Thin.C_Int;
   begin
      Ok := Xlib_Thin.XGetWMProtocols (Dwm_State.Dpy, C.Win, Protocols'Access, N'Access);
      if Ok /= 0 then
         for I in 0 .. Integer (N) - 1 loop
            if Xlib_Thin.Atom (C_Ulong_At (Protocols, I)) = Proto then
               Exists := True;
            end if;
         end loop;
         Ignore := Xlib_Thin.XFree (Protocols);
      end if;
      if Exists then
         Ce.Event_Type := Xlib_Thin.ClientMessage;
         Ce.Win := C.Win;
         Ce.Message_Type := Dwm_State.Wm_Atom (Dwm_State.WM_Protocols);
         Ce.Format := 32;
         Ce.Data.L (0) := Xlib_Thin.C_Long (Proto);
         Ce.Data.L (1) := Xlib_Thin.C_Long (Xlib_Thin.Current_Time);
         Ignore := Xlib_Thin.XSendEvent (Dwm_State.Dpy, C.Win, 0, Xlib_Thin.NoEventMask, Ev'Access);
      end if;
      return Exists;
   end Send_Event;

   procedure Send_Mon (C : Dwm_Types.Client_Access; M : Dwm_Types.Monitor_Access) is
   begin
      if C.Mon = M then
         return;
      end if;
      Unfocus (C, True);
      Detach (C);
      Detach_Stack (C);
      C.Mon := M;
      C.Tags := M.Tag_Set (M.Sel_Tags);
      Attach (C);
      Attach_Stack (C);
      if C.Is_Full_Screen then
         Resize_Client (C, M.Mx, M.My, M.Mw, M.Mh);
      end if;
      Focus (null);
      Arrange (null);
   end Send_Mon;

   procedure Set_Client_State (C : Dwm_Types.Client_Access; State : Long_Integer) is
      type Data_Pair is array (0 .. 1) of Xlib_Thin.C_ULong;
      Data : aliased Data_Pair := (Xlib_Thin.C_ULong (State), Xlib_Thin.None);
      Ignore : Xlib_Thin.C_Int;
   begin
      Ignore := Xlib_Thin.XChangeProperty
        (Dwm_State.Dpy, C.Win, Dwm_State.Wm_Atom (Dwm_State.WM_State), Dwm_State.Wm_Atom (Dwm_State.WM_State),
         32, Xlib_Thin.PropModeReplace, Data'Address, 2);
   end Set_Client_State;

   procedure Set_Focus (C : Dwm_Types.Client_Access) is
      Win_Buf : aliased Xlib_Thin.Window := C.Win;
      Ignore  : Xlib_Thin.C_Int;
      Ignore_Bool : Boolean;
   begin
      if not C.Never_Focus then
         Ignore := Xlib_Thin.XSetInputFocus
           (Dwm_State.Dpy, C.Win, Xlib_Thin.RevertToPointerRoot, Xlib_Thin.Current_Time);
      end if;
      Ignore := Xlib_Thin.XChangeProperty
        (Dwm_State.Dpy, Dwm_State.Root, Dwm_State.Net_Atom (Dwm_State.Net_Active_Window),
         Xlib_Thin.XA_WINDOW, 32, Xlib_Thin.PropModeReplace, Win_Buf'Address, 1);
      Ignore_Bool := Send_Event (C, Dwm_State.Wm_Atom (Dwm_State.WM_Take_Focus));
   end Set_Focus;

   procedure Set_Full_Screen (C : Dwm_Types.Client_Access; Fullscreen : Boolean) is
      Fs_Atom : aliased Xlib_Thin.Atom;
      Ignore  : Xlib_Thin.C_Int;
   begin
      if Fullscreen and then not C.Is_Full_Screen then
         Fs_Atom := Dwm_State.Net_Atom (Dwm_State.Net_WM_Fullscreen);
         Ignore := Xlib_Thin.XChangeProperty
           (Dwm_State.Dpy, C.Win, Dwm_State.Net_Atom (Dwm_State.Net_WM_State), Xlib_Thin.XA_ATOM, 32,
            Xlib_Thin.PropModeReplace, Fs_Atom'Address, 1);
         C.Is_Full_Screen := True;
         C.Old_State := C.Is_Floating;
         C.Oldbw := C.Bw;
         C.Bw := 0;
         C.Is_Floating := True;
         Resize_Client (C, C.Mon.Mx, C.Mon.My, C.Mon.Mw, C.Mon.Mh);
         Ignore := Xlib_Thin.XRaiseWindow (Dwm_State.Dpy, C.Win);
      elsif not Fullscreen and then C.Is_Full_Screen then
         Ignore := Xlib_Thin.XChangeProperty
           (Dwm_State.Dpy, C.Win, Dwm_State.Net_Atom (Dwm_State.Net_WM_State), Xlib_Thin.XA_ATOM, 32,
            Xlib_Thin.PropModeReplace, System.Null_Address, 0);
         C.Is_Full_Screen := False;
         C.Is_Floating := C.Old_State;
         C.Bw := C.Oldbw;
         C.X := C.Oldx;
         C.Y := C.Oldy;
         C.W := C.Oldw;
         C.H := C.Oldh;
         Resize_Client (C, C.X, C.Y, C.W, C.H);
         Arrange (C.Mon);
      end if;
   end Set_Full_Screen;

   procedure Set_Urgent (C : Dwm_Types.Client_Access; Urg : Boolean) is
      Wmh : access Xlib_Thin.XWMHints;
      Ignore : Xlib_Thin.C_Int;
   begin
      C.Is_Urgent := Urg;
      Wmh := Xlib_Thin.XGetWMHints (Dwm_State.Dpy, C.Win);
      if Wmh = null then
         return;
      end if;
      if Urg then
         Wmh.Flags := Wmh.Flags or Xlib_Thin.XUrgencyHint;
      else
         Wmh.Flags := Wmh.Flags and not Xlib_Thin.XUrgencyHint;
      end if;
      Ignore := Xlib_Thin.XSetWMHints (Dwm_State.Dpy, C.Win, Wmh);
      Ignore := Xlib_Thin.XFree (Wmh.all'Address);
   end Set_Urgent;

   procedure Show_Hide (C : Dwm_Types.Client_Access) is
      Ignore : Xlib_Thin.C_Int;
   begin
      if C = null then
         return;
      end if;
      if Dwm_Types.Is_Visible (C) then
         Ignore := Xlib_Thin.XMoveWindow (Dwm_State.Dpy, C.Win, Xlib_Thin.C_Int (C.X), Xlib_Thin.C_Int (C.Y));
         if (C.Mon.Lt (C.Mon.Sel_Lt).Arrange = null or else C.Is_Floating) and then not C.Is_Full_Screen then
            Resize (C, C.X, C.Y, C.W, C.H, False);
         end if;
         Show_Hide (C.Snext);
      else
         Show_Hide (C.Snext);
         Ignore := Xlib_Thin.XMoveWindow
           (Dwm_State.Dpy, C.Win, Xlib_Thin.C_Int (-(2 * Dwm_Types.Width (C))), Xlib_Thin.C_Int (C.Y));
      end if;
   end Show_Hide;

   procedure Unfocus (C : Dwm_Types.Client_Access; Clear_Focus : Boolean) is
      Ignore : Xlib_Thin.C_Int;
   begin
      if C = null then
         return;
      end if;
      Grab_Buttons (C, False);
      Ignore := Xlib_Thin.XSetWindowBorder
        (Dwm_State.Dpy, C.Win, Dwm_State.Scheme (Dwm_Types.Scheme_Norm) (Dwm_Types.Col_Border).Pixel);
      if Clear_Focus then
         Ignore := Xlib_Thin.XSetInputFocus
           (Dwm_State.Dpy, Dwm_State.Root, Xlib_Thin.RevertToPointerRoot, Xlib_Thin.Current_Time);
         Ignore := Xlib_Thin.XDeleteProperty
           (Dwm_State.Dpy, Dwm_State.Root, Dwm_State.Net_Atom (Dwm_State.Net_Active_Window));
      end if;
   end Unfocus;

   procedure Unmanage (C : Dwm_Types.Client_Access; Destroyed : Boolean) is
      M  : constant Dwm_Types.Monitor_Access := C.Mon;
      Wc : aliased Xlib_Thin.XWindowChanges;
      Cv : Dwm_Types.Client_Access := C;
      Ignore : Xlib_Thin.C_Int;
      Ignore_Handler : Xlib_Thin.XErrorHandler;
   begin
      Detach (C);
      Detach_Stack (C);
      if not Destroyed then
         Wc.Border_Width := Xlib_Thin.C_Int (C.Oldbw);
         Ignore := Xlib_Thin.XGrabServer (Dwm_State.Dpy);
         Ignore_Handler := Xlib_Thin.XSetErrorHandler (X_Error_Dummy'Access);
         Ignore := Xlib_Thin.XSelectInput (Dwm_State.Dpy, C.Win, Xlib_Thin.NoEventMask);
         Ignore := Xlib_Thin.XConfigureWindow (Dwm_State.Dpy, C.Win, Xlib_Thin.CWBorderWidth, Wc'Access);
         Ignore := Xlib_Thin.XUngrabButton
           (Dwm_State.Dpy, Xlib_Thin.Any_Button, Xlib_Thin.AnyModifier, C.Win);
         Set_Client_State (C, Xlib_Thin.WithdrawnState);
         Ignore := Xlib_Thin.XSync (Dwm_State.Dpy, 0);
         Ignore_Handler := Xlib_Thin.XSetErrorHandler (X_Error'Access);
         Ignore := Xlib_Thin.XUngrabServer (Dwm_State.Dpy);
      end if;
      Free_Client (Cv);
      Focus (null);
      Update_Client_List;
      Arrange (M);
   end Unmanage;

   procedure Update_Client_List is
      M : Dwm_Types.Monitor_Access := Dwm_State.Mons;
      C : Dwm_Types.Client_Access;
      Win_Buf : aliased Xlib_Thin.Window;
      Ignore : Xlib_Thin.C_Int;
   begin
      Ignore := Xlib_Thin.XDeleteProperty
        (Dwm_State.Dpy, Dwm_State.Root, Dwm_State.Net_Atom (Dwm_State.Net_Client_List));
      while M /= null loop
         C := M.Clients;
         while C /= null loop
            Win_Buf := C.Win;
            Ignore := Xlib_Thin.XChangeProperty
              (Dwm_State.Dpy, Dwm_State.Root, Dwm_State.Net_Atom (Dwm_State.Net_Client_List),
               Xlib_Thin.XA_WINDOW, 32, Xlib_Thin.PropModeAppend, Win_Buf'Address, 1);
            C := C.Next;
         end loop;
         M := M.Next;
      end loop;
   end Update_Client_List;

   procedure Update_Num_Lock_Mask is
      Modmap : Xlib_Thin.XModifierKeymap_Access;
      Ignore : Xlib_Thin.C_Int;
   begin
      Dwm_State.Num_Lock_Mask := 0;
      Modmap := Xlib_Thin.XGetModifierMapping (Dwm_State.Dpy);
      for I in 0 .. 7 loop
         for J in 0 .. Integer (Modmap.Max_Keypermod) - 1 loop
            if Key_Code_At (Modmap.Modifiermap, I * Integer (Modmap.Max_Keypermod) + J)
              = Xlib_Thin.XKeysymToKeycode (Dwm_State.Dpy, Keysyms.XK_Num_Lock)
            then
               Dwm_State.Num_Lock_Mask := Xlib_Thin.C_UInt (2 ** I);
            end if;
         end loop;
      end loop;
      Ignore := Xlib_Thin.XFreeModifiermap (Modmap);
   end Update_Num_Lock_Mask;

   procedure Update_Size_Hints (C : Dwm_Types.Client_Access) is
      Size   : aliased Xlib_Thin.XSizeHints;
      Msize  : aliased Xlib_Thin.C_Long;
      Ok     : Xlib_Thin.C_Int;
   begin
      Ok := Xlib_Thin.XGetWMNormalHints (Dwm_State.Dpy, C.Win, Size'Access, Msize'Access);
      if Ok = 0 then
         Size.Flags := Xlib_Thin.PSize;
      end if;
      if (Size.Flags and Xlib_Thin.PBaseSize) /= 0 then
         C.Basew := Integer (Size.Base_Width);
         C.Baseh := Integer (Size.Base_Height);
      elsif (Size.Flags and Xlib_Thin.PMinSize) /= 0 then
         C.Basew := Integer (Size.Min_Width);
         C.Baseh := Integer (Size.Min_Height);
      else
         C.Basew := 0;
         C.Baseh := 0;
      end if;
      if (Size.Flags and Xlib_Thin.PResizeInc) /= 0 then
         C.Incw := Integer (Size.Width_Inc);
         C.Inch := Integer (Size.Height_Inc);
      else
         C.Incw := 0;
         C.Inch := 0;
      end if;
      if (Size.Flags and Xlib_Thin.PMaxSize) /= 0 then
         C.Maxw := Integer (Size.Max_Width);
         C.Maxh := Integer (Size.Max_Height);
      else
         C.Maxw := 0;
         C.Maxh := 0;
      end if;
      if (Size.Flags and Xlib_Thin.PMinSize) /= 0 then
         C.Minw := Integer (Size.Min_Width);
         C.Minh := Integer (Size.Min_Height);
      elsif (Size.Flags and Xlib_Thin.PBaseSize) /= 0 then
         C.Minw := Integer (Size.Base_Width);
         C.Minh := Integer (Size.Base_Height);
      else
         C.Minw := 0;
         C.Minh := 0;
      end if;
      if (Size.Flags and Xlib_Thin.PAspect) /= 0 then
         C.Mina := Float (Size.Min_Aspect.Den) / Float (Size.Min_Aspect.Num);
         C.Maxa := Float (Size.Max_Aspect.Num) / Float (Size.Max_Aspect.Den);
      else
         C.Maxa := 0.0;
         C.Mina := 0.0;
      end if;
      C.Is_Fixed := C.Maxw /= 0 and then C.Maxh /= 0 and then C.Maxw = C.Minw and then C.Maxh = C.Minh;
      C.Hints_Valid := True;
   end Update_Size_Hints;

   procedure Update_Title (C : Dwm_Types.Client_Access) is
      --  Two separate constants, not a reassigned variable: a String
      --  object's length is fixed at its declaration, so assigning a
      --  differently-sized result from the second Get_Text_Prop call
      --  into the same variable would raise Constraint_Error.
      Net_Name : constant String :=
        Dwm_Xutil.Get_Text_Prop (C.Win, Dwm_State.Net_Atom (Dwm_State.Net_WM_Name));
   begin
      if Net_Name'Length > 0 then
         C.Name := Dwm_Types.Client_Name_Strings.To_Bounded_String (Net_Name, Ada.Strings.Right);
         return;
      end if;
      declare
         Wm_Name : constant String := Dwm_Xutil.Get_Text_Prop (C.Win, Xlib_Thin.XA_WM_NAME);
      begin
         if Wm_Name'Length > 0 then
            C.Name := Dwm_Types.Client_Name_Strings.To_Bounded_String (Wm_Name, Ada.Strings.Right);
         else
            C.Name := Dwm_Types.Client_Name_Strings.To_Bounded_String (Dwm_State.Broken);
         end if;
      end;
   end Update_Title;

   procedure Update_Window_Type (C : Dwm_Types.Client_Access) is
      State : constant Xlib_Thin.Atom :=
        Dwm_Xutil.Get_Atom_Prop (C.Win, Dwm_State.Net_Atom (Dwm_State.Net_WM_State));
      Wtype : constant Xlib_Thin.Atom :=
        Dwm_Xutil.Get_Atom_Prop (C.Win, Dwm_State.Net_Atom (Dwm_State.Net_WM_Window_Type));
   begin
      if State = Dwm_State.Net_Atom (Dwm_State.Net_WM_Fullscreen) then
         Set_Full_Screen (C, True);
      end if;
      if Wtype = Dwm_State.Net_Atom (Dwm_State.Net_WM_Window_Type_Dialog) then
         C.Is_Floating := True;
      end if;
   end Update_Window_Type;

   procedure Update_Wm_Hints (C : Dwm_Types.Client_Access) is
      Wmh : access Xlib_Thin.XWMHints;
      Ignore : Xlib_Thin.C_Int;
   begin
      Wmh := Xlib_Thin.XGetWMHints (Dwm_State.Dpy, C.Win);
      if Wmh /= null then
         if C = Dwm_State.Sel_Mon.Sel and then (Wmh.Flags and Xlib_Thin.XUrgencyHint) /= 0 then
            Wmh.Flags := Wmh.Flags and not Xlib_Thin.XUrgencyHint;
            Ignore := Xlib_Thin.XSetWMHints (Dwm_State.Dpy, C.Win, Wmh);
         else
            C.Is_Urgent := (Wmh.Flags and Xlib_Thin.XUrgencyHint) /= 0;
         end if;
         if (Wmh.Flags and Xlib_Thin.InputHint) /= 0 then
            C.Never_Focus := Wmh.Input = 0;
         else
            C.Never_Focus := False;
         end if;
         Ignore := Xlib_Thin.XFree (Wmh.all'Address);
      end if;
   end Update_Wm_Hints;

   function Win_To_Client (Win : Xlib_Thin.Window) return Dwm_Types.Client_Access is
      M : Dwm_Types.Monitor_Access := Dwm_State.Mons;
      C : Dwm_Types.Client_Access;
   begin
      while M /= null loop
         C := M.Clients;
         while C /= null loop
            if C.Win = Win then
               return C;
            end if;
            C := C.Next;
         end loop;
         M := M.Next;
      end loop;
      return null;
   end Win_To_Client;

   function X_Error
     (Disp : Xlib_Thin.Display; Event : access Xlib_Thin.XErrorEvent) return Xlib_Thin.C_Int
   is
   begin
      if Event.Error_Code = Xlib_Thin.BadWindow
        or else (Event.Request_Code = Xlib_Thin.X_SetInputFocus and then Event.Error_Code = Xlib_Thin.BadMatch)
        or else (Event.Request_Code = Xlib_Thin.X_PolyText8 and then Event.Error_Code = Xlib_Thin.BadDrawable)
        or else (Event.Request_Code = Xlib_Thin.X_PolyFillRectangle
                 and then Event.Error_Code = Xlib_Thin.BadDrawable)
        or else (Event.Request_Code = Xlib_Thin.X_PolySegment and then Event.Error_Code = Xlib_Thin.BadDrawable)
        or else (Event.Request_Code = Xlib_Thin.X_ConfigureWindow and then Event.Error_Code = Xlib_Thin.BadMatch)
        or else (Event.Request_Code = Xlib_Thin.X_GrabButton and then Event.Error_Code = Xlib_Thin.BadAccess)
        or else (Event.Request_Code = Xlib_Thin.X_GrabKey and then Event.Error_Code = Xlib_Thin.BadAccess)
        or else (Event.Request_Code = Xlib_Thin.X_CopyArea and then Event.Error_Code = Xlib_Thin.BadDrawable)
      then
         return 0;
      end if;
      return Dwm_State.X_Error_Xlib (Disp, Event);
   end X_Error;

   function X_Error_Dummy
     (Disp : Xlib_Thin.Display; Event : access Xlib_Thin.XErrorEvent) return Xlib_Thin.C_Int
   is
      pragma Unreferenced (Disp, Event);
   begin
      return 0;
   end X_Error_Dummy;

   function X_Error_Start
     (Disp : Xlib_Thin.Display; Event : access Xlib_Thin.XErrorEvent) return Xlib_Thin.C_Int
   is
      pragma Unreferenced (Disp, Event);
   begin
      Util.Die ("dwm: another window manager is already running");
      return -1;
   end X_Error_Start;

end Dwm_Clients;
