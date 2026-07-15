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

   function Textw (S : String) return Natural is
     (Drw.Fontset_Getwidth (Dwm_State.Dc, S) + Dwm_State.Lrpad);

   function Cleanmask (Mask : Xlib_Thin.C_UInt) return Xlib_Thin.C_UInt is
     (Mask and not (Dwm_State.Numlockmask or Xlib_Thin.LockMask)
      and (Xlib_Thin.ShiftMask or Xlib_Thin.ControlMask or Xlib_Thin.Mod1Mask or Xlib_Thin.Mod2Mask
             or Xlib_Thin.Mod3Mask or Xlib_Thin.Mod4Mask or Xlib_Thin.Mod5Mask));

   --------------------------------------------------------------------

   procedure Buttonpress (Ev : access Xlib_Thin.XEvent) is
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
      M := Dwm_Monitors.Wintomon (Be.Win);
      if M /= null and then M /= Dwm_State.Selmon then
         Dwm_Clients.Unfocus (Dwm_State.Selmon.Sel, True);
         Dwm_State.Selmon := M;
         Dwm_Clients.Focus (null);
      end if;
      if Be.Win = Dwm_State.Selmon.Barwin then
         loop
            X := X + Textw (Config.Tags (Config.Tags'First + I).all);
            exit when not (Integer (Be.X) >= X);
            I := I + 1;
            exit when not (I < Config.Tags'Length);
         end loop;
         if I < Config.Tags'Length then
            Click := Dwm_Types.Clk_Tag_Bar;
            Arg_Val := (Ui => 2 ** I, others => <>);
         elsif Integer (Be.X)
                 < X + Textw (Dwm_Types.Lt_Symbol_Strings.To_String (Dwm_State.Selmon.Ltsymbol))
         then
            Click := Dwm_Types.Clk_Lt_Symbol;
         elsif Integer (Be.X)
                 > Dwm_State.Selmon.Ww - Textw (Dwm_Types.Client_Name_Strings.To_String (Dwm_State.Stext))
                     + Dwm_State.Lrpad - 2
         then
            Click := Dwm_Types.Clk_Status_Text;
         else
            Click := Dwm_Types.Clk_Win_Title;
         end if;
      else
         C := Dwm_Clients.Wintoclient (Be.Win);
         if C /= null then
            Dwm_Clients.Focus (C);
            Dwm_Clients.Restack (Dwm_State.Selmon);
            Ignore := Xlib_Thin.XAllowEvents (Dwm_State.Dpy, Xlib_Thin.ReplayPointer, Xlib_Thin.Current_Time);
            Click := Dwm_Types.Clk_Client_Win;
         end if;
      end if;
      if Dwm_State.Buttons /= null then
         for B of Dwm_State.Buttons.all loop
            if Click = B.Click and then B.Func /= null
              and then B.Button = Be.Button
              and then Cleanmask (B.Modifier) = Cleanmask (Be.State)
            then
               if Click = Dwm_Types.Clk_Tag_Bar and then B.Argument.I = 0 then
                  B.Func (Arg_Val);
               else
                  B.Func (B.Argument);
               end if;
            end if;
         end loop;
      end if;
   end Buttonpress;

   procedure Clientmessage (Ev : access Xlib_Thin.XEvent) is
      Cme : Xlib_Thin.XClientMessageEvent with Address => Ev.all'Address;
      pragma Import (Ada, Cme);
      C : constant Dwm_Types.Client_Access := Dwm_Clients.Wintoclient (Cme.Win);
   begin
      if C = null then
         return;
      end if;
      if Cme.Message_Type = Dwm_State.Netatom (Dwm_State.Net_WM_State) then
         if Xlib_Thin.Atom (Cme.Data.L (1)) = Dwm_State.Netatom (Dwm_State.Net_WM_Fullscreen)
           or else Xlib_Thin.Atom (Cme.Data.L (2)) = Dwm_State.Netatom (Dwm_State.Net_WM_Fullscreen)
         then
            Dwm_Clients.Setfullscreen
              (C, Cme.Data.L (0) = 1 or else (Cme.Data.L (0) = 2 and then not C.Isfullscreen));
         end if;
      elsif Cme.Message_Type = Dwm_State.Netatom (Dwm_State.Net_Active_Window) then
         if C /= Dwm_State.Selmon.Sel and then not C.Isurgent then
            Dwm_Clients.Seturgent (C, True);
         end if;
      end if;
   end Clientmessage;

   procedure Configurenotify (Ev : access Xlib_Thin.XEvent) is
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
      if Dwm_Monitors.Updategeom or else Dirty then
         Drw.Resize (Dwm_State.Dc, Dwm_State.Sw, Dwm_State.Bh);
         Dwm_Bar.Updatebars;
         M := Dwm_State.Mons;
         while M /= null loop
            C := M.Clients;
            while C /= null loop
               if C.Isfullscreen then
                  Dwm_Clients.Resizeclient (C, M.Mx, M.My, M.Mw, M.Mh);
               end if;
               C := C.Next;
            end loop;
            Ignore := Xlib_Thin.XMoveResizeWindow
              (Dwm_State.Dpy, M.Barwin, Xlib_Thin.C_Int (M.Wx), Xlib_Thin.C_Int (M.By),
               Xlib_Thin.C_UInt (M.Ww), Xlib_Thin.C_UInt (Dwm_State.Bh));
            M := M.Next;
         end loop;
         Dwm_Clients.Focus (null);
         Dwm_Clients.Arrange (null);
      end if;
   end Configurenotify;

   procedure Destroynotify (Ev : access Xlib_Thin.XEvent) is
      De : Xlib_Thin.XDestroyWindowEvent with Address => Ev.all'Address;
      pragma Import (Ada, De);
      C : constant Dwm_Types.Client_Access := Dwm_Clients.Wintoclient (De.Win);
   begin
      if C /= null then
         Dwm_Clients.Unmanage (C, True);
      end if;
   end Destroynotify;

   procedure Enternotify (Ev : access Xlib_Thin.XEvent) is
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
      C := Dwm_Clients.Wintoclient (Ce.Win);
      M := (if C /= null then C.Mon else Dwm_Monitors.Wintomon (Ce.Win));
      if M /= Dwm_State.Selmon then
         Dwm_Clients.Unfocus (Dwm_State.Selmon.Sel, True);
         Dwm_State.Selmon := M;
      elsif C = null or else C = Dwm_State.Selmon.Sel then
         return;
      end if;
      Dwm_Clients.Focus (C);
   end Enternotify;

   procedure Focusin (Ev : access Xlib_Thin.XEvent) is
      Fe : Xlib_Thin.XFocusChangeEvent with Address => Ev.all'Address;
      pragma Import (Ada, Fe);
   begin
      if Dwm_State.Selmon.Sel /= null and then Fe.Win /= Dwm_State.Selmon.Sel.Win then
         Dwm_Clients.Setfocus (Dwm_State.Selmon.Sel);
      end if;
   end Focusin;

   procedure Keypress (Ev : access Xlib_Thin.XEvent) is
      Ke : Xlib_Thin.XKeyEvent with Address => Ev.all'Address;
      pragma Import (Ada, Ke);
      Sym : constant Xlib_Thin.KeySym :=
        Xlib_Thin.XKeycodeToKeysym (Dwm_State.Dpy, Xlib_Thin.KeyCode (Ke.Keycode), 0);
   begin
      if Dwm_State.Keys /= null then
         for K of Dwm_State.Keys.all loop
            if Sym = K.Sym and then Cleanmask (K.Modifier) = Cleanmask (Ke.State)
              and then K.Func /= null
            then
               K.Func (K.Argument);
            end if;
         end loop;
      end if;
   end Keypress;

   procedure Mappingnotify (Ev : access Xlib_Thin.XEvent) is
      Me : aliased Xlib_Thin.XMappingEvent with Address => Ev.all'Address;
      pragma Import (Ada, Me);
      Ignore : Xlib_Thin.C_Int;
   begin
      Ignore := Xlib_Thin.XRefreshKeyboardMapping (Me'Access);
      if Me.Request = Xlib_Thin.MappingKeyboard then
         Dwm_Clients.Grabkeys;
      end if;
   end Mappingnotify;

   Motion_Mon : Dwm_Types.Monitor_Access := null;

   procedure Motionnotify (Ev : access Xlib_Thin.XEvent) is
      Me : Xlib_Thin.XMotionEvent with Address => Ev.all'Address;
      pragma Import (Ada, Me);
      M : Dwm_Types.Monitor_Access;
   begin
      if Me.Win /= Dwm_State.Root then
         return;
      end if;
      M := Dwm_Monitors.Recttomon (Integer (Me.X_Root), Integer (Me.Y_Root), 1, 1);
      if M /= Motion_Mon and then Motion_Mon /= null then
         Dwm_Clients.Unfocus (Dwm_State.Selmon.Sel, True);
         Dwm_State.Selmon := M;
         Dwm_Clients.Focus (null);
      end if;
      Motion_Mon := M;
   end Motionnotify;

   procedure Propertynotify (Ev : access Xlib_Thin.XEvent) is
      Pe : Xlib_Thin.XPropertyEvent with Address => Ev.all'Address;
      pragma Import (Ada, Pe);
      C : Dwm_Types.Client_Access;
      Trans : aliased Xlib_Thin.Window;
   begin
      if Pe.Win = Dwm_State.Root and then Pe.Prop_Atom = Xlib_Thin.XA_WM_NAME then
         Dwm_Bar.Updatestatus;
         return;
      elsif Pe.State = Xlib_Thin.PropertyDelete then
         return;
      end if;
      C := Dwm_Clients.Wintoclient (Pe.Win);
      if C /= null then
         if Pe.Prop_Atom = Xlib_Thin.XA_WM_TRANSIENT_FOR then
            if not C.Isfloating and then Xlib_Thin.XGetTransientForHint (Dwm_State.Dpy, C.Win, Trans'Access) /= 0
            then
               C.Isfloating := Dwm_Clients.Wintoclient (Trans) /= null;
               if C.Isfloating then
                  Dwm_Clients.Arrange (C.Mon);
               end if;
            end if;
         elsif Pe.Prop_Atom = Xlib_Thin.XA_WM_NORMAL_HINTS then
            C.Hintsvalid := False;
         elsif Pe.Prop_Atom = Xlib_Thin.XA_WM_HINTS then
            Dwm_Clients.Updatewmhints (C);
            Dwm_Bar.Drawbars;
         end if;
         if Pe.Prop_Atom = Xlib_Thin.XA_WM_NAME or else Pe.Prop_Atom = Dwm_State.Netatom (Dwm_State.Net_WM_Name)
         then
            Dwm_Clients.Updatetitle (C);
            if C = C.Mon.Sel then
               Dwm_Bar.Drawbar (C.Mon);
            end if;
         end if;
         if Pe.Prop_Atom = Dwm_State.Netatom (Dwm_State.Net_WM_Window_Type) then
            Dwm_Clients.Updatewindowtype (C);
         end if;
      end if;
   end Propertynotify;

   procedure Unmapnotify (Ev : access Xlib_Thin.XEvent) is
      Ue : Xlib_Thin.XUnmapEvent with Address => Ev.all'Address;
      pragma Import (Ada, Ue);
      C : constant Dwm_Types.Client_Access := Dwm_Clients.Wintoclient (Ue.Win);
   begin
      if C /= null then
         if Ue.Send_Event /= 0 then
            Dwm_Clients.Setclientstate (C, Xlib_Thin.WithdrawnState);
         else
            Dwm_Clients.Unmanage (C, False);
         end if;
      end if;
   end Unmapnotify;

end Dwm_Events;
