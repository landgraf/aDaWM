with Dwm_Types;

--  Port of the bar-related parts of dwm.c: drawbar/drawbars,
--  updatebars, updatestatus. updatebarpos lives in Dwm_Monitors instead
--  (pure monitor-geometry bookkeeping, no window/drawing calls).
package Dwm_Bar is

   procedure Draw_Bar (M : Dwm_Types.Monitor_Access);
   procedure Draw_Bars;
   procedure Update_Bars;
   procedure Update_Status;

end Dwm_Bar;
