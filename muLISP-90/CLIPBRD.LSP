;
; muLISP-90 object storage explorer
;
;
; muLISP-90 Microsoft Windows clipboard copy/paste
;

; -------------------------------------------------------------
; Print out information about where we can find the elements
; of P in memory.
; P can be a string or a number or an atom, but no list.
;
; Martin Hepperle, 2025
;
(DEFUN EXPLORE ( P )

 (IF(NUMBERP P) (SETQ P (PACK* P))) ; convert numbers to string
 
 (IF (ATOM P)
  (PROGN ; P must be an atom!

   (SETQ OFFS (LOCATION P)) ; the offset to the cells of P

   ; predefined segments for object storage
   (SETQ DEF-SEG (DSMEMORY 16 NIL T)) ; definition pointers
   (SETQ PNP-SEG (DSMEMORY 18 NIL T)) ; print name pointers (offsets into print names)
   (SETQ PNS-SEG (DSMEMORY 20 NIL T)) ; print names (count, characters)
   (SETQ VEC-SEG (DSMEMORY 22 NIL T)) ; vector data

   (TERPRI)
   (PRINC "BASSYM     = ")(PRINT 256)
   (PRINC "ENDSYM     = ")(PRINT (DSMEMORY 0 NIL T))
   (PRINC "ENDNUM     = ")(PRINT (DSMEMORY 2 NIL T))
   (PRINC "ENDATM     = ")(PRINT (DSMEMORY 4 NIL T))
   (PRINC "ENDCNS     = ")(PRINT (DSMEMORY 6 NIL T))
   (PRINC "MAXCNS     = ")(PRINT (DSMEMORY 8 NIL T))
   (PRINC "BASSTK     = ")(PRINT 1024)
   (PRINC "BASCOD     = ")(PRINT (DSMEMORY 34 NIL T))
   (PRINC "ENDCOD     = ")(PRINT (DSMEMORY 36 NIL T))
   (PRINC "MAXCOD     = ")(PRINT (DSMEMORY 38 NIL T))
   (PRINC "ENDSTR     = ")(PRINT (DSMEMORY 40 NIL T))
   (PRINC "MAXSTR     = ")(PRINT (DSMEMORY 42 NIL T))
   (PRINC "ENDVEC     = ")(PRINT (DSMEMORY 44 NIL T))
   (PRINC "MAXVEC     = ")(PRINT (DSMEMORY 46 NIL T))

   (PRINC "DEF-SEG    = ")(PRINT DEF-SEG)
   (PRINC "PNP-SEG    = ")(PRINT PNP-SEG)
   (PRINC "PNS-SEG    = ")(PRINT PNS-SEG)
   (PRINC "VEC-SEG    = ")(PRINT VEC-SEG)
   (PRINC "OFFSET (P) = ")(PRINT OFFS)

   (PRINC " DS     :[OFFSET] = ")(PRINT (DSMEMORY OFFS NIL T)) ; cells are located here
   (PRINC " DEF-SEG:[OFFSET] = ")(PRINT (MEMORY (+ (SHIFT DEF-SEG 4) OFFS) NIL T))

   ; get offset of print name from offset in print name pointers segment
   (SETQ PNS-OFFS (MEMORY (+ (SHIFT PNP-SEG 4) (+ OFFS 0)) NIL T))
   (PRINC " PNP-SEG:[OFFSET] = ")(PRINT PNS-OFFS)

   ; read first word of print name in print name strings segment
   (SETQ PNS-ADDR (+ (SHIFT PNS-SEG 4) PNS-OFFS))
   (SETQ SLEN (MEMORY PNS-ADDR))
   (PRINC " PNS-SEG:[")(PRIN1 PNS-OFFS)(PRINC "] = String[")(PRIN1 SLEN)(PRINC "] = '")
   (INCQ PNS-ADDR 2)
   (LOOP
    ((ZEROP SLEN))
    (PRINC (ASCII(MEMORY PNS-ADDR))) 
    (INCQ PNS-ADDR)
    (DECQ SLEN)
   )
   (PRINC "'");(TERPRI)
)))
; -------------------------------------------------------------


; -------------------------------------------------------------
; CLIPBOARD-COPY ( P )
; Copy P as a text string to the windows clipboard in CF_TEXT format.
; P can be a string or a number or another atom, but no list.
; Uses Microsoft Windows Old Application Support.
; Works for example in DOS-Box under Windows.
;
; Martin Hepperle, 2025
;
(DEFUN CLIPBOARD-COPY ( P
                        PNP-SEG PNS-SEG PNS-OFFS PNS-ADDR SLEN )

 (IF(NUMBERP P) (SETQ P (PACK* P))) ; convert numbers to string

 (IF (ATOM P)(PROGN ; P must be an atom!
  ; try to identify WinOldApp Version
  (REGISTER 0 5888)   ; 0x1700 = 5888
  (INTERRUPT 47)      ; 0x2F = 47
  (IF (NEQ (REGISTER 0) 5888) ; AX modified?
   (PROGN ; yes -> WinOldApp is available
    (PRINC "WinOldApp Version: ")(PRIN1 (LOGAND (SHIFT (REGISTER 0) -8) 255))(PRINC '.)(PRINT (LOGAND (REGISTER 0) 255)) ; 
    ; try to open clipboard
    (REGISTER 0 5889)   ; 0x1701 = 5889
    (INTERRUPT 47)      ; 0x2F = 47
    (PRINC "Open Clipboard: ")(PRINT (REGISTER 0))
    (IF (EQ (REGISTER 0) 1) ; success?
     (PROGN ; clipboard opened -> empty clipboard
      (REGISTER 0 5890)   ; 0x1702 = 5890
      (INTERRUPT 47)      ; 0x2F = 47
      (PRINC "Empty Clipboard: ")(PRINT (REGISTER 0)) 
      (IF (EQ (REGISTER 0) 1) ; success?
       (PROGN ; clipboard emptied -> set text of P to clipboard
        (SETQ PNP-SEG (DSMEMORY 18 NIL T)) ; print name pointers (offsets into print names)
        (SETQ PNS-SEG (DSMEMORY 20 NIL T)) ; print names
        (SETQ PNS-OFFS (MEMORY (+ (SHIFT PNP-SEG 4) (LOCATION P)) NIL T))
        (SETQ PNS-ADDR (+ (SHIFT PNS-SEG 4) PNS-OFFS))
        (SETQ SLEN (MEMORY PNS-ADDR))
        (INCQ SLEN) ; add 1 for (non-present) null-byte
        (REGISTER 0 5891)              ; AX = 0x1703 = 5891
        (REGISTER 3 1)                 ; DX = 1 = CF_TEXT format
        (REGISTER 8 PNS-SEG)           ; ES = segment of string
        (REGISTER 1 (+ 2 PNS-OFFS))    ; BX = offset of string
        (REGISTER 4 (SHIFT SLEN -8))   ; SI = HI(length)
        (REGISTER 2 (LOGAND SLEN 255)) ; CX = LO(length)
        (INTERRUPT 47)                 ; 0x2F = 47
        (PRINC "Set Clipboard: ")(PRINT (REGISTER 0))
      )(PRINC "could not empty clipboard"))
      ; close clipboard
      (REGISTER 0 5896)   ; 0x1708 = 5896
      (INTERRUPT 47)    ; 0x2F = 47
      (PRINC "Close Clipboard: ")(PRINT (REGISTER 0)) 
    )(PRINC "could not open clipboard"))
  )(PRINC "WinOldApp not available"))
 )(PRINC "P is not an ATOM."))
 P ; return copied text
)
; -------------------------------------------------------------

; CLIPBOARD-PASTE
; Paste text from the Windows clipboard.
; Return the string or NIL if the clipbard did not contain
; text in CF_TEXT format.
; Uses Microsoft Windows Old Application Support.
; Works for example in DOS-Box under Windows.
;
; Martin Hepperle, 2025
;
(DEFUN CLIPBOARD-PASTE (
                      P I SLEN PNP-SEG PNS-SEG PNS-OFFS PNS-ADDR )
 
 (SETQ P NIL) ; default return value

  ; try to identify WinOldApp Version
  (REGISTER 0 5888)   ; 0x1700 = 5888
  (INTERRUPT 47)      ; 0x2F = 47
  (IF (NEQ (REGISTER 0) 5888) ; AX modified?
   (PROGN ; yes -> WinOldApp is available
    (PRINC "WinOldApp Version: ")(PRIN1 (LOGAND (SHIFT (REGISTER 0) -8) 255))(PRINC '.)(PRINT (LOGAND (REGISTER 0) 255)) ; 
    ; try to open clipboard
    (REGISTER 0 5889)   ; 0x1701 = 5889
    (INTERRUPT 47)      ; 0x2F = 47
    (PRINC "Open Clipboard: ")(PRINT (REGISTER 0))
    (IF (EQ (REGISTER 0) 1) ; success?
     (PROGN ; clipboard opened -> get clipboard data size
      (REGISTER 0 5892)              ; AX = 0x1704 = 5892
      (REGISTER 3 1)                 ; DX = 1 = CF_TEXT format
      (INTERRUPT 47)                 ; 0x2F = 47
      (SETQ SLEN (LOGIOR (SHIFT (REGISTER 3) 16)(REGISTER 0)))
      (PRINC "Get Clipboard Size: ")(PRINT (REGISTER 0))
      (IF (< 0 SLEN)
       (PROGN
        ; build a string buffer of SLEN+1 characters
        (SETQ P (PACK(MAKE-LIST SLEN "x")))
        (SETQ PNP-SEG (DSMEMORY 18 NIL T)) ; print name pointers (offsets into print names)
        (SETQ PNS-SEG (DSMEMORY 20 NIL T)) ; print names
        (SETQ PNS-OFFS (MEMORY (+ (SHIFT PNP-SEG 4) (LOCATION P)) NIL T))
        (SETQ PNS-ADDR (+ (SHIFT PNS-SEG 4) PNS-OFFS))
        (REGISTER 0 5893)              ; AX = 0x1705 = 5893
        (REGISTER 3 1)                 ; DX = 1 = CF_TEXT format
        (REGISTER 8 PNS-SEG)           ; ES = segment of string
        (REGISTER 1 (+ 2 PNS-OFFS))    ; BX = offset of string
        (REGISTER 4 (SHIFT SLEN -8))   ; SI = HI(length)
        (REGISTER 2 (LOGAND SLEN 255)) ; CX = LO(length)
        (INTERRUPT 47)                 ; 0x2F = 47
        ; trim trailing null byte
        (SETQ P (SUBSTRING P 0 (- (LENGTH P) 2)))
      ))
      ; close clipboard
      (REGISTER 0 5896)   ; 0x1708 = 5896
      (INTERRUPT 47)    ; 0x2F = 47
      (PRINC "Close Clipboard: ")(PRINT (REGISTER 0)) 
    )(PRINC "could not open clipboard"))
  )(PRINC "WinOldApp not available"))
 ; return NIL or string
 P
)
; -------------------------------------------------------------
