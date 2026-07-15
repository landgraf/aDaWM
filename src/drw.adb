with Ada.Unchecked_Deallocation;
with Interfaces;
with Interfaces.C.Strings;
with Util;

package body Drw is

   use type Xlib_Thin.C_Int;
   use type Xlib_Thin.XID;
   use type Xft_Thin.XftFont_Access;
   use type Xft_Thin.FcPattern;
   use type Xft_Thin.XftDraw;
   use type Interfaces.Unsigned_32;
   use type Dwm_Types.Color_Scheme_Access;

   procedure Free_Context is new Ada.Unchecked_Deallocation (Context, Context_Access);
   procedure Free_Fnt is new Ada.Unchecked_Deallocation (Fnt, Fnt_Access);
   procedure Free_Cur is new Ada.Unchecked_Deallocation (Cur, Cur_Access);
   procedure Free_Scheme is new Ada.Unchecked_Deallocation
     (Dwm_Types.Color_Scheme, Dwm_Types.Color_Scheme_Access);

   function New_String_Ptr (S : String) return Interfaces.C.Strings.chars_ptr
     renames Interfaces.C.Strings.New_String;

   subtype Codepoint_Type is Interfaces.Unsigned_32;
   UTF_Invalid : constant Codepoint_Type := 16#FFFD#;

   type Len_Table is array (0 .. 31) of Natural;
   Lens : constant Len_Table :=
     (0 .. 15 => 1, 16 .. 23 => 0, 24 .. 27 => 2, 28 .. 29 => 3, 30 => 4, 31 => 0);

   type Mask_Table is array (1 .. 4) of Codepoint_Type;
   Leading_Mask : constant Mask_Table := (16#7F#, 16#1F#, 16#0F#, 16#07#);
   Overlong     : constant Mask_Table := (16#0#, 16#80#, 16#800#, 16#10000#);

   --  Decodes the UTF-8 sequence starting at S (Pos), matching
   --  utf8decode(): returns the byte length consumed, the codepoint
   --  (UTF_Invalid on error), and whether the sequence was invalid.
   procedure Utf8_Decode
     (S : String; Pos : Positive; Codepoint : out Codepoint_Type;
      Length : out Natural; Err : out Boolean);

   --  Implementation detail of Fontset_Create; library users should use
   --  Fontset_Create instead (mirrors xfont_create()'s C comment).
   function Xfont_Create
     (D : Context_Access; Fontname : String; Fontpattern : Xft_Thin.FcPattern) return Fnt_Access;

   procedure Xfont_Free (Font : in out Fnt_Access);

   --------------------------------------------------------------------
   --  Color schemes                                                  --
   --------------------------------------------------------------------

   --  No null checks on D/Dest: both are always real objects here
   --  ('Access of an array component), never a possibly-null pointer
   --  handed in by an untrusted caller the way drw.c's public API
   --  had to allow for.
   procedure Clr_Create (D : Context_Access; Dest : access Xft_Thin.XftColor; Clrname : String) is
      Vis : constant Xlib_Thin.Visual := Xlib_Thin.XDefaultVisual (D.Disp, D.Screen);
      Cmap : constant Xlib_Thin.Colormap := Xlib_Thin.XDefaultColormap (D.Disp, D.Screen);
      C_Name : Interfaces.C.Strings.chars_ptr := New_String_Ptr (Clrname);
      Ok : Xlib_Thin.C_Int;
   begin
      Ok := Xft_Thin.XftColorAllocName (D.Disp, Vis, Cmap, C_Name, Dest);
      Interfaces.C.Strings.Free (C_Name);
      if Ok = 0 then
         Util.Die ("error, cannot allocate color '" & Clrname & "'");
      end if;
   end Clr_Create;

   procedure Clr_Free (D : Context_Access; C : access Xft_Thin.XftColor) is
      Vis : constant Xlib_Thin.Visual := Xlib_Thin.XDefaultVisual (D.Disp, D.Screen);
      Cmap : constant Xlib_Thin.Colormap := Xlib_Thin.XDefaultColormap (D.Disp, D.Screen);
   begin
      Xft_Thin.XftColorFree (D.Disp, Vis, Cmap, C);
   end Clr_Free;

   --------------------------------------------------------------------
   --  Context / fontset lifecycle                                    --
   --------------------------------------------------------------------

   function Create
     (Disp : Xlib_Thin.Display; Screen : Xlib_Thin.C_Int; Win : Xlib_Thin.Window;
      W, H : Natural) return Context_Access
   is
      D : constant Context_Access := new Context;
      Ignore : Xlib_Thin.C_Int;
   begin
      D.Disp := Disp;
      D.Screen := Screen;
      D.Root := Win;
      D.W := W;
      D.H := H;
      D.Drawable := Xlib_Thin.XCreatePixmap
        (Disp, Xlib_Thin.Drawable (Win), Xlib_Thin.C_UInt (W), Xlib_Thin.C_UInt (H),
         Xlib_Thin.C_UInt (Xlib_Thin.XDefaultDepth (Disp, Screen)));
      D.Gc := Xlib_Thin.XCreateGC (Disp, D.Drawable, 0, null);
      Ignore := Xlib_Thin.XSetLineAttributes
        (Disp, D.Gc, 1, Xlib_Thin.LineSolid, Xlib_Thin.CapButt, Xlib_Thin.JoinMiter);
      return D;
   end Create;

   function Cur_Create (D : Context_Access; Shape : Xlib_Thin.C_UInt) return Cur_Access is
      C : Cur_Access;
   begin
      if D = null then
         return null;
      end if;
      C := new Cur;
      C.Cursor := Xlib_Thin.XCreateFontCursor (D.Disp, Shape);
      return C;
   end Cur_Create;

   procedure Cur_Free (D : Context_Access; C : in out Cur_Access) is
      Ignore : Xlib_Thin.C_Int;
   begin
      if C = null then
         return;
      end if;
      Ignore := Xlib_Thin.XFreeCursor (D.Disp, C.Cursor);
      Free_Cur (C);
   end Cur_Free;

   procedure Font_Get_Exts
     (Font : Fnt_Access; Txt : String; Len : Natural; W : out Natural; H : out Natural)
   is
      Ext : aliased Xft_Thin.XGlyphInfo;
   begin
      W := 0;
      H := 0;
      if Font = null or else Txt'Length = 0 then
         return;
      end if;
      Xft_Thin.XftTextExtentsUtf8
        (Font.Disp, Font.Xfont, Txt (Txt'First)'Address, Xlib_Thin.C_Int (Len), Ext'Access);
      W := Natural (Ext.X_Off);
      H := Font.H;
   end Font_Get_Exts;

   function Fontset_Create (D : Context_Access; Fonts : Dwm_Types.Command) return Fnt_Access is
      Ret : Fnt_Access := null;
      Cur : Fnt_Access;
   begin
      if D = null or else Fonts'Length = 0 then
         return null;
      end if;
      for I in reverse Fonts'Range loop
         Cur := Xfont_Create (D, Fonts (I).all, null);
         if Cur /= null then
            Cur.Next := Ret;
            Ret := Cur;
         end if;
      end loop;
      D.Fonts := Ret;
      return Ret;
   end Fontset_Create;

   procedure Fontset_Free (Font : in out Fnt_Access) is
   begin
      if Font /= null then
         if Font.Next /= null then
            Fontset_Free (Font.Next);
         end if;
         Xfont_Free (Font);
      end if;
   end Fontset_Free;

   function Fontset_Get_Width (D : Context_Access; Txt : String) return Natural is
   begin
      if D = null or else D.Fonts = null or else Txt'Length = 0 then
         return 0;
      end if;
      return Text (D, 0, 0, 0, 0, 0, Txt, 0);
   end Fontset_Get_Width;

   function Fontset_Get_Width_Clamp (D : Context_Access; Txt : String; N : Natural) return Natural is
      Tmp : Natural := 0;
   begin
      if D /= null and then D.Fonts /= null and then Txt'Length > 0 and then N > 0 then
         Tmp := Drw.Text (D, 0, 0, 0, 0, 0, Txt, N);
      end if;
      return Natural'Min (N, Tmp);
   end Fontset_Get_Width_Clamp;

   procedure Free (D : in out Context_Access) is
      Ignore : Xlib_Thin.C_Int;
   begin
      Ignore := Xlib_Thin.XFreePixmap (D.Disp, D.Drawable);
      Ignore := Xlib_Thin.XFreeGC (D.Disp, D.Gc);
      Fontset_Free (D.Fonts);
      Free_Context (D);
   end Free;

   procedure Map
     (D : Context_Access; Win : Xlib_Thin.Window; X, Y : Integer; W, H : Natural)
   is
      Ignore : Xlib_Thin.C_Int;
   begin
      if D = null then
         return;
      end if;
      Ignore := Xlib_Thin.XCopyArea
        (D.Disp, D.Drawable, Xlib_Thin.Drawable (Win), D.Gc,
         Xlib_Thin.C_Int (X), Xlib_Thin.C_Int (Y), Xlib_Thin.C_UInt (W), Xlib_Thin.C_UInt (H),
         Xlib_Thin.C_Int (X), Xlib_Thin.C_Int (Y));
      Ignore := Xlib_Thin.XSync (D.Disp, 0);
   end Map;

   --------------------------------------------------------------------
   --  Drawing                                                        --
   --------------------------------------------------------------------

   procedure Rect
     (D : Context_Access; X, Y : Integer; W, H : Natural; Filled, Invert : Integer)
   is
      Ignore : Xlib_Thin.C_Int;
   begin
      if D = null or else D.Scheme = null then
         return;
      end if;
      Ignore := Xlib_Thin.XSetForeground
        (D.Disp, D.Gc,
         (if Invert /= 0
          then D.Scheme (Dwm_Types.Col_Bg).Pixel
          else D.Scheme (Dwm_Types.Col_Fg).Pixel));
      if Filled /= 0 then
         Ignore := Xlib_Thin.XFillRectangle
           (D.Disp, D.Drawable, D.Gc, Xlib_Thin.C_Int (X), Xlib_Thin.C_Int (Y),
            Xlib_Thin.C_UInt (W), Xlib_Thin.C_UInt (H));
      else
         Ignore := Xlib_Thin.XDrawRectangle
           (D.Disp, D.Drawable, D.Gc, Xlib_Thin.C_Int (X), Xlib_Thin.C_Int (Y),
            Xlib_Thin.C_UInt (Natural'Max (W, 1) - 1), Xlib_Thin.C_UInt (Natural'Max (H, 1) - 1));
      end if;
   end Rect;

   procedure Resize (D : Context_Access; W, H : Natural) is
      Ignore : Xlib_Thin.C_Int;
   begin
      if D = null then
         return;
      end if;
      D.W := W;
      D.H := H;
      if D.Drawable /= Xlib_Thin.None then
         Ignore := Xlib_Thin.XFreePixmap (D.Disp, D.Drawable);
      end if;
      D.Drawable := Xlib_Thin.XCreatePixmap
        (D.Disp, D.Root, Xlib_Thin.C_UInt (W), Xlib_Thin.C_UInt (H),
         Xlib_Thin.C_UInt (Xlib_Thin.XDefaultDepth (D.Disp, D.Screen)));
   end Resize;

   function Scm_Create
     (D : Context_Access; Clrnames : Dwm_Types.Color_Name_Triple)
      return Dwm_Types.Color_Scheme_Access
   is
      Ret : constant Dwm_Types.Color_Scheme_Access := new Dwm_Types.Color_Scheme;
   begin
      for K in Dwm_Types.Col_Kind loop
         Clr_Create (D, Ret (K)'Access, Clrnames (K).all);
      end loop;
      return Ret;
   end Scm_Create;

   procedure Scm_Free (D : Context_Access; Scm : in out Dwm_Types.Color_Scheme_Access) is
   begin
      if D = null or else Scm = null then
         return;
      end if;
      for K in Dwm_Types.Col_Kind loop
         Clr_Free (D, Scm (K)'Access);
      end loop;
      Free_Scheme (Scm);
   end Scm_Free;

   procedure Set_Fontset (D : Context_Access; Set : Fnt_Access) is
   begin
      if D /= null then
         D.Fonts := Set;
      end if;
   end Set_Fontset;

   procedure Set_Scheme (D : Context_Access; Scm : Dwm_Types.Color_Scheme_Access) is
   begin
      if D /= null then
         D.Scheme := Scm;
      end if;
   end Set_Scheme;

   --------------------------------------------------------------------
   --  Text                                                           --
   --------------------------------------------------------------------

   --  Per-process caches, mirroring drw_text()'s C `static` locals.
   Ellipsis_Width : Natural := 0;
   Invalid_Width  : Natural := 0;
   Nomatches      : array (0 .. 127) of Codepoint_Type := (others => 0);
   Invalid_Glyph  : constant String := Character'Val (16#EF#) & Character'Val (16#BF#) &
     Character'Val (16#BD#);  --  UTF-8 encoding of U+FFFD

   function Text
     (D : Context_Access; X, Y : Integer; W, H : Natural; Lpad : Natural;
      Txt : String; Invert : Integer) return Integer
   is
      Render : constant Boolean := X /= 0 or else Y /= 0 or else W /= 0 or else H /= 0;
      Cur_X  : Integer := X;
      Cur_W  : Natural := W;
      Draw   : Xft_Thin.XftDraw := null;
      Usedfont, Curfont, Nextfont : Fnt_Access;
      Overflow : Boolean := False;
      Ignore   : Xlib_Thin.C_Int;
      Text_Pos : Positive := Txt'First;
   begin
      if D = null or else (Render and then (D.Scheme = null or else W = 0))
        or else Txt'Length = 0 or else D.Fonts = null
      then
         return 0;
      end if;

      if not Render then
         Cur_W := (if Invert /= 0 then Natural (Invert) else Natural'Last);
      else
         Ignore := Xlib_Thin.XSetForeground
           (D.Disp, D.Gc,
            (if Invert /= 0
             then D.Scheme (Dwm_Types.Col_Fg).Pixel
             else D.Scheme (Dwm_Types.Col_Bg).Pixel));
         Ignore := Xlib_Thin.XFillRectangle
           (D.Disp, D.Drawable, D.Gc, Xlib_Thin.C_Int (X), Xlib_Thin.C_Int (Y),
            Xlib_Thin.C_UInt (W), Xlib_Thin.C_UInt (H));
         if W < Lpad then
            return X + W;
         end if;
         Draw := Xft_Thin.XftDrawCreate
           (D.Disp, D.Drawable, Xlib_Thin.XDefaultVisual (D.Disp, D.Screen),
            Xlib_Thin.XDefaultColormap (D.Disp, D.Screen));
         Cur_X := X + Lpad;
         Cur_W := W - Lpad;
      end if;

      Usedfont := D.Fonts;
      if Ellipsis_Width = 0 and then Render then
         Ellipsis_Width := Fontset_Get_Width (D, "...");
      end if;
      if Invalid_Width = 0 and then Render then
         Invalid_Width := Fontset_Get_Width (D, Invalid_Glyph);
      end if;

      Outer_Loop :
      loop
         declare
            Ew            : Natural := 0;
            Ellipsis_X    : Integer := 0;
            Ellipsis_W    : Natural := 0;
            Ellipsis_Len  : Natural := 0;
            Utf8_Str_Pos  : constant Positive := Text_Pos;
            Utf8_Strlen   : Natural := 0;
            Charexists    : Boolean := False;
            Codepoint     : Codepoint_Type := 0;
            Char_Len      : Natural := 0;
            Err           : Boolean := False;
         begin
            Nextfont := null;
            Inner_Loop :
            while Text_Pos <= Txt'Last loop
               Utf8_Decode (Txt, Text_Pos, Codepoint, Char_Len, Err);
               Charexists := False;
               Curfont := D.Fonts;
               while Curfont /= null loop
                  if not Charexists then
                     Charexists := Xft_Thin.XftCharExists
                       (D.Disp, Curfont.Xfont, Xft_Thin.FcChar32 (Codepoint)) /= 0;
                  end if;
                  if Charexists then
                     declare
                        Tmpw, Ignored_H : Natural;
                     begin
                        Font_Get_Exts
                          (Curfont, Txt (Text_Pos .. Text_Pos + Char_Len - 1), Char_Len,
                           Tmpw, Ignored_H);
                        if Ew + Ellipsis_Width <= Cur_W then
                           Ellipsis_X := Cur_X + Ew;
                           Ellipsis_W := Cur_W - Ew;
                           Ellipsis_Len := Utf8_Strlen;
                        end if;
                        if Ew + Tmpw > Cur_W then
                           Overflow := True;
                           if not Render then
                              Cur_X := Cur_X + Tmpw;
                           else
                              Utf8_Strlen := Ellipsis_Len;
                           end if;
                        elsif Curfont = Usedfont then
                           Text_Pos := Text_Pos + Char_Len;
                           if not Err then
                              Utf8_Strlen := Utf8_Strlen + Char_Len;
                              Ew := Ew + Tmpw;
                           end if;
                        else
                           Nextfont := Curfont;
                        end if;
                     end;
                     exit;
                  end if;
                  Curfont := Curfont.Next;
               end loop;

               exit Inner_Loop when Overflow or else not Charexists or else Nextfont /= null
                 or else Err;
            end loop Inner_Loop;

            if Utf8_Strlen > 0 then
               if Render then
                  declare
                     Ty : constant Xlib_Thin.C_Int :=
                       Xlib_Thin.C_Int (Y) + (Xlib_Thin.C_Int (H) - Xlib_Thin.C_Int (Usedfont.H)) / 2
                       + Usedfont.Xfont.Ascent;
                     Color : aliased constant Xft_Thin.XftColor :=
                       D.Scheme (if Invert /= 0 then Dwm_Types.Col_Bg else Dwm_Types.Col_Fg);
                  begin
                     Xft_Thin.XftDrawStringUtf8
                       (Draw, Color'Access, Usedfont.Xfont, Xlib_Thin.C_Int (Cur_X), Ty,
                        Txt (Utf8_Str_Pos)'Address, Xlib_Thin.C_Int (Utf8_Strlen));
                  end;
               end if;
               Cur_X := Cur_X + Ew;
               Cur_W := Cur_W - Ew;
            end if;

            if Err and then (not Render or else Invalid_Width < Cur_W) then
               if Render then
                  Ignore := Xlib_Thin.C_Int
                    (Text (D, Cur_X, Y, Cur_W, H, 0, Invalid_Glyph, Invert));
               end if;
               Cur_X := Cur_X + Invalid_Width;
               Cur_W := Cur_W - Invalid_Width;
            end if;

            if Render and then Overflow then
               Ignore := Xlib_Thin.C_Int
                 (Text (D, Ellipsis_X, Y, Ellipsis_W, H, 0, "...", Invert));
            end if;

            exit Outer_Loop when Text_Pos > Txt'Last or else Overflow;

            if Nextfont /= null then
               Usedfont := Nextfont;
            else
               declare
                  Hash : Interfaces.Unsigned_32;
                  H0, H1 : Natural;
                  Skip_Match : Boolean;
               begin
                  Hash := Codepoint;
                  Hash := ((Hash / 65536) xor Hash) * 16#21F0AAAD#;
                  Hash := ((Hash / 32768) xor Hash) * 16#D35A2D97#;
                  H0 := Natural (((Hash / 32768) xor Hash) mod Nomatches'Length);
                  H1 := Natural ((Hash / 131072) mod Nomatches'Length);

                  Skip_Match := Nomatches (H0) = Codepoint or else Nomatches (H1) = Codepoint;

                  if not Skip_Match then
                     declare
                        Fccharset : constant Xft_Thin.FcCharSet := Xft_Thin.FcCharSetCreate;
                        Fcpattern : Xft_Thin.FcPattern;
                        Match     : Xft_Thin.FcPattern;
                        Result    : aliased Xft_Thin.FcResult;
                        Bool_Ignore : Xft_Thin.FcBool;
                     begin
                        Bool_Ignore := Xft_Thin.FcCharSetAddChar
                          (Fccharset, Xft_Thin.FcChar32 (Codepoint));
                        if D.Fonts.Pattern = null then
                           Util.Die ("the first font in the cache must be loaded from a font string.");
                        end if;
                        Fcpattern := Xft_Thin.FcPatternDuplicate (D.Fonts.Pattern);
                        Bool_Ignore := Xft_Thin.FcPatternAddCharSet
                          (Fcpattern, Xft_Thin.FC_CHARSET, Fccharset);
                        Bool_Ignore := Xft_Thin.FcPatternAddBool
                          (Fcpattern, Xft_Thin.FC_SCALABLE, Xft_Thin.FcTrue);
                        Bool_Ignore := Xft_Thin.FcConfigSubstitute
                          (null, Fcpattern, Xft_Thin.FcMatchPattern);
                        Xft_Thin.FcDefaultSubstitute (Fcpattern);
                        Match := Xft_Thin.XftFontMatch (D.Disp, D.Screen, Fcpattern, Result'Access);
                        Xft_Thin.FcCharSetDestroy (Fccharset);
                        Xft_Thin.FcPatternDestroy (Fcpattern);

                        if Match /= null then
                           Usedfont := Xfont_Create (D, "", Match);
                           if Usedfont /= null
                             and then Xft_Thin.XftCharExists
                               (D.Disp, Usedfont.Xfont, Xft_Thin.FcChar32 (Codepoint)) /= 0
                           then
                              Curfont := D.Fonts;
                              while Curfont.Next /= null loop
                                 Curfont := Curfont.Next;
                              end loop;
                              Curfont.Next := Usedfont;
                           else
                              Xfont_Free (Usedfont);
                              if Nomatches (H0) /= 0 then
                                 Nomatches (H1) := Codepoint;
                              else
                                 Nomatches (H0) := Codepoint;
                              end if;
                              Usedfont := D.Fonts;
                           end if;
                        end if;
                     end;
                  else
                     Usedfont := D.Fonts;
                  end if;
               end;
            end if;
         end;
      end loop Outer_Loop;

      if Draw /= null then
         Xft_Thin.XftDrawDestroy (Draw);
      end if;

      return Cur_X + (if Render then Cur_W else 0);
   end Text;

   procedure Utf8_Decode
     (S : String; Pos : Positive; Codepoint : out Codepoint_Type;
      Length : out Natural; Err : out Boolean)
   is
      B0  : constant Natural := Character'Pos (S (Pos));
      Len : constant Natural := Lens (B0 / 8);
      Cp  : Codepoint_Type;
   begin
      Codepoint := UTF_Invalid;
      Err := True;
      if Len = 0 then
         Length := 1;
         return;
      end if;
      Cp := Codepoint_Type (B0) and Leading_Mask (Len);
      for I in 1 .. Len - 1 loop
         if Pos + I > S'Last then
            Length := I;
            return;
         end if;
         declare
            Bi : constant Natural := Character'Pos (S (Pos + I));
         begin
            if Bi = 0 or else (Bi / 64) /= 2 then  --  (Bi & 0xC0) /= 0x80
               Length := I;
               return;
            end if;
            Cp := (Cp * 64) or Codepoint_Type (Bi mod 64);
         end;
      end loop;
      if Cp > 16#10FFFF# or else (Cp / 2048) = 16#1B# or else Cp < Overlong (Len)
      then
         Length := Len;
         return;
      end if;
      Err := False;
      Codepoint := Cp;
      Length := Len;
   end Utf8_Decode;

   function Xfont_Create
     (D : Context_Access; Fontname : String; Fontpattern : Xft_Thin.FcPattern) return Fnt_Access
   is
      Xfont   : Xft_Thin.XftFont_Access := null;
      Pattern : Xft_Thin.FcPattern := null;
      Font    : Fnt_Access;
   begin
      if Fontname'Length > 0 then
         declare
            C_Name : Interfaces.C.Strings.chars_ptr := New_String_Ptr (Fontname);
         begin
            Xfont := Xft_Thin.XftFontOpenName (D.Disp, D.Screen, C_Name);
            if Xfont = null then
               Interfaces.C.Strings.Free (C_Name);
               return null;
            end if;
            Pattern := Xft_Thin.FcNameParse (C_Name);
            if Pattern = null then
               Xft_Thin.XftFontClose (D.Disp, Xfont);
               Interfaces.C.Strings.Free (C_Name);
               return null;
            end if;
            Interfaces.C.Strings.Free (C_Name);
         end;
      elsif Fontpattern /= null then
         Xfont := Xft_Thin.XftFontOpenPattern (D.Disp, Fontpattern);
         if Xfont = null then
            return null;
         end if;
      else
         Util.Die ("no font specified.");
      end if;

      Font := new Fnt;
      Font.Xfont := Xfont;
      Font.Pattern := Pattern;
      Font.H := Natural (Xfont.Ascent + Xfont.Descent);
      Font.Disp := D.Disp;
      return Font;
   end Xfont_Create;

   procedure Xfont_Free (Font : in out Fnt_Access) is
   begin
      if Font = null then
         return;
      end if;
      if Font.Pattern /= null then
         Xft_Thin.FcPatternDestroy (Font.Pattern);
      end if;
      Xft_Thin.XftFontClose (Font.Disp, Font.Xfont);
      Free_Fnt (Font);
   end Xfont_Free;

end Drw;
