--  Port of util.h/util.c. MAX/MIN become plain functions (BETWEEN is
--  unused anywhere in dwm.c/drw.c, so it is not ported); LENGTH has no
--  equivalent since Ada array types carry their own bounds ('Length,
--  'Range). ecalloc has no equivalent either: Ada's "new" already
--  raises Storage_Error (equivalent to dying) on allocation failure,
--  so callers just use "new" directly.
package Util is

   --  Returns the larger of Left and Right (dwm.c's MAX macro).
   function Max_Integer (Left, Right : Integer) return Integer is (if Left > Right then Left else Right);

   --  Returns the smaller of Left and Right (dwm.c's MIN macro).
   function Min_Integer (Left, Right : Integer) return Integer is (if Left < Right then Left else Right);

   --  Prints Msg to standard error and terminates the process with a
   --  failure status (equivalent to C's die(), which always exit(1)s).
   --  If With_Errno, the OS error text for errno is appended, mirroring
   --  die()'s "%s: %s", strerror(errno) convention for a "...:" message.
   procedure Die (Msg : String; With_Errno : Boolean := False);
   pragma No_Return (Die);

end Util;
