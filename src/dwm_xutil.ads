with Xlib_Thin;

--  Small X-property/state read helpers shared by Dwm_Clients, Dwm_Bar
--  and Dwm_Monitors (getatomprop/getstate/gettextprop/getrootptr in
--  dwm.c). Kept as a thin leaf package, depending only on Dwm_State,
--  so that both Dwm_Clients and Dwm_Bar (which Dwm_Clients itself
--  depends on, via focus() -> drawbars()) can use it without a cycle.
package Dwm_Xutil is

   --  Reads Window's Prop property as a single Atom value, or None (0) if
   --  it is absent or not format-32 (getatomprop()); used to read
   --  _NET_WM_STATE / _NET_WM_WINDOW_TYPE.
   function Get_Atom_Prop (Window : Xlib_Thin.Window; Prop : Xlib_Thin.Atom) return Xlib_Thin.Atom;

   --  Sets Pos_X, Pos_Y to the pointer's current root-relative position and
   --  returns True on success (getrootptr()).
   function Get_Root_Ptr (Pos_X, Pos_Y : out Integer) return Boolean;

   --  Returns -1 if the WM_STATE property is absent (matches getstate()
   --  returning -1 on failure); otherwise NormalState/IconicState/etc.
   function Get_State (Window : Xlib_Thin.Window) return Long_Integer;

   --  Returns the text property (WM_NAME-style), or "" if unavailable
   --  or unset, truncated to 255 bytes like dwm's fixed text buffers.
   function Get_Text_Prop (Window : Xlib_Thin.Window; Prop : Xlib_Thin.Atom) return String;

end Dwm_Xutil;
