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
   procedure Free_Font is new Ada.Unchecked_Deallocation (Font, Font_Access);
   procedure Free_Cursor is new Ada.Unchecked_Deallocation (Cursor, Cursor_Access);
   procedure Free_Scheme is new Ada.Unchecked_Deallocation
     (Dwm_Types.Color_Scheme, Dwm_Types.Color_Scheme_Access);

   function New_String_Ptr (S : in String) return Interfaces.C.Strings.chars_ptr
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
   --  Length always stays within the bytes actually available in S,
   --  so S (Pos .. Pos + Length - 1) is always a safe slice regardless
   --  of whether decoding succeeded or the sequence ran off the end of
   --  the string.
   procedure Utf8_Decode
     (S : in String; Pos : in Positive; Codepoint : out Codepoint_Type;
      Length : out Natural; Err : out Boolean)
     with
       Pre  => Pos in S'Range,
       Post => Length in 1 .. 4
         and then Pos + Length - 1 <= S'Last
         and then (if not Err then Codepoint <= 16#10FFFF#);

   --  Implementation detail of Fontset_Create; library users should use
   --  Fontset_Create instead (mirrors xfont_create()'s C comment).
   function Xfont_Create
     (Drw_Ctx : in Context_Access; Fontname : in String; Fontpattern : in Xft_Thin.FcPattern) return Font_Access;

   procedure Xfont_Free (Fnt : in out Font_Access);

   --------------------------------------------------------------------
   --  Color schemes                                                  --
   --------------------------------------------------------------------

   --  No null checks on Drw_Ctx/Dest: both are always real objects
   --  here ('Access of an array component), never a possibly-null
   --  pointer handed in by an untrusted caller the way drw.c's public
   --  API had to allow for.
   procedure Color_Create
     (Drw_Ctx : in Context_Access; Dest : access Xft_Thin.XftColor; Color_Name : in String)
   is
      Vis : constant Xlib_Thin.Visual := Xlib_Thin.XDefaultVisual (Drw_Ctx.Disp, Drw_Ctx.Screen);
      Cmap : constant Xlib_Thin.Colormap := Xlib_Thin.XDefaultColormap (Drw_Ctx.Disp, Drw_Ctx.Screen);
      Name_Ptr : Interfaces.C.Strings.chars_ptr := New_String_Ptr (Color_Name);
      Ok : Xlib_Thin.C_Int;
   begin
      Ok := Xft_Thin.XftColorAllocName (Drw_Ctx.Disp, Vis, Cmap, Name_Ptr, Dest);
      Interfaces.C.Strings.Free (Name_Ptr);
      if Ok = 0 then
         Util.Die ("error, cannot allocate color '" & Color_Name & "'");
      end if;
   end Color_Create;

   procedure Color_Free (Drw_Ctx : in Context_Access; Color : access Xft_Thin.XftColor) is
      Vis : constant Xlib_Thin.Visual := Xlib_Thin.XDefaultVisual (Drw_Ctx.Disp, Drw_Ctx.Screen);
      Cmap : constant Xlib_Thin.Colormap := Xlib_Thin.XDefaultColormap (Drw_Ctx.Disp, Drw_Ctx.Screen);
   begin
      Xft_Thin.XftColorFree (Drw_Ctx.Disp, Vis, Cmap, Color);
   end Color_Free;

   --------------------------------------------------------------------
   --  Context / fontset lifecycle                                    --
   --------------------------------------------------------------------

   function Create
     (Disp : in Xlib_Thin.Display; Screen : in Xlib_Thin.C_Int; Win : in Xlib_Thin.Window;
      Width, Height : in Natural) return Context_Access
   is
      Drw_Ctx : constant Context_Access := new Context;
      Ignore : Xlib_Thin.C_Int;
   begin
      Drw_Ctx.Disp := Disp;
      Drw_Ctx.Screen := Screen;
      Drw_Ctx.Root := Win;
      Drw_Ctx.Width := Width;
      Drw_Ctx.Height := Height;
      Drw_Ctx.Drawable := Xlib_Thin.XCreatePixmap
        (Disp, Xlib_Thin.Drawable (Win), Xlib_Thin.C_UInt (Width), Xlib_Thin.C_UInt (Height),
         Xlib_Thin.C_UInt (Xlib_Thin.XDefaultDepth (Disp, Screen)));
      Drw_Ctx.Gc := Xlib_Thin.XCreateGC (Disp, Drw_Ctx.Drawable, 0, null);
      Ignore := Xlib_Thin.XSetLineAttributes
        (Disp, Drw_Ctx.Gc, 1, Xlib_Thin.LineSolid, Xlib_Thin.CapButt, Xlib_Thin.JoinMiter);
      return Drw_Ctx;
   end Create;

   function Cursor_Create (Drw_Ctx : in Context_Access; Shape : in Xlib_Thin.C_UInt) return Cursor_Access is
      Result : Cursor_Access;
   begin
      if Drw_Ctx = null then
         return null;
      end if;
      Result := new Cursor;
      Result.X_Cursor := Xlib_Thin.XCreateFontCursor (Drw_Ctx.Disp, Shape);
      return Result;
   end Cursor_Create;

   procedure Cursor_Free (Drw_Ctx : in Context_Access; Cursor : in out Cursor_Access) is
      Ignore : Xlib_Thin.C_Int;
   begin
      if Cursor = null then
         return;
      end if;
      Ignore := Xlib_Thin.XFreeCursor (Drw_Ctx.Disp, Cursor.X_Cursor);
      Free_Cursor (Cursor);
   end Cursor_Free;

   procedure Font_Get_Exts
     (Fnt : in Font_Access; Txt : in String; Len : in Natural; Width : out Natural; Height : out Natural)
   is
      Ext : aliased Xft_Thin.XGlyphInfo;
   begin
      Width := 0;
      Height := 0;
      if Fnt = null or else Txt'Length = 0 then
         return;
      end if;
      Xft_Thin.XftTextExtentsUtf8
        (Fnt.Disp, Fnt.Xfont, Txt (Txt'First)'Address, Xlib_Thin.C_Int (Len), Ext'Access);
      Width := Natural (Ext.X_Off);
      Height := Fnt.Height;
   end Font_Get_Exts;

   function Fontset_Create (Drw_Ctx : in Context_Access; Fonts : in Dwm_Types.Command) return Font_Access is
      Result : Font_Access := null;
      Loaded_Font : Font_Access;
   begin
      if Drw_Ctx = null or else Fonts'Length = 0 then
         return null;
      end if;
      for Idx in reverse Fonts'Range loop
         Loaded_Font := Xfont_Create (Drw_Ctx, Fonts (Idx).all, null);
         if Loaded_Font /= null then
            Loaded_Font.Next := Result;
            Result := Loaded_Font;
         end if;
      end loop;
      return Result;
   end Fontset_Create;

   procedure Fontset_Free (Fnt : in out Font_Access) is
   begin
      if Fnt /= null then
         if Fnt.Next /= null then
            Fontset_Free (Fnt.Next);
         end if;
         Xfont_Free (Fnt);
      end if;
   end Fontset_Free;

   procedure Fontset_Get_Width (Drw_Ctx : in Context_Access; Txt : in String; Result : out Natural) is
      Raw : Integer;
   begin
      if Drw_Ctx = null or else Drw_Ctx.Fonts = null or else Txt'Length = 0 then
         Result := 0;
         return;
      end if;
      Text (Drw_Ctx, 0, 0, 0, 0, 0, Txt, 0, Raw);
      Result := Raw;
   end Fontset_Get_Width;

   procedure Fontset_Get_Width_Clamp
     (Drw_Ctx : in Context_Access; Txt : in String; Max_Width : in Natural; Result : out Natural)
   is
      Tmp : Integer := 0;
   begin
      if Drw_Ctx /= null and then Drw_Ctx.Fonts /= null and then Txt'Length > 0 and then Max_Width > 0
      then
         Drw.Text (Drw_Ctx, 0, 0, 0, 0, 0, Txt, Max_Width, Tmp);
      end if;
      Result := Natural'Min (Max_Width, Natural (Tmp));
   end Fontset_Get_Width_Clamp;

   procedure Free (Drw_Ctx : in out Context_Access) is
      Ignore : Xlib_Thin.C_Int;
   begin
      Ignore := Xlib_Thin.XFreePixmap (Drw_Ctx.Disp, Drw_Ctx.Drawable);
      Ignore := Xlib_Thin.XFreeGC (Drw_Ctx.Disp, Drw_Ctx.Gc);
      Fontset_Free (Drw_Ctx.Fonts);
      Free_Context (Drw_Ctx);
   end Free;

   procedure Map
     (Drw_Ctx : in Context_Access; Win : in Xlib_Thin.Window; Pos_X, Pos_Y : in Integer; Width, Height : in Natural)
   is
      Ignore : Xlib_Thin.C_Int;
   begin
      if Drw_Ctx = null then
         return;
      end if;
      Ignore := Xlib_Thin.XCopyArea
        (Drw_Ctx.Disp, Drw_Ctx.Drawable, Xlib_Thin.Drawable (Win), Drw_Ctx.Gc,
         Xlib_Thin.C_Int (Pos_X), Xlib_Thin.C_Int (Pos_Y), Xlib_Thin.C_UInt (Width),
         Xlib_Thin.C_UInt (Height), Xlib_Thin.C_Int (Pos_X), Xlib_Thin.C_Int (Pos_Y));
      Ignore := Xlib_Thin.XSync (Drw_Ctx.Disp, 0);
   end Map;

   --------------------------------------------------------------------
   --  Drawing                                                        --
   --------------------------------------------------------------------

   procedure Rect
     (Drw_Ctx : in Context_Access; Pos_X, Pos_Y : in Integer; Width, Height : in Natural;
      Filled, Invert : in Integer)
   is
      Ignore : Xlib_Thin.C_Int;
   begin
      if Drw_Ctx = null or else Drw_Ctx.Scheme = null then
         return;
      end if;
      Ignore := Xlib_Thin.XSetForeground
        (Drw_Ctx.Disp, Drw_Ctx.Gc,
         (if Invert /= 0
          then Drw_Ctx.Scheme (Dwm_Types.Col_Bg).Pixel
          else Drw_Ctx.Scheme (Dwm_Types.Col_Fg).Pixel));
      if Filled /= 0 then
         Ignore := Xlib_Thin.XFillRectangle
           (Drw_Ctx.Disp, Drw_Ctx.Drawable, Drw_Ctx.Gc, Xlib_Thin.C_Int (Pos_X), Xlib_Thin.C_Int (Pos_Y),
            Xlib_Thin.C_UInt (Width), Xlib_Thin.C_UInt (Height));
      else
         Ignore := Xlib_Thin.XDrawRectangle
           (Drw_Ctx.Disp, Drw_Ctx.Drawable, Drw_Ctx.Gc, Xlib_Thin.C_Int (Pos_X), Xlib_Thin.C_Int (Pos_Y),
            Xlib_Thin.C_UInt (Natural'Max (Width, 1) - 1), Xlib_Thin.C_UInt (Natural'Max (Height, 1) - 1));
      end if;
   end Rect;

   procedure Resize (Drw_Ctx : in Context_Access; Width, Height : in Natural) is
      Ignore : Xlib_Thin.C_Int;
   begin
      if Drw_Ctx = null then
         return;
      end if;
      Drw_Ctx.Width := Width;
      Drw_Ctx.Height := Height;
      if Drw_Ctx.Drawable /= Xlib_Thin.None then
         Ignore := Xlib_Thin.XFreePixmap (Drw_Ctx.Disp, Drw_Ctx.Drawable);
      end if;
      Drw_Ctx.Drawable := Xlib_Thin.XCreatePixmap
        (Drw_Ctx.Disp, Drw_Ctx.Root, Xlib_Thin.C_UInt (Width), Xlib_Thin.C_UInt (Height),
         Xlib_Thin.C_UInt (Xlib_Thin.XDefaultDepth (Drw_Ctx.Disp, Drw_Ctx.Screen)));
   end Resize;

   function Scheme_Create
     (Drw_Ctx : in Context_Access; Color_Names : in Dwm_Types.Color_Name_Triple)
      return Dwm_Types.Color_Scheme_Access
   is
      Result : constant Dwm_Types.Color_Scheme_Access := new Dwm_Types.Color_Scheme;
   begin
      for K in Dwm_Types.Col_Kind loop
         Color_Create (Drw_Ctx, Result (K)'Access, Color_Names (K).all);
      end loop;
      return Result;
   end Scheme_Create;

   procedure Scheme_Free (Drw_Ctx : in Context_Access; Scheme : in out Dwm_Types.Color_Scheme_Access) is
   begin
      if Drw_Ctx = null or else Scheme = null then
         return;
      end if;
      for K in Dwm_Types.Col_Kind loop
         Color_Free (Drw_Ctx, Scheme (K)'Access);
      end loop;
      Free_Scheme (Scheme);
   end Scheme_Free;

   procedure Set_Fontset (Drw_Ctx : in Context_Access; Set : in Font_Access) is
   begin
      if Drw_Ctx /= null then
         Drw_Ctx.Fonts := Set;
      end if;
   end Set_Fontset;

   procedure Set_Scheme (Drw_Ctx : in Context_Access; Scheme : in Dwm_Types.Color_Scheme_Access) is
   begin
      if Drw_Ctx /= null then
         Drw_Ctx.Scheme := Scheme;
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

   procedure Text
     (Drw_Ctx : in Context_Access; Pos_X, Pos_Y : in Integer; Width, Height : in Natural; Left_Pad : in Natural;
      Txt : in String; Invert : in Integer; Result : out Integer)
   is
      Render : constant Boolean := Pos_X /= 0 or else Pos_Y /= 0 or else Width /= 0 or else Height /= 0;
      Cur_X  : Integer := Pos_X;
      Cur_W  : Natural := Width;
      Draw   : Xft_Thin.XftDraw := null;
      Usedfont, Curfont, Nextfont : Font_Access;
      Overflow : Boolean := False;
      Ignore   : Xlib_Thin.C_Int;
      Text_Pos : Positive := Txt'First;
      --  Carries a forced "the glyph exists" flag from one Outer_Loop pass
      --  into the next, mirroring drw_text()'s function-scope `charexists`
      --  quirk: after a fallback-font search (found or not), the codepoint
      --  must be consumed on the very next pass rather than re-checked for
      --  real, since a real check would find no font has the glyph and spin
      --  forever. Set True right before Usedfont is (re)assigned in the
      --  "no more already-loaded font matches" branch below; consumed (and
      --  cleared) by the first font check of the next Inner_Loop pass.
      Force_Match : Boolean := False;
   begin
      if Drw_Ctx = null or else (Render and then (Drw_Ctx.Scheme = null or else Width = 0))
        or else Txt'Length = 0 or else Drw_Ctx.Fonts = null
      then
         Result := 0;
         return;
      end if;

      if not Render then
         Cur_W := (if Invert /= 0 then Natural (Invert) else Natural'Last);
      else
         Ignore := Xlib_Thin.XSetForeground
           (Drw_Ctx.Disp, Drw_Ctx.Gc,
            (if Invert /= 0
             then Drw_Ctx.Scheme (Dwm_Types.Col_Fg).Pixel
             else Drw_Ctx.Scheme (Dwm_Types.Col_Bg).Pixel));
         Ignore := Xlib_Thin.XFillRectangle
           (Drw_Ctx.Disp, Drw_Ctx.Drawable, Drw_Ctx.Gc, Xlib_Thin.C_Int (Pos_X), Xlib_Thin.C_Int (Pos_Y),
            Xlib_Thin.C_UInt (Width), Xlib_Thin.C_UInt (Height));
         if Width < Left_Pad then
            Result := Pos_X + Width;
            return;
         end if;
         Draw := Xft_Thin.XftDrawCreate
           (Drw_Ctx.Disp, Drw_Ctx.Drawable, Xlib_Thin.XDefaultVisual (Drw_Ctx.Disp, Drw_Ctx.Screen),
            Xlib_Thin.XDefaultColormap (Drw_Ctx.Disp, Drw_Ctx.Screen));
         Cur_X := Pos_X + Left_Pad;
         Cur_W := Width - Left_Pad;
      end if;

      Usedfont := Drw_Ctx.Fonts;
      if Ellipsis_Width = 0 and then Render then
         Fontset_Get_Width (Drw_Ctx, "...", Ellipsis_Width);
      end if;
      if Invalid_Width = 0 and then Render then
         Fontset_Get_Width (Drw_Ctx, Invalid_Glyph, Invalid_Width);
      end if;

      Outer_Loop :
      loop
         declare
            Extent_W            : Natural := 0;
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
               Charexists := Force_Match;
               Force_Match := False;
               Curfont := Drw_Ctx.Fonts;
               while Curfont /= null loop
                  if not Charexists then
                     Charexists := Xft_Thin.XftCharExists
                       (Drw_Ctx.Disp, Curfont.Xfont, Xft_Thin.FcChar32 (Codepoint)) /= 0;
                  end if;
                  if Charexists then
                     declare
                        Char_W, Ignored_Height : Natural;
                     begin
                        Font_Get_Exts
                          (Curfont, Txt (Text_Pos .. Text_Pos + Char_Len - 1), Char_Len,
                           Char_W, Ignored_Height);
                        if Extent_W + Ellipsis_Width <= Cur_W then
                           Ellipsis_X := Cur_X + Extent_W;
                           Ellipsis_W := Cur_W - Extent_W;
                           Ellipsis_Len := Utf8_Strlen;
                        end if;
                        if Extent_W + Char_W > Cur_W then
                           Overflow := True;
                           if not Render then
                              Cur_X := Cur_X + Char_W;
                           else
                              Utf8_Strlen := Ellipsis_Len;
                           end if;
                        elsif Curfont = Usedfont then
                           Text_Pos := Text_Pos + Char_Len;
                           if not Err then
                              Utf8_Strlen := Utf8_Strlen + Char_Len;
                              Extent_W := Extent_W + Char_W;
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
                       Xlib_Thin.C_Int (Pos_Y)
                       + (Xlib_Thin.C_Int (Height) - Xlib_Thin.C_Int (Usedfont.Height)) / 2
                       + Usedfont.Xfont.Ascent;
                     Color : aliased constant Xft_Thin.XftColor :=
                       Drw_Ctx.Scheme (if Invert /= 0 then Dwm_Types.Col_Bg else Dwm_Types.Col_Fg);
                  begin
                     Xft_Thin.XftDrawStringUtf8
                       (Draw, Color'Access, Usedfont.Xfont, Xlib_Thin.C_Int (Cur_X), Ty,
                        Txt (Utf8_Str_Pos)'Address, Xlib_Thin.C_Int (Utf8_Strlen));
                  end;
               end if;
               Cur_X := Cur_X + Extent_W;
               Cur_W := Cur_W - Extent_W;
            end if;

            if Err and then (not Render or else Invalid_Width < Cur_W) then
               if Render then
                  declare
                     Ignore_Result : Integer;
                  begin
                     Text (Drw_Ctx, Cur_X, Pos_Y, Cur_W, Height, 0, Invalid_Glyph, Invert, Ignore_Result);
                  end;
               end if;
               Cur_X := Cur_X + Invalid_Width;
               Cur_W := Cur_W - Invalid_Width;
            end if;

            if Render and then Overflow then
               declare
                  Ignore_Result : Integer;
               begin
                  Text (Drw_Ctx, Ellipsis_X, Pos_Y, Ellipsis_W, Height, 0, "...", Invert, Ignore_Result);
               end;
            end if;

            exit Outer_Loop when Text_Pos > Txt'Last or else Overflow;

            if Nextfont /= null then
               Force_Match := False;
               Usedfont := Nextfont;
            else
               --  Regardless of whether or not a fallback font is found
               --  below, the character must be drawn on the next pass
               --  (drw_text()'s "charexists = 1;").
               Force_Match := True;
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
                        Match_Status : aliased Xft_Thin.FcResult;
                        Bool_Ignore : Xft_Thin.FcBool;
                     begin
                        Bool_Ignore := Xft_Thin.FcCharSetAddChar
                          (Fccharset, Xft_Thin.FcChar32 (Codepoint));
                        if Drw_Ctx.Fonts.Pattern = null then
                           Util.Die ("the first font in the cache must be loaded from a font string.");
                        end if;
                        Fcpattern := Xft_Thin.FcPatternDuplicate (Drw_Ctx.Fonts.Pattern);
                        Bool_Ignore := Xft_Thin.FcPatternAddCharSet
                          (Fcpattern, Xft_Thin.FC_CHARSET, Fccharset);
                        Bool_Ignore := Xft_Thin.FcPatternAddBool
                          (Fcpattern, Xft_Thin.FC_SCALABLE, Xft_Thin.FcTrue);
                        Bool_Ignore := Xft_Thin.FcConfigSubstitute
                          (null, Fcpattern, Xft_Thin.FcMatchPattern);
                        Xft_Thin.FcDefaultSubstitute (Fcpattern);
                        Match := Xft_Thin.XftFontMatch
                          (Drw_Ctx.Disp, Drw_Ctx.Screen, Fcpattern, Match_Status'Access);
                        Xft_Thin.FcCharSetDestroy (Fccharset);
                        Xft_Thin.FcPatternDestroy (Fcpattern);

                        if Match /= null then
                           Usedfont := Xfont_Create (Drw_Ctx, "", Match);
                           if Usedfont /= null
                             and then Xft_Thin.XftCharExists
                               (Drw_Ctx.Disp, Usedfont.Xfont, Xft_Thin.FcChar32 (Codepoint)) /= 0
                           then
                              Curfont := Drw_Ctx.Fonts;
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
                              Usedfont := Drw_Ctx.Fonts;
                           end if;
                        else
                           --  No fallback font matched at all (not even a
                           --  generic substitute): cache the miss just
                           --  like the "matched but the glyph still isn't
                           --  there" case above, so this codepoint isn't
                           --  re-attempted (an expensive FcFontMatch call)
                           --  on every redraw. Without this, a glyph
                           --  nothing on the system can render would spin
                           --  the outer loop forever, since neither
                           --  Text_Pos nor Usedfont would ever change.
                           if Nomatches (H0) /= 0 then
                              Nomatches (H1) := Codepoint;
                           else
                              Nomatches (H0) := Codepoint;
                           end if;
                           Usedfont := Drw_Ctx.Fonts;
                        end if;
                     end;
                  else
                     Usedfont := Drw_Ctx.Fonts;
                  end if;
               end;
            end if;
         end;
      end loop Outer_Loop;

      if Draw /= null then
         Xft_Thin.XftDrawDestroy (Draw);
      end if;

      Result := Cur_X + (if Render then Cur_W else 0);
   end Text;

   procedure Utf8_Decode
     (S : in String; Pos : in Positive; Codepoint : out Codepoint_Type;
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
      for Idx in 1 .. Len - 1 loop
         if Pos + Idx > S'Last then
            Length := Idx;
            return;
         end if;
         declare
            Bi : constant Natural := Character'Pos (S (Pos + Idx));
         begin
            if Bi = 0 or else (Bi / 64) /= 2 then  --  (Bi & 0xC0) /= 0x80
               Length := Idx;
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
     (Drw_Ctx : in Context_Access; Fontname : in String; Fontpattern : in Xft_Thin.FcPattern) return Font_Access
   is
      Xfont   : Xft_Thin.XftFont_Access := null;
      Pattern : Xft_Thin.FcPattern := null;
      Result  : Font_Access;
   begin
      if Fontname'Length > 0 then
         declare
            Name_Ptr : Interfaces.C.Strings.chars_ptr := New_String_Ptr (Fontname);
         begin
            Xfont := Xft_Thin.XftFontOpenName (Drw_Ctx.Disp, Drw_Ctx.Screen, Name_Ptr);
            if Xfont = null then
               Interfaces.C.Strings.Free (Name_Ptr);
               return null;
            end if;
            Pattern := Xft_Thin.FcNameParse (Name_Ptr);
            if Pattern = null then
               Xft_Thin.XftFontClose (Drw_Ctx.Disp, Xfont);
               Interfaces.C.Strings.Free (Name_Ptr);
               return null;
            end if;
            Interfaces.C.Strings.Free (Name_Ptr);
         end;
      elsif Fontpattern /= null then
         Xfont := Xft_Thin.XftFontOpenPattern (Drw_Ctx.Disp, Fontpattern);
         if Xfont = null then
            return null;
         end if;
      else
         Util.Die ("no font specified.");
      end if;

      Result := new Font;
      Result.Xfont := Xfont;
      Result.Pattern := Pattern;
      Result.Height := Natural (Xfont.Ascent + Xfont.Descent);
      Result.Disp := Drw_Ctx.Disp;
      return Result;
   end Xfont_Create;

   procedure Xfont_Free (Fnt : in out Font_Access) is
   begin
      if Fnt = null then
         return;
      end if;
      if Fnt.Pattern /= null then
         Xft_Thin.FcPatternDestroy (Fnt.Pattern);
      end if;
      Xft_Thin.XftFontClose (Fnt.Disp, Fnt.Xfont);
      Free_Font (Fnt);
   end Xfont_Free;

end Drw;
