with System;
with Interfaces.C;
with Xlib_Thin;

--  Thin hand-written Ada binding to the small Xinerama surface dwm's
--  updategeom() uses to discover monitor geometry.
package Xinerama_Thin is

   subtype C_Int is Interfaces.C.int;

   type XineramaScreenInfo is record
      Screen_Number : C_Int := 0;
      X_Org         : Interfaces.C.short := 0;
      Y_Org         : Interfaces.C.short := 0;
      Width         : Interfaces.C.short := 0;
      Height        : Interfaces.C.short := 0;
   end record
     with Convention => C;

   type Screen_Info_Array is array (C_Int range <>) of XineramaScreenInfo;

   function XineramaIsActive (Disp : Xlib_Thin.Display) return C_Int;
   pragma Import (C, XineramaIsActive, "XineramaIsActive");

   function XineramaQueryScreens
     (Disp : Xlib_Thin.Display; Number : access C_Int) return System.Address;
   pragma Import (C, XineramaQueryScreens, "XineramaQueryScreens");

end Xinerama_Thin;
