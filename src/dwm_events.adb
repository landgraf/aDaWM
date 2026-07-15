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
     (Drw.Fontset_Get_Width (Dwm_State.Dc, S) + Dwm_State.Lrpad);

   function Clean_Mask (Mask : Xlib_Thin.C_UInt) return Xlib_Thin.C_UInt is
     (Mask and not (Dwm_State.Num_Lock_Mask or Xlib_Thin.LockMask)
      and (Xlib_Thin.ShiftMask or Xlib_Thin.ControlMask or Xlib_Thin.Mod1Mask or Xlib_Thin.Mod2Mask
             or Xlib_Thin.Mod3Mask or Xlib_Thin.Mod4Mask or Xlib_Thin.Mod5Mask));

   --------------------------------------------------------------------

   procedure Button_Press (Ev : access Xlib_Thin.XEvent) is
      Be : Xlib_Thin.XButtonEvent with Address => Ev.all'Address;
      pragma Import (Ada, Be);
      Click   : Dwm_Types.Click_Kind := Dwm_Types.Clk_Root_Win;
      Arg_Val : Dwm_Types.Arg := Dwm_Types.No_Arg;
      C : Dwm_Types.Client_Access;
      M : Dwm_Types.Monitor_Access;
      I : Natural := 0;
      X : Integer := 0;
      Ignore : Xlib_Thin.C_Int;
   begin
      M := Dwm_Monitors.Win_To_Mon (Be.Win);
      if M /= null and then M /= Dwm_State.Sel_Mon then
         Dwm_Clients.Unfocus (Dwm_State.Sel_Mon.Sel, True);
         Dwm_State.Sel_Mon := M;
         Dwm_Clients.Focus (null);
      end if;
      if Be.Win = Dwm_State.Sel_Mon.Bar_Win then
         loop
            X := X + Text_Width (Config.Tags (Config.Tags'First + I).all);
            exit when not (Integer (Be.X) >= X);
            I := I + 1;
            exit when not (I < Config.Tags'Length);
         end loop;
         if I < Config.Tags'Length then
            Click := Dwm_Types.Clk_Tag_Bar;
            Arg_Val := (Ui => 2 ** I, others => <>);
         elsif Integer (Be.X)
                 < X + Text_Width (Dwm_Types.Lt_Symbol_Strings.To_String (Dwm_State.Sel_Mon.Lt_Symbol))
         then
            Click := Dwm_Types.Clk_Lt_Symbol;
         elsif Integer (Be.X)
                 > Dwm_State.Sel_Mon.Ww - Text_Width (Dwm_Types.Client_Name_Strings.To_String (Dwm_State.Stext))
                     + Dwm_State.Lrpad - 2
         then
            Click := Dwm_Types.Clk_Status_Text;
         else
            Click := Dwm_Types.Clk_Win_Title;
         end if;
      else
         C := Dwm_Clients.Win_To_Client (Be.Win);
         if C /= null then
            Dwm_Clients.Focus (C);
            Dwm_Clients.Restack (Dwm_State.Sel_Mon);
            Ignore := Xlib_Thin.XAllowEvents (Dwm_State.Dpy, Xlib_Thin.ReplayPointer, Xlib_Thin.Current_Time);
            Click := Dwm_Types.Clk_Client_Win;
         end if;
      end if;
      if Dwm_State.Buttons /= null then
         for B of Dwm_State.Buttons.all loop
            if Click = B.Click and then B.Func /= null
              and then B.Button = Be.Button
              and then Clean_Mask (B.Modifier) = Clean_Mask (Be.State)
            then
               if Click = Dwm_Types.Clk_Tag_Bar and then B.Argument.I = 0 then
                  B.Func (Arg_Val);
               else
                  B.Func (B.Argument);
               end if;
            end if;
         end loop;
      end if;
   end Button_Press;

   procedure Client_Message (Ev : access Xlib_Thin.XEvent) is
      Cme : Xlib_Thin.XClientMessageEvent with Address => Ev.all'Address;
      pragma Import (Ada, Cme);
      C : constant Dwm_Types.Client_Access := Dwm_Clients.Win_To_Client (Cme.Win);
   begin
      if C = null then
         return;
      end if;
      if Cme.Message_Type = Dwm_State.Net_Atom (Dwm_State.Net_WM_State) then
         if Xlib_Thin.Atom (Cme.Data.L (1)) = Dwm_State.Net_Atom (Dwm_State.Net_WM_Fullscreen)
           or else Xlib_Thin.Atom (Cme.Data.L (2)) = Dwm_State.Net_Atom (Dwm_State.Net_WM_Fullscreen)
         then
            Dwm_Clients.Set_Full_Screen
              (C, Cme.Data.L (0) = 1 or else (Cme.Data.L (0) = 2 and then not C.Is_Full_Screen));
         end if;
      elsif Cme.Message_Type = Dwm_State.Net_Atom (Dwm_State.Net_Active_Window) then
         if C /= Dwm_State.Sel_Mon.Sel and then not C.Is_Urgent then
            Dwm_Clients.Set_Urgent (C, True);
         end if;
      end if;
   end Client_Message;

   procedure Configure_Notify (Ev : access Xlib_Thin.XEvent) is
      Ce : Xlib_Thin.XConfigureEvent with Address => Ev.all'Address;
      pragma Import (Ada, Ce);
      Dirty : Boolean;
      M : Dwm_Types.Monitor_Access;
      C : Dwm_Types.Client_Access;
      Ignore : Xlib_Thin.C_Int;
   begin
      if Ce.Win /= Dwm_State.Root then
         return;
      end if;
      Dirty := Dwm_State.Sw /= Integer (Ce.Width) or else Dwm_State.Sh /= Integer (Ce.Height);
      Dwm_State.Sw := Integer (Ce.Width);
      Dwm_State.Sh := Integer (Ce.Height);
      if Dwm_Monitors.Update_Geom or else Dirty then
         Drw.Resize (Dwm_State.Dc, Dwm_State.Sw, Dwm_State.Bh);
         Dwm_Bar.Update_Bars;
         M := Dwm_State.Mons;
         while M /= null loop
            C := M.Clients;
            while C /= null loop
               if C.Is_Full_Screen then
                  Dwm_Clients.Resize_Client (C, M.Mx, M.My, M.Mw, M.Mh);
               end if;
               C := C.Next;
            end loop;
            Ignore := Xlib_Thin.XMoveResizeWindow
              (Dwm_State.Dpy, M.Bar_Win, Xlib_Thin.C_Int (M.Wx), Xlib_Thin.C_Int (M.By),
               Xlib_Thin.C_UInt (M.Ww), Xlib_Thin.C_UInt (Dwm_State.Bh));
            M := M.Next;
         end loop;
         Dwm_Clients.Focus (null);
         Dwm_Clients.Arrange (null);
      end if;
   end Configure_Notify;

   procedure Destroy_Notify (Ev : access Xlib_Thin.XEvent) is
      De : Xlib_Thin.XDestroyWindowEvent with Address => Ev.all'Address;
      pragma Import (Ada, De);
      C : constant Dwm_Types.Client_Access := Dwm_Clients.Win_To_Client (De.Win);
   begin
      if C /= null then
         Dwm_Clients.Unmanage (C, True);
      end if;
   end Destroy_Notify;

   procedure Enter_Notify (Ev : access Xlib_Thin.XEvent) is
      Ce : Xlib_Thin.XCrossingEvent with Address => Ev.all'Address;
      pragma Import (Ada, Ce);
      C : Dwm_Types.Client_Access;
      M : Dwm_Types.Monitor_Access;
   begin
      if (Ce.Mode /= Xlib_Thin.NotifyNormal or else Ce.Detail = Xlib_Thin.NotifyInferior)
        and then Ce.Win /= Dwm_State.Root
      then
         return;
      end if;
      C := Dwm_Clients.Win_To_Client (Ce.Win);
      M := (if C /= null then C.Mon else Dwm_Monitors.Win_To_Mon (Ce.Win));
      if M /= Dwm_State.Sel_Mon then
         Dwm_Clients.Unfocus (Dwm_State.Sel_Mon.Sel, True);
         Dwm_State.Sel_Mon := M;
      elsif C = null or else C = Dwm_State.Sel_Mon.Sel then
         return;
      end if;
      Dwm_Clients.Focus (C);
   end Enter_Notify;

   procedure Focus_In (Ev : access Xlib_Thin.XEvent) is
      Fe : Xlib_Thin.XFocusChangeEvent with Address => Ev.all'Address;
      pragma Import (Ada, Fe);
   begin
      if Dwm_State.Sel_Mon.Sel /= null and then Fe.Win /= Dwm_State.Sel_Mon.Sel.Win then
         Dwm_Clients.Set_Focus (Dwm_State.Sel_Mon.Sel);
      end if;
   end Focus_In;

   procedure Key_Press (Ev : access Xlib_Thin.XEvent) is
      Ke : Xlib_Thin.XKeyEvent with Address => Ev.all'Address;
      pragma Import (Ada, Ke);
      Sym : constant Xlib_Thin.KeySym :=
        Xlib_Thin.XKeycodeToKeysym (Dwm_State.Dpy, Xlib_Thin.KeyCode (Ke.Keycode), 0);
   begin
      if Dwm_State.Keys /= null then
         for K of Dwm_State.Keys.all loop
            if Sym = K.Sym and then Clean_Mask (K.Modifier) = Clean_Mask (Ke.State)
              and then K.Func /= null
            then
               K.Func (K.Argument);
            end if;
         end loop;
      end if;
   end Key_Press;

   procedure Mapping_Notify (Ev : access Xlib_Thin.XEvent) is
      Me : aliased Xlib_Thin.XMappingEvent with Address => Ev.all'Address;
      pragma Import (Ada, Me);
      Ignore : Xlib_Thin.C_Int;
   begin
      Ignore := Xlib_Thin.XRefreshKeyboardMapping (Me'Access);
      if Me.Request = Xlib_Thin.MappingKeyboard then
         Dwm_Clients.Grab_Keys;
      end if;
   end Mapping_Notify;

   Motion_Mon : Dwm_Types.Monitor_Access := null;

   procedure Motion_Notify (Ev : access Xlib_Thin.XEvent) is
      Me : Xlib_Thin.XMotionEvent with Address => Ev.all'Address;
      pragma Import (Ada, Me);
      M : Dwm_Types.Monitor_Access;
   begin
      if Me.Win /= Dwm_State.Root then
         return;
      end if;
      M := Dwm_Monitors.Rect_To_Mon (Integer (Me.X_Root), Integer (Me.Y_Root), 1, 1);
      if M /= Motion_Mon and then Motion_Mon /= null then
         Dwm_Clients.Unfocus (Dwm_State.Sel_Mon.Sel, True);
         Dwm_State.Sel_Mon := M;
         Dwm_Clients.Focus (null);
      end if;
      Motion_Mon := M;
   end Motion_Notify;

   procedure Property_Notify (Ev : access Xlib_Thin.XEvent) is
      Pe : Xlib_Thin.XPropertyEvent with Address => Ev.all'Address;
      pragma Import (Ada, Pe);
      C : Dwm_Types.Client_Access;
      Trans : aliased Xlib_Thin.Window;
   begin
      if Pe.Win = Dwm_State.Root and then Pe.Prop_Atom = Xlib_Thin.XA_WM_NAME then
         Dwm_Bar.Update_Status;
         return;
      elsif Pe.State = Xlib_Thin.PropertyDelete then
         return;
      end if;
      C := Dwm_Clients.Win_To_Client (Pe.Win);
      if C /= null then
         if Pe.Prop_Atom = Xlib_Thin.XA_WM_TRANSIENT_FOR then
            if not C.Is_Floating and then Xlib_Thin.XGetTransientForHint (Dwm_State.Dpy, C.Win, Trans'Access) /= 0
            then
               C.Is_Floating := Dwm_Clients.Win_To_Client (Trans) /= null;
               if C.Is_Floating then
                  Dwm_Clients.Arrange (C.Mon);
               end if;
            end if;
         elsif Pe.Prop_Atom = Xlib_Thin.XA_WM_NORMAL_HINTS then
            C.Hints_Valid := False;
         elsif Pe.Prop_Atom = Xlib_Thin.XA_WM_HINTS then
            Dwm_Clients.Update_Wm_Hints (C);
            Dwm_Bar.Draw_Bars;
         end if;
         if Pe.Prop_Atom = Xlib_Thin.XA_WM_NAME or else Pe.Prop_Atom = Dwm_State.Net_Atom (Dwm_State.Net_WM_Name)
         then
            Dwm_Clients.Update_Title (C);
            if C = C.Mon.Sel then
               Dwm_Bar.Draw_Bar (C.Mon);
            end if;
         end if;
         if Pe.Prop_Atom = Dwm_State.Net_Atom (Dwm_State.Net_WM_Window_Type) then
            Dwm_Clients.Update_Window_Type (C);
         end if;
      end if;
   end Property_Notify;

   procedure Unmap_Notify (Ev : access Xlib_Thin.XEvent) is
      Ue : Xlib_Thin.XUnmapEvent with Address => Ev.all'Address;
      pragma Import (Ada, Ue);
      C : constant Dwm_Types.Client_Access := Dwm_Clients.Win_To_Client (Ue.Win);
   begin
      if C /= null then
         if Ue.Send_Event /= 0 then
            Dwm_Clients.Set_Client_State (C, Xlib_Thin.WithdrawnState);
         else
            Dwm_Clients.Unmanage (C, False);
         end if;
      end if;
   end Unmap_Notify;

end Dwm_Events;
