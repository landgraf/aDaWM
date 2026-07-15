with Ada.Strings.Fixed;
with Dwm_Clients;
with Util;

package body Dwm_Layouts is

   use type Dwm_Types.Client_Access;

   procedure Monocle (M : Dwm_Types.Monitor_Access) is
      N : Natural := 0;
      C : Dwm_Types.Client_Access;
   begin
      C := M.Clients;
      while C /= null loop
         if Dwm_Types.Is_Visible (C) then
            N := N + 1;
         end if;
         C := C.Next;
      end loop;
      if N > 0 then
         M.Ltsymbol := Dwm_Types.Lt_Symbol_Strings.To_Bounded_String
           ("[" & Ada.Strings.Fixed.Trim (Natural'Image (N), Ada.Strings.Left) & "]");
      end if;
      C := Dwm_Clients.Nexttiled (M.Clients);
      while C /= null loop
         Dwm_Clients.Resize (C, M.Wx, M.Wy, M.Ww - 2 * C.Bw, M.Wh - 2 * C.Bw, False);
         C := Dwm_Clients.Nexttiled (C.Next);
      end loop;
   end Monocle;

   procedure Tile (M : Dwm_Types.Monitor_Access) is
      N  : Integer := 0;
      C  : Dwm_Types.Client_Access;
      Mw : Integer;
      My, Ty : Integer := 0;
      H  : Integer;
      I  : Integer := 0;
   begin
      C := Dwm_Clients.Nexttiled (M.Clients);
      while C /= null loop
         N := N + 1;
         C := Dwm_Clients.Nexttiled (C.Next);
      end loop;
      if N = 0 then
         return;
      end if;

      if N > M.Nmaster then
         Mw := (if M.Nmaster /= 0 then Integer (Float (M.Ww) * M.Mfact) else 0);
      else
         Mw := M.Ww;
      end if;

      C := Dwm_Clients.Nexttiled (M.Clients);
      I := 0;
      while C /= null loop
         if I < M.Nmaster then
            H := (M.Wh - My) / (Util.Min_Integer (N, M.Nmaster) - I);
            Dwm_Clients.Resize (C, M.Wx, M.Wy + My, Mw - 2 * C.Bw, H - 2 * C.Bw, False);
            if My + Dwm_Types.Height (C) < M.Wh then
               My := My + Dwm_Types.Height (C);
            end if;
         else
            H := (M.Wh - Ty) / (N - I);
            Dwm_Clients.Resize (C, M.Wx + Mw, M.Wy + Ty, M.Ww - Mw - 2 * C.Bw, H - 2 * C.Bw, False);
            if Ty + Dwm_Types.Height (C) < M.Wh then
               Ty := Ty + Dwm_Types.Height (C);
            end if;
         end if;
         I := I + 1;
         C := Dwm_Clients.Nexttiled (C.Next);
      end loop;
   end Tile;

end Dwm_Layouts;
