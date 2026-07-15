with Dwm_Types;

--  Port of the bar-related parts of dwm.c: drawbar/drawbars,
--  updatebars, updatestatus. updatebarpos lives in Dwm_Monitors instead
--  (pure monitor-geometry bookkeeping, no window/drawing calls).
package Dwm_Bar is

   procedure Drawbar (M : Dwm_Types.Monitor_Access);
   procedure Drawbars;
   procedure Updatebars;
   procedure Updatestatus;

end Dwm_Bar;
