with Ada.Unchecked_Conversion;
with System;
with Interfaces.C;
with Interfaces.C.Strings;
with Dwm_State;

package body Dwm_Xutil is

   use type Xlib_Thin.C_Int;
   use type Xlib_Thin.C_ULong;
   use type Xlib_Thin.XID;
   use type System.Address;

   type C_Ulong_Access is access all Xlib_Thin.C_ULong;
   function To_C_Ulong_Access is new Ada.Unchecked_Conversion (System.Address, C_Ulong_Access);

   type Address_Access is access all System.Address;
   function To_Address_Access is new Ada.Unchecked_Conversion (System.Address, Address_Access);

   function To_Chars_Ptr is new Ada.Unchecked_Conversion
     (System.Address, Interfaces.C.Strings.chars_ptr);

   function Get_Atom_Prop (Window : in Xlib_Thin.Window; Prop : in Xlib_Thin.Atom) return Xlib_Thin.Atom is
      Actual_Type : aliased Xlib_Thin.Atom;
      Format : aliased Xlib_Thin.C_Int;
      Nitems, Bytes_After : aliased Xlib_Thin.C_ULong;
      Prop_Value : aliased System.Address := System.Null_Address;
      Status : Xlib_Thin.C_Int;
      Result : Xlib_Thin.Atom := Xlib_Thin.None;
      Ignore : Xlib_Thin.C_Int;
   begin
      Status := Xlib_Thin.XGetWindowProperty
        (Dwm_State.Get_Display, Window, Prop, 0, 8, 0, Xlib_Thin.XA_ATOM,
         Actual_Type'Access, Format'Access, Nitems'Access, Bytes_After'Access, Prop_Value'Access);
      if Status = Xlib_Thin.Success and then Prop_Value /= System.Null_Address then
         if Nitems > 0 and then Format = 32 then
            Result := Xlib_Thin.Atom (To_C_Ulong_Access (Prop_Value).all);
         end if;
         Ignore := Xlib_Thin.XFree (Prop_Value);
      end if;
      return Result;
   end Get_Atom_Prop;

   function Get_Root_Ptr return Root_Ptr_Result is
      Dummy_Win : aliased Xlib_Thin.Window;
      Dummy_Int1, Dummy_Int2 : aliased Xlib_Thin.C_Int;
      Dummy_Mask : aliased Xlib_Thin.C_UInt;
      Root_X, Root_Y : aliased Xlib_Thin.C_Int;
      Ok : Xlib_Thin.C_Int;
   begin
      Ok := Xlib_Thin.XQueryPointer
        (Dwm_State.Get_Display, Dwm_State.Get_Root, Dummy_Win'Access, Dummy_Win'Access,
         Root_X'Access, Root_Y'Access, Dummy_Int1'Access, Dummy_Int2'Access, Dummy_Mask'Access);
      return (Pos_X => Integer (Root_X), Pos_Y => Integer (Root_Y), Found => Ok /= 0);
   end Get_Root_Ptr;

   function Get_State (Window : in Xlib_Thin.Window) return Long_Integer is
      Format : aliased Xlib_Thin.C_Int;
      Nitems, Bytes_After : aliased Xlib_Thin.C_ULong;
      Actual_Type : aliased Xlib_Thin.Atom;
      Prop_Value : aliased System.Address := System.Null_Address;
      Result : Long_Integer := -1;
      Status : Xlib_Thin.C_Int;
      Ignore : Xlib_Thin.C_Int;
   begin
      Status := Xlib_Thin.XGetWindowProperty
        (Dwm_State.Get_Display, Window, Dwm_State.Get_Wm_Atom (Dwm_State.WM_State), 0, 2, 0,
         Dwm_State.Get_Wm_Atom (Dwm_State.WM_State), Actual_Type'Access, Format'Access,
         Nitems'Access, Bytes_After'Access, Prop_Value'Access);
      if Status /= Xlib_Thin.Success then
         return -1;
      end if;
      if Nitems /= 0 and then Format = 32 then
         Result := Long_Integer (To_C_Ulong_Access (Prop_Value).all);
      end if;
      if Prop_Value /= System.Null_Address then
         Ignore := Xlib_Thin.XFree (Prop_Value);
      end if;
      return Result;
   end Get_State;

   function Get_Text_Prop (Window : in Xlib_Thin.Window; Prop : in Xlib_Thin.Atom) return String is
      Name : aliased Xlib_Thin.XTextProperty;
      Ok   : Xlib_Thin.C_Int;
   begin
      Ok := Xlib_Thin.XGetTextProperty (Dwm_State.Get_Display, Window, Name'Access, Prop);
      if Ok = 0 or else Name.Nitems = 0 then
         return "";
      end if;
      declare
         Result : String (1 .. 255);
         Len    : Natural := 0;
         Ignore : Xlib_Thin.C_Int;
      begin
         if Name.Encoding = Xlib_Thin.XA_STRING then
            declare
               Str : constant String := Interfaces.C.Strings.Value (To_Chars_Ptr (Name.Value));
            begin
               Len := Natural'Min (Str'Length, 255);
               Result (1 .. Len) := Str (Str'First .. Str'First + Len - 1);
            end;
         else
            declare
               List_Ptr : aliased System.Address := System.Null_Address;
               Count    : aliased Xlib_Thin.C_Int;
               Result_Code : Xlib_Thin.C_Int;
            begin
               Result_Code := Xlib_Thin.XmbTextPropertyToTextList
                 (Dwm_State.Get_Display, Name'Access, List_Ptr'Access, Count'Access);
               if Result_Code >= Xlib_Thin.Success and then Count > 0
                 and then List_Ptr /= System.Null_Address
               then
                  declare
                     First_Str : constant System.Address := To_Address_Access (List_Ptr).all;
                     Str : constant String := Interfaces.C.Strings.Value (To_Chars_Ptr (First_Str));
                  begin
                     Len := Natural'Min (Str'Length, 255);
                     Result (1 .. Len) := Str (Str'First .. Str'First + Len - 1);
                  end;
                  Xlib_Thin.XFreeStringList (List_Ptr);
               end if;
            end;
         end if;
         Ignore := Xlib_Thin.XFree (Name.Value);
         return Result (1 .. Len);
      end;
   end Get_Text_Prop;

end Dwm_Xutil;
