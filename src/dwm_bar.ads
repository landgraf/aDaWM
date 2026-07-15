with Dwm_Types;

--  Port of the bar-related parts of dwm.c: drawbar/drawbars,
--  updatebars, updatestatus. updatebarpos lives in Dwm_Monitors instead
--  (pure monitor-geometry bookkeeping, no window/drawing calls).
package Dwm_Bar is

   --  Redraws M's bar: tags (with occupied/urgent indicator boxes),
   --  layout symbol, and either the selected client's title or (on
   --  the selected monitor) the status text (drawbar()).
   procedure Draw_Bar (M : Dwm_Types.Monitor_Access);

   --  Calls Draw_Bar for every monitor (drawbars()).
   procedure Draw_Bars;

   --  Creates the bar window for any monitor that doesn't have one yet
   --  (updatebars()); called at startup and whenever monitor geometry
   --  changes adds monitors.
   procedure Update_Bars;

   --  Re-reads the root window's WM_NAME into Dwm_State.Stext (falling
   --  back to "dwm-<version>" if unset) and redraws the selected
   --  monitor's bar (updatestatus()).
   procedure Update_Status;

end Dwm_Bar;
