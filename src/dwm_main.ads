--  Port of dwm.c's checkotherwm/setup/scan/run/cleanup and main().
package Dwm_Main is

   procedure Checkotherwm;
   procedure Setup;
   procedure Scan;
   procedure Run;
   procedure Cleanup;

   --  The dwm executable's entry point (mirrors C's main()); called
   --  from src/main.adb.
   procedure Main;

end Dwm_Main;
