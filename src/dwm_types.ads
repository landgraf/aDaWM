with Ada.Strings.Bounded;
with Ada.Unchecked_Deallocation;
with Interfaces;
use type Interfaces.Unsigned_32;
with Xft_Thin;
with Xlib_Thin;

--  Shared record/access types: the Ada analogue of the struct and
--  typedef declarations near the top of dwm.c (Client, Monitor, Arg,
--  Key, Button, Layout, Rule) plus a couple of enums dwm.c expresses
--  as anonymous C enums (SchemeNorm/SchemeSel, ColFg/ColBg/ColBorder,
--  the click kinds).
--
--  Arg does not mirror C's union layout bit-for-bit: Arg never crosses
--  the Xlib FFI boundary (it is dwm's own internal callback-argument
--  type), so there is no reason to reproduce a C union's aliasing
--  unsafety here. Each field is typed for what it actually holds, and
--  by convention (same as the C) only one field is meaningful per use.
package Dwm_Types is

   subtype Tag_Mask is Interfaces.Unsigned_32;

   package Client_Name_Strings is new Ada.Strings.Bounded.Generic_Bounded_Length (255);
   package Lt_Symbol_Strings is new Ada.Strings.Bounded.Generic_Bounded_Length (15);

   type Scheme_Kind is (Scheme_Norm, Scheme_Sel);
   type Col_Kind is (Col_Fg, Col_Bg, Col_Border);

   type Color_Scheme is array (Col_Kind) of aliased Xft_Thin.XftColor;
   type Color_Scheme_Access is access all Color_Scheme;

   --  Three color-name strings (fg, bg, border), e.g. "#222222"; the
   --  input Drw.Scm_Create resolves into a Color_Scheme.
   type Color_Name_Triple is array (Col_Kind) of access constant String;

   type Click_Kind is
     (Clk_Tag_Bar, Clk_Lt_Symbol, Clk_Status_Text, Clk_Win_Title, Clk_Client_Win, Clk_Root_Win);

   type Client;
   type Client_Access is access all Client;

   type Monitor;
   type Monitor_Access is access all Monitor;

   type Layout;
   type Layout_Const_Access is access constant Layout;
   type Layout_Pair is array (0 .. 1) of Layout_Const_Access;

   type Command is array (Positive range <>) of access constant String;
   type Command_Access is access constant Command;

   type Arg is record
      I   : Integer := 0;
      Ui  : Tag_Mask := 0;
      F   : Float := 0.0;
      Cmd : Command_Access := null;
      Lt  : Layout_Const_Access := null;
   end record;

   No_Arg : constant Arg := (I => 0, Ui => 0, F => 0.0, Cmd => null, Lt => null);

   type Key_Func is access procedure (A : Arg);

   type Key is record
      Modifier : Xlib_Thin.C_UInt;
      Sym      : Xlib_Thin.KeySym;
      Func     : Key_Func;
      Argument : Arg;
   end record;

   type Key_Array is array (Positive range <>) of Key;
   type Key_Array_Access is access constant Key_Array;

   type Button_Binding is record
      Click    : Click_Kind;
      Modifier : Xlib_Thin.C_UInt;
      Button   : Xlib_Thin.C_UInt;
      Func     : Key_Func;
      Argument : Arg;
   end record;

   type Button_Array is array (Positive range <>) of Button_Binding;
   type Button_Array_Access is access constant Button_Array;

   type Arrange_Func is access procedure (M : Monitor_Access);

   type Layout is record
      Symbol  : access constant String;
      Arrange : Arrange_Func;
   end record;

   type Layout_Array is array (Positive range <>) of aliased Layout;
   type Layout_Array_Access is access constant Layout_Array;

   type Rule is record
      Class      : access constant String := null;
      Instance   : access constant String := null;
      Title      : access constant String := null;
      Tags       : Tag_Mask := 0;
      Is_Floating : Boolean := False;
      Monitor    : Integer := -1;
   end record;

   type Rule_Array is array (Positive range <>) of Rule;
   type Rule_Array_Access is access constant Rule_Array;

   --  X event handler signature (dwm.c's `void (*)(XEvent *)`), shared
   --  by the handlers scattered across Dwm_Clients/Dwm_Monitors/
   --  Dwm_Events and Dwm_Events.Handler's dispatch table.
   type Event_Handler is access procedure (Ev : access Xlib_Thin.XEvent);

   type Client is record
      Name        : Client_Name_Strings.Bounded_String := Client_Name_Strings.Null_Bounded_String;
      Mina, Maxa  : Float := 0.0;
      X, Y, W, H  : Integer := 0;
      Oldx, Oldy, Oldw, Oldh : Integer := 0;
      Basew, Baseh, Incw, Inch : Integer := 0;
      Maxw, Maxh, Minw, Minh  : Integer := 0;
      Hints_Valid  : Boolean := False;
      Bw, Oldbw   : Integer := 0;
      Tags        : Tag_Mask := 0;
      Is_Fixed     : Boolean := False;
      Is_Floating  : Boolean := False;
      Is_Urgent    : Boolean := False;
      Never_Focus  : Boolean := False;
      Old_State    : Boolean := False;
      Is_Full_Screen : Boolean := False;
      Next        : Client_Access := null;
      Snext       : Client_Access := null;
      Mon         : Monitor_Access := null;
      Win         : Xlib_Thin.Window := Xlib_Thin.None;
   end record;

   type Tagset_Array is array (0 .. 1) of Tag_Mask;

   type Monitor is record
      Lt_Symbol    : Lt_Symbol_Strings.Bounded_String := Lt_Symbol_Strings.Null_Bounded_String;
      Mfact       : Float := 0.0;
      Nmaster     : Integer := 0;
      Num         : Integer := 0;
      By          : Integer := 0;
      Mx, My, Mw, Mh : Integer := 0;
      Wx, Wy, Ww, Wh : Integer := 0;
      Sel_Tags     : Natural range 0 .. 1 := 0;
      Sel_Lt       : Natural range 0 .. 1 := 0;
      Tag_Set      : Tagset_Array := (others => 1);
      Show_Bar     : Boolean := True;
      Top_Bar      : Boolean := True;
      Clients     : Client_Access := null;
      Sel         : Client_Access := null;
      Stack       : Client_Access := null;
      Next        : Monitor_Access := null;
      Bar_Win      : Xlib_Thin.Window := Xlib_Thin.None;
      Lt          : Layout_Pair := (others => null);
   end record;

   --  Deallocates a Client (unmanage()'s free(c)); the access value is
   --  set to null on return, per Ada.Unchecked_Deallocation.
   procedure Free_Client is new Ada.Unchecked_Deallocation (Client, Client_Access);

   --  Deallocates a Monitor (cleanupmon()'s free(mon)).
   procedure Free_Monitor is new Ada.Unchecked_Deallocation (Monitor, Monitor_Access);

   --  True if C has any tag in common with its monitor's currently
   --  viewed tag set (dwm.c's ISVISIBLE(C) macro).
   function Is_Visible (C : Client_Access) return Boolean is
     ((C.Tags and C.Mon.Tag_Set (C.Mon.Sel_Tags)) /= 0);

   --  Outer window width including both borders (dwm.c's WIDTH(X)).
   function Width (C : Client_Access) return Integer is (C.W + 2 * C.Bw);

   --  Outer window height including both borders (dwm.c's HEIGHT(X)).
   function Height (C : Client_Access) return Integer is (C.H + 2 * C.Bw);

end Dwm_Types;
