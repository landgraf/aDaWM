with Config;
with Dwm_Bar;
with Dwm_State;
with Drw;

package body Dwm_Events is

   use type Xlib_Thin.C_Int;
   use type Xlib_Thin.C_UInt;
   use type Xlib_Thin.C_Long;
   use type Xlib_Thin.XID;
   use type Dwm_Types.Client_Access;
   use type Dwm_Types.Monitor_Access;
   use type Dwm_Types.Click_Kind;
   use type Dwm_Types.Tag_Mask;
   use type Dwm_Types.Key_Array_Access;
   use type Dwm_Types.Button_Array_Access;
   use type Dwm_Types.Key_Func;

   function Text_Width (S : String) return Natural is
     (Drw.Fontset_Get_Width (Dwm_State.Drw_Ctx, S) + Dwm_State.Left_Right_Pad);

   function Clean_Mask (Mask : Xlib_Thin.C_UInt) return Xlib_Thin.C_UInt is
     (Mask and not (Dwm_State.Num_Lock_Mask or Xlib_Thin.LockMask)
      and (Xlib_Thin.ShiftMask or Xlib_Thin.ControlMask or Xlib_Thin.Mod1Mask or Xlib_Thin.Mod2Mask
             or Xlib_Thin.Mod3Mask or Xlib_Thin.Mod4Mask or Xlib_Thin.Mod5Mask));

   --------------------------------------------------------------------

   procedure Button_Press (Event : access Xlib_Thin.XEvent) is
      Button_Event : Xlib_Thin.XButtonEvent with Address => Event.all'Address;
      pragma Import (Ada, Button_Event);
      Click   : Dwm_Types.Click_Kind := Dwm_Types.Clk_Root_Win;
      Arg_Val : Dwm_Types.Arg := Dwm_Types.No_Arg;
      Client  : Dwm_Types.Client_Access;
      Monitor : Dwm_Types.Monitor_Access;
      Idx : Natural := 0;
      Cur_X : Integer := 0;
      Ignore : Xlib_Thin.C_Int;
   begin
      Monitor := Dwm_Monitors.Win_To_Mon (Button_Event.Win);
      if Monitor /= null and then Monitor /= Dwm_State.Selected_Monitor then
         Dwm_Clients.Unfocus (Dwm_State.Selected_Monitor.Selected_Client, True);
         Dwm_State.Selected_Monitor := Monitor;
         Dwm_Clients.Focus (null);
      end if;
      if Button_Event.Win = Dwm_State.Selected_Monitor.Bar_Window then
         loop
            Cur_X := Cur_X + Text_Width (Config.Tags (Config.Tags'First + Idx).all);
            exit when not (Integer (Button_Event.X) >= Cur_X);
            Idx := Idx + 1;
            exit when not (Idx < Config.Tags'Length);
         end loop;
         if Idx < Config.Tags'Length then
            Click := Dwm_Types.Clk_Tag_Bar;
            Arg_Val := (Uint_Value => 2 ** Idx, others => <>);
         elsif Integer (Button_Event.X)
                 < Cur_X
                     + Text_Width (Dwm_Types.Lt_Symbol_Strings.To_String (Dwm_State.Selected_Monitor.Lt_Symbol))
         then
            Click := Dwm_Types.Clk_Lt_Symbol;
         elsif Integer (Button_Event.X)
                 > Dwm_State.Selected_Monitor.Work_Width
                     - Text_Width (Dwm_Types.Client_Name_Strings.To_String (Dwm_State.Stext))
                     + Dwm_State.Left_Right_Pad - 2
         then
            Click := Dwm_Types.Clk_Status_Text;
         else
            Click := Dwm_Types.Clk_Win_Title;
         end if;
      else
         Client := Dwm_Clients.Win_To_Client (Button_Event.Win);
         if Client /= null then
            Dwm_Clients.Focus (Client);
            Dwm_Clients.Restack (Dwm_State.Selected_Monitor);
            Ignore := Xlib_Thin.XAllowEvents (Dwm_State.Display, Xlib_Thin.ReplayPointer, Xlib_Thin.Current_Time);
            Click := Dwm_Types.Clk_Client_Win;
         end if;
      end if;
      if Dwm_State.Buttons /= null then
         for Binding of Dwm_State.Buttons.all loop
            if Click = Binding.Click and then Binding.Func /= null
              and then Binding.Button = Button_Event.Button
              and then Clean_Mask (Binding.Modifier) = Clean_Mask (Button_Event.State)
            then
               if Click = Dwm_Types.Clk_Tag_Bar and then Binding.Argument.Int_Value = 0 then
                  Binding.Func (Arg_Val);
               else
                  Binding.Func (Binding.Argument);
               end if;
            end if;
         end loop;
      end if;
   end Button_Press;

   procedure Client_Message (Event : access Xlib_Thin.XEvent) is
      Message_Event : Xlib_Thin.XClientMessageEvent with Address => Event.all'Address;
      pragma Import (Ada, Message_Event);
      Client : constant Dwm_Types.Client_Access := Dwm_Clients.Win_To_Client (Message_Event.Win);
   begin
      if Client = null then
         return;
      end if;
      if Message_Event.Message_Type = Dwm_State.Net_Atom (Dwm_State.Net_WM_State) then
         if Xlib_Thin.Atom (Message_Event.Data.L (1)) = Dwm_State.Net_Atom (Dwm_State.Net_WM_Fullscreen)
           or else Xlib_Thin.Atom (Message_Event.Data.L (2)) = Dwm_State.Net_Atom (Dwm_State.Net_WM_Fullscreen)
         then
            Dwm_Clients.Set_Full_Screen
              (Client,
               Message_Event.Data.L (0) = 1
                 or else (Message_Event.Data.L (0) = 2 and then not Client.Is_Full_Screen));
         end if;
      elsif Message_Event.Message_Type = Dwm_State.Net_Atom (Dwm_State.Net_Active_Window) then
         if Client /= Dwm_State.Selected_Monitor.Selected_Client and then not Client.Is_Urgent then
            Dwm_Clients.Set_Urgent (Client, True);
         end if;
      end if;
   end Client_Message;

   procedure Configure_Notify (Event : access Xlib_Thin.XEvent) is
      Configure_Event : Xlib_Thin.XConfigureEvent with Address => Event.all'Address;
      pragma Import (Ada, Configure_Event);
      Dirty : Boolean;
      Monitor : Dwm_Types.Monitor_Access;
      Client  : Dwm_Types.Client_Access;
      Ignore : Xlib_Thin.C_Int;
   begin
      if Configure_Event.Win /= Dwm_State.Root then
         return;
      end if;
      Dirty := Dwm_State.Screen_Width /= Integer (Configure_Event.Width)
        or else Dwm_State.Screen_Height /= Integer (Configure_Event.Height);
      Dwm_State.Screen_Width := Integer (Configure_Event.Width);
      Dwm_State.Screen_Height := Integer (Configure_Event.Height);
      if Dwm_Monitors.Update_Geom or else Dirty then
         Drw.Resize (Dwm_State.Drw_Ctx, Dwm_State.Screen_Width, Dwm_State.Bar_Height);
         Dwm_Bar.Update_Bars;
         Monitor := Dwm_State.Monitors;
         while Monitor /= null loop
            Client := Monitor.Clients;
            while Client /= null loop
               if Client.Is_Full_Screen then
                  Dwm_Clients.Resize_Client
                    (Client, Monitor.Screen_X, Monitor.Screen_Y, Monitor.Screen_Width, Monitor.Screen_Height);
               end if;
               Client := Client.Next;
            end loop;
            Ignore := Xlib_Thin.XMoveResizeWindow
              (Dwm_State.Display, Monitor.Bar_Window, Xlib_Thin.C_Int (Monitor.Work_X),
               Xlib_Thin.C_Int (Monitor.Bar_Y), Xlib_Thin.C_UInt (Monitor.Work_Width),
               Xlib_Thin.C_UInt (Dwm_State.Bar_Height));
            Monitor := Monitor.Next;
         end loop;
         Dwm_Clients.Focus (null);
         Dwm_Clients.Arrange (null);
      end if;
   end Configure_Notify;

   procedure Destroy_Notify (Event : access Xlib_Thin.XEvent) is
      Destroy_Event : Xlib_Thin.XDestroyWindowEvent with Address => Event.all'Address;
      pragma Import (Ada, Destroy_Event);
      Client : constant Dwm_Types.Client_Access := Dwm_Clients.Win_To_Client (Destroy_Event.Win);
   begin
      if Client /= null then
         Dwm_Clients.Unmanage (Client, True);
      end if;
   end Destroy_Notify;

   procedure Enter_Notify (Event : access Xlib_Thin.XEvent) is
      Crossing_Event : Xlib_Thin.XCrossingEvent with Address => Event.all'Address;
      pragma Import (Ada, Crossing_Event);
      Client  : Dwm_Types.Client_Access;
      Monitor : Dwm_Types.Monitor_Access;
   begin
      if (Crossing_Event.Mode /= Xlib_Thin.NotifyNormal or else Crossing_Event.Detail = Xlib_Thin.NotifyInferior)
        and then Crossing_Event.Win /= Dwm_State.Root
      then
         return;
      end if;
      Client := Dwm_Clients.Win_To_Client (Crossing_Event.Win);
      Monitor :=
        (if Client /= null then Client.Monitor else Dwm_Monitors.Win_To_Mon (Crossing_Event.Win));
      if Monitor /= Dwm_State.Selected_Monitor then
         Dwm_Clients.Unfocus (Dwm_State.Selected_Monitor.Selected_Client, True);
         Dwm_State.Selected_Monitor := Monitor;
      elsif Client = null or else Client = Dwm_State.Selected_Monitor.Selected_Client then
         return;
      end if;
      Dwm_Clients.Focus (Client);
   end Enter_Notify;

   procedure Focus_In (Event : access Xlib_Thin.XEvent) is
      Focus_Event : Xlib_Thin.XFocusChangeEvent with Address => Event.all'Address;
      pragma Import (Ada, Focus_Event);
   begin
      if Dwm_State.Selected_Monitor.Selected_Client /= null
        and then Focus_Event.Win /= Dwm_State.Selected_Monitor.Selected_Client.Window
      then
         Dwm_Clients.Set_Focus (Dwm_State.Selected_Monitor.Selected_Client);
      end if;
   end Focus_In;

   procedure Key_Press (Event : access Xlib_Thin.XEvent) is
      Key_Event : Xlib_Thin.XKeyEvent with Address => Event.all'Address;
      pragma Import (Ada, Key_Event);
      Sym : constant Xlib_Thin.KeySym :=
        Xlib_Thin.XKeycodeToKeysym (Dwm_State.Display, Xlib_Thin.KeyCode (Key_Event.Keycode), 0);
   begin
      if Dwm_State.Keys /= null then
         for Key_Def of Dwm_State.Keys.all loop
            if Sym = Key_Def.Sym and then Clean_Mask (Key_Def.Modifier) = Clean_Mask (Key_Event.State)
              and then Key_Def.Func /= null
            then
               Key_Def.Func (Key_Def.Argument);
            end if;
         end loop;
      end if;
   end Key_Press;

   procedure Mapping_Notify (Event : access Xlib_Thin.XEvent) is
      Mapping_Event : aliased Xlib_Thin.XMappingEvent with Address => Event.all'Address;
      pragma Import (Ada, Mapping_Event);
      Ignore : Xlib_Thin.C_Int;
   begin
      Ignore := Xlib_Thin.XRefreshKeyboardMapping (Mapping_Event'Access);
      if Mapping_Event.Request = Xlib_Thin.MappingKeyboard then
         Dwm_Clients.Grab_Keys;
      end if;
   end Mapping_Notify;

   Last_Motion_Monitor : Dwm_Types.Monitor_Access := null;

   procedure Motion_Notify (Event : access Xlib_Thin.XEvent) is
      Motion_Event : Xlib_Thin.XMotionEvent with Address => Event.all'Address;
      pragma Import (Ada, Motion_Event);
      Monitor : Dwm_Types.Monitor_Access;
   begin
      if Motion_Event.Win /= Dwm_State.Root then
         return;
      end if;
      Monitor := Dwm_Monitors.Rect_To_Mon (Integer (Motion_Event.X_Root), Integer (Motion_Event.Y_Root), 1, 1);
      if Monitor /= Last_Motion_Monitor and then Last_Motion_Monitor /= null then
         Dwm_Clients.Unfocus (Dwm_State.Selected_Monitor.Selected_Client, True);
         Dwm_State.Selected_Monitor := Monitor;
         Dwm_Clients.Focus (null);
      end if;
      Last_Motion_Monitor := Monitor;
   end Motion_Notify;

   procedure Property_Notify (Event : access Xlib_Thin.XEvent) is
      Property_Event : Xlib_Thin.XPropertyEvent with Address => Event.all'Address;
      pragma Import (Ada, Property_Event);
      Client : Dwm_Types.Client_Access;
      Trans : aliased Xlib_Thin.Window;
   begin
      if Property_Event.Win = Dwm_State.Root and then Property_Event.Prop_Atom = Xlib_Thin.XA_WM_NAME then
         Dwm_Bar.Update_Status;
         return;
      elsif Property_Event.State = Xlib_Thin.PropertyDelete then
         return;
      end if;
      Client := Dwm_Clients.Win_To_Client (Property_Event.Win);
      if Client /= null then
         if Property_Event.Prop_Atom = Xlib_Thin.XA_WM_TRANSIENT_FOR then
            if not Client.Is_Floating
              and then Xlib_Thin.XGetTransientForHint (Dwm_State.Display, Client.Window, Trans'Access) /= 0
            then
               Client.Is_Floating := Dwm_Clients.Win_To_Client (Trans) /= null;
               if Client.Is_Floating then
                  Dwm_Clients.Arrange (Client.Monitor);
               end if;
            end if;
         elsif Property_Event.Prop_Atom = Xlib_Thin.XA_WM_NORMAL_HINTS then
            Client.Hints_Valid := False;
         elsif Property_Event.Prop_Atom = Xlib_Thin.XA_WM_HINTS then
            Dwm_Clients.Update_Wm_Hints (Client);
            Dwm_Bar.Draw_Bars;
         end if;
         if Property_Event.Prop_Atom = Xlib_Thin.XA_WM_NAME
           or else Property_Event.Prop_Atom = Dwm_State.Net_Atom (Dwm_State.Net_WM_Name)
         then
            Dwm_Clients.Update_Title (Client);
            if Client = Client.Monitor.Selected_Client then
               Dwm_Bar.Draw_Bar (Client.Monitor);
            end if;
         end if;
         if Property_Event.Prop_Atom = Dwm_State.Net_Atom (Dwm_State.Net_WM_Window_Type) then
            Dwm_Clients.Update_Window_Type (Client);
         end if;
      end if;
   end Property_Notify;

   procedure Unmap_Notify (Event : access Xlib_Thin.XEvent) is
      Unmap_Event : Xlib_Thin.XUnmapEvent with Address => Event.all'Address;
      pragma Import (Ada, Unmap_Event);
      Client : constant Dwm_Types.Client_Access := Dwm_Clients.Win_To_Client (Unmap_Event.Win);
   begin
      if Client /= null then
         if Unmap_Event.Send_Event /= 0 then
            Dwm_Clients.Set_Client_State (Client, Xlib_Thin.WithdrawnState);
         else
            Dwm_Clients.Unmanage (Client, False);
         end if;
      end if;
   end Unmap_Notify;

end Dwm_Events;
