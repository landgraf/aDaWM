with Xlib_Thin;

--  Small X-property/state read helpers shared by Dwm_Clients, Dwm_Bar
--  and Dwm_Monitors (getatomprop/getstate/gettextprop/getrootptr in
--  dwm.c). Kept as a thin leaf package, depending only on Dwm_State,
--  so that both Dwm_Clients and Dwm_Bar (which Dwm_Clients itself
--  depends on, via focus() -> drawbars()) can use it without a cycle.
package Dwm_Xutil is

   function Getatomprop (Win : Xlib_Thin.Window; Prop : Xlib_Thin.Atom) return Xlib_Thin.Atom;

   function Getrootptr (X, Y : out Integer) return Boolean;

   --  Returns -1 if the WM_STATE property is absent (matches getstate()
   --  returning -1 on failure); otherwise NormalState/IconicState/etc.
   function Getstate (Win : Xlib_Thin.Window) return Long_Integer;

   --  Returns the text property (WM_NAME-style), or "" if unavailable
   --  or unset, truncated to 255 bytes like dwm's fixed text buffers.
   function Gettextprop (Win : Xlib_Thin.Window; Prop : Xlib_Thin.Atom) return String;

end Dwm_Xutil;
