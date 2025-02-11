; ============================================================
;
; HEX-EDIT
;
; A simple hex editor written in muLISP-90.
;
; Reads and writes records of 256 bytes.
; Displays records in classical hexadecimal/ASCII view.
; Allows editing bytes in hexadecimal or ASCII view (ASCII codes above 31).
; A modified record is saved when the next record is read or when the 
; program is terminated.
; A backup file is created before each update, thus only the previous edit-state 
; is backed up.
; 
; Keys:
; F2 toggle edit mode on/off
; F3 insert bytes at cursor position - prompts for number of bytes, inserts '\0' bytes.
; F4 delete bytes at cursor position - prompts for number of bytes.
; TAB toggle cursor between hexadecimal and ASCII view.
; Cursor motion: <=, =>, ^, v (cursor left, right, up, down).
; Record motion: Page-Up and Page-Down load the previous resp. the next record.
;
; In Edit mode:
; Accepted characters in hexadecimal view: 0-7,A-F,a-f.
;      2 characters must be entered to complete one byte.
; Accepted in ASCII view: character codes 32...255.
;      1 character is one byte.
; 
; Uses about 5 kBytes of dynamic muLISP RAM.
;
; Martin Hepperle, 2024
;
; Example screen:
; ============================================================================
; File: 'xx.txt'                Length: 394 Bytes
; 
; --Addr--  00-01-02-03-04-05-06-07-08-09-0A-0B-0C-0D-0E-0F   0123456789ABCDEF
; --------  -----------------------------------------------   ----------------
; 00000000: 3C 2D 3C 2D 2D 2D 2D 20 53 54 41 52 54 20 2D 2D : <-<---- START --
; 00000010: 2D 2D 2D 2D 2D 2D 2D 2D 3E 0D 0A 31 20 48 65 72 : -------->..1 Her
; 00000020: 65 20 77 65 20 67 6F 20 61 6E 64 20 67 6F 20 61 : e we go and go a
; 00000030: 6E 64 20 67 6F 20 75 6E 74 69 6C 20 74 68 65 20 : nd go until the
; 00000040: 65 6E 64 2E 0D 0A 32 20 54 77 6F 20 48 65 72 65 : end...2 Two Here
; 00000050: 20 77 65 20 67 6F 20 61 6E 64 20 67 6F 20 61 6E :  we go and go an
; 00000060: 64 20 67 6F 20 75 6E 74 69 6C 20 74 68 65 20 65 : d go until the e
; 00000070: 6E 64 2E 0D 0A 33 20 48 65 72 65 20 77 65 20 67 : nd...3 Here we g
; 00000080: 6F 20 61 6E 64 20 67 6F 20 61 6E 64 20 67 6F 20 : o and go and go
; 00000090: 75 6E 74 69 6C 20 74 68 65 20 65 6E 64 2E 0D 0A : until the end...
; 000000A0: 34 20 48 65 72 65 20 77 65 20 67 6F 20 61 6E 64 : 4 Here we go and
; 000000B0: 20 67 6F 20 61 6E 64 20 67 6F 20 75 6E 74 69 6C :  go and go until
; 000000C0: 20 74 68 65 20 65 6E 64 2E 0D 0A 35 20 48 65 72 :  the end...5 Her
; 000000D0: 65 20 77 65 20 67 6F 20 61 6E 64 20 67 6F 20 61 : e we go and go a
; 000000E0: 6E 64 20 67 6F 20 75 6E 74 69 6C 20 74 68 65 20 : nd go until the
; 000000F0: 65 6E 64 2E 0D 0A 36 20 48 65 72 65 20 77 65 20 : end...6 Here we
; --------  -----------------------------------------------   ----------------
; 
; 
; PgUp/PgDn  TAB Toggle   F2 Toggle  F3 Insert  F4 Delete     Esc
; Prev/Next  HEX/ASCII    Edit-Mode     Bytes      Bytes      Exit
; ============================================================================
;
; ============================================================
; UTILITY function
; Convert a 4-bit nibble to its ASCII hexadecimal character code.
(DEFUN HEX-NIB ( N )
 (ASCII (+ N (IF (> N 9) 55 48)))  ; 0=>48('0') 10=>65('A')
)
; ============================================================
; UTILITY function
; Convert an 8-bit byte to a string of two ASCII hexadecimal characters.
(DEFUN HEX-BYTE ( N )
 (PACK* (HEX-NIB (LOGAND (SHIFT N -4) 15))     ; high nibble
        (HEX-NIB (LOGAND N 15)))               ; low nibble
)
; ============================================================
; UTILITY function
; convert a 16-bit word to a string of four ASCII hexadecimal characters.
(DEFUN HEX-WORD ( N )
 (PACK* (HEX-BYTE (LOGAND (SHIFT N -8) 255))    ; high byte
        (HEX-BYTE (LOGAND N 255)))              ; low byte
)
; ============================================================
; UTILITY function
; Convert a 32-bit word to a string of eight ASCII hexadecimal characters.
(DEFUN HEX-DWORD ( N )
 (PACK* (HEX-WORD (LOGAND (SHIFT N -16) 65535)) ; high word
        (HEX-WORD (LOGAND N 65535)))            ; low word
)
; ============================================================
; UTILITY function
; Concatenate a list of strings into a single string
; recursive.
(DEFUN STRLCAT (SLIST)
 (COND ( (NULL SLIST) NIL )
       ( T            (CONS (CAR SLIST) (STRLCAT (CDR SLIST)))))
 (PACK SLIST) 
)
; ============================================================
; UTILITY function
; Concatenate two strings into a single string.
(DEFUN STR2CAT (S1 S2)
 (PACK* S1 S2)
)
; ============================================================
; UTILITY function
; Wait for key press and return key/ASCII code.
;
; Examples:
; Backspace      8
; Tab            9
; Return        13
; ESC           27
; extended 2-code keys add 255
; function F1  314 (255 + 59)
; function F10 323 (255 + 68)
; function F11 388 (255 + 33)
; function F12 389 (255 + 34)
; cursor   ^   327 (255 + 72)
; cursor   <   330 (255 + 75)
; cursor   >   332 (255 + 77)
; cursor   v   335 (255 + 80)
(DEFUN GET-KEY(
 RET ) ; local
 (SETQ RET (READ-BYTE))
 (IF (= RET 255)
  (SETQ RET (+ RET (READ-BYTE))))
 RET
)
; ============================================================
; UTILITY function
; 1) Rename file with FILENAME to a backup file with extension .BAK.
; 2) Rename file TEMP-FILENAME to FILENAME.
(DEFUN SHIFT-TO-BACKUP(FILENAME TEMP-FILENAME
                       BACKUP-FILENAME)
 (SETQ BACKUP-FILENAME (MAKE-BACKUP-NAME FILENAME))
 (CATCH "NOFILE"                           ; avoid error if no backup exists
  (DELETE-FILE BACKUP-FILENAME)           ; delete previous backup file, if any
 )
 (RENAME-FILE FILENAME BACKUP-FILENAME)  ; rename old file to backup file
 (RENAME-FILE TEMP-FILENAME FILENAME)     ; replace old file with temporary file
)
; ============================================================
; HEX-EDIT
; Read and return a 256 byte block from FILENAME, starting at position FILOFF.
(DEFUN READ-BLOCK( FILENAME FILOFF FLEN
                   REC READ-LENGTH)

 ; open file, seek to FILOFF and read record
 ((IF (EQ NIL (OPEN-INPUT-FILE FILENAME)) (PROG1(PRINC "Cannot open input file")(TERPRI))))
 (FILE-READ-POSITION FILOFF)
 (SETQ READ-LENGTH (MIN 256 (- FLEN FILOFF)))

;  (CSMEMORY 846 255) ; muLISP-90, change character input mask
;  (SETQ REC (READ-RECORD READ-LENGTH)) ; masks bit 7 off
;  (CSMEMORY 846 127) ; muLISP-90, reset character input mask

 ; this replacement works, but is slower
 ; one could possibly also modify the character mask byte 
 ; at 0x277=631d (muLISP-83) in the muLISP base page from 0x7F to 0xFF
 ; at 0x34E=846d (muLISP-90) in the muLISP base page from 0x7F to 0xFF
 (SETQ REC "")
 (LOOP ((ZEROP READ-LENGTH))
       (SETQ REC (PACK* REC (ASCII(READ-BYTE))))
       (DECQ READ-LENGTH) )

 ; done
 (CLOSE-INPUT-FILE FILENAME)
 REC
)
; ============================================================
; HEX-EDIT
; Dump the 256 byte record REC into the HEX/ASCII view areas.
; Return nothing.
(DEFUN DUMP-BLOCK( REC FILOFF
                   ROW LINE ASCI NUM BYTE LEN)

 (SETQ REC (UNPACK REC))

  ; over the complete block
 (SETQ ROW 0)
 (LOOP
  ((ZEROP REC) NIL)   ; break at end of REC
  ((ZEROP (LENGTH REC)))

  ; build one line of 16 hex bytes and ASCII characters
  (SETQ LINE (STR2CAT (HEX-DWORD FILOFF) ": "))
  (SETQ ASCI ": ") ; preset with separator
  ; read up to 16 bytes per line
  (SETQ NUM 16)
  (LOOP
   ((ZEROP (LENGTH REC)))
   ((ZEROP NUM))        ; break when NUM == 0
   (SETQ BYTE (ASCII(CAR REC)))
   (SETQ REC (CDR REC))
   (SETQ LINE (STRLCAT (LIST LINE (HEX-BYTE BYTE) " ")))
   (SETQ ASCI (STR2CAT ASCI (IF (OR (< BYTE 32) 
                                    (> BYTE 128)) "." (ASCII BYTE))))
   (DECQ NUM)
  )
  ; pad to 16 bytes per line
  (SETQ LEN (- (LENGTH ASCI) 2))
  (LOOP
  ((= LEN 16)) ; break if 16 bytes per line
   (SETQ LINE (STR2CAT LINE "   ")) ; pad hex bytes
   (SETQ ASCI (STR2CAT ASCI " "))   ; pad ASCII characters
   (INCQ LEN)
  )
  (PRINC(PACK* LINE ASCI))
  (TERPRI)
  ; prepare for next line
  (SETQ FILOFF (+ FILOFF 16))
  (INCQ ROW)
 )

 (LOOP
 ((= ROW 16)) ; break if 16 bytes per line
  (SPACES 80)
  (INCQ ROW)
 )
)
; ============================================================
; HEX-EDIT
; Move the HEX view cursor to DIGIT [0,1] of the 2-digit hex 
; number at CARET-OFF.
; Return nothing.
(DEFUN SET-HEX-CURSOR(CARET-OFF DIGIT
                      XY)
  (SETQ XY (DIVIDE CARET-OFF 16))  ; e.g. CARET-OFF 35 -> (2 . 3) row 2, column 3
  (SET-CURSOR (+  4 (CAR XY))
              (+ 10 (* (CDR XY) 3) DIGIT))
)
; ============================================================
; HEX-EDIT
; Move the ASCII view cursor to the character at CARET-OFF.
; Return nothing.
(DEFUN SET-ASCII-CURSOR(CARET-OFF
                        XY)
  (SETQ XY (DIVIDE CARET-OFF 16))  ; e.g. CARET-OFF 35 -> (2 . 3) row 2, column 3
  (SET-CURSOR (+  4 (CAR XY))
              (+ 60 (CDR XY)))
)
; ============================================================
; HEX-EDIT
; Insert the character with ASCII CODE at the CARET-OFF in the ASCII view.
; Return nothing.
(DEFUN OUTPUT-ASCII-VIEW(CARET-OFF CODE
                         XY X Y )
 (SETQ XY (DIVIDE CARET-OFF 16))  ; e.g. CARET-OFF 35 -> (2 . 3) row 2, column 3
 (SETQ X (COLUMN)) ; save current column (may be in HEX view)
 (SETQ Y (ROW))
 (SET-CURSOR Y (+ 60 (CDR XY)))
 (PRINC (IF (OR (< CODE 32) 
                (> CODE 128)) "." (ASCII CODE)))
 (SET-CURSOR Y X) ; back
)
; ============================================================
; HEX-EDIT
; Update the record REC at FILOFF in FILENAME, move the pointer 
; to the end of file at FLEN to avoid truncation.
(DEFUN UPDATE-FILE(FILENAME FLEN FILOFF REC)
 ; save REC at FILOFF in file
 (OPEN-OUTPUT-FILE FILENAME T)
 (FILE-WRITE-POSITION FILOFF)
 (WRITE-STRING REC)
 (FILE-WRITE-POSITION FLEN) ; to end of file
 (CLOSE-OUTPUT-FILE FILENAME) ; done
)
; ============================================================
; HEX-EDIT
; Create a file name with ".BAK" extension
; Return nothing.
(DEFUN MAKE-BACKUP-NAME(FILENAME
                DOT)
 (SETQ DOT (FINDSTRING "." FILENAME))
 (IF (ZEROP DOT)
  (PACK* FILENAME ".BAK") ; append
  (PACK* (SUBSTRING FILENAME 0 DOT) "BAK") ; replace
 )
)
; ============================================================
; HEX-EDIT
; Insert NBYTES new '\0' bytes into the file FILENAME at FILOFF.
; Return the new length of the file.
(DEFUN INSERT-BYTES(FILENAME FLEN FILOFF NBYTES
                    N BACKUP-FILENAME)
 ((ZEROP NBYTES) FLEN) ; nothing to do: return
 
 (OPEN-INPUT-FILE FILENAME)
 (OPEN-OUTPUT-FILE "$$$.$$$" T) ; overwrite temporary file, if any
 ; copy leading part
 (SETQ N FILOFF)
 ( LOOP  ((ZEROP N))  (WRITE-BYTE (READ-BYTE))  (DECQ N) )
 ; insert new NULL bytes
 (SETQ N NBYTES)
 ( LOOP  ((ZEROP N))  (WRITE-BYTE 0)  (DECQ N) )
 ; copy trailing part
 (SETQ N (- FLEN FILOFF))
 ( LOOP  ((ZEROP N))  (WRITE-BYTE (READ-BYTE))  (DECQ N) )
 
 (CLOSE-INPUT-FILE FILENAME) ; done current file length
 (CLOSE-OUTPUT-FILE "$$$.$$$") ; done
 
 (SHIFT-TO-BACKUP FILENAME "$$$.$$$")
 
 (+ FLEN NBYTES) ; return new file length
)
; ============================================================
; HEX-EDIT
; Delete NBYTES new bytes from the file FILENAME at FILOFF.
; Return the new length of the file.
(DEFUN DELETE-BYTES(FILENAME FLEN FILOFF NBYTES
                    N NEW-FLEN BAKNAME)
 ((ZEROP NBYTES) FLEN) ;  nothing to do: return current file length
 (OPEN-INPUT-FILE FILENAME)
 (OPEN-OUTPUT-FILE "$$$.$$$" T) ; overwrite temporary file, if any
 ; copy leading part
 (SETQ N (MIN FILOFF FLEN))
 (SETQ NEW-FLEN N)
 ( LOOP  ((ZEROP N))  (WRITE-BYTE (READ-BYTE))  (DECQ N) )
 ; skip bytes to delete
 (SETQ N (MIN NBYTES (- FLEN FILOFF)))
 ( LOOP  ((ZEROP N))  (READ-BYTE)  (DECQ N) )
 ; copy trailing part, if any
 (SETQ N (MAX 0 (- FLEN FILOFF NBYTES)))
 (INCQ NEW-FLEN N)
 ( LOOP  ((ZEROP N))  (WRITE-BYTE (READ-BYTE))  (DECQ N) )
 
 (CLOSE-INPUT-FILE FILENAME) ; done
 (CLOSE-OUTPUT-FILE "$$$.$$$") ; done
 
 (SHIFT-TO-BACKUP FILENAME "$$$.$$$")
  
 NEW-FLEN ; return the length of the modified file
)
; ============================================================
; HEX-EDIT
; Replace a single byte NUMBER in record REC at CARET-OFF.
; Return the modified record REC.
(DEFUN REPLACE-BYTE(CARET-OFF NUMBER REC)
 ; enter NUMBER into REC... at CARET-OFF, 
 (IF (ZEROP CARET-OFF) ; A) replace first byte in REC
    (SETQ REC(PACK(LIST (ASCII NUMBER) (SUBSTRING REC 1 255))))
    (IF (EQ CARET-OFF (LENGTH REC)) ; B) replace last byte in REC
        (SETQ REC(PACK(LIST (SUBSTRING REC 0 (-(LENGTH REC)2)) (ASCII NUMBER))))
        ; C) replace intermediate byte in REC
        (SETQ REC(PACK(LIST (SUBSTRING REC 0 (- CARET-OFF 1)) (ASCII NUMBER) (SUBSTRING REC (+ CARET-OFF 1) 255))))
    ) )
 REC
)
; ============================================================
; Redraw the header bar after FILENAME or FLEN has ben changed
; Return nothing.
(DEFUN DRAW-HEADER-BAR()
 (SET-CURSOR 0 0)(PRINC (STRLCAT (LIST "File: '" FILENAME "'")))
 (SET-CURSOR 0 30)(PRINC "Length: ")(PRIN1 FLEN)(PRINC " Bytes")
)
; ============================================================
; Redraw the footer bar with key after the right area has ben changed
; Return nothing.
(DEFUN DRAW-FOOTER-BAR()
 (SET-CURSOR (- (ROWS) 5) 0)
 (PRINC "--------  -----------------------------------------------   ----------------")
 (SET-CURSOR (- (ROWS) 4) (- (COLUMNS) 20))(SPACES 20)
 (SET-CURSOR (- (ROWS) 3) (- (COLUMNS) 20))(SPACES 20)
 (PRINC "PgUp/PgDn  TAB Toggle   F2 Toggle  F3 Insert  F4 Delete     Esc "); +20 spaces
 (PRINC "Prev/Next  HEX/ASCII    Edit-Mode     Bytes      Bytes      Exit"); +20 spaces
)
; ============================================================
; Save the current record if it has been modified.
; Return NIL (== not DIRTY).
(DEFUN UPDATE-REC(FILENAME FLEN FILOFF REC)
 (SET-CURSOR (- (ROWS) 4) (- (COLUMNS) 20))
 (PRINC "*SAVED*")
 (UPDATE-FILE FILENAME FLEN FILOFF REC)
 (SET-CURSOR (- (ROWS) 4) (- (COLUMNS) 20))
 (SPACES 7)
 NIL
)
; ============================================================
; HEX-EDIT main program
; Requires (READ-BLOCK
;           (DUMP-BLOCK 
;            (STR2CAT STRLCAT HEX-NIB HEX-BYTE HEX-DWORD GET-KEX))
;           SET-HEX-CURSOR SET-ASCII-CURSOR OUTPUT-ASCII-VIEW
;           MAKE-BACKUP-NAME INSERT-BYTES DELETE-BYTES REPLACE-BYTE 
;           DRAW-HEADER-BAR DRAW-FOOTER-BAR UPDATE-REC)
(DEFUN HEX-EDIT(FILENAME
                KEY D FLEN MINOFF MAXOFF FILOFF NEW-FILOFF
                CARET-OFF MAX-CARET-OFF BYTE-COUNT FILE-POS
                RELOAD DIRTY EDIT-MODE EDIT NUMBER DIGITS N)

 ; test whether file exists and determine its length
 ((IF (EQ NIL (OPEN-INPUT-FILE FILENAME)) (PROG1(PRINC "Cannot open input file")(TERPRI))))
 (SETQ FLEN (FILE-LENGTH *INPUT-FILE*))
 (SETQ MAXOFF (- FLEN (MOD FLEN 256)))
 (SETQ MINOFF 0)
 (CLOSE-INPUT-FILE FILENAME)
 
 ; initial offset into file
 (SETQ FILOFF 0)
 (SETQ NEW-FILOFF FILOFF)
 (CLEAR-SCREEN)
 (DRAW-HEADER-BAR)
 
 (SET-CURSOR 2 0)(PRINC "--Addr--  00-01-02-03-04-05-06-07-08-09-0A-0B-0C-0D-0E-0F   0123456789ABCDEF")
 (SET-CURSOR 3 0)(PRINC "--------  -----------------------------------------------   ----------------")
 
 (DRAW-FOOTER-BAR)

 (CURSOR-LINES 6 8)
 (SETQ CARET-OFF 0)   ; offset in current record
 (SETQ EDIT NIL)      ; editing initially disabled
 (SETQ EDIT-MODE 'A)  ; HEX editing initially selected
 (SETQ RELOAD T)
 (SETQ DIRTY NIL)
 (SETQ NUMBER 0)      ; accumulator for two digit number
 (SETQ DIGITS 0)      ; digit counter two digit number

  ; swallow carriage return when starting program from command line
;  (READ-BYTE)
 
 (LOOP
 
  (IF RELOAD 
   (PROG1
    ; load new record and display it (256 or less bytes)
    (SETQ REC (READ-BLOCK FILENAME FILOFF FLEN))
    (SET-CURSOR 4 0)
    (DUMP-BLOCK REC FILOFF)
    (SETQ RELOAD NIL)
    (SETQ MAX-CARET-OFF (- (LENGTH REC) 1)) ; maximum offset in current record
    ; clip caret position
    (SETQ CARET-OFF (MIN CARET-OFF MAX-CARET-OFF))
   )
  )

  ; HEX view cursor position offset relative to screen (0,0) 9 upper left
  ; prepare for input of HEX digits
  (IF (EQ EDIT-MODE 'H) (SET-HEX-CURSOR CARET-OFF DIGITS)
                        (SET-ASCII-CURSOR CARET-OFF))
  
  (SETQ KEY (GET-KEY))

  (IF (AND EDIT (EQ EDIT-MODE 'H))
   ; HEX edit mode
   (PROG1
    ; valid hex nibble in decimal, if any
    (SETQ D -1)

    ; '0'=48 ... '9'=57    'A'=65 ... 'F'=70
    (IF (< 96 KEY 103)                    ; a-f to A-F
        (DECQ KEY 32) )
  
    (IF (< 47 KEY 58) (SETQ D (- KEY 48)) ; digits to decimal
                      (IF (< 64 KEY 71)   ; A-F    to decimal
                          (SETQ D (- KEY 55))
                      ) )

    (IF (NEQ -1 D) ; a valid hex digit was entered
        (PROG1 (SETQ NUMBER (+ (* NUMBER 16) D)) 
               (PRINC (ASCII KEY))
               (INCQ DIGITS)
               (IF (EQ DIGITS 2)
                   (PROG1 
                      ; update ASCII block
                      (OUTPUT-ASCII-VIEW CARET-OFF NUMBER)

                      ; enter NUMBER into REC... at CARET-OFF, 
                      (SETQ REC (REPLACE-BYTE CARET-OFF KEY REC))

                      ; get ready for editing next byte
                      (SETQ DIGITS 0)
                      (SETQ NUMBER 0)
                      (SETQ DIRTY T)
                      (SETQ KEY 332) ; inject cursor right to move to next byte
                   ) ) )
    )
   ) ; PROG1
   ; else: ASCII edit mode
   (IF (AND EDIT (< 31 KEY 256)) ; edit mode and printable
    (PROG1 (OUTPUT-ASCII-VIEW CARET-OFF KEY)
           ; update HEX block
           (SET-HEX-CURSOR CARET-OFF 0)
           (PRINC (HEX-BYTE KEY))
           ; enter KEY into REC... at CARET-OFF, 
           (SETQ REC (REPLACE-BYTE CARET-OFF KEY REC))
           (SETQ DIRTY T)
           (SETQ KEY 332) ; inject cursor right to move to next byte
    ) )
  ) ; end of (IF EDIT


  ; ESC = exit  
  ((EQ KEY 27)(PROG1 ; before exiting on: update file, if necessary
                     (IF DIRTY (SETQ DIRTY (UPDATE-REC FILENAME FLEN FILOFF REC)))
                     (SET-CURSOR (- (ROWS) 4) (- (COLUMNS) 20))(PRINC "Exit.")
                     (SET-CURSOR (- (ROWS) 3) (- (COLUMNS) 20))
                     (CURSOR-LINES 6 8)
                     (SETQ REC NIL)
                     (RECLAIM)))  ; try to clean up

  ; CTRL+C = exit
  ((EQ KEY 3))

  ; TAB = toggle HEX/ASCII mode
  (IF (EQ KEY 9)
   (IF (EQ EDIT-MODE 'A) (SETQ EDIT-MODE 'H)   ; HEX editing mode
                         (SETQ EDIT-MODE 'A))  ; ASCII editing mode
  )
  
  ; F2 = EDIT togle
  (IF (EQ KEY 315)
    ( PROG1 (SETQ EDIT (NOT EDIT))
            (SET-CURSOR (- (ROWS) 2) (- (COLUMNS) 15))
            (PRINC (IF EDIT "*EDIT*" 
                            "      "))
            (IF EDIT (CURSOR-LINES 0 8) (CURSOR-LINES 6 8))
    ) ) 
 
  ; F3 = insert bytes at cursor position
  (IF (EQ KEY 316)
    ( PROG1 ; save current page before inserting on
            (IF DIRTY (SETQ DIRTY (UPDATE-REC FILENAME FLEN FILOFF REC)))
            (SET-CURSOR (- (ROWS) 4) (- (COLUMNS) 20))(PRINC "Insert Null-Bytes")
            (SET-CURSOR (- (ROWS) 3) (- (COLUMNS) 20))(PRINC "# of BYTES?")
            (SETQ BYTE-COUNT (READ-ATOM))
            (SETQ FILE-POS (+ CARET-OFF FILOFF))
            (SETQ FLEN (INSERT-BYTES FILENAME FLEN FILE-POS BYTE-COUNT))
            (SETQ MAXOFF (- FLEN (MOD FLEN 256)))
            (SETQ RELOAD T) ; must reload this page
            (DRAW-HEADER-BAR) ; FLEN has changed
            (DRAW-FOOTER-BAR)
    ) ) 

  ; F4 = delete bytes at cursor position
  (IF (EQ KEY 317)
    ( PROG1 ; save current page before deleting on
            (SETQ DIRTY (UPDATE-REC FILENAME FLEN FILOFF REC))
            (SET-CURSOR (- (ROWS) 4) (- (COLUMNS) 20))(PRINC "Delete Bytes")
            (SET-CURSOR (- (ROWS) 3) (- (COLUMNS) 20))(PRINC "# of BYTES?")
            (SETQ BYTE-COUNT (READ-ATOM))
            (SETQ FILE-POS (+ CARET-OFF FILOFF))
            (SETQ FLEN (DELETE-BYTES FILENAME FLEN FILE-POS BYTE-COUNT))
            (SETQ MAXOFF (- FLEN (MOD FLEN 256)))
            (SETQ RELOAD T) ; must reload this page
            (DRAW-HEADER-BAR) ; FLEN has changed
            (DRAW-FOOTER-BAR)
    ) ) 

  ; move to a new record?
  (IF (EQ KEY 336) ; PgDn - page forward
    ( PROG1 (SETQ NEW-FILOFF (MIN MAXOFF (+ FILOFF 256))) ) )
  (IF (EQ KEY 328) ; PgUp - page backward
    ( PROG1 (SETQ NEW-FILOFF (MAX MINOFF (- FILOFF 256))) ) )
  (IF (EQ KEY 326) ; Pos1 - Home
    ( PROG1 (SETQ NEW-FILOFF MINOFF)                      ) )
  (IF (EQ KEY 334) ; End
    ( PROG1 (SETQ NEW-FILOFF MAXOFF)                      ) )

  (IF (NEQ NEW-FILOFF FILOFF)
      ; page has been changed
    ( PROG1
         ; save current page before moving on
         (IF DIRTY (SETQ DIRTY (UPDATE-REC FILENAME FLEN FILOFF REC)))
         ; new page
         (SETQ FILOFF NEW-FILOFF)
         (SETQ RELOAD T) ; must load this new page
  ))

  ; cursor motion within current page?
  (IF (EQ KEY 330) ; cursor left
    ( IF (> CARET-OFF 0)                    (DECQ CARET-OFF) ) )
  (IF (EQ KEY 332) ; cursor right
    ( IF (< CARET-OFF MAX-CARET-OFF)        (INCQ CARET-OFF) ) )
  (IF (EQ KEY 335) ; cursor down
    ( IF (< CARET-OFF (- MAX-CARET-OFF 15)) (INCQ CARET-OFF 16)) )
  (IF (EQ KEY 327) ; cursor up
    ( IF (> CARET-OFF 15)                   (DECQ CARET-OFF 16)) )
 )
 FILENAME ; muLISP driver prints out file name when exiting
 ;(SYSTEM) ; standalone: back to MS-DOS
)
; ============================================================
; load muLISP with compiler and compile HEX-EDIT.LSP to HEX-EDIT.SYS:
; MULISP COMPILE               ; select 'F' file compiler
; (COMPILE-FILE HEX-EDIT)      ; compile
; (SAVE HEX-EDIT)              ; store HEX-EDIT.SYS
; (SYSTEM)                     ; done
; 
; load muLISP with HEX-EDIT.SYS:
; MULISP HEX-EDIT              ; runs DRIVER
;
; the driver routine for HEX-EDIT
(DEFUN DRIVER()
 (SET-CURSOR (- (ROWS) 3) 0)(SPACES (- (COLUMNS) 1))
 (SET-CURSOR (- (ROWS) 2) 0)(SPACES (- (COLUMNS) 1))
 (SET-CURSOR (- (ROWS) 1) 0)(SPACES (- (COLUMNS) 1))
 (SET-CURSOR (- (ROWS) 2) 0)
 (PRINC "File to edit?   [ENTER to exit]      > ")
 (SETQ FNAME (READ-LINE))
 (IF (ZEROP (LENGTH FNAME))(SYSTEM)) ; leave if ENTER was pressed
 (HEX-EDIT FNAME)
)
