with Ada.Command_Line;
with Ada.Text_IO;
with Ada.Unchecked_Conversion;
with Interfaces.C;
with Interfaces.C.Strings;
with System;
with System.Storage_Elements;
with Config;
with Drw;
with Dwm_Actions;
with Dwm_Bar;
with Dwm_Bindings;
with Dwm_Clients;
with Dwm_Events;
with Dwm_Monitors;
with Dwm_State;
with Dwm_Types;
with Dwm_Xutil;
with Util;
with Xlib_Thin;

package body Dwm_Main is

   use type Xlib_Thin.C_Int;
   use type Xlib_Thin.C_ULong;
   use type Xlib_Thin.C_UInt;
   use type Xlib_Thin.C_Mask;
   use type Xlib_Thin.XID;
   use type System.Address;
   use type Interfaces.C.Strings.chars_ptr;
   use type Drw.Fnt_Access;
   use type Dwm_Types.Client_Access;
   use type Dwm_Types.Monitor_Access;
   use type Dwm_Types.Event_Handler;
   use type Dwm_Types.Tag_Mask;

   function C_Setlocale
     (Category : Interfaces.C.int; Locale : Interfaces.C.Strings.chars_ptr)
      return Interfaces.C.Strings.chars_ptr;
   pragma Import (C, C_Setlocale, "setlocale");
   LC_CTYPE : constant Interfaces.C.int := 0;

   function C_Waitpid
     (Pid : Interfaces.C.int; Status : System.Address; Options : Interfaces.C.int)
      return Interfaces.C.int;
   pragma Import (C, C_Waitpid, "waitpid");
   WNOHANG : constant Interfaces.C.int := 1;

   function C_Signal (Signum : Interfaces.C.int; Handler : System.Address) return System.Address;
   pragma Import (C, C_Signal, "signal");
   SIGCHLD : constant Interfaces.C.int := 17;
   SIG_IGN : constant System.Address := System.Storage_Elements.To_Address (1);

   type Window_Access is access all Xlib_Thin.Window;
   function To_Window_Access is new Ada.Unchecked_Conversion (System.Address, Window_Access);

   --  Given library-level accessibility so Cleanup can point
   --  Selmon.Lt at it (dwm.c's local `Layout foo = {"", NULL}` works
   --  in C only because C never checks pointer lifetimes; the pointer
   --  is equally dangling-after-return there once cleanup() returns,
   --  it's just that nothing dereferences it afterwards. Ada's
   --  accessibility rules catch that shape at compile time, so this
   --  gets a stable home instead).
   Cleanup_Foo_Symbol : aliased constant String := "";
   Cleanup_Foo : aliased constant Dwm_Types.Layout :=
     (Symbol => Cleanup_Foo_Symbol'Access, Arrange => null);

   function Window_At (Base : System.Address; Index : Natural) return Xlib_Thin.Window is
      use type System.Storage_Elements.Storage_Offset;
   begin
      return To_Window_Access
        (Base + System.Storage_Elements.Storage_Offset (Index) * 8).all;
   end Window_At;

   procedure Checkotherwm is
      Ignore_Handler : Xlib_Thin.XErrorHandler;
      Ignore : Xlib_Thin.C_Int;
   begin
      Dwm_State.Xerrorxlib := Xlib_Thin.XSetErrorHandler (Dwm_Clients.Xerrorstart'Access);
      Ignore := Xlib_Thin.XSelectInput
        (Dwm_State.Dpy, Xlib_Thin.XDefaultRootWindow (Dwm_State.Dpy),
         Xlib_Thin.SubstructureRedirectMask);
      Ignore := Xlib_Thin.XSync (Dwm_State.Dpy, 0);
      Ignore_Handler := Xlib_Thin.XSetErrorHandler (Dwm_Clients.Xerror'Access);
      Ignore := Xlib_Thin.XSync (Dwm_State.Dpy, 0);
   end Checkotherwm;

   procedure Setup is
      Utf8string : Xlib_Thin.Atom;
      Wa : aliased Xlib_Thin.XSetWindowAttributes;
      Wmcheckwin_Buf : aliased Xlib_Thin.Window;
      Dwm_Name : aliased constant String := "dwm";
      Ignore : Xlib_Thin.C_Int;
      Ignore_Bool : Boolean;
      Ignore_Addr : System.Address;

      function Atom (Name : String) return Xlib_Thin.Atom is
         C_Name : Interfaces.C.Strings.chars_ptr := Interfaces.C.Strings.New_String (Name);
         Result : Xlib_Thin.Atom;
      begin
         Result := Xlib_Thin.XInternAtom (Dwm_State.Dpy, C_Name, 0);
         Interfaces.C.Strings.Free (C_Name);
         return Result;
      end Atom;
   begin
      Ignore_Addr := C_Signal (SIGCHLD, SIG_IGN);
      while C_Waitpid (-1, System.Null_Address, WNOHANG) > 0 loop
         null;
      end loop;

      Dwm_State.Screen := Xlib_Thin.XDefaultScreen (Dwm_State.Dpy);
      Dwm_State.Sw := Integer (Xlib_Thin.XDisplayWidth (Dwm_State.Dpy, Dwm_State.Screen));
      Dwm_State.Sh := Integer (Xlib_Thin.XDisplayHeight (Dwm_State.Dpy, Dwm_State.Screen));
      Dwm_State.Root := Xlib_Thin.XRootWindow (Dwm_State.Dpy, Dwm_State.Screen);
      Dwm_State.Dc := Drw.Create (Dwm_State.Dpy, Dwm_State.Screen, Dwm_State.Root, Dwm_State.Sw, Dwm_State.Sh);
      if Drw.Fontset_Create (Dwm_State.Dc, Config.Fonts) = null then
         Util.Die ("no fonts could be loaded.");
      end if;
      Dwm_State.Lrpad := Dwm_State.Dc.Fonts.H;
      Dwm_State.Bh := Dwm_State.Dc.Fonts.H + 2;

      --  Wire the Dwm_Bindings-resolved defaults into Dwm_State before
      --  updategeom()/grabkeys() (in createmon/grabbuttons/grabkeys)
      --  can read them; see Dwm_State.Default_Lt/Keys/Buttons.
      Dwm_State.Default_Lt := (Dwm_Bindings.Layouts (1)'Access, Dwm_Bindings.Layouts (2)'Access);
      Dwm_State.Keys := Dwm_Bindings.Keys'Access;
      Dwm_State.Buttons := Dwm_Bindings.Buttons'Access;

      Ignore_Bool := Dwm_Monitors.Updategeom;

      Utf8string := Atom ("UTF8_STRING");
      Dwm_State.Wmatom (Dwm_State.WM_Protocols) := Atom ("WM_PROTOCOLS");
      Dwm_State.Wmatom (Dwm_State.WM_Delete) := Atom ("WM_DELETE_WINDOW");
      Dwm_State.Wmatom (Dwm_State.WM_State) := Atom ("WM_STATE");
      Dwm_State.Wmatom (Dwm_State.WM_Take_Focus) := Atom ("WM_TAKE_FOCUS");
      Dwm_State.Netatom (Dwm_State.Net_Active_Window) := Atom ("_NET_ACTIVE_WINDOW");
      Dwm_State.Netatom (Dwm_State.Net_Supported) := Atom ("_NET_SUPPORTED");
      Dwm_State.Netatom (Dwm_State.Net_WM_Name) := Atom ("_NET_WM_NAME");
      Dwm_State.Netatom (Dwm_State.Net_WM_State) := Atom ("_NET_WM_STATE");
      Dwm_State.Netatom (Dwm_State.Net_WM_Check) := Atom ("_NET_SUPPORTING_WM_CHECK");
      Dwm_State.Netatom (Dwm_State.Net_WM_Fullscreen) := Atom ("_NET_WM_STATE_FULLSCREEN");
      Dwm_State.Netatom (Dwm_State.Net_WM_Window_Type) := Atom ("_NET_WM_WINDOW_TYPE");
      Dwm_State.Netatom (Dwm_State.Net_WM_Window_Type_Dialog) := Atom ("_NET_WM_WINDOW_TYPE_DIALOG");
      Dwm_State.Netatom (Dwm_State.Net_Client_List) := Atom ("_NET_CLIENT_LIST");

      Dwm_State.Cursors (Dwm_State.Cur_Normal) := Drw.Cur_Create (Dwm_State.Dc, Xlib_Thin.XC_left_ptr);
      Dwm_State.Cursors (Dwm_State.Cur_Resize) := Drw.Cur_Create (Dwm_State.Dc, Xlib_Thin.XC_sizing);
      Dwm_State.Cursors (Dwm_State.Cur_Move) := Drw.Cur_Create (Dwm_State.Dc, Xlib_Thin.XC_fleur);

      for S in Dwm_Types.Scheme_Kind loop
         Dwm_State.Scheme (S) := Drw.Scm_Create (Dwm_State.Dc, Config.Colors (S));
      end loop;

      Dwm_Bar.Updatebars;
      Dwm_Bar.Updatestatus;

      Dwm_State.Wmcheckwin := Xlib_Thin.XCreateSimpleWindow
        (Dwm_State.Dpy, Dwm_State.Root, 0, 0, 1, 1, 0, 0, 0);
      Wmcheckwin_Buf := Dwm_State.Wmcheckwin;
      Ignore := Xlib_Thin.XChangeProperty
        (Dwm_State.Dpy, Dwm_State.Wmcheckwin, Dwm_State.Netatom (Dwm_State.Net_WM_Check), Xlib_Thin.XA_WINDOW,
         32, Xlib_Thin.PropModeReplace, Wmcheckwin_Buf'Address, 1);
      Ignore := Xlib_Thin.XChangeProperty
        (Dwm_State.Dpy, Dwm_State.Wmcheckwin, Dwm_State.Netatom (Dwm_State.Net_WM_Name), Utf8string, 8,
         Xlib_Thin.PropModeReplace, Dwm_Name'Address, 3);
      Ignore := Xlib_Thin.XChangeProperty
        (Dwm_State.Dpy, Dwm_State.Root, Dwm_State.Netatom (Dwm_State.Net_WM_Check), Xlib_Thin.XA_WINDOW, 32,
         Xlib_Thin.PropModeReplace, Wmcheckwin_Buf'Address, 1);
      Ignore := Xlib_Thin.XChangeProperty
        (Dwm_State.Dpy, Dwm_State.Root, Dwm_State.Netatom (Dwm_State.Net_Supported), Xlib_Thin.XA_ATOM, 32,
         Xlib_Thin.PropModeReplace, Dwm_State.Netatom (Dwm_State.Netatom'First)'Address,
         Interfaces.C.int (Dwm_State.Netatom'Length));
      Ignore := Xlib_Thin.XDeleteProperty
        (Dwm_State.Dpy, Dwm_State.Root, Dwm_State.Netatom (Dwm_State.Net_Client_List));

      Wa.Cursor_Id := Dwm_State.Cursors (Dwm_State.Cur_Normal).Cursor;
      Wa.Event_Mask :=
        Xlib_Thin.SubstructureRedirectMask or Xlib_Thin.SubstructureNotifyMask or Xlib_Thin.ButtonPressMask
          or Xlib_Thin.PointerMotionMask or Xlib_Thin.EnterWindowMask or Xlib_Thin.LeaveWindowMask
          or Xlib_Thin.StructureNotifyMask or Xlib_Thin.PropertyChangeMask;
      Ignore := Xlib_Thin.XChangeWindowAttributes
        (Dwm_State.Dpy, Dwm_State.Root, Xlib_Thin.CWEventMask or Xlib_Thin.CWCursor, Wa'Access);
      Ignore := Xlib_Thin.XSelectInput (Dwm_State.Dpy, Dwm_State.Root, Wa.Event_Mask);
      Dwm_Clients.Grabkeys;
      Dwm_Clients.Focus (null);
   end Setup;

   procedure Scan is
      D1, D2 : aliased Xlib_Thin.Window;
      Wins : aliased System.Address := System.Null_Address;
      Num : aliased Xlib_Thin.C_UInt;
      Wa : aliased Xlib_Thin.XWindowAttributes;
      Ok : Xlib_Thin.C_Int;
      Ignore : Xlib_Thin.C_Int;
   begin
      Ok := Xlib_Thin.XQueryTree (Dwm_State.Dpy, Dwm_State.Root, D1'Access, D2'Access, Wins'Access, Num'Access);
      if Ok = 0 then
         return;
      end if;
      for I in 0 .. Integer (Num) - 1 loop
         declare
            W : constant Xlib_Thin.Window := Window_At (Wins, I);
         begin
            Ok := Xlib_Thin.XGetWindowAttributes (Dwm_State.Dpy, W, Wa'Access);
            if Ok /= 0 and then Wa.Override_Redirect = 0
              and then Xlib_Thin.XGetTransientForHint (Dwm_State.Dpy, W, D1'Access) = 0
            then
               if Wa.Map_State = Xlib_Thin.IsViewable
                 or else Dwm_Xutil.Getstate (W) = Xlib_Thin.IconicState
               then
                  Dwm_Clients.Manage (W, Wa);
               end if;
            end if;
         end;
      end loop;
      for I in 0 .. Integer (Num) - 1 loop
         declare
            W : constant Xlib_Thin.Window := Window_At (Wins, I);
         begin
            Ok := Xlib_Thin.XGetWindowAttributes (Dwm_State.Dpy, W, Wa'Access);
            if Ok /= 0
              and then Xlib_Thin.XGetTransientForHint (Dwm_State.Dpy, W, D1'Access) /= 0
              and then (Wa.Map_State = Xlib_Thin.IsViewable
                          or else Dwm_Xutil.Getstate (W) = Xlib_Thin.IconicState)
            then
               Dwm_Clients.Manage (W, Wa);
            end if;
         end;
      end loop;
      if Wins /= System.Null_Address then
         Ignore := Xlib_Thin.XFree (Wins);
      end if;
   end Scan;

   procedure Run is
      Ev  : aliased Xlib_Thin.XEvent;
      Any : Xlib_Thin.XAnyEvent with Address => Ev'Address;
      pragma Import (Ada, Any);
      Ignore : Xlib_Thin.C_Int;
   begin
      Ignore := Xlib_Thin.XSync (Dwm_State.Dpy, 0);
      while Dwm_State.Running loop
         Ignore := Xlib_Thin.XNextEvent (Dwm_State.Dpy, Ev'Access);
         if Any.Event_Type in 0 .. Xlib_Thin.LASTEvent - 1 then
            declare
               H : constant Dwm_Types.Event_Handler := Dwm_Events.Handler (Integer (Any.Event_Type));
            begin
               if H /= null then
                  H (Ev'Access);
               end if;
            end;
         end if;
      end loop;
   end Run;

   procedure Cleanup is
      A : constant Dwm_Types.Arg := (Ui => not Dwm_Types.Tag_Mask'(0), others => <>);
      M : Dwm_Types.Monitor_Access;
      Ignore : Xlib_Thin.C_Int;
   begin
      Dwm_Actions.View (A);
      Dwm_State.Selmon.Lt (Dwm_State.Selmon.Sellt) := Cleanup_Foo'Access;
      M := Dwm_State.Mons;
      while M /= null loop
         while M.Stack /= null loop
            Dwm_Clients.Unmanage (M.Stack, False);
         end loop;
         M := M.Next;
      end loop;
      Ignore := Xlib_Thin.XUngrabKey (Dwm_State.Dpy, Xlib_Thin.Any_Key, Xlib_Thin.AnyModifier, Dwm_State.Root);
      while Dwm_State.Mons /= null loop
         Dwm_Monitors.Cleanupmon (Dwm_State.Mons);
      end loop;
      for K in Dwm_State.Cursor_Kind loop
         Drw.Cur_Free (Dwm_State.Dc, Dwm_State.Cursors (K));
      end loop;
      for S in Dwm_Types.Scheme_Kind loop
         Drw.Scm_Free (Dwm_State.Dc, Dwm_State.Scheme (S));
      end loop;
      Ignore := Xlib_Thin.XDestroyWindow (Dwm_State.Dpy, Dwm_State.Wmcheckwin);
      Drw.Free (Dwm_State.Dc);
      Ignore := Xlib_Thin.XSync (Dwm_State.Dpy, 0);
      Ignore := Xlib_Thin.XSetInputFocus
        (Dwm_State.Dpy, Xlib_Thin.Pointer_Root, Xlib_Thin.RevertToPointerRoot, Xlib_Thin.Current_Time);
      Ignore := Xlib_Thin.XDeleteProperty
        (Dwm_State.Dpy, Dwm_State.Root, Dwm_State.Netatom (Dwm_State.Net_Active_Window));
   end Cleanup;

   procedure Main is
      Ok : Xlib_Thin.C_Int;
      Locale_Ptr : constant Interfaces.C.Strings.chars_ptr := Interfaces.C.Strings.New_String ("");
      Locale_Result : Interfaces.C.Strings.chars_ptr;
   begin
      if Ada.Command_Line.Argument_Count = 1 and then Ada.Command_Line.Argument (1) = "-v" then
         Util.Die ("dwm-" & Dwm_State.Version);
      elsif Ada.Command_Line.Argument_Count /= 0 then
         Util.Die ("usage: dwm [-v]");
      end if;

      Locale_Result := C_Setlocale (LC_CTYPE, Locale_Ptr);
      if Locale_Result = Interfaces.C.Strings.Null_Ptr or else Xlib_Thin.XSupportsLocale = 0 then
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "warning: no locale support");
      end if;

      Dwm_State.Dpy := Xlib_Thin.XOpenDisplay (Interfaces.C.Strings.Null_Ptr);
      if Dwm_State.Dpy = System.Null_Address then
         Util.Die ("dwm: cannot open display");
      end if;
      Checkotherwm;
      Setup;
      Scan;
      Run;
      Cleanup;
      Ok := Xlib_Thin.XCloseDisplay (Dwm_State.Dpy);
   end Main;

end Dwm_Main;
