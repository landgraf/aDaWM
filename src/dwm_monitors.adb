with Ada.Strings;
with Ada.Unchecked_Conversion;
with Interfaces.C;
with System;
with System.Storage_Elements;
with Config;
with Dwm_Bar;
with Dwm_Clients;
with Dwm_State;
with Dwm_Xutil;
with Util;
with Xinerama_Thin;

package body Dwm_Monitors is

   use type Xlib_Thin.C_Int;
   use type Xlib_Thin.XID;
   use type System.Address;
   use type System.Storage_Elements.Storage_Offset;
   use type Interfaces.C.short;
   use type Dwm_Types.Client_Access;
   use type Dwm_Types.Monitor_Access;
   use type Dwm_Types.Layout_Const_Access;

   type Xinerama_Info_Access is access all Xinerama_Thin.XineramaScreenInfo;
   function To_Info_Access is new Ada.Unchecked_Conversion
     (System.Address, Xinerama_Info_Access);

   Xinerama_Info_Elem_Size : constant System.Storage_Elements.Storage_Offset :=
     Xinerama_Thin.XineramaScreenInfo'Size / 8;

   --  Private helpers used only by Update_Geom's Xinerama path; specs
   --  given here (rather than in dwm_monitors.ads) since they're not
   --  part of the public API.
   function Info_At (Base : System.Address; Index : Natural) return Xinerama_Thin.XineramaScreenInfo;

   type Info_Array is array (Natural range <>) of Xinerama_Thin.XineramaScreenInfo;

   function Is_Unique_Geom
     (Unique : Info_Array; Count : Natural; Info : Xinerama_Thin.XineramaScreenInfo) return Boolean;

   --------------------------------------------------------------------
   --  Subprogram bodies (alphabetical order; -gnatyo)                --
   --------------------------------------------------------------------

   procedure Cleanup_Mon (Mon : Dwm_Types.Monitor_Access) is
      M  : Dwm_Types.Monitor_Access;
      Mv : Dwm_Types.Monitor_Access := Mon;
      Ignore : Xlib_Thin.C_Int;
   begin
      if Mon = Dwm_State.Mons then
         Dwm_State.Mons := Dwm_State.Mons.Next;
      else
         M := Dwm_State.Mons;
         while M /= null and then M.Next /= Mon loop
            M := M.Next;
         end loop;
         if M /= null then
            M.Next := Mon.Next;
         end if;
      end if;
      Ignore := Xlib_Thin.XUnmapWindow (Dwm_State.Dpy, Mon.Bar_Win);
      Ignore := Xlib_Thin.XDestroyWindow (Dwm_State.Dpy, Mon.Bar_Win);
      Dwm_Types.Free_Monitor (Mv);
   end Cleanup_Mon;

   function Create_Mon return Dwm_Types.Monitor_Access is
      M : constant Dwm_Types.Monitor_Access := new Dwm_Types.Monitor;
   begin
      M.Tag_Set := (1, 1);
      M.Mfact := Config.Mfact;
      M.Nmaster := Config.Nmaster;
      M.Show_Bar := Config.Show_Bar;
      M.Top_Bar := Config.Top_Bar;
      M.Lt := Dwm_State.Default_Lt;
      if Dwm_State.Default_Lt (0) /= null then
         M.Lt_Symbol := Dwm_Types.Lt_Symbol_Strings.To_Bounded_String
           (Dwm_State.Default_Lt (0).Symbol.all, Ada.Strings.Right);
      end if;
      return M;
   end Create_Mon;

   function Dir_To_Mon (Dir : Integer) return Dwm_Types.Monitor_Access is
      M : Dwm_Types.Monitor_Access := null;
   begin
      if Dir > 0 then
         M := Dwm_State.Sel_Mon.Next;
         if M = null then
            M := Dwm_State.Mons;
         end if;
      elsif Dwm_State.Sel_Mon = Dwm_State.Mons then
         M := Dwm_State.Mons;
         while M.Next /= null loop
            M := M.Next;
         end loop;
      else
         M := Dwm_State.Mons;
         while M.Next /= Dwm_State.Sel_Mon loop
            M := M.Next;
         end loop;
      end if;
      return M;
   end Dir_To_Mon;

   procedure Expose (Ev : access Xlib_Thin.XEvent) is
      Exp : Xlib_Thin.XExposeEvent with Address => Ev.all'Address;
      pragma Import (Ada, Exp);
      M : Dwm_Types.Monitor_Access;
   begin
      if Exp.Count = 0 then
         M := Win_To_Mon (Exp.Win);
         if M /= null then
            Dwm_Bar.Draw_Bar (M);
         end if;
      end if;
   end Expose;

   function Info_At (Base : System.Address; Index : Natural) return Xinerama_Thin.XineramaScreenInfo
   is
   begin
      return To_Info_Access
        (Base + System.Storage_Elements.Storage_Offset (Index) * Xinerama_Info_Elem_Size).all;
   end Info_At;

   function Is_Unique_Geom
     (Unique : Info_Array; Count : Natural; Info : Xinerama_Thin.XineramaScreenInfo) return Boolean
   is
   begin
      for I in 0 .. Count - 1 loop
         if Unique (I).X_Org = Info.X_Org and then Unique (I).Y_Org = Info.Y_Org
           and then Unique (I).Width = Info.Width and then Unique (I).Height = Info.Height
         then
            return False;
         end if;
      end loop;
      return True;
   end Is_Unique_Geom;

   function Rect_To_Mon (X, Y, W, H : Integer) return Dwm_Types.Monitor_Access is
      M, R : Dwm_Types.Monitor_Access;
      Area, A : Integer := 0;
   begin
      R := Dwm_State.Sel_Mon;
      M := Dwm_State.Mons;
      while M /= null loop
         A := Util.Max_Integer (0, Util.Min_Integer (X + W, M.Wx + M.Ww) - Util.Max_Integer (X, M.Wx))
            * Util.Max_Integer (0, Util.Min_Integer (Y + H, M.Wy + M.Wh) - Util.Max_Integer (Y, M.Wy));
         if A > Area then
            Area := A;
            R := M;
         end if;
         M := M.Next;
      end loop;
      return R;
   end Rect_To_Mon;

   procedure Update_Bar_Pos (M : Dwm_Types.Monitor_Access) is
   begin
      M.Wy := M.My;
      M.Wh := M.Mh;
      if M.Show_Bar then
         M.Wh := M.Wh - Dwm_State.Bh;
         M.By := (if M.Top_Bar then M.Wy else M.Wy + M.Wh);
         M.Wy := (if M.Top_Bar then M.Wy + Dwm_State.Bh else M.Wy);
      else
         M.By := -Dwm_State.Bh;
      end if;
   end Update_Bar_Pos;

   function Update_Geom return Boolean is
      Dirty : Boolean := False;
      Active : Xlib_Thin.C_Int;
   begin
      Active := Xinerama_Thin.XineramaIsActive (Dwm_State.Dpy);
      if Active /= 0 then
         declare
            Nn_C : aliased Xlib_Thin.C_Int;
            Info_Addr : System.Address;
            N : Natural := 0;
            M, Mm : Dwm_Types.Monitor_Access;
            C : Dwm_Types.Client_Access;
            Ignore : Xlib_Thin.C_Int;
         begin
            Info_Addr := Xinerama_Thin.XineramaQueryScreens (Dwm_State.Dpy, Nn_C'Access);

            M := Dwm_State.Mons;
            while M /= null loop
               N := N + 1;
               M := M.Next;
            end loop;

            declare
               Nn_In : constant Natural := Natural (Nn_C);
               Unique : Info_Array (0 .. Natural'Max (Nn_In, 1) - 1);
               J : Natural := 0;
            begin
               for I in 0 .. Nn_In - 1 loop
                  declare
                     Info : constant Xinerama_Thin.XineramaScreenInfo := Info_At (Info_Addr, I);
                  begin
                     if Is_Unique_Geom (Unique, J, Info) then
                        Unique (J) := Info;
                        J := J + 1;
                     end if;
                  end;
               end loop;
               Ignore := Xlib_Thin.XFree (Info_Addr);

               declare
                  Nn : constant Natural := J;
               begin
                  for I in N .. Nn - 1 loop
                     M := Dwm_State.Mons;
                     while M /= null and then M.Next /= null loop
                        M := M.Next;
                     end loop;
                     if M /= null then
                        M.Next := Create_Mon;
                     else
                        Dwm_State.Mons := Create_Mon;
                     end if;
                  end loop;

                  M := Dwm_State.Mons;
                  for I in 0 .. Nn - 1 loop
                     exit when M = null;
                     if I >= N or else Unique (I).X_Org /= Xlib_Thin.C_Short (M.Mx)
                       or else Unique (I).Y_Org /= Xlib_Thin.C_Short (M.My)
                       or else Unique (I).Width /= Xlib_Thin.C_Short (M.Mw)
                       or else Unique (I).Height /= Xlib_Thin.C_Short (M.Mh)
                     then
                        Dirty := True;
                        M.Num := I;
                        M.Mx := Integer (Unique (I).X_Org);
                        M.Wx := M.Mx;
                        M.My := Integer (Unique (I).Y_Org);
                        M.Wy := M.My;
                        M.Mw := Integer (Unique (I).Width);
                        M.Ww := M.Mw;
                        M.Mh := Integer (Unique (I).Height);
                        M.Wh := M.Mh;
                        Update_Bar_Pos (M);
                     end if;
                     M := M.Next;
                  end loop;

                  for I in Nn .. N - 1 loop
                     M := Dwm_State.Mons;
                     while M /= null and then M.Next /= null loop
                        M := M.Next;
                     end loop;
                     exit when M = null;
                     while M.Clients /= null loop
                        Dirty := True;
                        C := M.Clients;
                        M.Clients := C.Next;
                        Dwm_Clients.Detach_Stack (C);
                        C.Mon := Dwm_State.Mons;
                        Dwm_Clients.Attach (C);
                        Dwm_Clients.Attach_Stack (C);
                     end loop;
                     if M = Dwm_State.Sel_Mon then
                        Dwm_State.Sel_Mon := Dwm_State.Mons;
                     end if;
                     Mm := M;
                     Cleanup_Mon (Mm);
                  end loop;
               end;
            end;
         end;
      else
         if Dwm_State.Mons = null then
            Dwm_State.Mons := Create_Mon;
         end if;
         if Dwm_State.Mons.Mw /= Dwm_State.Sw or else Dwm_State.Mons.Mh /= Dwm_State.Sh then
            Dirty := True;
            Dwm_State.Mons.Mw := Dwm_State.Sw;
            Dwm_State.Mons.Ww := Dwm_State.Sw;
            Dwm_State.Mons.Mh := Dwm_State.Sh;
            Dwm_State.Mons.Wh := Dwm_State.Sh;
            Update_Bar_Pos (Dwm_State.Mons);
         end if;
      end if;
      if Dirty then
         Dwm_State.Sel_Mon := Dwm_State.Mons;
         Dwm_State.Sel_Mon := Win_To_Mon (Dwm_State.Root);
      end if;
      return Dirty;
   end Update_Geom;

   function Win_To_Mon (Win : Xlib_Thin.Window) return Dwm_Types.Monitor_Access is
      X, Y : Integer;
      C : Dwm_Types.Client_Access;
      M : Dwm_Types.Monitor_Access;
   begin
      if Win = Dwm_State.Root and then Dwm_Xutil.Get_Root_Ptr (X, Y) then
         return Rect_To_Mon (X, Y, 1, 1);
      end if;
      M := Dwm_State.Mons;
      while M /= null loop
         if Win = M.Bar_Win then
            return M;
         end if;
         M := M.Next;
      end loop;
      C := Dwm_Clients.Win_To_Client (Win);
      if C /= null then
         return C.Mon;
      end if;
      return Dwm_State.Sel_Mon;
   end Win_To_Mon;

end Dwm_Monitors;
