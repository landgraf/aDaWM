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
   function Info_At (Base : in System.Address; Index : in Natural) return Xinerama_Thin.XineramaScreenInfo;

   type Info_Array is array (Natural range <>) of Xinerama_Thin.XineramaScreenInfo;

   function Is_Unique_Geom
     (Unique : in Info_Array; Count : in Natural; Info : in Xinerama_Thin.XineramaScreenInfo) return Boolean;

   --------------------------------------------------------------------
   --  Subprogram bodies (alphabetical order; -gnatyo)                --
   --------------------------------------------------------------------

   procedure Cleanup_Mon (Monitor : in Dwm_Types.Monitor_Access) is
      Cur : Dwm_Types.Monitor_Access;
      Freed_Monitor : Dwm_Types.Monitor_Access := Monitor;
      Ignore : Xlib_Thin.C_Int;
   begin
      if Monitor = Dwm_State.Get_Monitors then
         Dwm_State.Set_Monitors (Dwm_State.Get_Monitors.Next);
      else
         Cur := Dwm_State.Get_Monitors;
         while Cur /= null and then Cur.Next /= Monitor loop
            Cur := Cur.Next;
         end loop;
         if Cur /= null then
            Cur.Next := Monitor.Next;
         end if;
      end if;
      Ignore := Xlib_Thin.XUnmapWindow (Dwm_State.Get_Display, Monitor.Bar_Window);
      Ignore := Xlib_Thin.XDestroyWindow (Dwm_State.Get_Display, Monitor.Bar_Window);
      Dwm_Types.Free_Per_Tag (Freed_Monitor.Per_Tag);
      Dwm_Types.Free_Monitor (Freed_Monitor);
   end Cleanup_Mon;

   function Create_Mon return Dwm_Types.Monitor_Access is
      Monitor : constant Dwm_Types.Monitor_Access := new Dwm_Types.Monitor;
   begin
      Monitor.Tag_Set := (1, 1);
      Monitor.Master_Factor := Config.Master_Factor;
      Monitor.Num_Master := Config.Num_Master;
      Monitor.Show_Bar := Config.Show_Bar;
      Monitor.Top_Bar := Config.Top_Bar;
      Monitor.Layout := Dwm_State.Get_Default_Layout;
      if Dwm_State.Get_Default_Layout (0) /= null then
         Monitor.Lt_Symbol := Dwm_Types.Lt_Symbol_Strings.To_Bounded_String
           (Dwm_State.Get_Default_Layout (0).Symbol.all, Ada.Strings.Right);
      end if;

      Monitor.Per_Tag := new Dwm_Types.Per_Tag_State;
      Monitor.Per_Tag.Cur_Tag := 1;
      Monitor.Per_Tag.Prev_Tag := 1;
      for Tag in 0 .. Config.Tags'Length loop
         Monitor.Per_Tag.Num_Masters (Tag) := Monitor.Num_Master;
         Monitor.Per_Tag.Master_Factors (Tag) := Monitor.Master_Factor;
         Monitor.Per_Tag.Layouts (Tag) := Monitor.Layout;
         Monitor.Per_Tag.Sel_Layouts (Tag) := Monitor.Sel_Lt;
         Monitor.Per_Tag.Show_Bars (Tag) := Monitor.Show_Bar;
      end loop;

      return Monitor;
   end Create_Mon;

   function Dir_To_Mon (Direction : in Integer) return Dwm_Types.Monitor_Access is
      Result : Dwm_Types.Monitor_Access := null;
   begin
      if Direction > 0 then
         Result := Dwm_State.Get_Selected_Monitor.Next;
         if Result = null then
            Result := Dwm_State.Get_Monitors;
         end if;
      elsif Dwm_State.Get_Selected_Monitor = Dwm_State.Get_Monitors then
         Result := Dwm_State.Get_Monitors;
         while Result.Next /= null loop
            Result := Result.Next;
         end loop;
      else
         Result := Dwm_State.Get_Monitors;
         while Result.Next /= Dwm_State.Get_Selected_Monitor loop
            Result := Result.Next;
         end loop;
      end if;
      return Result;
   end Dir_To_Mon;

   procedure Expose (Event : access Xlib_Thin.XEvent) is
      Expose_Event : Xlib_Thin.XExposeEvent with Address => Event.all'Address;
      pragma Import (Ada, Expose_Event);
      Monitor : Dwm_Types.Monitor_Access;
   begin
      if Expose_Event.Count = 0 then
         Monitor := Win_To_Mon (Expose_Event.Win);
         if Monitor /= null then
            Dwm_Bar.Draw_Bar (Monitor);
         end if;
      end if;
   end Expose;

   function Info_At (Base : in System.Address; Index : in Natural) return Xinerama_Thin.XineramaScreenInfo
   is
   begin
      return To_Info_Access
        (Base + System.Storage_Elements.Storage_Offset (Index) * Xinerama_Info_Elem_Size).all;
   end Info_At;

   function Is_Unique_Geom
     (Unique : in Info_Array; Count : in Natural; Info : in Xinerama_Thin.XineramaScreenInfo) return Boolean
   is
   begin
      for Idx in 0 .. Count - 1 loop
         if Unique (Idx).X_Org = Info.X_Org and then Unique (Idx).Y_Org = Info.Y_Org
           and then Unique (Idx).Width = Info.Width and then Unique (Idx).Height = Info.Height
         then
            return False;
         end if;
      end loop;
      return True;
   end Is_Unique_Geom;

   function Rect_To_Mon (Pos_X, Pos_Y, Width, Height : in Integer) return Dwm_Types.Monitor_Access is
      Monitor, Best : Dwm_Types.Monitor_Access;
      Best_Area, Cur_Area : Integer := 0;
   begin
      Best := Dwm_State.Get_Selected_Monitor;
      Monitor := Dwm_State.Get_Monitors;
      while Monitor /= null loop
         Cur_Area :=
           Util.Max_Integer
             (0, Util.Min_Integer (Pos_X + Width, Monitor.Work_X + Monitor.Work_Width)
                   - Util.Max_Integer (Pos_X, Monitor.Work_X))
           * Util.Max_Integer
               (0, Util.Min_Integer (Pos_Y + Height, Monitor.Work_Y + Monitor.Work_Height)
                     - Util.Max_Integer (Pos_Y, Monitor.Work_Y));
         if Cur_Area > Best_Area then
            Best_Area := Cur_Area;
            Best := Monitor;
         end if;
         Monitor := Monitor.Next;
      end loop;
      return Best;
   end Rect_To_Mon;

   procedure Update_Bar_Pos (Monitor : in Dwm_Types.Monitor_Access) is
   begin
      Monitor.Work_Y := Monitor.Screen_Y;
      Monitor.Work_Height := Monitor.Screen_Height;
      if Monitor.Show_Bar then
         Monitor.Work_Height := Monitor.Work_Height - Dwm_State.Get_Bar_Height;
         Monitor.Bar_Y := (if Monitor.Top_Bar then Monitor.Work_Y else Monitor.Work_Y + Monitor.Work_Height);
         Monitor.Work_Y :=
           (if Monitor.Top_Bar then Monitor.Work_Y + Dwm_State.Get_Bar_Height else Monitor.Work_Y);
      else
         Monitor.Bar_Y := -Dwm_State.Get_Bar_Height;
      end if;
   end Update_Bar_Pos;

   procedure Update_Geom (Dirty : out Boolean) is
      Active : Xlib_Thin.C_Int;
   begin
      Dirty := False;
      Active := Xinerama_Thin.XineramaIsActive (Dwm_State.Get_Display);
      if Active /= 0 then
         declare
            Screen_Count : aliased Xlib_Thin.C_Int;
            Info_Addr : System.Address;
            Existing_Count : Natural := 0;
            Monitor, To_Remove : Dwm_Types.Monitor_Access;
            Client : Dwm_Types.Client_Access;
            Ignore : Xlib_Thin.C_Int;
         begin
            Info_Addr := Xinerama_Thin.XineramaQueryScreens (Dwm_State.Get_Display, Screen_Count'Access);

            Monitor := Dwm_State.Get_Monitors;
            while Monitor /= null loop
               Existing_Count := Existing_Count + 1;
               Monitor := Monitor.Next;
            end loop;

            declare
               Screen_Count_Nat : constant Natural := Natural (Screen_Count);
               Unique : Info_Array (0 .. Natural'Max (Screen_Count_Nat, 1) - 1);
               Unique_Count : Natural := 0;
            begin
               for Idx in 0 .. Screen_Count_Nat - 1 loop
                  declare
                     Info : constant Xinerama_Thin.XineramaScreenInfo := Info_At (Info_Addr, Idx);
                  begin
                     if Is_Unique_Geom (Unique, Unique_Count, Info) then
                        Unique (Unique_Count) := Info;
                        Unique_Count := Unique_Count + 1;
                     end if;
                  end;
               end loop;
               Ignore := Xlib_Thin.XFree (Info_Addr);

               declare
                  Unique_Total : constant Natural := Unique_Count;
               begin
                  for Idx in Existing_Count .. Unique_Total - 1 loop
                     Monitor := Dwm_State.Get_Monitors;
                     while Monitor /= null and then Monitor.Next /= null loop
                        Monitor := Monitor.Next;
                     end loop;
                     if Monitor /= null then
                        Monitor.Next := Create_Mon;
                     else
                        Dwm_State.Set_Monitors (Create_Mon);
                     end if;
                  end loop;

                  Monitor := Dwm_State.Get_Monitors;
                  for Idx in 0 .. Unique_Total - 1 loop
                     exit when Monitor = null;
                     if Idx >= Existing_Count
                       or else Unique (Idx).X_Org /= Xlib_Thin.C_Short (Monitor.Screen_X)
                       or else Unique (Idx).Y_Org /= Xlib_Thin.C_Short (Monitor.Screen_Y)
                       or else Unique (Idx).Width /= Xlib_Thin.C_Short (Monitor.Screen_Width)
                       or else Unique (Idx).Height /= Xlib_Thin.C_Short (Monitor.Screen_Height)
                     then
                        Dirty := True;
                        Monitor.Number := Idx;
                        Monitor.Screen_X := Integer (Unique (Idx).X_Org);
                        Monitor.Work_X := Monitor.Screen_X;
                        Monitor.Screen_Y := Integer (Unique (Idx).Y_Org);
                        Monitor.Work_Y := Monitor.Screen_Y;
                        Monitor.Screen_Width := Integer (Unique (Idx).Width);
                        Monitor.Work_Width := Monitor.Screen_Width;
                        Monitor.Screen_Height := Integer (Unique (Idx).Height);
                        Monitor.Work_Height := Monitor.Screen_Height;
                        Update_Bar_Pos (Monitor);
                     end if;
                     Monitor := Monitor.Next;
                  end loop;

                  for Idx in Unique_Total .. Existing_Count - 1 loop
                     Monitor := Dwm_State.Get_Monitors;
                     while Monitor /= null and then Monitor.Next /= null loop
                        Monitor := Monitor.Next;
                     end loop;
                     exit when Monitor = null;
                     while Monitor.Clients /= null loop
                        Dirty := True;
                        Client := Monitor.Clients;
                        Monitor.Clients := Client.Next;
                        Dwm_Clients.Detach_Stack (Client);
                        Client.Monitor := Dwm_State.Get_Monitors;
                        Dwm_Clients.Attach (Client);
                        Dwm_Clients.Attach_Stack (Client);
                     end loop;
                     if Monitor = Dwm_State.Get_Selected_Monitor then
                        Dwm_State.Set_Selected_Monitor (Dwm_State.Get_Monitors);
                     end if;
                     To_Remove := Monitor;
                     Cleanup_Mon (To_Remove);
                  end loop;
               end;
            end;
         end;
      else
         if Dwm_State.Get_Monitors = null then
            Dwm_State.Set_Monitors (Create_Mon);
         end if;
         if Dwm_State.Get_Monitors.Screen_Width /= Dwm_State.Get_Screen_Width
           or else Dwm_State.Get_Monitors.Screen_Height /= Dwm_State.Get_Screen_Height
         then
            Dirty := True;
            Dwm_State.Get_Monitors.Screen_Width := Dwm_State.Get_Screen_Width;
            Dwm_State.Get_Monitors.Work_Width := Dwm_State.Get_Screen_Width;
            Dwm_State.Get_Monitors.Screen_Height := Dwm_State.Get_Screen_Height;
            Dwm_State.Get_Monitors.Work_Height := Dwm_State.Get_Screen_Height;
            Update_Bar_Pos (Dwm_State.Get_Monitors);
         end if;
      end if;
      if Dirty then
         Dwm_State.Set_Selected_Monitor (Dwm_State.Get_Monitors);
         Dwm_State.Set_Selected_Monitor (Win_To_Mon (Dwm_State.Get_Root));
      end if;
   end Update_Geom;

   function Win_To_Mon (Window : in Xlib_Thin.Window) return Dwm_Types.Monitor_Access is
      Client : Dwm_Types.Client_Access;
      Monitor : Dwm_Types.Monitor_Access;
   begin
      if Window = Dwm_State.Get_Root then
         declare
            Ptr : constant Dwm_Xutil.Root_Ptr_Result := Dwm_Xutil.Get_Root_Ptr;
         begin
            if Ptr.Found then
               return Rect_To_Mon (Ptr.Pos_X, Ptr.Pos_Y, 1, 1);
            end if;
         end;
      end if;
      Monitor := Dwm_State.Get_Monitors;
      while Monitor /= null loop
         if Window = Monitor.Bar_Window then
            return Monitor;
         end if;
         Monitor := Monitor.Next;
      end loop;
      Client := Dwm_Clients.Win_To_Client (Window);
      if Client /= null then
         return Client.Monitor;
      end if;
      return Dwm_State.Get_Selected_Monitor;
   end Win_To_Mon;

end Dwm_Monitors;
