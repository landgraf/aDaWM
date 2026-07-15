with Interfaces.C.Strings;
with Config;
with Drw;
with Dwm_State;
with Dwm_Xutil;
with Xlib_Thin;

package body Dwm_Bar is

   use type Xlib_Thin.C_ULong;
   use type Xlib_Thin.XID;
   use type Dwm_Types.Tag_Mask;
   use type Dwm_Types.Client_Access;
   use type Dwm_Types.Monitor_Access;

   function Text_Width (S : String) return Natural is
     (Drw.Fontset_Get_Width (Dwm_State.Dc, S) + Dwm_State.Lrpad);

   procedure Draw_Bar (M : Dwm_Types.Monitor_Access) is
      Boxs : constant Natural := Dwm_State.Dc.Fonts.H / 9;
      Boxw : constant Natural := Dwm_State.Dc.Fonts.H / 6 + 2;
      Occ, Urg : Dwm_Types.Tag_Mask := 0;
      C  : Dwm_Types.Client_Access;
      X  : Integer;
      W  : Integer;
      Tw : Integer := 0;
      Ignore : Integer;
   begin
      if not M.Show_Bar then
         return;
      end if;

      if M = Dwm_State.Sel_Mon then
         Drw.Set_Scheme (Dwm_State.Dc, Dwm_State.Scheme (Dwm_Types.Scheme_Norm));
         Tw := Text_Width (Dwm_Types.Client_Name_Strings.To_String (Dwm_State.Stext)) - Dwm_State.Lrpad + 2;
         Ignore := Drw.Text
           (Dwm_State.Dc, M.Ww - Tw, 0, Tw, Dwm_State.Bh, 0,
            Dwm_Types.Client_Name_Strings.To_String (Dwm_State.Stext), 0);
      end if;

      C := M.Clients;
      while C /= null loop
         Occ := Occ or C.Tags;
         if C.Is_Urgent then
            Urg := Urg or C.Tags;
         end if;
         C := C.Next;
      end loop;

      X := 0;
      for I in Config.Tags'Range loop
         declare
            Bit : constant Dwm_Types.Tag_Mask := 2 ** (I - Config.Tags'First);
            Wd  : constant Natural := Text_Width (Config.Tags (I).all);
         begin
            Drw.Set_Scheme
              (Dwm_State.Dc,
               Dwm_State.Scheme
                 (if (M.Tag_Set (M.Sel_Tags) and Bit) /= 0
                  then Dwm_Types.Scheme_Sel else Dwm_Types.Scheme_Norm));
            Ignore := Drw.Text
              (Dwm_State.Dc, X, 0, Wd, Dwm_State.Bh, Dwm_State.Lrpad / 2, Config.Tags (I).all,
               (if (Urg and Bit) /= 0 then 1 else 0));
            if (Occ and Bit) /= 0 then
               Drw.Rect
                 (Dwm_State.Dc, X + Boxs, Boxs, Boxw, Boxw,
                  (if M = Dwm_State.Sel_Mon and then Dwm_State.Sel_Mon.Sel /= null
                     and then (Dwm_State.Sel_Mon.Sel.Tags and Bit) /= 0
                   then 1 else 0),
                  (if (Urg and Bit) /= 0 then 1 else 0));
            end if;
            X := X + Wd;
         end;
      end loop;

      declare
         Wd : constant Natural := Text_Width (Dwm_Types.Lt_Symbol_Strings.To_String (M.Lt_Symbol));
      begin
         Drw.Set_Scheme (Dwm_State.Dc, Dwm_State.Scheme (Dwm_Types.Scheme_Norm));
         X := Drw.Text
           (Dwm_State.Dc, X, 0, Wd, Dwm_State.Bh, Dwm_State.Lrpad / 2,
            Dwm_Types.Lt_Symbol_Strings.To_String (M.Lt_Symbol), 0);
      end;

      W := M.Ww - Tw - X;
      if W > Dwm_State.Bh then
         if M.Sel /= null then
            Drw.Set_Scheme
              (Dwm_State.Dc,
               Dwm_State.Scheme (if M = Dwm_State.Sel_Mon then Dwm_Types.Scheme_Sel else Dwm_Types.Scheme_Norm));
            Ignore := Drw.Text
              (Dwm_State.Dc, X, 0, W, Dwm_State.Bh, Dwm_State.Lrpad / 2,
               Dwm_Types.Client_Name_Strings.To_String (M.Sel.Name), 0);
            if M.Sel.Is_Floating then
               Drw.Rect (Dwm_State.Dc, X + Boxs, Boxs, Boxw, Boxw, (if M.Sel.Is_Fixed then 1 else 0), 0);
            end if;
         else
            Drw.Set_Scheme (Dwm_State.Dc, Dwm_State.Scheme (Dwm_Types.Scheme_Norm));
            Drw.Rect (Dwm_State.Dc, X, 0, W, Dwm_State.Bh, 1, 1);
         end if;
      end if;
      Drw.Map (Dwm_State.Dc, M.Bar_Win, 0, 0, M.Ww, Dwm_State.Bh);
   end Draw_Bar;

   procedure Draw_Bars is
      M : Dwm_Types.Monitor_Access := Dwm_State.Mons;
   begin
      while M /= null loop
         Draw_Bar (M);
         M := M.Next;
      end loop;
   end Draw_Bars;

   procedure Update_Bars is
      Wa : aliased Xlib_Thin.XSetWindowAttributes;
      Ch : aliased Xlib_Thin.XClassHint;
      M  : Dwm_Types.Monitor_Access := Dwm_State.Mons;
      Class_Name : constant Interfaces.C.Strings.chars_ptr := Interfaces.C.Strings.New_String ("dwm");
      Ignore : Xlib_Thin.C_Int;
   begin
      Wa.Override_Redirect := 1;
      Wa.Background_Pixmap := Xlib_Thin.Parent_Relative;
      Wa.Event_Mask := Xlib_Thin.ButtonPressMask or Xlib_Thin.ExposureMask;
      Ch.Res_Name := Class_Name;
      Ch.Res_Class := Class_Name;
      while M /= null loop
         if M.Bar_Win = Xlib_Thin.None then
            M.Bar_Win := Xlib_Thin.XCreateWindow
              (Dwm_State.Dpy, Dwm_State.Root, Xlib_Thin.C_Int (M.Wx), Xlib_Thin.C_Int (M.By),
               Xlib_Thin.C_UInt (M.Ww), Xlib_Thin.C_UInt (Dwm_State.Bh), 0,
               Xlib_Thin.XDefaultDepth (Dwm_State.Dpy, Dwm_State.Screen), Xlib_Thin.Copy_From_Parent,
               Xlib_Thin.XDefaultVisual (Dwm_State.Dpy, Dwm_State.Screen),
               Xlib_Thin.CWOverrideRedirect or Xlib_Thin.CWBackPixmap or Xlib_Thin.CWEventMask,
               Wa'Access);
            Ignore := Xlib_Thin.XDefineCursor
              (Dwm_State.Dpy, M.Bar_Win, Dwm_State.Cursors (Dwm_State.Cur_Normal).Cursor);
            Ignore := Xlib_Thin.XMapRaised (Dwm_State.Dpy, M.Bar_Win);
            Ignore := Xlib_Thin.XSetClassHint (Dwm_State.Dpy, M.Bar_Win, Ch'Access);
         end if;
         M := M.Next;
      end loop;
   end Update_Bars;

   procedure Update_Status is
      Text : constant String := Dwm_Xutil.Get_Text_Prop (Dwm_State.Root, Xlib_Thin.XA_WM_NAME);
   begin
      if Text'Length = 0 then
         Dwm_State.Stext :=
           Dwm_Types.Client_Name_Strings.To_Bounded_String ("dwm-" & Dwm_State.Version);
      else
         Dwm_State.Stext := Dwm_Types.Client_Name_Strings.To_Bounded_String (Text);
      end if;
      Draw_Bar (Dwm_State.Sel_Mon);
   end Update_Status;

end Dwm_Bar;
