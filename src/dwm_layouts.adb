with Ada.Strings.Fixed;
with Dwm_Clients;
with Util;

package body Dwm_Layouts is

   use type Dwm_Types.Client_Access;

   procedure Monocle (Monitor : Dwm_Types.Monitor_Access) is
      Visible_Count : Natural := 0;
      Client : Dwm_Types.Client_Access;
   begin
      Client := Monitor.Clients;
      while Client /= null loop
         if Dwm_Types.Is_Visible (Client) then
            Visible_Count := Visible_Count + 1;
         end if;
         Client := Client.Next;
      end loop;
      if Visible_Count > 0 then
         Monitor.Lt_Symbol := Dwm_Types.Lt_Symbol_Strings.To_Bounded_String
           ("[" & Ada.Strings.Fixed.Trim (Natural'Image (Visible_Count), Ada.Strings.Left) & "]");
      end if;
      Client := Dwm_Clients.Next_Tiled (Monitor.Clients);
      while Client /= null loop
         Dwm_Clients.Resize
           (Client, Monitor.Work_X, Monitor.Work_Y,
            Monitor.Work_Width - 2 * Client.Border_Width, Monitor.Work_Height - 2 * Client.Border_Width, False);
         Client := Dwm_Clients.Next_Tiled (Client.Next);
      end loop;
   end Monocle;

   procedure Tile (Monitor : Dwm_Types.Monitor_Access) is
      Client_Count : Integer := 0;
      Client       : Dwm_Types.Client_Access;
      Master_Width : Integer;
      Master_Y, Tile_Y : Integer := 0;
      Client_Height : Integer;
      Idx : Integer := 0;
   begin
      Client := Dwm_Clients.Next_Tiled (Monitor.Clients);
      while Client /= null loop
         Client_Count := Client_Count + 1;
         Client := Dwm_Clients.Next_Tiled (Client.Next);
      end loop;
      if Client_Count = 0 then
         return;
      end if;

      if Client_Count > Monitor.Num_Master then
         Master_Width :=
           (if Monitor.Num_Master /= 0
            then Integer (Float (Monitor.Work_Width) * Monitor.Master_Factor)
            else 0);
      else
         Master_Width := Monitor.Work_Width;
      end if;

      Client := Dwm_Clients.Next_Tiled (Monitor.Clients);
      Idx := 0;
      while Client /= null loop
         if Idx < Monitor.Num_Master then
            Client_Height :=
              (Monitor.Work_Height - Master_Y) / (Util.Min_Integer (Client_Count, Monitor.Num_Master) - Idx);
            Dwm_Clients.Resize
              (Client, Monitor.Work_X, Monitor.Work_Y + Master_Y,
               Master_Width - 2 * Client.Border_Width, Client_Height - 2 * Client.Border_Width, False);
            if Master_Y + Dwm_Types.Outer_Height (Client) < Monitor.Work_Height then
               Master_Y := Master_Y + Dwm_Types.Outer_Height (Client);
            end if;
         else
            Client_Height := (Monitor.Work_Height - Tile_Y) / (Client_Count - Idx);
            Dwm_Clients.Resize
              (Client, Monitor.Work_X + Master_Width, Monitor.Work_Y + Tile_Y,
               Monitor.Work_Width - Master_Width - 2 * Client.Border_Width,
               Client_Height - 2 * Client.Border_Width, False);
            if Tile_Y + Dwm_Types.Outer_Height (Client) < Monitor.Work_Height then
               Tile_Y := Tile_Y + Dwm_Types.Outer_Height (Client);
            end if;
         end if;
         Idx := Idx + 1;
         Client := Dwm_Clients.Next_Tiled (Client.Next);
      end loop;
   end Tile;

end Dwm_Layouts;
