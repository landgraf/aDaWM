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
   use type System.Address;
   use type Xlib_Thin.Display;
   use type Interfaces.C.Strings.chars_ptr;
   use type Drw.Font_Access;
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

   --  Reads the Index'th Window (8-byte XID) from a flat Window* array
   --  address, as returned by XQueryTree. Private; spec given here
   --  (rather than in dwm_main.ads) since it's not part of the public
   --  API.
   function Window_At (Base : System.Address; Index : Natural) return Xlib_Thin.Window;

   --  Given library-level accessibility so Cleanup can point
   --  Selected_Monitor.Layout at it (dwm.c's local `Layout foo = {"", NULL}`
   --  works in C only because C never checks pointer lifetimes; the
   --  pointer is equally dangling-after-return there once cleanup()
   --  returns, it's just that nothing dereferences it afterwards.
   --  Ada's accessibility rules catch that shape at compile time, so
   --  this gets a stable home instead).
   Cleanup_Foo_Symbol : aliased constant String := "";
   Cleanup_Foo : aliased constant Dwm_Types.Layout :=
     (Symbol => Cleanup_Foo_Symbol'Access, Arrange => null);

   --------------------------------------------------------------------
   --  Subprogram bodies (alphabetical order; -gnatyo)                --
   --------------------------------------------------------------------

   procedure Check_Other_Wm is
      Ignore_Handler : Xlib_Thin.XErrorHandler;
      Ignore : Xlib_Thin.C_Int;
   begin
      Dwm_State.X_Error_Xlib := Xlib_Thin.XSetErrorHandler (Dwm_Clients.X_Error_Start'Access);
      Ignore := Xlib_Thin.XSelectInput
        (Dwm_State.Display, Xlib_Thin.XDefaultRootWindow (Dwm_State.Display),
         Xlib_Thin.SubstructureRedirectMask);
      Ignore := Xlib_Thin.XSync (Dwm_State.Display, 0);
      Ignore_Handler := Xlib_Thin.XSetErrorHandler (Dwm_Clients.X_Error'Access);
      Ignore := Xlib_Thin.XSync (Dwm_State.Display, 0);
   end Check_Other_Wm;

   procedure Cleanup is
      Argument : constant Dwm_Types.Arg := (Uint_Value => not Dwm_Types.Tag_Mask'(0), others => <>);
      Monitor : Dwm_Types.Monitor_Access;
      Ignore : Xlib_Thin.C_Int;
   begin
      Dwm_Actions.View (Argument);
      Dwm_State.Selected_Monitor.Layout (Dwm_State.Selected_Monitor.Sel_Lt) := Cleanup_Foo'Access;
      Monitor := Dwm_State.Monitors;
      while Monitor /= null loop
         while Monitor.Stack /= null loop
            Dwm_Clients.Unmanage (Monitor.Stack, False);
         end loop;
         Monitor := Monitor.Next;
      end loop;
      Ignore := Xlib_Thin.XUngrabKey (Dwm_State.Display, Xlib_Thin.Any_Key, Xlib_Thin.AnyModifier, Dwm_State.Root);
      while Dwm_State.Monitors /= null loop
         Dwm_Monitors.Cleanup_Mon (Dwm_State.Monitors);
      end loop;
      for Kind in Dwm_State.Cursor_Kind loop
         Drw.Cursor_Free (Dwm_State.Drw_Ctx, Dwm_State.Cursors (Kind));
      end loop;
      for Kind in Dwm_Types.Scheme_Kind loop
         Drw.Scheme_Free (Dwm_State.Drw_Ctx, Dwm_State.Scheme (Kind));
      end loop;
      Ignore := Xlib_Thin.XDestroyWindow (Dwm_State.Display, Dwm_State.Wm_Check_Window);
      Drw.Free (Dwm_State.Drw_Ctx);
      Ignore := Xlib_Thin.XSync (Dwm_State.Display, 0);
      Ignore := Xlib_Thin.XSetInputFocus
        (Dwm_State.Display, Xlib_Thin.Pointer_Root, Xlib_Thin.RevertToPointerRoot, Xlib_Thin.Current_Time);
      Ignore := Xlib_Thin.XDeleteProperty
        (Dwm_State.Display, Dwm_State.Root, Dwm_State.Net_Atom (Dwm_State.Net_Active_Window));
   end Cleanup;

   procedure Main is
      Ignore : Xlib_Thin.C_Int;
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

      Dwm_State.Display := Xlib_Thin.XOpenDisplay (Interfaces.C.Strings.Null_Ptr);
      if Dwm_State.Display = null then
         Util.Die ("dwm: cannot open display");
      end if;
      Check_Other_Wm;
      Setup;
      Scan;
      Run;
      Cleanup;
      Ignore := Xlib_Thin.XCloseDisplay (Dwm_State.Display);
   end Main;

   procedure Run is
      Event : aliased Xlib_Thin.XEvent;
      Any_Event : Xlib_Thin.XAnyEvent with Address => Event'Address;
      pragma Import (Ada, Any_Event);
      Ignore : Xlib_Thin.C_Int;
   begin
      Ignore := Xlib_Thin.XSync (Dwm_State.Display, 0);
      while Dwm_State.Running loop
         Ignore := Xlib_Thin.XNextEvent (Dwm_State.Display, Event'Access);
         if Any_Event.Event_Type in 0 .. Xlib_Thin.LASTEvent - 1 then
            declare
               Handler_Func : constant Dwm_Types.Event_Handler :=
                 Dwm_Events.Handler (Integer (Any_Event.Event_Type));
            begin
               if Handler_Func /= null then
                  Handler_Func (Event'Access);
               end if;
            end;
         end if;
      end loop;
   end Run;

   procedure Scan is
      Dummy1, Dummy2 : aliased Xlib_Thin.Window;
      Wins : aliased System.Address := System.Null_Address;
      Count : aliased Xlib_Thin.C_UInt;
      Attrs : aliased Xlib_Thin.XWindowAttributes;
      Ok : Xlib_Thin.C_Int;
      Ignore : Xlib_Thin.C_Int;
   begin
      Ok := Xlib_Thin.XQueryTree
        (Dwm_State.Display, Dwm_State.Root, Dummy1'Access, Dummy2'Access, Wins'Access, Count'Access);
      if Ok = 0 then
         return;
      end if;
      for Idx in 0 .. Integer (Count) - 1 loop
         declare
            Window : constant Xlib_Thin.Window := Window_At (Wins, Idx);
         begin
            Ok := Xlib_Thin.XGetWindowAttributes (Dwm_State.Display, Window, Attrs'Access);
            if Ok /= 0 and then Attrs.Override_Redirect = 0
              and then Xlib_Thin.XGetTransientForHint (Dwm_State.Display, Window, Dummy1'Access) = 0
            then
               if Attrs.Map_State = Xlib_Thin.IsViewable
                 or else Dwm_Xutil.Get_State (Window) = Xlib_Thin.IconicState
               then
                  Dwm_Clients.Manage (Window, Attrs);
               end if;
            end if;
         end;
      end loop;
      for Idx in 0 .. Integer (Count) - 1 loop
         declare
            Window : constant Xlib_Thin.Window := Window_At (Wins, Idx);
         begin
            Ok := Xlib_Thin.XGetWindowAttributes (Dwm_State.Display, Window, Attrs'Access);
            if Ok /= 0
              and then Xlib_Thin.XGetTransientForHint (Dwm_State.Display, Window, Dummy1'Access) /= 0
              and then (Attrs.Map_State = Xlib_Thin.IsViewable
                          or else Dwm_Xutil.Get_State (Window) = Xlib_Thin.IconicState)
            then
               Dwm_Clients.Manage (Window, Attrs);
            end if;
         end;
      end loop;
      if Wins /= System.Null_Address then
         Ignore := Xlib_Thin.XFree (Wins);
      end if;
   end Scan;

   procedure Setup is
      Utf8string : Xlib_Thin.Atom;
      Attrs : aliased Xlib_Thin.XSetWindowAttributes;
      Check_Win_Buf : aliased Xlib_Thin.Window;
      Dwm_Name : aliased constant String := "dwm";
      Ignore : Xlib_Thin.C_Int;
      Ignore_Bool : Boolean;
      Ignore_Addr : System.Address;

      function Atom (Name : String) return Xlib_Thin.Atom;

      function Atom (Name : String) return Xlib_Thin.Atom is
         Name_Ptr : Interfaces.C.Strings.chars_ptr := Interfaces.C.Strings.New_String (Name);
         Result : Xlib_Thin.Atom;
      begin
         Result := Xlib_Thin.XInternAtom (Dwm_State.Display, Name_Ptr, 0);
         Interfaces.C.Strings.Free (Name_Ptr);
         return Result;
      end Atom;
   begin
      Ignore_Addr := C_Signal (SIGCHLD, SIG_IGN);
      while C_Waitpid (-1, System.Null_Address, WNOHANG) > 0 loop
         null;
      end loop;

      Dwm_State.Screen := Xlib_Thin.XDefaultScreen (Dwm_State.Display);
      Dwm_State.Screen_Width := Integer (Xlib_Thin.XDisplayWidth (Dwm_State.Display, Dwm_State.Screen));
      Dwm_State.Screen_Height := Integer (Xlib_Thin.XDisplayHeight (Dwm_State.Display, Dwm_State.Screen));
      Dwm_State.Root := Xlib_Thin.XRootWindow (Dwm_State.Display, Dwm_State.Screen);
      Dwm_State.Drw_Ctx := Drw.Create
        (Dwm_State.Display, Dwm_State.Screen, Dwm_State.Root,
         Dwm_State.Screen_Width, Dwm_State.Screen_Height);
      if Drw.Fontset_Create (Dwm_State.Drw_Ctx, Config.Fonts) = null then
         Util.Die ("no fonts could be loaded.");
      end if;
      Dwm_State.Left_Right_Pad := Dwm_State.Drw_Ctx.Fonts.Height;
      Dwm_State.Bar_Height := Dwm_State.Drw_Ctx.Fonts.Height + 2;

      --  Wire the Dwm_Bindings-resolved defaults into Dwm_State before
      --  updategeom()/grabkeys() (in createmon/grabbuttons/grabkeys)
      --  can read them; see Dwm_State.Default_Layout/Keys/Buttons.
      Dwm_State.Default_Layout := (Dwm_Bindings.Layouts (1)'Access, Dwm_Bindings.Layouts (2)'Access);
      Dwm_State.Keys := Dwm_Bindings.Keys'Access;
      Dwm_State.Buttons := Dwm_Bindings.Buttons'Access;

      Ignore_Bool := Dwm_Monitors.Update_Geom;

      Utf8string := Atom ("UTF8_STRING");
      Dwm_State.Wm_Atom (Dwm_State.WM_Protocols) := Atom ("WM_PROTOCOLS");
      Dwm_State.Wm_Atom (Dwm_State.WM_Delete) := Atom ("WM_DELETE_WINDOW");
      Dwm_State.Wm_Atom (Dwm_State.WM_State) := Atom ("WM_STATE");
      Dwm_State.Wm_Atom (Dwm_State.WM_Take_Focus) := Atom ("WM_TAKE_FOCUS");
      Dwm_State.Net_Atom (Dwm_State.Net_Active_Window) := Atom ("_NET_ACTIVE_WINDOW");
      Dwm_State.Net_Atom (Dwm_State.Net_Supported) := Atom ("_NET_SUPPORTED");
      Dwm_State.Net_Atom (Dwm_State.Net_WM_Name) := Atom ("_NET_WM_NAME");
      Dwm_State.Net_Atom (Dwm_State.Net_WM_State) := Atom ("_NET_WM_STATE");
      Dwm_State.Net_Atom (Dwm_State.Net_WM_Check) := Atom ("_NET_SUPPORTING_WM_CHECK");
      Dwm_State.Net_Atom (Dwm_State.Net_WM_Fullscreen) := Atom ("_NET_WM_STATE_FULLSCREEN");
      Dwm_State.Net_Atom (Dwm_State.Net_WM_Window_Type) := Atom ("_NET_WM_WINDOW_TYPE");
      Dwm_State.Net_Atom (Dwm_State.Net_WM_Window_Type_Dialog) := Atom ("_NET_WM_WINDOW_TYPE_DIALOG");
      Dwm_State.Net_Atom (Dwm_State.Net_Client_List) := Atom ("_NET_CLIENT_LIST");

      Dwm_State.Cursors (Dwm_State.Cursor_Normal) := Drw.Cursor_Create (Dwm_State.Drw_Ctx, Xlib_Thin.XC_left_ptr);
      Dwm_State.Cursors (Dwm_State.Cursor_Resize) := Drw.Cursor_Create (Dwm_State.Drw_Ctx, Xlib_Thin.XC_sizing);
      Dwm_State.Cursors (Dwm_State.Cursor_Move) := Drw.Cursor_Create (Dwm_State.Drw_Ctx, Xlib_Thin.XC_fleur);

      for Kind in Dwm_Types.Scheme_Kind loop
         Dwm_State.Scheme (Kind) := Drw.Scheme_Create (Dwm_State.Drw_Ctx, Config.Colors (Kind));
      end loop;

      Dwm_Bar.Update_Bars;
      Dwm_Bar.Update_Status;

      Dwm_State.Wm_Check_Window := Xlib_Thin.XCreateSimpleWindow
        (Dwm_State.Display, Dwm_State.Root, 0, 0, 1, 1, 0, 0, 0);
      Check_Win_Buf := Dwm_State.Wm_Check_Window;
      Ignore := Xlib_Thin.XChangeProperty
        (Dwm_State.Display, Dwm_State.Wm_Check_Window, Dwm_State.Net_Atom (Dwm_State.Net_WM_Check),
         Xlib_Thin.XA_WINDOW, 32, Xlib_Thin.PropModeReplace, Check_Win_Buf'Address, 1);
      Ignore := Xlib_Thin.XChangeProperty
        (Dwm_State.Display, Dwm_State.Wm_Check_Window, Dwm_State.Net_Atom (Dwm_State.Net_WM_Name), Utf8string, 8,
         Xlib_Thin.PropModeReplace, Dwm_Name'Address, 3);
      Ignore := Xlib_Thin.XChangeProperty
        (Dwm_State.Display, Dwm_State.Root, Dwm_State.Net_Atom (Dwm_State.Net_WM_Check), Xlib_Thin.XA_WINDOW, 32,
         Xlib_Thin.PropModeReplace, Check_Win_Buf'Address, 1);
      Ignore := Xlib_Thin.XChangeProperty
        (Dwm_State.Display, Dwm_State.Root, Dwm_State.Net_Atom (Dwm_State.Net_Supported), Xlib_Thin.XA_ATOM, 32,
         Xlib_Thin.PropModeReplace, Dwm_State.Net_Atom (Dwm_State.Net_Atom'First)'Address,
         Interfaces.C.int (Dwm_State.Net_Atom'Length));
      Ignore := Xlib_Thin.XDeleteProperty
        (Dwm_State.Display, Dwm_State.Root, Dwm_State.Net_Atom (Dwm_State.Net_Client_List));

      Attrs.Cursor_Id := Dwm_State.Cursors (Dwm_State.Cursor_Normal).X_Cursor;
      Attrs.Event_Mask :=
        Xlib_Thin.SubstructureRedirectMask or Xlib_Thin.SubstructureNotifyMask or Xlib_Thin.ButtonPressMask
          or Xlib_Thin.PointerMotionMask or Xlib_Thin.EnterWindowMask or Xlib_Thin.LeaveWindowMask
          or Xlib_Thin.StructureNotifyMask or Xlib_Thin.PropertyChangeMask;
      Ignore := Xlib_Thin.XChangeWindowAttributes
        (Dwm_State.Display, Dwm_State.Root, Xlib_Thin.CWEventMask or Xlib_Thin.CWCursor, Attrs'Access);
      Ignore := Xlib_Thin.XSelectInput (Dwm_State.Display, Dwm_State.Root, Attrs.Event_Mask);
      Dwm_Clients.Grab_Keys;
      Dwm_Clients.Focus (null);
   end Setup;

   function Window_At (Base : System.Address; Index : Natural) return Xlib_Thin.Window is
      use type System.Storage_Elements.Storage_Offset;
   begin
      return To_Window_Access
        (Base + System.Storage_Elements.Storage_Offset (Index) * 8).all;
   end Window_At;

end Dwm_Main;
