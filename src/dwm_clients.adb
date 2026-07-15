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

   procedure Apply_Rules (Client : Dwm_Types.Client_Access) is
      Class_Hint : aliased Xlib_Thin.XClassHint;
      Rule_Monitor : Dwm_Types.Monitor_Access;
      Ignore : Xlib_Thin.C_Int;
   begin
      Client.Is_Floating := False;
      Client.Tags := 0;
      Ignore := Xlib_Thin.XGetClassHint (Dwm_State.Get_Display, Client.Window, Class_Hint'Access);
      declare
         Class_S : constant String :=
           (if Class_Hint.Res_Class /= Interfaces.C.Strings.Null_Ptr
            then Interfaces.C.Strings.Value (Class_Hint.Res_Class) else Dwm_State.Broken);
         Instance_S : constant String :=
           (if Class_Hint.Res_Name /= Interfaces.C.Strings.Null_Ptr
            then Interfaces.C.Strings.Value (Class_Hint.Res_Name) else Dwm_State.Broken);
         Name_S : constant String := Dwm_Types.Client_Name_Strings.To_String (Client.Name);
      begin
         for Rule of Config.Rules loop
            if (Rule.Title = null or else Contains (Name_S, Rule.Title.all))
              and then (Rule.Class = null or else Contains (Class_S, Rule.Class.all))
              and then (Rule.Instance = null or else Contains (Instance_S, Rule.Instance.all))
            then
               Client.Is_Floating := Rule.Is_Floating;
               Client.Tags := Client.Tags or Rule.Tags;
               Rule_Monitor := Dwm_State.Get_Monitors;
               while Rule_Monitor /= null and then Rule_Monitor.Number /= Rule.Monitor loop
                  Rule_Monitor := Rule_Monitor.Next;
               end loop;
               if Rule_Monitor /= null then
                  Client.Monitor := Rule_Monitor;
               end if;
            end if;
         end loop;
      end;
      if Class_Hint.Res_Class /= Interfaces.C.Strings.Null_Ptr then
         Ignore := Xlib_Thin.XFree (To_Address (Class_Hint.Res_Class));
      end if;
      if Class_Hint.Res_Name /= Interfaces.C.Strings.Null_Ptr then
         Ignore := Xlib_Thin.XFree (To_Address (Class_Hint.Res_Name));
      end if;
      Client.Tags := (if (Client.Tags and Tagmask) /= 0
                 then Client.Tags and Tagmask
                 else Client.Monitor.Tag_Set (Client.Monitor.Sel_Tags));
   end Apply_Rules;

   function Apply_Size_Hints
     (Client : Dwm_Types.Client_Access; Pos_X, Pos_Y, Width, Height : in out Integer;
      Interact : Boolean) return Boolean
   is
      Monitor : constant Dwm_Types.Monitor_Access := Client.Monitor;
      Base_Is_Min : Boolean;
   begin
      Width := Util.Max_Integer (1, Width);
      Height := Util.Max_Integer (1, Height);
      if Interact then
         if Pos_X > Dwm_State.Get_Screen_Width then
            Pos_X := Dwm_State.Get_Screen_Width - Dwm_Types.Outer_Width (Client);
         end if;
         if Pos_Y > Dwm_State.Get_Screen_Height then
            Pos_Y := Dwm_State.Get_Screen_Height - Dwm_Types.Outer_Height (Client);
         end if;
         if Pos_X + Width + 2 * Client.Border_Width < 0 then
            Pos_X := 0;
         end if;
         if Pos_Y + Height + 2 * Client.Border_Width < 0 then
            Pos_Y := 0;
         end if;
      else
         if Pos_X >= Monitor.Work_X + Monitor.Work_Width then
            Pos_X := Monitor.Work_X + Monitor.Work_Width - Dwm_Types.Outer_Width (Client);
         end if;
         if Pos_Y >= Monitor.Work_Y + Monitor.Work_Height then
            Pos_Y := Monitor.Work_Y + Monitor.Work_Height - Dwm_Types.Outer_Height (Client);
         end if;
         if Pos_X + Width + 2 * Client.Border_Width <= Monitor.Work_X then
            Pos_X := Monitor.Work_X;
         end if;
         if Pos_Y + Height + 2 * Client.Border_Width <= Monitor.Work_Y then
            Pos_Y := Monitor.Work_Y;
         end if;
      end if;
      if Height < Dwm_State.Get_Bar_Height then
         Height := Dwm_State.Get_Bar_Height;
      end if;
      if Width < Dwm_State.Get_Bar_Height then
         Width := Dwm_State.Get_Bar_Height;
      end if;
      if Config.Resize_Hints or else Client.Is_Floating
        or else Client.Monitor.Layout (Client.Monitor.Sel_Lt).Arrange = null
      then
         if not Client.Hints_Valid then
            Update_Size_Hints (Client);
         end if;
         Base_Is_Min := Client.Base_Width = Client.Min_Width and then Client.Base_Height = Client.Min_Height;
         if not Base_Is_Min then
            Width := Width - Client.Base_Width;
            Height := Height - Client.Base_Height;
         end if;
         if Client.Min_Aspect > 0.0 and then Client.Max_Aspect > 0.0 then
            if Client.Max_Aspect < Float (Width) / Float (Height) then
               Width := Integer (Float (Height) * Client.Max_Aspect + 0.5);
            elsif Client.Min_Aspect < Float (Height) / Float (Width) then
               Height := Integer (Float (Width) * Client.Min_Aspect + 0.5);
            end if;
         end if;
         if Base_Is_Min then
            Width := Width - Client.Base_Width;
            Height := Height - Client.Base_Height;
         end if;
         if Client.Inc_Width /= 0 then
            Width := Width - (Width rem Client.Inc_Width);
         end if;
         if Client.Inc_Height /= 0 then
            Height := Height - (Height rem Client.Inc_Height);
         end if;
         Width := Util.Max_Integer (Width + Client.Base_Width, Client.Min_Width);
         Height := Util.Max_Integer (Height + Client.Base_Height, Client.Min_Height);
         if Client.Max_Width /= 0 then
            Width := Util.Min_Integer (Width, Client.Max_Width);
         end if;
         if Client.Max_Height /= 0 then
            Height := Util.Min_Integer (Height, Client.Max_Height);
         end if;
      end if;
      return Pos_X /= Client.Pos_X or else Pos_Y /= Client.Pos_Y
        or else Width /= Client.Width or else Height /= Client.Height;
   end Apply_Size_Hints;

   procedure Arrange (Monitor : Dwm_Types.Monitor_Access) is
      Cur_Monitor : Dwm_Types.Monitor_Access;
   begin
      if Monitor /= null then
         Show_Hide (Monitor.Stack);
      else
         Cur_Monitor := Dwm_State.Get_Monitors;
         while Cur_Monitor /= null loop
            Show_Hide (Cur_Monitor.Stack);
            Cur_Monitor := Cur_Monitor.Next;
         end loop;
      end if;
      if Monitor /= null then
         Arrange_Mon (Monitor);
         Restack (Monitor);
      else
         Cur_Monitor := Dwm_State.Get_Monitors;
         while Cur_Monitor /= null loop
            Arrange_Mon (Cur_Monitor);
            Cur_Monitor := Cur_Monitor.Next;
         end loop;
      end if;
   end Arrange;

   procedure Arrange_Mon (Monitor : Dwm_Types.Monitor_Access) is
   begin
      Monitor.Lt_Symbol := Dwm_Types.Lt_Symbol_Strings.To_Bounded_String
        (Monitor.Layout (Monitor.Sel_Lt).Symbol.all, Ada.Strings.Right);
      if Monitor.Layout (Monitor.Sel_Lt).Arrange /= null then
         Monitor.Layout (Monitor.Sel_Lt).Arrange (Monitor);
      end if;
   end Arrange_Mon;

   procedure Attach (Client : Dwm_Types.Client_Access) is
   begin
      Client.Next := Client.Monitor.Clients;
      Client.Monitor.Clients := Client;
   end Attach;

   procedure Attach_Stack (Client : Dwm_Types.Client_Access) is
   begin
      Client.Stack_Next := Client.Monitor.Stack;
      Client.Monitor.Stack := Client;
   end Attach_Stack;

   function C_Ulong_At (Base : System.Address; Index : Natural) return Xlib_Thin.C_ULong is
      use type System.Storage_Elements.Storage_Offset;
   begin
      return To_C_Ulong_Access
        (Base + System.Storage_Elements.Storage_Offset (Index * 8)).all;
   end C_Ulong_At;

   procedure Configure (Client : Dwm_Types.Client_Access) is
      Event : aliased Xlib_Thin.XEvent;
      Configure_Event : Xlib_Thin.XConfigureEvent with Address => Event'Address;
      pragma Import (Ada, Configure_Event);
      Ignore : Xlib_Thin.C_Int;
   begin
      Configure_Event.Event_Type := Xlib_Thin.ConfigureNotify;
      Configure_Event.Disp := Dwm_State.Get_Display;
      Configure_Event.Event := Client.Window;
      Configure_Event.Win := Client.Window;
      Configure_Event.X := Xlib_Thin.C_Int (Client.Pos_X);
      Configure_Event.Y := Xlib_Thin.C_Int (Client.Pos_Y);
      Configure_Event.Width := Xlib_Thin.C_Int (Client.Width);
      Configure_Event.Height := Xlib_Thin.C_Int (Client.Height);
      Configure_Event.Border_Width := Xlib_Thin.C_Int (Client.Border_Width);
      Configure_Event.Above := Xlib_Thin.None;
      Configure_Event.Override_Redirect := 0;
      Ignore := Xlib_Thin.XSendEvent
        (Dwm_State.Get_Display, Client.Window, 0, Xlib_Thin.StructureNotifyMask, Event'Access);
   end Configure;

   procedure Configure_Request (Event : access Xlib_Thin.XEvent) is
      Request_Event : Xlib_Thin.XConfigureRequestEvent with Address => Event.all'Address;
      pragma Import (Ada, Request_Event);
      Client  : Dwm_Types.Client_Access;
      Monitor : Dwm_Types.Monitor_Access;
      Changes : aliased Xlib_Thin.XWindowChanges;
      Ignore : Xlib_Thin.C_Int;
   begin
      Client := Win_To_Client (Request_Event.Win);
      if Client /= null then
         if (Request_Event.Value_Mask and Xlib_Thin.C_ULong (Xlib_Thin.CWBorderWidth)) /= 0 then
            Client.Border_Width := Integer (Request_Event.Border_Width);
         elsif Client.Is_Floating
           or else Dwm_State.Get_Selected_Monitor.Layout (Dwm_State.Get_Selected_Monitor.Sel_Lt).Arrange = null
         then
            Monitor := Client.Monitor;
            if (Request_Event.Value_Mask and Xlib_Thin.C_ULong (Xlib_Thin.CWX)) /= 0 then
               Client.Old_X := Client.Pos_X;
               Client.Pos_X := Monitor.Screen_X + Integer (Request_Event.X);
            end if;
            if (Request_Event.Value_Mask and Xlib_Thin.C_ULong (Xlib_Thin.CWY)) /= 0 then
               Client.Old_Y := Client.Pos_Y;
               Client.Pos_Y := Monitor.Screen_Y + Integer (Request_Event.Y);
            end if;
            if (Request_Event.Value_Mask and Xlib_Thin.C_ULong (Xlib_Thin.CWWidth)) /= 0 then
               Client.Old_Width := Client.Width;
               Client.Width := Integer (Request_Event.Width);
            end if;
            if (Request_Event.Value_Mask and Xlib_Thin.C_ULong (Xlib_Thin.CWHeight)) /= 0 then
               Client.Old_Height := Client.Height;
               Client.Height := Integer (Request_Event.Height);
            end if;
            if (Client.Pos_X + Client.Width) > Monitor.Screen_X + Monitor.Screen_Width
              and then Client.Is_Floating
            then
               Client.Pos_X := Monitor.Screen_X + (Monitor.Screen_Width / 2 - Dwm_Types.Outer_Width (Client) / 2);
            end if;
            if (Client.Pos_Y + Client.Height) > Monitor.Screen_Y + Monitor.Screen_Height
              and then Client.Is_Floating
            then
               Client.Pos_Y :=
                 Monitor.Screen_Y + (Monitor.Screen_Height / 2 - Dwm_Types.Outer_Height (Client) / 2);
            end if;
            if (Request_Event.Value_Mask
                  and (Xlib_Thin.C_ULong (Xlib_Thin.CWX) or Xlib_Thin.C_ULong (Xlib_Thin.CWY))) /= 0
              and then (Request_Event.Value_Mask
                          and (Xlib_Thin.C_ULong (Xlib_Thin.CWWidth) or Xlib_Thin.C_ULong (Xlib_Thin.CWHeight)))
                        = 0
            then
               Configure (Client);
            end if;
            if Dwm_Types.Is_Visible (Client) then
               Ignore := Xlib_Thin.XMoveResizeWindow
                 (Dwm_State.Get_Display, Client.Window, Xlib_Thin.C_Int (Client.Pos_X), Xlib_Thin.C_Int (Client.Pos_Y),
                  Xlib_Thin.C_UInt (Client.Width), Xlib_Thin.C_UInt (Client.Height));
            end if;
         else
            Configure (Client);
         end if;
      else
         Changes.X := Request_Event.X;
         Changes.Y := Request_Event.Y;
         Changes.Width := Request_Event.Width;
         Changes.Height := Request_Event.Height;
         Changes.Border_Width := Request_Event.Border_Width;
         Changes.Sibling := Request_Event.Above;
         Changes.Stack_Mode := Request_Event.Detail;
         Ignore := Xlib_Thin.XConfigureWindow
           (Dwm_State.Get_Display, Request_Event.Win, Xlib_Thin.C_UInt (Request_Event.Value_Mask), Changes'Access);
      end if;
      Ignore := Xlib_Thin.XSync (Dwm_State.Get_Display, 0);
   end Configure_Request;

   procedure Detach (Client : Dwm_Types.Client_Access) is
      Cur, Prev : Dwm_Types.Client_Access := null;
   begin
      Cur := Client.Monitor.Clients;
      while Cur /= null and then Cur /= Client loop
         Prev := Cur;
         Cur := Cur.Next;
      end loop;
      if Prev = null then
         Client.Monitor.Clients := Client.Next;
      else
         Prev.Next := Client.Next;
      end if;
   end Detach;

   procedure Detach_Stack (Client : Dwm_Types.Client_Access) is
      Cur, Prev, New_Selected : Dwm_Types.Client_Access := null;
   begin
      Cur := Client.Monitor.Stack;
      while Cur /= null and then Cur /= Client loop
         Prev := Cur;
         Cur := Cur.Stack_Next;
      end loop;
      if Prev = null then
         Client.Monitor.Stack := Client.Stack_Next;
      else
         Prev.Stack_Next := Client.Stack_Next;
      end if;

      if Client = Client.Monitor.Selected_Client then
         New_Selected := Client.Monitor.Stack;
         while New_Selected /= null and then not Dwm_Types.Is_Visible (New_Selected) loop
            New_Selected := New_Selected.Stack_Next;
         end loop;
         Client.Monitor.Selected_Client := New_Selected;
      end if;
   end Detach_Stack;

   procedure Focus (Client : Dwm_Types.Client_Access) is
      Target : Dwm_Types.Client_Access := Client;
      Ignore : Xlib_Thin.C_Int;
   begin
      if Target = null or else not Dwm_Types.Is_Visible (Target) then
         Target := Dwm_State.Get_Selected_Monitor.Stack;
         while Target /= null and then not Dwm_Types.Is_Visible (Target) loop
            Target := Target.Stack_Next;
         end loop;
      end if;
      if Dwm_State.Get_Selected_Monitor.Selected_Client /= null
        and then Dwm_State.Get_Selected_Monitor.Selected_Client /= Target
      then
         Unfocus (Dwm_State.Get_Selected_Monitor.Selected_Client, False);
      end if;
      if Target /= null then
         if Target.Monitor /= Dwm_State.Get_Selected_Monitor then
            Dwm_State.Set_Selected_Monitor (Target.Monitor);
         end if;
         if Target.Is_Urgent then
            Set_Urgent (Target, False);
         end if;
         Detach_Stack (Target);
         Attach_Stack (Target);
         Grab_Buttons (Target, True);
         Ignore := Xlib_Thin.XSetWindowBorder
           (Dwm_State.Get_Display, Target.Window,
            Dwm_State.Get_Scheme (Dwm_Types.Scheme_Sel) (Dwm_Types.Col_Border).Pixel);
         Set_Focus (Target);
      else
         Ignore := Xlib_Thin.XSetInputFocus
           (Dwm_State.Get_Display, Dwm_State.Get_Root, Xlib_Thin.RevertToPointerRoot, Xlib_Thin.Current_Time);
         Ignore := Xlib_Thin.XDeleteProperty
           (Dwm_State.Get_Display, Dwm_State.Get_Root, Dwm_State.Get_Net_Atom (Dwm_State.Net_Active_Window));
      end if;
      Dwm_State.Get_Selected_Monitor.Selected_Client := Target;
      Dwm_Bar.Draw_Bars;
   end Focus;

   procedure Grab_Buttons (Client : Dwm_Types.Client_Access; Focused : Boolean) is
      Modifiers : constant array (0 .. 3) of Xlib_Thin.C_UInt :=
        (0, Xlib_Thin.LockMask, Dwm_State.Get_Num_Lock_Mask, Dwm_State.Get_Num_Lock_Mask or Xlib_Thin.LockMask);
      Button_Mask : constant Xlib_Thin.C_UInt :=
        Xlib_Thin.C_UInt (Xlib_Thin.ButtonPressMask) or Xlib_Thin.C_UInt (Xlib_Thin.ButtonReleaseMask);
      Ignore : Xlib_Thin.C_Int;
   begin
      Update_Num_Lock_Mask;
      Ignore := Xlib_Thin.XUngrabButton
        (Dwm_State.Get_Display, Xlib_Thin.Any_Button, Xlib_Thin.AnyModifier, Client.Window);
      if not Focused then
         Ignore := Xlib_Thin.XGrabButton
           (Dwm_State.Get_Display, Xlib_Thin.Any_Button, Xlib_Thin.AnyModifier, Client.Window, 0,
            Button_Mask, Xlib_Thin.GrabModeSync, Xlib_Thin.GrabModeSync, 0, 0);
      end if;
      if Dwm_State.Get_Buttons /= null then
         for Binding of Dwm_State.Get_Buttons.all loop
            if Binding.Click = Dwm_Types.Clk_Client_Win then
               for Mod_Bits of Modifiers loop
                  Ignore := Xlib_Thin.XGrabButton
                    (Dwm_State.Get_Display, Binding.Button, Binding.Modifier or Mod_Bits, Client.Window, 0,
                     Button_Mask, Xlib_Thin.GrabModeAsync, Xlib_Thin.GrabModeSync, 0, 0);
               end loop;
            end if;
         end loop;
      end if;
   end Grab_Buttons;

   procedure Grab_Keys is
      Modifiers : constant array (0 .. 3) of Xlib_Thin.C_UInt :=
        (0, Xlib_Thin.LockMask, Dwm_State.Get_Num_Lock_Mask, Dwm_State.Get_Num_Lock_Mask or Xlib_Thin.LockMask);
      Start_Keycode, End_Keycode, Syms_Per_Keycode : aliased Xlib_Thin.C_Int;
      Keysym_Table : System.Address;
      Ignore : Xlib_Thin.C_Int;
   begin
      Update_Num_Lock_Mask;
      Ignore := Xlib_Thin.XUngrabKey
        (Dwm_State.Get_Display, Xlib_Thin.Any_Key, Xlib_Thin.AnyModifier, Dwm_State.Get_Root);
      Ignore := Xlib_Thin.XDisplayKeycodes (Dwm_State.Get_Display, Start_Keycode'Access, End_Keycode'Access);
      Keysym_Table := Xlib_Thin.XGetKeyboardMapping
        (Dwm_State.Get_Display, Xlib_Thin.KeyCode (Start_Keycode), End_Keycode - Start_Keycode + 1,
         Syms_Per_Keycode'Access);
      if Keysym_Table = System.Null_Address then
         return;
      end if;
      if Dwm_State.Get_Keys /= null then
         for Keycode in Integer (Start_Keycode) .. Integer (End_Keycode) loop
            for Key_Def of Dwm_State.Get_Keys.all loop
               if Xlib_Thin.KeySym
                    (C_Ulong_At
                       (Keysym_Table, (Keycode - Integer (Start_Keycode)) * Integer (Syms_Per_Keycode)))
                 = Key_Def.Sym
               then
                  for Mod_Bits of Modifiers loop
                     Ignore := Xlib_Thin.XGrabKey
                       (Dwm_State.Get_Display, Xlib_Thin.C_Int (Keycode), Key_Def.Modifier or Mod_Bits,
                        Dwm_State.Get_Root, 1, Xlib_Thin.GrabModeAsync, Xlib_Thin.GrabModeAsync);
                  end loop;
               end if;
            end loop;
         end loop;
      end if;
      Ignore := Xlib_Thin.XFree (Keysym_Table);
   end Grab_Keys;

   function Key_Code_At (Base : System.Address; Index : Natural) return Xlib_Thin.KeyCode is
      use type System.Storage_Elements.Storage_Offset;
   begin
      return To_Key_Code_Access
        (Base + System.Storage_Elements.Storage_Offset (Index)).all;
   end Key_Code_At;

   procedure Manage (Window : Xlib_Thin.Window; Attrs : Xlib_Thin.XWindowAttributes) is
      Client : constant Dwm_Types.Client_Access := new Dwm_Types.Client;
      Trans_Client : Dwm_Types.Client_Access := null;
      Trans : aliased Xlib_Thin.Window := Xlib_Thin.None;
      Changes : aliased Xlib_Thin.XWindowChanges;
      Window_Buf : aliased Xlib_Thin.Window;
      Ignore : Xlib_Thin.C_Int;
   begin
      Client.Window := Window;
      Client.Pos_X := Integer (Attrs.X);
      Client.Old_X := Client.Pos_X;
      Client.Pos_Y := Integer (Attrs.Y);
      Client.Old_Y := Client.Pos_Y;
      Client.Width := Integer (Attrs.Width);
      Client.Old_Width := Client.Width;
      Client.Height := Integer (Attrs.Height);
      Client.Old_Height := Client.Height;
      Client.Old_Border_Width := Integer (Attrs.Border_Width);

      Update_Title (Client);
      if Xlib_Thin.XGetTransientForHint (Dwm_State.Get_Display, Window, Trans'Access) /= 0 then
         Trans_Client := Win_To_Client (Trans);
      end if;
      if Trans_Client /= null then
         Client.Monitor := Trans_Client.Monitor;
         Client.Tags := Trans_Client.Tags;
      else
         Client.Monitor := Dwm_State.Get_Selected_Monitor;
         Apply_Rules (Client);
      end if;

      if Client.Pos_X + Dwm_Types.Outer_Width (Client) > Client.Monitor.Work_X + Client.Monitor.Work_Width then
         Client.Pos_X := Client.Monitor.Work_X + Client.Monitor.Work_Width - Dwm_Types.Outer_Width (Client);
      end if;
      if Client.Pos_Y + Dwm_Types.Outer_Height (Client) > Client.Monitor.Work_Y + Client.Monitor.Work_Height then
         Client.Pos_Y := Client.Monitor.Work_Y + Client.Monitor.Work_Height - Dwm_Types.Outer_Height (Client);
      end if;
      Client.Pos_X := Util.Max_Integer (Client.Pos_X, Client.Monitor.Work_X);
      Client.Pos_Y := Util.Max_Integer (Client.Pos_Y, Client.Monitor.Work_Y);
      Client.Border_Width := Config.Border_Px;

      Changes.Border_Width := Xlib_Thin.C_Int (Client.Border_Width);
      Ignore := Xlib_Thin.XConfigureWindow (Dwm_State.Get_Display, Window, Xlib_Thin.CWBorderWidth, Changes'Access);
      Ignore := Xlib_Thin.XSetWindowBorder
        (Dwm_State.Get_Display, Window, Dwm_State.Get_Scheme (Dwm_Types.Scheme_Norm) (Dwm_Types.Col_Border).Pixel);
      Configure (Client);
      Update_Window_Type (Client);
      Update_Size_Hints (Client);
      Update_Wm_Hints (Client);
      Ignore := Xlib_Thin.XSelectInput
        (Dwm_State.Get_Display, Window,
         Xlib_Thin.EnterWindowMask or Xlib_Thin.FocusChangeMask or Xlib_Thin.PropertyChangeMask
           or Xlib_Thin.StructureNotifyMask);
      Grab_Buttons (Client, False);
      if not Client.Is_Floating then
         Client.Is_Floating := Trans /= Xlib_Thin.None or else Client.Is_Fixed;
         Client.Old_State := Client.Is_Floating;
      end if;
      if Client.Is_Floating then
         Ignore := Xlib_Thin.XRaiseWindow (Dwm_State.Get_Display, Client.Window);
      end if;
      Attach (Client);
      Attach_Stack (Client);
      Window_Buf := Client.Window;
      Ignore := Xlib_Thin.XChangeProperty
        (Dwm_State.Get_Display, Dwm_State.Get_Root, Dwm_State.Get_Net_Atom (Dwm_State.Net_Client_List),
         Xlib_Thin.XA_WINDOW, 32, Xlib_Thin.PropModeAppend, Window_Buf'Address, 1);
      Ignore := Xlib_Thin.XMoveResizeWindow
        (Dwm_State.Get_Display, Client.Window,
         Xlib_Thin.C_Int (Client.Pos_X + 2 * Dwm_State.Get_Screen_Width), Xlib_Thin.C_Int (Client.Pos_Y),
         Xlib_Thin.C_UInt (Client.Width), Xlib_Thin.C_UInt (Client.Height));
      Set_Client_State (Client, Xlib_Thin.NormalState);
      if Client.Monitor = Dwm_State.Get_Selected_Monitor then
         Unfocus (Dwm_State.Get_Selected_Monitor.Selected_Client, False);
      end if;
      Client.Monitor.Selected_Client := Client;
      Arrange (Client.Monitor);
      Ignore := Xlib_Thin.XMapWindow (Dwm_State.Get_Display, Client.Window);
      Focus (null);
   end Manage;

   procedure Map_Request (Event : access Xlib_Thin.XEvent) is
      Request_Event : Xlib_Thin.XMapRequestEvent with Address => Event.all'Address;
      pragma Import (Ada, Request_Event);
      Attrs : aliased Xlib_Thin.XWindowAttributes;
      Ok : Xlib_Thin.C_Int;
   begin
      Ok := Xlib_Thin.XGetWindowAttributes (Dwm_State.Get_Display, Request_Event.Win, Attrs'Access);
      if Ok = 0 or else Attrs.Override_Redirect /= 0 then
         return;
      end if;
      if Win_To_Client (Request_Event.Win) = null then
         Manage (Request_Event.Win, Attrs);
      end if;
   end Map_Request;

   function Next_Tiled (Client : Dwm_Types.Client_Access) return Dwm_Types.Client_Access is
      Cur : Dwm_Types.Client_Access := Client;
   begin
      while Cur /= null and then (Cur.Is_Floating or else not Dwm_Types.Is_Visible (Cur)) loop
         Cur := Cur.Next;
      end loop;
      return Cur;
   end Next_Tiled;

   procedure Pop (Client : Dwm_Types.Client_Access) is
   begin
      Detach (Client);
      Attach (Client);
      Focus (Client);
      Arrange (Client.Monitor);
   end Pop;

   procedure Resize
     (Client : Dwm_Types.Client_Access; Pos_X, Pos_Y, Width, Height : Integer; Interact : Boolean)
   is
      Nx : Integer := Pos_X;
      Ny : Integer := Pos_Y;
      Nw : Integer := Width;
      Nh : Integer := Height;
   begin
      if Apply_Size_Hints (Client, Nx, Ny, Nw, Nh, Interact) then
         Resize_Client (Client, Nx, Ny, Nw, Nh);
      end if;
   end Resize;

   procedure Resize_Client (Client : Dwm_Types.Client_Access; Pos_X, Pos_Y, Width, Height : Integer) is
      Changes : aliased Xlib_Thin.XWindowChanges;
      Ignore : Xlib_Thin.C_Int;
   begin
      Client.Old_X := Client.Pos_X;
      Client.Pos_X := Pos_X;
      Client.Old_Y := Client.Pos_Y;
      Client.Pos_Y := Pos_Y;
      Client.Old_Width := Client.Width;
      Client.Width := Width;
      Client.Old_Height := Client.Height;
      Client.Height := Height;
      Changes.X := Xlib_Thin.C_Int (Pos_X);
      Changes.Y := Xlib_Thin.C_Int (Pos_Y);
      Changes.Width := Xlib_Thin.C_Int (Width);
      Changes.Height := Xlib_Thin.C_Int (Height);
      Changes.Border_Width := Xlib_Thin.C_Int (Client.Border_Width);
      Ignore := Xlib_Thin.XConfigureWindow
        (Dwm_State.Get_Display, Client.Window,
         Xlib_Thin.CWX or Xlib_Thin.CWY or Xlib_Thin.CWWidth or Xlib_Thin.CWHeight
           or Xlib_Thin.CWBorderWidth,
         Changes'Access);
      Configure (Client);
      Ignore := Xlib_Thin.XSync (Dwm_State.Get_Display, 0);
   end Resize_Client;

   procedure Restack (Monitor : Dwm_Types.Monitor_Access) is
      Changes : aliased Xlib_Thin.XWindowChanges;
      Event : aliased Xlib_Thin.XEvent;
      Client : Dwm_Types.Client_Access;
      Ignore : Xlib_Thin.C_Int;
   begin
      Dwm_Bar.Draw_Bar (Monitor);
      if Monitor.Selected_Client = null then
         return;
      end if;
      if Monitor.Selected_Client.Is_Floating or else Monitor.Layout (Monitor.Sel_Lt).Arrange = null then
         Ignore := Xlib_Thin.XRaiseWindow (Dwm_State.Get_Display, Monitor.Selected_Client.Window);
      end if;
      if Monitor.Layout (Monitor.Sel_Lt).Arrange /= null then
         Changes.Stack_Mode := Xlib_Thin.Below;
         Changes.Sibling := Monitor.Bar_Window;
         Client := Monitor.Stack;
         while Client /= null loop
            if not Client.Is_Floating and then Dwm_Types.Is_Visible (Client) then
               Ignore := Xlib_Thin.XConfigureWindow
                 (Dwm_State.Get_Display, Client.Window, Xlib_Thin.CWSibling or Xlib_Thin.CWStackMode, Changes'Access);
               Changes.Sibling := Client.Window;
            end if;
            Client := Client.Stack_Next;
         end loop;
      end if;
      Ignore := Xlib_Thin.XSync (Dwm_State.Get_Display, 0);
      while Xlib_Thin.XCheckMaskEvent (Dwm_State.Get_Display, Xlib_Thin.EnterWindowMask, Event'Access) /= 0 loop
         null;
      end loop;
   end Restack;

   function Send_Event (Client : Dwm_Types.Client_Access; Proto : Xlib_Thin.Atom) return Boolean is
      Protocols : aliased System.Address := System.Null_Address;
      Count : aliased Xlib_Thin.C_Int;
      Exists : Boolean := False;
      Event : aliased Xlib_Thin.XEvent;
      Message_Event : Xlib_Thin.XClientMessageEvent with Address => Event'Address;
      pragma Import (Ada, Message_Event);
      Ok : Xlib_Thin.C_Int;
      Ignore : Xlib_Thin.C_Int;
   begin
      Ok := Xlib_Thin.XGetWMProtocols (Dwm_State.Get_Display, Client.Window, Protocols'Access, Count'Access);
      if Ok /= 0 then
         for Idx in 0 .. Integer (Count) - 1 loop
            if Xlib_Thin.Atom (C_Ulong_At (Protocols, Idx)) = Proto then
               Exists := True;
            end if;
         end loop;
         Ignore := Xlib_Thin.XFree (Protocols);
      end if;
      if Exists then
         Message_Event.Event_Type := Xlib_Thin.ClientMessage;
         Message_Event.Win := Client.Window;
         Message_Event.Message_Type := Dwm_State.Get_Wm_Atom (Dwm_State.WM_Protocols);
         Message_Event.Format := 32;
         Message_Event.Data.L (0) := Xlib_Thin.C_Long (Proto);
         Message_Event.Data.L (1) := Xlib_Thin.C_Long (Xlib_Thin.Current_Time);
         Ignore := Xlib_Thin.XSendEvent
           (Dwm_State.Get_Display, Client.Window, 0, Xlib_Thin.NoEventMask, Event'Access);
      end if;
      return Exists;
   end Send_Event;

   procedure Send_Mon (Client : Dwm_Types.Client_Access; Monitor : Dwm_Types.Monitor_Access) is
   begin
      if Client.Monitor = Monitor then
         return;
      end if;
      Unfocus (Client, True);
      Detach (Client);
      Detach_Stack (Client);
      Client.Monitor := Monitor;
      Client.Tags := Monitor.Tag_Set (Monitor.Sel_Tags);
      Attach (Client);
      Attach_Stack (Client);
      if Client.Is_Full_Screen then
         Resize_Client (Client, Monitor.Screen_X, Monitor.Screen_Y, Monitor.Screen_Width, Monitor.Screen_Height);
      end if;
      Focus (null);
      Arrange (null);
   end Send_Mon;

   procedure Set_Client_State (Client : Dwm_Types.Client_Access; State : Long_Integer) is
      type Data_Pair is array (0 .. 1) of Xlib_Thin.C_ULong;
      Data : aliased Data_Pair := (Xlib_Thin.C_ULong (State), Xlib_Thin.None);
      Ignore : Xlib_Thin.C_Int;
   begin
      Ignore := Xlib_Thin.XChangeProperty
        (Dwm_State.Get_Display, Client.Window, Dwm_State.Get_Wm_Atom (Dwm_State.WM_State),
         Dwm_State.Get_Wm_Atom (Dwm_State.WM_State), 32, Xlib_Thin.PropModeReplace, Data'Address, 2);
   end Set_Client_State;

   procedure Set_Focus (Client : Dwm_Types.Client_Access) is
      Window_Buf : aliased Xlib_Thin.Window := Client.Window;
      Ignore  : Xlib_Thin.C_Int;
      Ignore_Bool : Boolean;
   begin
      if not Client.Never_Focus then
         Ignore := Xlib_Thin.XSetInputFocus
           (Dwm_State.Get_Display, Client.Window, Xlib_Thin.RevertToPointerRoot, Xlib_Thin.Current_Time);
      end if;
      Ignore := Xlib_Thin.XChangeProperty
        (Dwm_State.Get_Display, Dwm_State.Get_Root, Dwm_State.Get_Net_Atom (Dwm_State.Net_Active_Window),
         Xlib_Thin.XA_WINDOW, 32, Xlib_Thin.PropModeReplace, Window_Buf'Address, 1);
      Ignore_Bool := Send_Event (Client, Dwm_State.Get_Wm_Atom (Dwm_State.WM_Take_Focus));
   end Set_Focus;

   procedure Set_Full_Screen (Client : Dwm_Types.Client_Access; Fullscreen : Boolean) is
      Fs_Atom : aliased Xlib_Thin.Atom;
      Ignore  : Xlib_Thin.C_Int;
   begin
      if Fullscreen and then not Client.Is_Full_Screen then
         Fs_Atom := Dwm_State.Get_Net_Atom (Dwm_State.Net_WM_Fullscreen);
         Ignore := Xlib_Thin.XChangeProperty
           (Dwm_State.Get_Display, Client.Window, Dwm_State.Get_Net_Atom (Dwm_State.Net_WM_State),
            Xlib_Thin.XA_ATOM, 32, Xlib_Thin.PropModeReplace, Fs_Atom'Address, 1);
         Client.Is_Full_Screen := True;
         Client.Old_State := Client.Is_Floating;
         Client.Old_Border_Width := Client.Border_Width;
         Client.Border_Width := 0;
         Client.Is_Floating := True;
         Resize_Client
           (Client, Client.Monitor.Screen_X, Client.Monitor.Screen_Y,
            Client.Monitor.Screen_Width, Client.Monitor.Screen_Height);
         Ignore := Xlib_Thin.XRaiseWindow (Dwm_State.Get_Display, Client.Window);
      elsif not Fullscreen and then Client.Is_Full_Screen then
         Ignore := Xlib_Thin.XChangeProperty
           (Dwm_State.Get_Display, Client.Window, Dwm_State.Get_Net_Atom (Dwm_State.Net_WM_State),
            Xlib_Thin.XA_ATOM, 32, Xlib_Thin.PropModeReplace, System.Null_Address, 0);
         Client.Is_Full_Screen := False;
         Client.Is_Floating := Client.Old_State;
         Client.Border_Width := Client.Old_Border_Width;
         Client.Pos_X := Client.Old_X;
         Client.Pos_Y := Client.Old_Y;
         Client.Width := Client.Old_Width;
         Client.Height := Client.Old_Height;
         Resize_Client (Client, Client.Pos_X, Client.Pos_Y, Client.Width, Client.Height);
         Arrange (Client.Monitor);
      end if;
   end Set_Full_Screen;

   procedure Set_Urgent (Client : Dwm_Types.Client_Access; Urgent : Boolean) is
      Hints : access Xlib_Thin.XWMHints;
      Ignore : Xlib_Thin.C_Int;
   begin
      Client.Is_Urgent := Urgent;
      Hints := Xlib_Thin.XGetWMHints (Dwm_State.Get_Display, Client.Window);
      if Hints = null then
         return;
      end if;
      if Urgent then
         Hints.Flags := Hints.Flags or Xlib_Thin.XUrgencyHint;
      else
         Hints.Flags := Hints.Flags and not Xlib_Thin.XUrgencyHint;
      end if;
      Ignore := Xlib_Thin.XSetWMHints (Dwm_State.Get_Display, Client.Window, Hints);
      Ignore := Xlib_Thin.XFree (Hints.all'Address);
   end Set_Urgent;

   procedure Show_Hide (Client : Dwm_Types.Client_Access) is
      Ignore : Xlib_Thin.C_Int;
   begin
      if Client = null then
         return;
      end if;
      if Dwm_Types.Is_Visible (Client) then
         Ignore := Xlib_Thin.XMoveWindow
           (Dwm_State.Get_Display, Client.Window, Xlib_Thin.C_Int (Client.Pos_X), Xlib_Thin.C_Int (Client.Pos_Y));
         if (Client.Monitor.Layout (Client.Monitor.Sel_Lt).Arrange = null or else Client.Is_Floating)
           and then not Client.Is_Full_Screen
         then
            Resize (Client, Client.Pos_X, Client.Pos_Y, Client.Width, Client.Height, False);
         end if;
         Show_Hide (Client.Stack_Next);
      else
         Show_Hide (Client.Stack_Next);
         Ignore := Xlib_Thin.XMoveWindow
           (Dwm_State.Get_Display, Client.Window,
            Xlib_Thin.C_Int (-(2 * Dwm_Types.Outer_Width (Client))), Xlib_Thin.C_Int (Client.Pos_Y));
      end if;
   end Show_Hide;

   procedure Unfocus (Client : Dwm_Types.Client_Access; Clear_Focus : Boolean) is
      Ignore : Xlib_Thin.C_Int;
   begin
      if Client = null then
         return;
      end if;
      Grab_Buttons (Client, False);
      Ignore := Xlib_Thin.XSetWindowBorder
        (Dwm_State.Get_Display, Client.Window,
         Dwm_State.Get_Scheme (Dwm_Types.Scheme_Norm) (Dwm_Types.Col_Border).Pixel);
      if Clear_Focus then
         Ignore := Xlib_Thin.XSetInputFocus
           (Dwm_State.Get_Display, Dwm_State.Get_Root, Xlib_Thin.RevertToPointerRoot, Xlib_Thin.Current_Time);
         Ignore := Xlib_Thin.XDeleteProperty
           (Dwm_State.Get_Display, Dwm_State.Get_Root, Dwm_State.Get_Net_Atom (Dwm_State.Net_Active_Window));
      end if;
   end Unfocus;

   procedure Unmanage (Client : Dwm_Types.Client_Access; Destroyed : Boolean) is
      Monitor : constant Dwm_Types.Monitor_Access := Client.Monitor;
      Changes : aliased Xlib_Thin.XWindowChanges;
      Freed_Client : Dwm_Types.Client_Access := Client;
      Ignore : Xlib_Thin.C_Int;
      Ignore_Handler : Xlib_Thin.XErrorHandler;
   begin
      Detach (Client);
      Detach_Stack (Client);
      if not Destroyed then
         Changes.Border_Width := Xlib_Thin.C_Int (Client.Old_Border_Width);
         Ignore := Xlib_Thin.XGrabServer (Dwm_State.Get_Display);
         Ignore_Handler := Xlib_Thin.XSetErrorHandler (X_Error_Dummy'Access);
         Ignore := Xlib_Thin.XSelectInput (Dwm_State.Get_Display, Client.Window, Xlib_Thin.NoEventMask);
         Ignore := Xlib_Thin.XConfigureWindow
           (Dwm_State.Get_Display, Client.Window, Xlib_Thin.CWBorderWidth, Changes'Access);
         Ignore := Xlib_Thin.XUngrabButton
           (Dwm_State.Get_Display, Xlib_Thin.Any_Button, Xlib_Thin.AnyModifier, Client.Window);
         Set_Client_State (Client, Xlib_Thin.WithdrawnState);
         Ignore := Xlib_Thin.XSync (Dwm_State.Get_Display, 0);
         Ignore_Handler := Xlib_Thin.XSetErrorHandler (X_Error'Access);
         Ignore := Xlib_Thin.XUngrabServer (Dwm_State.Get_Display);
      end if;
      Free_Client (Freed_Client);
      Focus (null);
      Update_Client_List;
      Arrange (Monitor);
   end Unmanage;

   procedure Update_Client_List is
      Monitor : Dwm_Types.Monitor_Access := Dwm_State.Get_Monitors;
      Client : Dwm_Types.Client_Access;
      Window_Buf : aliased Xlib_Thin.Window;
      Ignore : Xlib_Thin.C_Int;
   begin
      Ignore := Xlib_Thin.XDeleteProperty
        (Dwm_State.Get_Display, Dwm_State.Get_Root, Dwm_State.Get_Net_Atom (Dwm_State.Net_Client_List));
      while Monitor /= null loop
         Client := Monitor.Clients;
         while Client /= null loop
            Window_Buf := Client.Window;
            Ignore := Xlib_Thin.XChangeProperty
              (Dwm_State.Get_Display, Dwm_State.Get_Root, Dwm_State.Get_Net_Atom (Dwm_State.Net_Client_List),
               Xlib_Thin.XA_WINDOW, 32, Xlib_Thin.PropModeAppend, Window_Buf'Address, 1);
            Client := Client.Next;
         end loop;
         Monitor := Monitor.Next;
      end loop;
   end Update_Client_List;

   procedure Update_Num_Lock_Mask is
      Modmap : Xlib_Thin.XModifierKeymap_Access;
      Ignore : Xlib_Thin.C_Int;
   begin
      Dwm_State.Set_Num_Lock_Mask (0);
      Modmap := Xlib_Thin.XGetModifierMapping (Dwm_State.Get_Display);
      for Bit in 0 .. 7 loop
         for Slot in 0 .. Integer (Modmap.Max_Keypermod) - 1 loop
            if Key_Code_At (Modmap.Modifiermap, Bit * Integer (Modmap.Max_Keypermod) + Slot)
              = Xlib_Thin.XKeysymToKeycode (Dwm_State.Get_Display, Keysyms.XK_Num_Lock)
            then
               Dwm_State.Set_Num_Lock_Mask (Xlib_Thin.C_UInt (2 ** Bit));
            end if;
         end loop;
      end loop;
      Ignore := Xlib_Thin.XFreeModifiermap (Modmap);
   end Update_Num_Lock_Mask;

   procedure Update_Size_Hints (Client : Dwm_Types.Client_Access) is
      Size   : aliased Xlib_Thin.XSizeHints;
      Msize  : aliased Xlib_Thin.C_Long;
      Ok     : Xlib_Thin.C_Int;
   begin
      Ok := Xlib_Thin.XGetWMNormalHints (Dwm_State.Get_Display, Client.Window, Size'Access, Msize'Access);
      if Ok = 0 then
         Size.Flags := Xlib_Thin.PSize;
      end if;
      if (Size.Flags and Xlib_Thin.PBaseSize) /= 0 then
         Client.Base_Width := Integer (Size.Base_Width);
         Client.Base_Height := Integer (Size.Base_Height);
      elsif (Size.Flags and Xlib_Thin.PMinSize) /= 0 then
         Client.Base_Width := Integer (Size.Min_Width);
         Client.Base_Height := Integer (Size.Min_Height);
      else
         Client.Base_Width := 0;
         Client.Base_Height := 0;
      end if;
      if (Size.Flags and Xlib_Thin.PResizeInc) /= 0 then
         Client.Inc_Width := Integer (Size.Width_Inc);
         Client.Inc_Height := Integer (Size.Height_Inc);
      else
         Client.Inc_Width := 0;
         Client.Inc_Height := 0;
      end if;
      if (Size.Flags and Xlib_Thin.PMaxSize) /= 0 then
         Client.Max_Width := Integer (Size.Max_Width);
         Client.Max_Height := Integer (Size.Max_Height);
      else
         Client.Max_Width := 0;
         Client.Max_Height := 0;
      end if;
      if (Size.Flags and Xlib_Thin.PMinSize) /= 0 then
         Client.Min_Width := Integer (Size.Min_Width);
         Client.Min_Height := Integer (Size.Min_Height);
      elsif (Size.Flags and Xlib_Thin.PBaseSize) /= 0 then
         Client.Min_Width := Integer (Size.Base_Width);
         Client.Min_Height := Integer (Size.Base_Height);
      else
         Client.Min_Width := 0;
         Client.Min_Height := 0;
      end if;
      if (Size.Flags and Xlib_Thin.PAspect) /= 0 then
         Client.Min_Aspect := Float (Size.Min_Aspect.Den) / Float (Size.Min_Aspect.Num);
         Client.Max_Aspect := Float (Size.Max_Aspect.Num) / Float (Size.Max_Aspect.Den);
      else
         Client.Max_Aspect := 0.0;
         Client.Min_Aspect := 0.0;
      end if;
      Client.Is_Fixed := Client.Max_Width /= 0 and then Client.Max_Height /= 0
        and then Client.Max_Width = Client.Min_Width and then Client.Max_Height = Client.Min_Height;
      Client.Hints_Valid := True;
   end Update_Size_Hints;

   procedure Update_Title (Client : Dwm_Types.Client_Access) is
      --  Two separate constants, not a reassigned variable: a String
      --  object's length is fixed at its declaration, so assigning a
      --  differently-sized result from the second Get_Text_Prop call
      --  into the same variable would raise Constraint_Error.
      Net_Name : constant String :=
        Dwm_Xutil.Get_Text_Prop (Client.Window, Dwm_State.Get_Net_Atom (Dwm_State.Net_WM_Name));
   begin
      if Net_Name'Length > 0 then
         Client.Name := Dwm_Types.Client_Name_Strings.To_Bounded_String (Net_Name, Ada.Strings.Right);
         return;
      end if;
      declare
         Wm_Name : constant String := Dwm_Xutil.Get_Text_Prop (Client.Window, Xlib_Thin.XA_WM_NAME);
      begin
         if Wm_Name'Length > 0 then
            Client.Name := Dwm_Types.Client_Name_Strings.To_Bounded_String (Wm_Name, Ada.Strings.Right);
         else
            Client.Name := Dwm_Types.Client_Name_Strings.To_Bounded_String (Dwm_State.Broken);
         end if;
      end;
   end Update_Title;

   procedure Update_Window_Type (Client : Dwm_Types.Client_Access) is
      State : constant Xlib_Thin.Atom :=
        Dwm_Xutil.Get_Atom_Prop (Client.Window, Dwm_State.Get_Net_Atom (Dwm_State.Net_WM_State));
      Wtype : constant Xlib_Thin.Atom :=
        Dwm_Xutil.Get_Atom_Prop (Client.Window, Dwm_State.Get_Net_Atom (Dwm_State.Net_WM_Window_Type));
   begin
      if State = Dwm_State.Get_Net_Atom (Dwm_State.Net_WM_Fullscreen) then
         Set_Full_Screen (Client, True);
      end if;
      if Wtype = Dwm_State.Get_Net_Atom (Dwm_State.Net_WM_Window_Type_Dialog) then
         Client.Is_Floating := True;
      end if;
   end Update_Window_Type;

   procedure Update_Wm_Hints (Client : Dwm_Types.Client_Access) is
      Hints : access Xlib_Thin.XWMHints;
      Ignore : Xlib_Thin.C_Int;
   begin
      Hints := Xlib_Thin.XGetWMHints (Dwm_State.Get_Display, Client.Window);
      if Hints /= null then
         if Client = Dwm_State.Get_Selected_Monitor.Selected_Client
           and then (Hints.Flags and Xlib_Thin.XUrgencyHint) /= 0
         then
            Hints.Flags := Hints.Flags and not Xlib_Thin.XUrgencyHint;
            Ignore := Xlib_Thin.XSetWMHints (Dwm_State.Get_Display, Client.Window, Hints);
         else
            Client.Is_Urgent := (Hints.Flags and Xlib_Thin.XUrgencyHint) /= 0;
         end if;
         if (Hints.Flags and Xlib_Thin.InputHint) /= 0 then
            Client.Never_Focus := Hints.Input = 0;
         else
            Client.Never_Focus := False;
         end if;
         Ignore := Xlib_Thin.XFree (Hints.all'Address);
      end if;
   end Update_Wm_Hints;

   function Win_To_Client (Window : Xlib_Thin.Window) return Dwm_Types.Client_Access is
      Monitor : Dwm_Types.Monitor_Access := Dwm_State.Get_Monitors;
      Client : Dwm_Types.Client_Access;
   begin
      while Monitor /= null loop
         Client := Monitor.Clients;
         while Client /= null loop
            if Client.Window = Window then
               return Client;
            end if;
            Client := Client.Next;
         end loop;
         Monitor := Monitor.Next;
      end loop;
      return null;
   end Win_To_Client;

   function X_Error
     (Display : Xlib_Thin.Display; Event : access Xlib_Thin.XErrorEvent) return Xlib_Thin.C_Int
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
      return Dwm_State.Get_X_Error_Xlib (Display, Event);
   end X_Error;

   function X_Error_Dummy
     (Display : Xlib_Thin.Display; Event : access Xlib_Thin.XErrorEvent) return Xlib_Thin.C_Int
   is
      pragma Unreferenced (Display, Event);
   begin
      return 0;
   end X_Error_Dummy;

   function X_Error_Start
     (Display : Xlib_Thin.Display; Event : access Xlib_Thin.XErrorEvent) return Xlib_Thin.C_Int
   is
      pragma Unreferenced (Display, Event);
   begin
      Util.Die ("dwm: another window manager is already running");
      return -1;
   end X_Error_Start;

end Dwm_Clients;
