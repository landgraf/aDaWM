with Dwm_Types;

--  Port of the two built-in layout algorithms (tile/monocle) from
--  dwm.c. Depends on Dwm_Clients for Next_Tiled/Resize; arrange()/
--  arrangemon() themselves live in Dwm_Clients (see its header comment
--  for why) and invoke these only indirectly, through the function
--  pointer stored in Monitor.Lt -- never by name -- so this package
--  never needs to be named back from there.
package Dwm_Layouts is

   procedure Tile (M : Dwm_Types.Monitor_Access);
   procedure Monocle (M : Dwm_Types.Monitor_Access);

end Dwm_Layouts;
