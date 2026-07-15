with Ada.Text_IO;
with Ada.Unchecked_Conversion;
with System;
with Interfaces.C;
with Interfaces.C.Strings;
with GNAT.OS_Lib;

package body Util is

   --  glibc has no plain "errno" symbol to import (it is a macro around
   --  __errno_location()), so fetch the per-thread errno cell directly.
   function Errno_Location return System.Address;
   pragma Import (C, Errno_Location, "__errno_location");

   function Strerror (Errnum : in Interfaces.C.int) return Interfaces.C.Strings.chars_ptr;
   pragma Import (C, Strerror, "strerror");

   type Int_Access is access all Interfaces.C.int;

   function To_Int_Access is new Ada.Unchecked_Conversion (System.Address, Int_Access);

   function Errno_Value return Interfaces.C.int is
     (To_Int_Access (Errno_Location).all);

   procedure Die (Msg : in String; With_Errno : in Boolean := False) is
   begin
      Ada.Text_IO.Put (Ada.Text_IO.Standard_Error, Msg);
      if With_Errno then
         Ada.Text_IO.Put (Ada.Text_IO.Standard_Error, " ");
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            Interfaces.C.Strings.Value (Strerror (Errno_Value)));
      else
         Ada.Text_IO.New_Line (Ada.Text_IO.Standard_Error);
      end if;
      GNAT.OS_Lib.OS_Exit (1);
   end Die;

end Util;
