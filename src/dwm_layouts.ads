with Dwm_Types;

--  Port of the two built-in layout algorithms (tile/monocle) from
--  dwm.c. Depends on Dwm_Clients for Next_Tiled/Resize; arrange()/
--  arrangemon() themselves live in Dwm_Clients (see its header comment
--  for why) and invoke these only indirectly, through the function
--  pointer stored in Monitor.Layout -- never by name -- so this package
--  never needs to be named back from there.
package Dwm_Layouts is

   --  The default "[]=" layout: up to Num_Master tiled clients stacked
   --  in a master column on the left sized by Master_Factor, the rest
   --  stacked in a second column filling the remaining width (tile()).
   procedure Tile (Monitor : in Dwm_Types.Monitor_Access);

   --  The "[M]" layout: every tiled client resized to fill the whole
   --  window area, overlapping (monocle()); Monitor.Lt_Symbol is
   --  overridden to show the visible client count, e.g. "[3]".
   procedure Monocle (Monitor : in Dwm_Types.Monitor_Access);

end Dwm_Layouts;
