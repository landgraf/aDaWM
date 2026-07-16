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

   --  Private helper; spec given here (rather than in dwm_bar.ads)
   --  since it's not part of the public API.
   procedure Text_Width (S : in String; Result : out Natural);

   --------------------------------------------------------------------
   --  Subprogram bodies (alphabetical order; -gnatyo)                --
   --------------------------------------------------------------------

   procedure Draw_Bar (Monitor : in Dwm_Types.Monitor_Access) is
      Box_Pad : constant Natural := Dwm_State.Get_Drw_Ctx.Fonts.Height / 9;
      Box_Width : constant Natural := Dwm_State.Get_Drw_Ctx.Fonts.Height / 6 + 2;
      Occupied, Urgent : Dwm_Types.Tag_Mask := 0;
      Client : Dwm_Types.Client_Access;
      Cur_X  : Integer;
      Remaining_Width : Integer;
      Status_Width : Integer := 0;
      Ignore : Integer;
      Ignore_Natural : Natural;
   begin
      if not Monitor.Show_Bar then
         return;
      end if;

      if Monitor = Dwm_State.Get_Selected_Monitor then
         Drw.Set_Scheme (Dwm_State.Get_Drw_Ctx, Dwm_State.Get_Scheme (Dwm_Types.Scheme_Norm));
         Text_Width (Dwm_Types.Client_Name_Strings.To_String (Dwm_State.Get_Stext), Ignore_Natural);
         Status_Width := Ignore_Natural - Dwm_State.Get_Left_Right_Pad + 2;
         Drw.Text
           (Dwm_State.Get_Drw_Ctx, Monitor.Work_Width - Status_Width, 0, Status_Width, Dwm_State.Get_Bar_Height, 0,
            Dwm_Types.Client_Name_Strings.To_String (Dwm_State.Get_Stext), 0, Ignore);
      end if;

      Client := Monitor.Clients;
      while Client /= null loop
         Occupied := Occupied or Client.Tags;
         if Client.Is_Urgent then
            Urgent := Urgent or Client.Tags;
         end if;
         Client := Client.Next;
      end loop;

      Cur_X := 0;
      for Idx in Config.Tags'Range loop
         declare
            Bit : constant Dwm_Types.Tag_Mask := 2 ** (Idx - Config.Tags'First);
            Label_Width : Natural;
         begin
            Text_Width (Config.Tags (Idx).all, Label_Width);
            Drw.Set_Scheme
              (Dwm_State.Get_Drw_Ctx,
               Dwm_State.Get_Scheme
                 (if (Monitor.Tag_Set (Monitor.Sel_Tags) and Bit) /= 0
                  then Dwm_Types.Scheme_Sel else Dwm_Types.Scheme_Norm));
            Drw.Text
              (Dwm_State.Get_Drw_Ctx, Cur_X, 0, Label_Width, Dwm_State.Get_Bar_Height,
               Dwm_State.Get_Left_Right_Pad / 2, Config.Tags (Idx).all, (if (Urgent and Bit) /= 0 then 1 else 0),
               Ignore);
            if (Occupied and Bit) /= 0 then
               Drw.Rect
                 (Dwm_State.Get_Drw_Ctx, Cur_X + Box_Pad, Box_Pad, Box_Width, Box_Width,
                  (if Monitor = Dwm_State.Get_Selected_Monitor
                     and then Dwm_State.Get_Selected_Monitor.Selected_Client /= null
                     and then (Dwm_State.Get_Selected_Monitor.Selected_Client.Tags and Bit) /= 0
                   then 1 else 0),
                  (if (Urgent and Bit) /= 0 then 1 else 0));
            end if;
            Cur_X := Cur_X + Label_Width;
         end;
      end loop;

      declare
         Label_Width : Natural;
         New_Cur_X : Integer;
      begin
         Text_Width (Dwm_Types.Lt_Symbol_Strings.To_String (Monitor.Lt_Symbol), Label_Width);
         Drw.Set_Scheme (Dwm_State.Get_Drw_Ctx, Dwm_State.Get_Scheme (Dwm_Types.Scheme_Norm));
         Drw.Text
           (Dwm_State.Get_Drw_Ctx, Cur_X, 0, Label_Width, Dwm_State.Get_Bar_Height, Dwm_State.Get_Left_Right_Pad / 2,
            Dwm_Types.Lt_Symbol_Strings.To_String (Monitor.Lt_Symbol), 0, New_Cur_X);
         Cur_X := New_Cur_X;
      end;

      Remaining_Width := Monitor.Work_Width - Status_Width - Cur_X;
      if Remaining_Width > Dwm_State.Get_Bar_Height then
         if Monitor.Selected_Client /= null then
            Drw.Set_Scheme
              (Dwm_State.Get_Drw_Ctx,
               Dwm_State.Get_Scheme
                 (if Monitor = Dwm_State.Get_Selected_Monitor then Dwm_Types.Scheme_Sel else Dwm_Types.Scheme_Norm));
            Drw.Text
              (Dwm_State.Get_Drw_Ctx, Cur_X, 0, Remaining_Width, Dwm_State.Get_Bar_Height,
               Dwm_State.Get_Left_Right_Pad / 2,
               Dwm_Types.Client_Name_Strings.To_String (Monitor.Selected_Client.Name), 0, Ignore);
            if Monitor.Selected_Client.Is_Floating then
               Drw.Rect
                 (Dwm_State.Get_Drw_Ctx, Cur_X + Box_Pad, Box_Pad, Box_Width, Box_Width,
                  (if Monitor.Selected_Client.Is_Fixed then 1 else 0), 0);
            end if;
         else
            Drw.Set_Scheme (Dwm_State.Get_Drw_Ctx, Dwm_State.Get_Scheme (Dwm_Types.Scheme_Norm));
            Drw.Rect (Dwm_State.Get_Drw_Ctx, Cur_X, 0, Remaining_Width, Dwm_State.Get_Bar_Height, 1, 1);
         end if;
      end if;
      Drw.Map (Dwm_State.Get_Drw_Ctx, Monitor.Bar_Window, 0, 0, Monitor.Work_Width, Dwm_State.Get_Bar_Height);
   end Draw_Bar;

   procedure Draw_Bars is
      Monitor : Dwm_Types.Monitor_Access := Dwm_State.Get_Monitors;
   begin
      while Monitor /= null loop
         Draw_Bar (Monitor);
         Monitor := Monitor.Next;
      end loop;
   end Draw_Bars;

   procedure Text_Width (S : in String; Result : out Natural) is
   begin
      Drw.Fontset_Get_Width (Dwm_State.Get_Drw_Ctx, S, Result);
      Result := Result + Dwm_State.Get_Left_Right_Pad;
   end Text_Width;

   procedure Update_Bars is
      Attrs : aliased Xlib_Thin.XSetWindowAttributes;
      Class_Hint : aliased Xlib_Thin.XClassHint;
      Monitor : Dwm_Types.Monitor_Access := Dwm_State.Get_Monitors;
      Class_Name : Interfaces.C.Strings.chars_ptr := Interfaces.C.Strings.New_String ("dwm");
      Ignore : Xlib_Thin.C_Int;
   begin
      Attrs.Override_Redirect := 1;
      Attrs.Background_Pixmap := Xlib_Thin.Parent_Relative;
      Attrs.Event_Mask := Xlib_Thin.ButtonPressMask or Xlib_Thin.ExposureMask;
      Class_Hint.Res_Name := Class_Name;
      Class_Hint.Res_Class := Class_Name;
      while Monitor /= null loop
         if Monitor.Bar_Window = Xlib_Thin.None then
            Monitor.Bar_Window := Xlib_Thin.XCreateWindow
              (Dwm_State.Get_Display, Dwm_State.Get_Root, Xlib_Thin.C_Int (Monitor.Work_X),
               Xlib_Thin.C_Int (Monitor.Bar_Y),
               Xlib_Thin.C_UInt (Monitor.Work_Width), Xlib_Thin.C_UInt (Dwm_State.Get_Bar_Height), 0,
               Xlib_Thin.XDefaultDepth (Dwm_State.Get_Display, Dwm_State.Get_Screen), Xlib_Thin.Copy_From_Parent,
               Xlib_Thin.XDefaultVisual (Dwm_State.Get_Display, Dwm_State.Get_Screen),
               Xlib_Thin.CWOverrideRedirect or Xlib_Thin.CWBackPixmap or Xlib_Thin.CWEventMask,
               Attrs'Access);
            Ignore := Xlib_Thin.XDefineCursor
              (Dwm_State.Get_Display, Monitor.Bar_Window, Dwm_State.Get_Cursor (Dwm_State.Cursor_Normal).X_Cursor);
            Ignore := Xlib_Thin.XMapRaised (Dwm_State.Get_Display, Monitor.Bar_Window);
            Ignore := Xlib_Thin.XSetClassHint (Dwm_State.Get_Display, Monitor.Bar_Window, Class_Hint'Access);
         end if;
         Monitor := Monitor.Next;
      end loop;
      Interfaces.C.Strings.Free (Class_Name);
   end Update_Bars;

   procedure Update_Status is
      Text : constant String := Dwm_Xutil.Get_Text_Prop (Dwm_State.Get_Root, Xlib_Thin.XA_WM_NAME);
   begin
      if Text'Length = 0 then
         Dwm_State.Set_Stext
           (Dwm_Types.Client_Name_Strings.To_Bounded_String ("dwm-" & Dwm_State.Version));
      else
         Dwm_State.Set_Stext (Dwm_Types.Client_Name_Strings.To_Bounded_String (Text));
      end if;
      Draw_Bar (Dwm_State.Get_Selected_Monitor);
   end Update_Status;

end Dwm_Bar;
