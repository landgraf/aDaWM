with Xlib_Thin;

--  The small subset of X11/keysymdef.h dwm's default config and
--  updatenumlockmask() need. Latin letter/digit keysyms equal their
--  ASCII codepoint (a documented X11 convention), which is why most of
--  these look like plain character codes.
package Keysyms is

   XK_Num_Lock : constant Xlib_Thin.KeySym := 16#FF7F#;
   XK_Tab      : constant Xlib_Thin.KeySym := 16#FF09#;
   XK_Return   : constant Xlib_Thin.KeySym := 16#FF0D#;

   XK_space  : constant Xlib_Thin.KeySym := 16#0020#;
   XK_comma  : constant Xlib_Thin.KeySym := 16#002C#;
   XK_period : constant Xlib_Thin.KeySym := 16#002E#;

   XK_0 : constant Xlib_Thin.KeySym := 16#0030#;
   XK_1 : constant Xlib_Thin.KeySym := 16#0031#;
   XK_2 : constant Xlib_Thin.KeySym := 16#0032#;
   XK_3 : constant Xlib_Thin.KeySym := 16#0033#;
   XK_4 : constant Xlib_Thin.KeySym := 16#0034#;
   XK_5 : constant Xlib_Thin.KeySym := 16#0035#;
   XK_6 : constant Xlib_Thin.KeySym := 16#0036#;
   XK_7 : constant Xlib_Thin.KeySym := 16#0037#;
   XK_8 : constant Xlib_Thin.KeySym := 16#0038#;
   XK_9 : constant Xlib_Thin.KeySym := 16#0039#;

   XK_b : constant Xlib_Thin.KeySym := 16#0062#;
   XK_c : constant Xlib_Thin.KeySym := 16#0063#;
   XK_d : constant Xlib_Thin.KeySym := 16#0064#;
   XK_f : constant Xlib_Thin.KeySym := 16#0066#;
   XK_h : constant Xlib_Thin.KeySym := 16#0068#;
   XK_i : constant Xlib_Thin.KeySym := 16#0069#;
   XK_j : constant Xlib_Thin.KeySym := 16#006A#;
   XK_k : constant Xlib_Thin.KeySym := 16#006B#;
   XK_l : constant Xlib_Thin.KeySym := 16#006C#;
   XK_m : constant Xlib_Thin.KeySym := 16#006D#;
   XK_p : constant Xlib_Thin.KeySym := 16#0070#;
   XK_q : constant Xlib_Thin.KeySym := 16#0071#;
   XK_t : constant Xlib_Thin.KeySym := 16#0074#;

end Keysyms;
