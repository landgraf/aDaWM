with System;
with Interfaces.C;
with Interfaces.C.Strings;
use type Interfaces.C.int;
use type Interfaces.C.unsigned;
use type Interfaces.C.unsigned_long;

--  Thin hand-written Ada binding to exactly the Xlib surface dwm needs.
--  No Alire crate for Xlib exists, so this binds libX11 directly via
--  Interfaces.C, following the struct layouts and constants in
--  /usr/include/X11/{Xlib,X,Xutil,Xatom,cursorfont,Xproto}.h.
package Xlib_Thin is

   subtype C_Int    is Interfaces.C.int;
   subtype C_UInt   is Interfaces.C.unsigned;
   subtype C_Long   is Interfaces.C.long;
   --  X event/attribute masks are declared `long` in X.h but only ever
   --  used bitwise; Interfaces.C.long is signed and has no "and"/"or",
   --  so masks use this unsigned alias instead (identical bit pattern
   --  and parameter-passing convention as C_Long on this ABI).
   subtype C_Mask   is Interfaces.C.unsigned_long;
   subtype C_ULong  is Interfaces.C.unsigned_long;
   subtype C_UChar  is Interfaces.C.unsigned_char;
   subtype C_Short  is Interfaces.C.short;
   subtype C_UShort is Interfaces.C.unsigned_short;

   --------------------------------------------------------------------
   --  Opaque pointer types (Display, GC, Visual, Screen are never     --
   --  dereferenced from Ada, only passed around and null-checked).   --
   --  Each is a distinct access-to-null-record type rather than a    --
   --  System.Address subtype: same machine representation (a plain   --
   --  pointer) for FFI purposes, but the compiler now rejects        --
   --  passing e.g. a GC where a Display is expected, and "null"      --
   --  replaces System.Null_Address for comparisons.                  --
   --------------------------------------------------------------------

   type Display_Object is limited null record;
   type Display is access all Display_Object;

   type GC_Object is limited null record;
   type GC is access all GC_Object;

   type Visual_Object is limited null record;
   type Visual is access all Visual_Object;

   type Screen_Object is limited null record;
   type Screen is access all Screen_Object;

   --------------------------------------------------------------------
   --  Resource IDs: all XID (unsigned long) in C, freely             --
   --  interconvertible there, so modelled as subtypes of one type.   --
   --------------------------------------------------------------------

   type XID is new C_ULong;
   subtype Window   is XID;
   subtype Drawable is XID;
   subtype Pixmap   is XID;
   subtype Cursor   is XID;
   subtype Colormap is XID;
   subtype GContext is XID;
   subtype KeySym   is XID;
   subtype Atom     is XID;
   subtype Time_T   is XID;
   subtype Mask_T   is XID;

   type KeyCode is new C_UChar;

   None            : constant := 0;
   Parent_Relative : constant := 1;
   Copy_From_Parent : constant := 0;
   Pointer_Root    : constant := 1;
   Any_Property_Type : constant := 0;
   Any_Key         : constant := 0;
   Any_Button      : constant := 0;
   Current_Time    : constant := 0;

   function To_C_Bool (B : Boolean) return C_Int is
     (if B then 1 else 0);
   function From_C_Bool (V : C_Int) return Boolean is (V /= 0);

   --------------------------------------------------------------------
   --  Event masks / types / modifiers (X11/X.h)                      --
   --------------------------------------------------------------------

   NoEventMask              : constant C_Mask := 0;
   KeyPressMask             : constant C_Mask := 2 ** 0;
   KeyReleaseMask           : constant C_Mask := 2 ** 1;
   ButtonPressMask          : constant C_Mask := 2 ** 2;
   ButtonReleaseMask        : constant C_Mask := 2 ** 3;
   EnterWindowMask          : constant C_Mask := 2 ** 4;
   LeaveWindowMask          : constant C_Mask := 2 ** 5;
   PointerMotionMask        : constant C_Mask := 2 ** 6;
   ExposureMask             : constant C_Mask := 2 ** 15;
   StructureNotifyMask      : constant C_Mask := 2 ** 17;
   SubstructureNotifyMask   : constant C_Mask := 2 ** 19;
   SubstructureRedirectMask : constant C_Mask := 2 ** 20;
   FocusChangeMask          : constant C_Mask := 2 ** 21;
   PropertyChangeMask       : constant C_Mask := 2 ** 22;

   KeyPress         : constant := 2;
   KeyRelease       : constant := 3;
   ButtonPress      : constant := 4;
   ButtonRelease    : constant := 5;
   MotionNotify     : constant := 6;
   EnterNotify      : constant := 7;
   LeaveNotify      : constant := 8;
   FocusIn          : constant := 9;
   FocusOut         : constant := 10;
   Expose           : constant := 12;
   DestroyNotify    : constant := 17;
   UnmapNotify      : constant := 18;
   MapNotify        : constant := 19;
   MapRequest       : constant := 20;
   ConfigureNotify  : constant := 22;
   ConfigureRequest : constant := 23;
   PropertyNotify   : constant := 28;
   ClientMessage    : constant := 33;
   MappingNotify    : constant := 34;
   LASTEvent        : constant := 36;

   ShiftMask   : constant C_UInt := 2 ** 0;
   LockMask    : constant C_UInt := 2 ** 1;
   ControlMask : constant C_UInt := 2 ** 2;
   Mod1Mask    : constant C_UInt := 2 ** 3;
   Mod2Mask    : constant C_UInt := 2 ** 4;
   Mod3Mask    : constant C_UInt := 2 ** 5;
   Mod4Mask    : constant C_UInt := 2 ** 6;
   Mod5Mask    : constant C_UInt := 2 ** 7;
   AnyModifier : constant C_UInt := 2 ** 15;

   Button1 : constant := 1;
   Button2 : constant := 2;
   Button3 : constant := 3;
   Button4 : constant := 4;
   Button5 : constant := 5;

   NotifyNormal    : constant := 0;
   NotifyInferior  : constant := 2;

   IsViewable : constant := 2;

   DestroyAllMode : constant := 0;

   Above : constant := 0;
   Below : constant := 1;

   PropModeReplace : constant := 0;
   PropModePrepend : constant := 1;
   PropModeAppend  : constant := 2;

   CWBackPixmap      : constant C_ULong := 2 ** 0;
   CWOverrideRedirect : constant C_ULong := 2 ** 9;
   CWEventMask       : constant C_ULong := 2 ** 11;
   CWCursor          : constant C_ULong := 2 ** 14;

   CWX           : constant C_UInt := 2 ** 0;
   CWY           : constant C_UInt := 2 ** 1;
   CWWidth       : constant C_UInt := 2 ** 2;
   CWHeight      : constant C_UInt := 2 ** 3;
   CWBorderWidth : constant C_UInt := 2 ** 4;
   CWSibling     : constant C_UInt := 2 ** 5;
   CWStackMode   : constant C_UInt := 2 ** 6;

   LineSolid : constant := 0;
   CapButt   : constant := 1;
   JoinMiter : constant := 0;

   GrabModeSync  : constant := 0;
   GrabModeAsync : constant := 1;
   GrabSuccess   : constant := 0;
   ReplayPointer : constant := 2;

   RevertToPointerRoot : constant := Pointer_Root;

   Success     : constant := 0;
   BadWindow   : constant := 3;
   BadMatch    : constant := 8;
   BadDrawable : constant := 9;
   BadAccess   : constant := 10;

   WithdrawnState : constant := 0;
   NormalState    : constant := 1;
   IconicState    : constant := 3;

   MappingKeyboard : constant := 1;

   PropertyNewValue : constant := 0;
   PropertyDelete   : constant := 1;

   --  Xutil.h size-hint / WM-hint flags and states
   PSize      : constant C_Mask := 2 ** 3;
   PMinSize   : constant C_Mask := 2 ** 4;
   PMaxSize   : constant C_Mask := 2 ** 5;
   PResizeInc : constant C_Mask := 2 ** 6;
   PAspect    : constant C_Mask := 2 ** 7;
   PBaseSize  : constant C_Mask := 2 ** 8;

   InputHint    : constant C_Mask := 2 ** 0;
   XUrgencyHint : constant C_Mask := 2 ** 8;

   --  cursorfont.h
   XC_fleur    : constant := 52;
   XC_left_ptr : constant := 68;
   XC_sizing   : constant := 120;

   --  Xatom.h
   XA_ATOM              : constant Atom := 4;
   XA_STRING            : constant Atom := 31;
   XA_WINDOW            : constant Atom := 33;
   XA_WM_HINTS          : constant Atom := 35;
   XA_WM_NAME           : constant Atom := 39;
   XA_WM_NORMAL_HINTS   : constant Atom := 40;
   XA_WM_TRANSIENT_FOR  : constant Atom := 68;

   --  Xproto.h request opcodes (used by xerror to whitelist races)
   X_ConfigureWindow    : constant := 12;
   X_GrabButton         : constant := 28;
   X_GrabKey            : constant := 33;
   X_SetInputFocus      : constant := 42;
   X_CopyArea           : constant := 62;
   X_PolySegment        : constant := 66;
   X_PolyFillRectangle  : constant := 70;
   X_PolyText8          : constant := 74;

   --------------------------------------------------------------------
   --  Structs                                                        --
   --------------------------------------------------------------------

   type XSetWindowAttributes is record
      Background_Pixmap    : Pixmap := None;
      Background_Pixel     : C_ULong := 0;
      Border_Pixmap        : Pixmap := None;
      Border_Pixel         : C_ULong := 0;
      Bit_Gravity          : C_Int := 0;
      Win_Gravity          : C_Int := 0;
      Backing_Store        : C_Int := 0;
      Backing_Planes       : C_ULong := 0;
      Backing_Pixel        : C_ULong := 0;
      Save_Under           : C_Int := 0;
      Event_Mask           : C_Mask := 0;
      Do_Not_Propagate_Mask : C_Mask := 0;
      Override_Redirect    : C_Int := 0;
      Colormap_Id          : Colormap := None;
      Cursor_Id            : Cursor := None;
   end record
     with Convention => C;

   type XWindowAttributes is record
      X, Y                 : C_Int := 0;
      Width, Height        : C_Int := 0;
      Border_Width         : C_Int := 0;
      Depth                : C_Int := 0;
      Vis                  : Visual := null;
      Root                 : Window := None;
      Class                : C_Int := 0;
      Bit_Gravity          : C_Int := 0;
      Win_Gravity          : C_Int := 0;
      Backing_Store        : C_Int := 0;
      Backing_Planes       : C_ULong := 0;
      Backing_Pixel        : C_ULong := 0;
      Save_Under           : C_Int := 0;
      Colormap_Id          : Colormap := None;
      Map_Installed        : C_Int := 0;
      Map_State            : C_Int := 0;
      All_Event_Masks      : C_Mask := 0;
      Your_Event_Mask      : C_Mask := 0;
      Do_Not_Propagate_Mask : C_Mask := 0;
      Override_Redirect    : C_Int := 0;
      Scr                  : Screen := null;
   end record
     with Convention => C;

   type XWindowChanges is record
      X, Y          : C_Int := 0;
      Width, Height : C_Int := 0;
      Border_Width  : C_Int := 0;
      Sibling       : Window := None;
      Stack_Mode    : C_Int := 0;
   end record
     with Convention => C;

   type Aspect is record
      Num, Den : C_Int := 0;
   end record
     with Convention => C;

   type XSizeHints is record
      Flags        : C_Mask := 0;
      X, Y         : C_Int := 0;
      Width, Height : C_Int := 0;
      Min_Width, Min_Height : C_Int := 0;
      Max_Width, Max_Height : C_Int := 0;
      Width_Inc, Height_Inc : C_Int := 0;
      Min_Aspect, Max_Aspect : Aspect;
      Base_Width, Base_Height : C_Int := 0;
      Win_Gravity  : C_Int := 0;
   end record
     with Convention => C;

   type XWMHints is record
      Flags          : C_Mask := 0;
      Input          : C_Int := 0;
      Initial_State  : C_Int := 0;
      Icon_Pixmap    : Pixmap := None;
      Icon_Window    : Window := None;
      Icon_X, Icon_Y : C_Int := 0;
      Icon_Mask      : Pixmap := None;
      Window_Group   : XID := 0;
   end record
     with Convention => C;

   type XClassHint is record
      Res_Name  : Interfaces.C.Strings.chars_ptr := Interfaces.C.Strings.Null_Ptr;
      Res_Class : Interfaces.C.Strings.chars_ptr := Interfaces.C.Strings.Null_Ptr;
   end record
     with Convention => C;

   type XTextProperty is record
      Value    : System.Address := System.Null_Address;
      Encoding : Atom := None;
      Format   : C_Int := 0;
      Nitems   : C_ULong := 0;
   end record
     with Convention => C;

   type XModifierKeymap is record
      Max_Keypermod : C_Int := 0;
      Modifiermap   : System.Address := System.Null_Address;
   end record
     with Convention => C;
   type XModifierKeymap_Access is access all XModifierKeymap;

   --  XErrorEvent: used by the error-handler callback
   type XErrorEvent is record
      Event_Type    : C_Int := 0;
      Disp          : Display := null;
      Resourceid    : XID := 0;
      Serial        : C_ULong := 0;
      Error_Code    : C_UChar := 0;
      Request_Code  : C_UChar := 0;
      Minor_Code    : C_UChar := 0;
   end record
     with Convention => C;

   type XErrorHandler is access function
     (Disp : Display; Event : access XErrorEvent) return C_Int
     with Convention => C;

   --------------------------------------------------------------------
   --  XEvent: modelled as the raw union payload (24 longs, 192       --
   --  bytes on LP64), matching C's `long pad[24]` union member.      --
   --  Specific fields are read via typed overlays declared with      --
   --  'Address => Ev'Address (see Dwm_Events).                       --
   --------------------------------------------------------------------

   type XEvent_Pad is array (0 .. 23) of C_Long;

   type XEvent is record
      Pad : XEvent_Pad := (others => 0);
   end record
     with Convention => C;

   --  Read Ev's discriminant by overlaying XAnyEvent at the same address
   --  (see Dwm_Events for the pattern used with the other event kinds).
   type XAnyEvent is record
      Event_Type : C_Int := 0;
      Serial     : C_ULong := 0;
      Send_Event : C_Int := 0;
      Disp       : Display := null;
      Win        : Window := None;
   end record
     with Convention => C;

   type XKeyEvent is record
      Event_Type  : C_Int := 0;
      Serial      : C_ULong := 0;
      Send_Event  : C_Int := 0;
      Disp        : Display := null;
      Win         : Window := None;
      Root        : Window := None;
      Subwindow   : Window := None;
      Evt_Time    : Time_T := 0;
      X, Y        : C_Int := 0;
      X_Root, Y_Root : C_Int := 0;
      State       : C_UInt := 0;
      Keycode     : C_UInt := 0;
      Same_Screen : C_Int := 0;
   end record
     with Convention => C;

   type XButtonEvent is record
      Event_Type  : C_Int := 0;
      Serial      : C_ULong := 0;
      Send_Event  : C_Int := 0;
      Disp        : Display := null;
      Win         : Window := None;
      Root        : Window := None;
      Subwindow   : Window := None;
      Evt_Time    : Time_T := 0;
      X, Y        : C_Int := 0;
      X_Root, Y_Root : C_Int := 0;
      State       : C_UInt := 0;
      Button      : C_UInt := 0;
      Same_Screen : C_Int := 0;
   end record
     with Convention => C;

   type XMotionEvent is record
      Event_Type  : C_Int := 0;
      Serial      : C_ULong := 0;
      Send_Event  : C_Int := 0;
      Disp        : Display := null;
      Win         : Window := None;
      Root        : Window := None;
      Subwindow   : Window := None;
      Evt_Time    : Time_T := 0;
      X, Y        : C_Int := 0;
      X_Root, Y_Root : C_Int := 0;
      State       : C_UInt := 0;
      Is_Hint     : C_UChar := 0;
      Same_Screen : C_Int := 0;
   end record
     with Convention => C;

   type XCrossingEvent is record
      Event_Type  : C_Int := 0;
      Serial      : C_ULong := 0;
      Send_Event  : C_Int := 0;
      Disp        : Display := null;
      Win         : Window := None;
      Root        : Window := None;
      Subwindow   : Window := None;
      Evt_Time    : Time_T := 0;
      X, Y        : C_Int := 0;
      X_Root, Y_Root : C_Int := 0;
      Mode        : C_Int := 0;
      Detail      : C_Int := 0;
      Same_Screen : C_Int := 0;
      Focus       : C_Int := 0;
      State       : C_UInt := 0;
   end record
     with Convention => C;

   type XFocusChangeEvent is record
      Event_Type : C_Int := 0;
      Serial     : C_ULong := 0;
      Send_Event : C_Int := 0;
      Disp       : Display := null;
      Win        : Window := None;
      Mode       : C_Int := 0;
      Detail     : C_Int := 0;
   end record
     with Convention => C;

   type XExposeEvent is record
      Event_Type : C_Int := 0;
      Serial     : C_ULong := 0;
      Send_Event : C_Int := 0;
      Disp       : Display := null;
      Win        : Window := None;
      X, Y       : C_Int := 0;
      Width, Height : C_Int := 0;
      Count      : C_Int := 0;
   end record
     with Convention => C;

   type XDestroyWindowEvent is record
      Event_Type : C_Int := 0;
      Serial     : C_ULong := 0;
      Send_Event : C_Int := 0;
      Disp       : Display := null;
      Event      : Window := None;
      Win        : Window := None;
   end record
     with Convention => C;

   type XUnmapEvent is record
      Event_Type      : C_Int := 0;
      Serial          : C_ULong := 0;
      Send_Event      : C_Int := 0;
      Disp            : Display := null;
      Event           : Window := None;
      Win             : Window := None;
      From_Configure  : C_Int := 0;
   end record
     with Convention => C;

   type XMapRequestEvent is record
      Event_Type : C_Int := 0;
      Serial     : C_ULong := 0;
      Send_Event : C_Int := 0;
      Disp       : Display := null;
      Parent     : Window := None;
      Win        : Window := None;
   end record
     with Convention => C;

   type XConfigureEvent is record
      Event_Type       : C_Int := 0;
      Serial           : C_ULong := 0;
      Send_Event       : C_Int := 0;
      Disp             : Display := null;
      Event            : Window := None;
      Win              : Window := None;
      X, Y             : C_Int := 0;
      Width, Height    : C_Int := 0;
      Border_Width     : C_Int := 0;
      Above            : Window := None;
      Override_Redirect : C_Int := 0;
   end record
     with Convention => C;

   type XConfigureRequestEvent is record
      Event_Type    : C_Int := 0;
      Serial        : C_ULong := 0;
      Send_Event    : C_Int := 0;
      Disp          : Display := null;
      Parent        : Window := None;
      Win           : Window := None;
      X, Y          : C_Int := 0;
      Width, Height : C_Int := 0;
      Border_Width  : C_Int := 0;
      Above         : Window := None;
      Detail        : C_Int := 0;
      Value_Mask    : C_ULong := 0;
   end record
     with Convention => C;

   type XPropertyEvent is record
      Event_Type : C_Int := 0;
      Serial     : C_ULong := 0;
      Send_Event : C_Int := 0;
      Disp       : Display := null;
      Win        : Window := None;
      Prop_Atom  : Atom := None;
      Evt_Time   : Time_T := 0;
      State      : C_Int := 0;
   end record
     with Convention => C;

   type Client_Message_Long_Array is array (0 .. 4) of C_Long;

   type Client_Message_Data is record
      L : Client_Message_Long_Array := (others => 0);
   end record
     with Convention => C;

   type XClientMessageEvent is record
      Event_Type   : C_Int := 0;
      Serial       : C_ULong := 0;
      Send_Event   : C_Int := 0;
      Disp         : Display := null;
      Win          : Window := None;
      Message_Type : Atom := None;
      Format       : C_Int := 0;
      Data         : Client_Message_Data;
   end record
     with Convention => C;

   type XMappingEvent is record
      Event_Type    : C_Int := 0;
      Serial        : C_ULong := 0;
      Send_Event    : C_Int := 0;
      Disp          : Display := null;
      Win           : Window := None;
      Request       : C_Int := 0;
      First_Keycode : C_Int := 0;
      Count         : C_Int := 0;
   end record
     with Convention => C;

   --------------------------------------------------------------------
   --  Functions                                                      --
   --------------------------------------------------------------------

   function XOpenDisplay (Display_Name : Interfaces.C.Strings.chars_ptr) return Display;
   pragma Import (C, XOpenDisplay, "XOpenDisplay");

   function XCloseDisplay (Disp : Display) return C_Int;
   pragma Import (C, XCloseDisplay, "XCloseDisplay");

   function XSupportsLocale return C_Int;
   pragma Import (C, XSupportsLocale, "XSupportsLocale");

   function XDefaultScreen (Disp : Display) return C_Int;
   pragma Import (C, XDefaultScreen, "XDefaultScreen");

   function XDisplayWidth (Disp : Display; Screen_Num : C_Int) return C_Int;
   pragma Import (C, XDisplayWidth, "XDisplayWidth");

   function XDisplayHeight (Disp : Display; Screen_Num : C_Int) return C_Int;
   pragma Import (C, XDisplayHeight, "XDisplayHeight");

   function XRootWindow (Disp : Display; Screen_Num : C_Int) return Window;
   pragma Import (C, XRootWindow, "XRootWindow");

   function XDefaultRootWindow (Disp : Display) return Window;
   pragma Import (C, XDefaultRootWindow, "XDefaultRootWindow");

   function XDefaultDepth (Disp : Display; Screen_Num : C_Int) return C_Int;
   pragma Import (C, XDefaultDepth, "XDefaultDepth");

   function XDefaultVisual (Disp : Display; Screen_Num : C_Int) return Visual;
   pragma Import (C, XDefaultVisual, "XDefaultVisual");

   function XDefaultColormap (Disp : Display; Screen_Num : C_Int) return Colormap;
   pragma Import (C, XDefaultColormap, "XDefaultColormap");

   function XConnectionNumber (Disp : Display) return C_Int;
   pragma Import (C, XConnectionNumber, "XConnectionNumber");

   function XSetErrorHandler (Handler : XErrorHandler) return XErrorHandler;
   pragma Import (C, XSetErrorHandler, "XSetErrorHandler");

   function XSelectInput (Disp : Display; Win : Window; Event_Mask : C_Mask) return C_Int;
   pragma Import (C, XSelectInput, "XSelectInput");

   function XSync (Disp : Display; Discard : C_Int) return C_Int;
   pragma Import (C, XSync, "XSync");

   function XFree (Data : System.Address) return C_Int;
   pragma Import (C, XFree, "XFree");

   function XNextEvent (Disp : Display; Event_Return : access XEvent) return C_Int;
   pragma Import (C, XNextEvent, "XNextEvent");

   function XMaskEvent
     (Disp : Display; Event_Mask : C_Mask; Event_Return : access XEvent) return C_Int;
   pragma Import (C, XMaskEvent, "XMaskEvent");

   function XCheckMaskEvent
     (Disp : Display; Event_Mask : C_Mask; Event_Return : access XEvent) return C_Int;
   pragma Import (C, XCheckMaskEvent, "XCheckMaskEvent");

   function XAllowEvents (Disp : Display; Event_Mode : C_Int; Evt_Time : Time_T) return C_Int;
   pragma Import (C, XAllowEvents, "XAllowEvents");

   function XQueryPointer
     (Disp         : Display;
      Win          : Window;
      Root_Return  : access Window;
      Child_Return : access Window;
      Root_X       : access C_Int;
      Root_Y       : access C_Int;
      Win_X        : access C_Int;
      Win_Y        : access C_Int;
      Mask_Return  : access C_UInt) return C_Int;
   pragma Import (C, XQueryPointer, "XQueryPointer");

   function XGetWindowAttributes
     (Disp : Display; Win : Window; Attrs : access XWindowAttributes) return C_Int;
   pragma Import (C, XGetWindowAttributes, "XGetWindowAttributes");

   function XChangeWindowAttributes
     (Disp : Display; Win : Window; Valuemask : C_ULong;
      Attrs : access XSetWindowAttributes) return C_Int;
   pragma Import (C, XChangeWindowAttributes, "XChangeWindowAttributes");

   function XCreateWindow
     (Disp         : Display;
      Parent       : Window;
      X, Y         : C_Int;
      Width, Height : C_UInt;
      Border_Width : C_UInt;
      Depth        : C_Int;
      Class        : C_UInt;
      Vis          : Visual;
      Valuemask    : C_ULong;
      Attrs        : access XSetWindowAttributes) return Window;
   pragma Import (C, XCreateWindow, "XCreateWindow");

   function XCreateSimpleWindow
     (Disp          : Display;
      Parent        : Window;
      X, Y          : C_Int;
      Width, Height : C_UInt;
      Border_Width  : C_UInt;
      Border, Background : C_ULong) return Window;
   pragma Import (C, XCreateSimpleWindow, "XCreateSimpleWindow");

   function XDestroyWindow (Disp : Display; Win : Window) return C_Int;
   pragma Import (C, XDestroyWindow, "XDestroyWindow");

   function XMapWindow (Disp : Display; Win : Window) return C_Int;
   pragma Import (C, XMapWindow, "XMapWindow");

   function XMapRaised (Disp : Display; Win : Window) return C_Int;
   pragma Import (C, XMapRaised, "XMapRaised");

   function XUnmapWindow (Disp : Display; Win : Window) return C_Int;
   pragma Import (C, XUnmapWindow, "XUnmapWindow");

   function XRaiseWindow (Disp : Display; Win : Window) return C_Int;
   pragma Import (C, XRaiseWindow, "XRaiseWindow");

   function XMoveWindow (Disp : Display; Win : Window; X, Y : C_Int) return C_Int;
   pragma Import (C, XMoveWindow, "XMoveWindow");

   function XMoveResizeWindow
     (Disp : Display; Win : Window; X, Y : C_Int; Width, Height : C_UInt) return C_Int;
   pragma Import (C, XMoveResizeWindow, "XMoveResizeWindow");

   function XConfigureWindow
     (Disp : Display; Win : Window; Value_Mask : C_UInt;
      Values : access XWindowChanges) return C_Int;
   pragma Import (C, XConfigureWindow, "XConfigureWindow");

   function XSetWindowBorder (Disp : Display; Win : Window; Border_Pixel : C_ULong) return C_Int;
   pragma Import (C, XSetWindowBorder, "XSetWindowBorder");

   function XDefineCursor (Disp : Display; Win : Window; Curs : Cursor) return C_Int;
   pragma Import (C, XDefineCursor, "XDefineCursor");

   function XCreateFontCursor (Disp : Display; Shape : C_UInt) return Cursor;
   pragma Import (C, XCreateFontCursor, "XCreateFontCursor");

   function XFreeCursor (Disp : Display; Curs : Cursor) return C_Int;
   pragma Import (C, XFreeCursor, "XFreeCursor");

   function XInternAtom
     (Disp : Display; Atom_Name : Interfaces.C.Strings.chars_ptr;
      Only_If_Exists : C_Int) return Atom;
   pragma Import (C, XInternAtom, "XInternAtom");

   function XChangeProperty
     (Disp     : Display;
      Win      : Window;
      Property : Atom;
      Prop_Type : Atom;
      Format   : C_Int;
      Mode     : C_Int;
      Data     : System.Address;
      Nelements : C_Int) return C_Int;
   pragma Import (C, XChangeProperty, "XChangeProperty");

   function XDeleteProperty (Disp : Display; Win : Window; Property : Atom) return C_Int;
   pragma Import (C, XDeleteProperty, "XDeleteProperty");

   function XGetWindowProperty
     (Disp                : Display;
      Win                 : Window;
      Property            : Atom;
      Long_Offset         : C_Long;
      Long_Length         : C_Long;
      Delete              : C_Int;
      Req_Type            : Atom;
      Actual_Type_Return  : access Atom;
      Actual_Format_Return : access C_Int;
      Nitems_Return       : access C_ULong;
      Bytes_After_Return  : access C_ULong;
      Prop_Return         : access System.Address) return C_Int;
   pragma Import (C, XGetWindowProperty, "XGetWindowProperty");

   function XGetClassHint (Disp : Display; Win : Window; Hints : access XClassHint) return C_Int;
   pragma Import (C, XGetClassHint, "XGetClassHint");

   function XSetClassHint (Disp : Display; Win : Window; Hints : access XClassHint) return C_Int;
   pragma Import (C, XSetClassHint, "XSetClassHint");

   function XGetTextProperty
     (Disp : Display; Win : Window; Text_Prop_Return : access XTextProperty;
      Property : Atom) return C_Int;
   pragma Import (C, XGetTextProperty, "XGetTextProperty");

   function XmbTextPropertyToTextList
     (Disp : Display; Text_Prop : access XTextProperty;
      List_Return : access System.Address; Count_Return : access C_Int) return C_Int;
   pragma Import (C, XmbTextPropertyToTextList, "XmbTextPropertyToTextList");

   procedure XFreeStringList (List : System.Address);
   pragma Import (C, XFreeStringList, "XFreeStringList");

   function XGetTransientForHint
     (Disp : Display; Win : Window; Prop_Window_Return : access Window) return C_Int;
   pragma Import (C, XGetTransientForHint, "XGetTransientForHint");

   function XGetWMNormalHints
     (Disp : Display; Win : Window; Hints_Return : access XSizeHints;
      Supplied_Return : access C_Long) return C_Int;
   pragma Import (C, XGetWMNormalHints, "XGetWMNormalHints");

   function XGetWMHints (Disp : Display; Win : Window) return access XWMHints;
   pragma Import (C, XGetWMHints, "XGetWMHints");

   function XSetWMHints (Disp : Display; Win : Window; Hints : access XWMHints) return C_Int;
   pragma Import (C, XSetWMHints, "XSetWMHints");

   function XGetWMProtocols
     (Disp : Display; Win : Window; Protocols_Return : access System.Address;
      Count_Return : access C_Int) return C_Int;
   pragma Import (C, XGetWMProtocols, "XGetWMProtocols");

   function XSendEvent
     (Disp : Display; Win : Window; Propagate : C_Int; Event_Mask : C_Mask;
      Event_Send : access XEvent) return C_Int;
   pragma Import (C, XSendEvent, "XSendEvent");

   function XQueryTree
     (Disp             : Display;
      Win              : Window;
      Root_Return      : access Window;
      Parent_Return    : access Window;
      Children_Return  : access System.Address;
      Nchildren_Return : access C_UInt) return C_Int;
   pragma Import (C, XQueryTree, "XQueryTree");

   function XKillClient (Disp : Display; Resource : XID) return C_Int;
   pragma Import (C, XKillClient, "XKillClient");

   function XGrabServer (Disp : Display) return C_Int;
   pragma Import (C, XGrabServer, "XGrabServer");

   function XUngrabServer (Disp : Display) return C_Int;
   pragma Import (C, XUngrabServer, "XUngrabServer");

   function XSetCloseDownMode (Disp : Display; Close_Mode : C_Int) return C_Int;
   pragma Import (C, XSetCloseDownMode, "XSetCloseDownMode");

   function XSetInputFocus
     (Disp : Display; Focus : Window; Revert_To : C_Int; Evt_Time : Time_T) return C_Int;
   pragma Import (C, XSetInputFocus, "XSetInputFocus");

   function XGrabButton
     (Disp        : Display;
      Button      : C_UInt;
      Modifiers   : C_UInt;
      Grab_Window : Window;
      Owner_Events : C_Int;
      Event_Mask  : C_UInt;
      Pointer_Mode : C_Int;
      Keyboard_Mode : C_Int;
      Confine_To  : Window;
      Curs        : Cursor) return C_Int;
   pragma Import (C, XGrabButton, "XGrabButton");

   function XUngrabButton
     (Disp : Display; Button : C_UInt; Modifiers : C_UInt; Grab_Window : Window) return C_Int;
   pragma Import (C, XUngrabButton, "XUngrabButton");

   function XGrabKey
     (Disp         : Display;
      Keycode      : C_Int;
      Modifiers    : C_UInt;
      Grab_Window  : Window;
      Owner_Events : C_Int;
      Pointer_Mode : C_Int;
      Keyboard_Mode : C_Int) return C_Int;
   pragma Import (C, XGrabKey, "XGrabKey");

   function XUngrabKey
     (Disp : Display; Keycode : C_Int; Modifiers : C_UInt; Grab_Window : Window) return C_Int;
   pragma Import (C, XUngrabKey, "XUngrabKey");

   function XGrabPointer
     (Disp         : Display;
      Grab_Window  : Window;
      Owner_Events : C_Int;
      Event_Mask   : C_UInt;
      Pointer_Mode : C_Int;
      Keyboard_Mode : C_Int;
      Confine_To   : Window;
      Curs         : Cursor;
      Evt_Time     : Time_T) return C_Int;
   pragma Import (C, XGrabPointer, "XGrabPointer");

   function XUngrabPointer (Disp : Display; Evt_Time : Time_T) return C_Int;
   pragma Import (C, XUngrabPointer, "XUngrabPointer");

   function XWarpPointer
     (Disp     : Display;
      Src_Win, Dest_Win : Window;
      Src_X, Src_Y : C_Int;
      Src_Width, Src_Height : C_UInt;
      Dest_X, Dest_Y : C_Int) return C_Int;
   pragma Import (C, XWarpPointer, "XWarpPointer");

   function XDisplayKeycodes
     (Disp : Display; Min_Keycodes_Return : access C_Int;
      Max_Keycodes_Return : access C_Int) return C_Int;
   pragma Import (C, XDisplayKeycodes, "XDisplayKeycodes");

   function XGetKeyboardMapping
     (Disp : Display; First_Keycode : KeyCode; Keycode_Count : C_Int;
      Keysyms_Per_Keycode_Return : access C_Int) return System.Address;
   pragma Import (C, XGetKeyboardMapping, "XGetKeyboardMapping");

   function XKeycodeToKeysym (Disp : Display; Kc : KeyCode; Index : C_Int) return KeySym;
   pragma Import (C, XKeycodeToKeysym, "XKeycodeToKeysym");

   function XKeysymToKeycode (Disp : Display; Sym : KeySym) return KeyCode;
   pragma Import (C, XKeysymToKeycode, "XKeysymToKeycode");

   function XGetModifierMapping (Disp : Display) return XModifierKeymap_Access;
   pragma Import (C, XGetModifierMapping, "XGetModifierMapping");

   function XFreeModifiermap (Modmap : XModifierKeymap_Access) return C_Int;
   pragma Import (C, XFreeModifiermap, "XFreeModifiermap");

   function XRefreshKeyboardMapping (Event_Map : access XMappingEvent) return C_Int;
   pragma Import (C, XRefreshKeyboardMapping, "XRefreshKeyboardMapping");

   --  Drawing primitives (used by Drw)
   function XCreatePixmap
     (Disp : Display; D : Drawable; Width, Height : C_UInt; Depth : C_UInt) return Pixmap;
   pragma Import (C, XCreatePixmap, "XCreatePixmap");

   function XFreePixmap (Disp : Display; Pmap : Pixmap) return C_Int;
   pragma Import (C, XFreePixmap, "XFreePixmap");

   --  XGCValues is never populated (dwm always passes Values => null,
   --  Valuemask => 0), so it stays an opaque null-record type rather
   --  than a fully-fielded struct like the ones dwm actually reads.
   type XGCValues_Object is limited null record;
   type XGCValues_Access is access all XGCValues_Object;

   function XCreateGC
     (Disp : Display; D : Drawable; Valuemask : C_ULong; Values : XGCValues_Access) return GC;
   pragma Import (C, XCreateGC, "XCreateGC");

   function XFreeGC (Disp : Display; The_GC : GC) return C_Int;
   pragma Import (C, XFreeGC, "XFreeGC");

   function XSetLineAttributes
     (Disp : Display; The_GC : GC; Line_Width : C_UInt; Line_Style, Cap_Style, Join_Style : C_Int)
      return C_Int;
   pragma Import (C, XSetLineAttributes, "XSetLineAttributes");

   function XSetForeground (Disp : Display; The_GC : GC; Foreground : C_ULong) return C_Int;
   pragma Import (C, XSetForeground, "XSetForeground");

   function XFillRectangle
     (Disp : Display; D : Drawable; The_GC : GC; X, Y : C_Int; Width, Height : C_UInt)
      return C_Int;
   pragma Import (C, XFillRectangle, "XFillRectangle");

   function XDrawRectangle
     (Disp : Display; D : Drawable; The_GC : GC; X, Y : C_Int; Width, Height : C_UInt)
      return C_Int;
   pragma Import (C, XDrawRectangle, "XDrawRectangle");

   function XCopyArea
     (Disp : Display; Src, Dest : Drawable; The_GC : GC; Src_X, Src_Y : C_Int;
      Width, Height : C_UInt; Dest_X, Dest_Y : C_Int) return C_Int;
   pragma Import (C, XCopyArea, "XCopyArea");

end Xlib_Thin;
