;
; Simple Lotus WK1 Parser Framework
;
; Martin Hepperle, 2025
;

; ------------------------------------------------------------------
; Read a 16-bit integer number starting at byte IDX in list BYTES.
; Return the value read.
(DEFUN INTEGER ( BYTES IDX )
 ; IDX:    low byte
 ; IDX+1:  high byte
 (SETQ VALUE (LOGIOR (NTH IDX BYTES)(SHIFT(NTH (+ IDX 1) BYTES)8) ))
 (IF (> VALUE 32767)(DECQ VALUE 65536))
 ;  7FFF...0001...0000...FFFF...8000 
 ; 32767      1      0     -1   -32768
 (PRINC ", INTEGER VALUE: ")(PRIN1 VALUE)
 VALUE
)
; ------------------------------------------------------------------
; Read the 4 bytes of a cell reference
; Return a list of column and row read.
(DEFUN CELLREF ( BYTES IDX
                 COL ROW )
 ;  IDX:   column
 ;  IDX+2: row
 (SETQ COL (INTEGER BYTES IDX))
 (SETQ ROW (INTEGER BYTES (+ IDX 2)))

 (PRINC ", COL:")(PRIN1 COL)
 (PRINC ", ROW:")(PRIN1 ROW)
 ; return reference
 (LIST COL ROW)
)

; ------------------------------------------------------------------
; Read the 4 bytes of a range reference inside an formula
(DEFUN RANGEREF ( BYTES IDX
                  COL ROW TMP )
 ;  IDX:   column
 ;  IDX+2: row
 (SETQ COL (LOGIOR(NTH IDX BYTES)      (SHIFT(NTH (+ IDX 1) BYTES)8)))
 (SETQ ROW (LOGIOR(NTH (+ IDX 2) BYTES)(SHIFT(NTH (+ IDX 3) BYTES)8)))

 ; coordinates are 0-based

 ; column
 (COND
  ((ZEROP (LOGAND COL 32768)) ; if bit 15 clear: absolute reference
    (PRINC "$")
    (SETQ TMP (DIVIDE COL 26))
    (IF (> COL 25)(PRINC (ASCII(+(CAR TMP) 64))))
    (PRINC (ASCII(+(CADR TMP) 65)))
  )
  ; else: relative reference
  (T (SETQ COL (LOGAND COL 8191))      ; 0x1FFF
     (IF (> COL 4095) (DECQ COL 8192)) ; negative offset
     (PRINC "C(")(PRIN1 COL)(PRINC ")")
  ) 
 )
 ; row
 (COND
  ((ZEROP (LOGAND ROW 32768)) ; absolute reference
   (PRINC "$")
   (PRIN1 (+ ROW 1)) ; absolute addresses are 1 based
  )
  ; else: relative reference
  (T (SETQ ROW (LOGAND ROW 8191)) 
  (IF (> ROW 4095) (DECQ ROW 8192)) ; negative offset
     (PRINC "R(")(PRIN1 ROW)(PRINC ")")  
  )             ; relative
 )
)

; ------------------------------------------------------------------
; Read the first 5 common header bytes of a cell
; Return a list of column and row read.
(DEFUN CELLHDR ( BYTES
                 FMT )
 ;    0: format
 ;  1-2: column
 ;  3-4: row
 (SETQ FMT (CAR BYTES))
 (PRINC ": FMT:")(PRIN1 FMT)

 (CELLREF BYTES 1)
)

; ------------------------------------------------------------------
; Read a Formula cell
(DEFUN FORMULA( BYTES IDX FUNCS
                B1 B2 B3 B4 B5 B6 B7 B8
                ISNAN SIGN EXPONENT SIGNIFICAND VALUE )
 ; IDX   5-12: floating point value 
 ; IDX+8 13-... formula
 (NUMBER BYTES IDX)
 (INCQ IDX 8)
 
 (SETQ LENGTH (LOGIOR(NTH IDX BYTES)(SHIFT(NTH (+ IDX 1) BYTES)8)))
 (INCQ IDX 2)
 (PRINC ", LENGTH:")(PRIN1 LENGTH)(TERPRI)
 (PRINC "  ")

; Formula: @SUM(A1..B4)+2.5
; 02 FFBF FCBF 0080 FCBF range A1..B1  push range
; 50 01                  @SUM[1]       perform SUM with 1 parameter
; 00 0000000000000440    2.5           push 2.5
; 09                     +             perform +
; 03                     end           done
; 
; Range coordinates can be absolute ($ prefix) or relative
; (+/- to current cell) references.
;      0x1FFF 8191d         11111 11111111
;      13 bits used?    Rxx.00000.00000000
;                       ^ bit 15 set if relative reference

 (LOOP
  ((ZEROP IDX)) ; break
  (SETQ CODE (NTH IDX BYTES))
  (INCQ IDX)

  ; one could also store the function names in a list and extract by index
  (PRINC "|")
  (PRINC (NTH CODE FUNCS))  
  ; special handling for certain functions
  (COND
    ((EQ CODE  0)(NUMBER BYTES IDX)(INCQ IDX 8)) ; CONST: read double number
    ((EQ CODE  1)(CELLREF BYTES IDX)(INCQ IDX 4))                   ; VAR:   
    ((EQ CODE  2)(PRINC "[")(RANGEREF BYTES IDX)(INCQ IDX 4) ; RANGE: Col,Row Col,Row
                 (PRINC ":")(RANGEREF BYTES IDX)(INCQ IDX 4)(PRINC "]"))
    ((EQ CODE  3)(SETQ IDX 0)) ; break           ; END:   
    ((EQ CODE  5)(INTEGER BYTES IDX)(INCQ IDX 2))  ; INTEGER
    ((EQ CODE  6)(INCQ IDX (ASCIIZ BYTES IDX)))  ; ASCIIZ: read characters
    ; 80-84: @SUM..@MAX variable # of arguments: followed by 1 byte argument count
    ((<= 80 CODE 84)(PRINC "[")(PRIN1 (NTH IDX BYTES))(PRINC "]")(INCQ IDX))
  )
 )
 (PRINC "|") ; terminator
)

; ------------------------------------------------------------------
; Read a IEEE 754 64-bit floating point number
; starting at byte IDX in list BYTES.
; Format of an IEEE floating point number in Intel order
;     ex. 2.25 : 0x0 0x0 0x0 0x00 0x00 0x00 0x02 0x40
;                                      |    |    S.EEEEEEE
;                                      |    EEEE.MMMM 
;                                      MMMMMMMM
(DEFUN NUMBER ( BYTES IDX
                B1 B2 B3 B4 B5 B6 B7 B8
                ISNAN SIGN EXPONENT SIGNIFICAND VALUE )
 ; B1 B2 B3 B4 B5 B6 B7 B8 bytes
 ; MM MM MM MM MM MM EM SE nibbles
 
                            ; bits
 (SETQ B1 (NTH IDX BYTES))  ; MMMMMMMM LSB Mantissa
 (INCQ IDX)
 (SETQ B2 (NTH IDX BYTES))  ; MMMMMMMM 
 (INCQ IDX)
 (SETQ B3 (NTH IDX BYTES))  ; MMMMMMMM 
 (INCQ IDX)
 (SETQ B4 (NTH IDX BYTES))  ; MMMMMMMM
 (INCQ IDX)
 (SETQ B5 (NTH IDX BYTES))  ; MMMMMMMM
 (INCQ IDX)
 (SETQ B6 (NTH IDX BYTES))  ; MMMMMMMM
 (INCQ IDX)
 (SETQ B7 (NTH IDX BYTES))  ; EEEEMMMM LSB Exponent, MSB Mantissa
 (INCQ IDX)
 (SETQ B8 (NTH IDX BYTES))  ; SEEEEEEE Mantissa Sign, MSB Exponent
                            ; the Exponent is biased by 1023

; (PRINC "[")(PRIN1 B1)(PRINC ",")
; (PRIN1 B2)(PRINC ",")
; (PRIN1 B3)(PRINC ",")
; (PRIN1 B4)(PRINC ",")
; (PRIN1 B5)(PRINC ",")
; (PRIN1 B6)(PRINC ",")
; (PRIN1 B7)(PRINC ",")
; (PRIN1 B8)(PRINC "]")

 (SETQ VALUE 99999.999)
 (SETQ ISNAN NIL)
 
 ; detect NaN, zero or regular number
 (COND
  ; if NaN: all E bits set to one
  ((AND(EQ (LOGAND B8 127) 127)(EQ (LOGAND B7 240) 240))(SETQ ISNAN T))
  ; if zero:
  ((= 0 B1 B2 B3 B4 B5 B6 B7 (LOGAND B8 127)) (SETQ VALUE 0) )
  ; else: convert number
  ( T
     ; decode IEEE number
     ; sign
     (IF (EQ (LOGAND B8 128) 128) (SETQ SIGN -1) (SETQ SIGN 1))
     ; exponent
     (SETQ EXPONENT (+ (SHIFT (LOGAND B8 127) 4) (SHIFT (LOGAND B7 240) -4) -1023))
     ; get mantissa
     (SETQ SUM B1)                 ; start with LSBits
     (SETQ SUM (+ (/ SUM 256) B2)) ; shift bits and add next SBits
     (SETQ SUM (+ (/ SUM 256) B3)) ; ...
     (SETQ SUM (+ (/ SUM 256) B4)) ; ...
     (SETQ SUM (+ (/ SUM 256) B5)) ; ...
     (SETQ SUM (+ (/ SUM 256) B6)) ; ...
     (SETQ SUM (+ (/ SUM 256) (LOGAND B7 15))) ; mask and add the last 4 MSBits
     (SETQ SIGNIFICAND (+ 1 (/ SUM 16))) ; shift 4 mantissa bits and add 1
     ; compute final value
     ; 2 ^ EXPONENT
     (COND 
      ((ZEROP EXPONENT)(SETQ SCALE 1))
      ((> EXPONENT 0)  (SETQ SCALE      (SHIFT 1 EXPONENT)))
      ( T              (SETQ SCALE (/ 1 (SHIFT 1 (- EXPONENT)))))
     )
     (SETQ VALUE (* SIGN SIGNIFICAND SCALE))
     ;(PRINC ", MANT=")(PRIN1 SIGNIFICAND)
     ;(PRINC ", SIGN=")(PRIN1 SIGN)
     ;(PRINC ", EXPO=")(PRINT EXPONENT)
  )
 )
 (PRINC ", VALUE:")
 (IF ISNAN (PRINC "NaN")
           (PROGN(PRIN1 VALUE))
 )
)

; ------------------------------------------------------------------
; Read a zero-terminated string starting at IDX from the list BYTES.
; Return length of string, including the terminating zero byte
(DEFUN ASCIIZ ( BYTES IDX
                IDX0 )
 (PRINC "\"")
 (SETQ IDX0 IDX) ; save starting index
 (LOOP
  ((ZEROP (NTH IDX BYTES))) ; done
  (PRINC (ASCII(NTH IDX BYTES)))
  (INCQ IDX)
 )
 (INCQ IDX) ; skip null-byte
 (PRINC "\"")
 (- IDX IDX0) ; return length
)

; ------------------------------------------------------------------
;
; Read a Lotus 1-2-3 Worksheet file in WK1 format.
;
(DEFUN READ-WK1 ( FILE-NAME )
; indexed list of formula functions
 (SETQ FUNCS
  (LIST
   ; 0...9 (PRINC "+") would execute the "+" function, therefore quote and not "+"
   'RCONST 'VAR 'RANGE 'END 'PARENS 'ICONST 'ASCIIZ '?7? 'U- '+ 
   ; 10...19
   '- '* '/ '^ '= '<> '<= '>= '< '> 
   ; 20...29  (25-30 unused)
   '#AND# '#OR# '#NOT# 'U+ '& '?25? '?26? '?27? '?28? '?29?
   ; 30...39
   '?30? '@NA '@ERR '@ABS '@INT '@SQRT '@LOG '@LN '@PI '@SIN 
   ; 40...49
   '@COS '@TAN '@ATAN2 '@ATAN '@ASIN '@ACOS '@EXP '@MOD '@CHOOSE '@ISNA
   ; 50...59
   '@ISERR '@FALSE '@TRUE '@RAND '@DATE '@TODAY '@PMT '@PV '@FV '@IF
   ; 60...69
   '@DAY '@MONTH '@YEAR '@ROUND '@TIME '@HOUR '@MINUTE '@SECOND '@ISNUMBER '@ISSTRING
   ; 70...79
   '@LENGTH '@VALUE '@FIXED '@MID '@CHR '@ASCII '@FIND '@DATEVALUE '@TIMEVALUE '@CELLPOINTER
   ; 80...89
   '@SUM '@AVG '@CNT '@MIN '@MAX '@VLOOKUP '@NPV '@VAR '@STD '@IRR
   ; 90...99
   '@HLOOKUP '@DSUM '@AVG '@DCNT '@DMIN '@DMAX '@DVAR '@DSTD '@INDEX '@COLS
   ; 100...109
   '@ROWS '@REPEAT '@UPPER '@LOWER '@LEFT '@RIGHT '@REPLACE '@PROPER '@CELL '@TRIM
   ; 110...115
   '@CLEAN '@S '@V '@STREQ '@CALL '@INDIRECT))

 (OPEN-INPUT-FILE FILE-NAME)

 (SETQ OFILE-NAME (PACK* (SUBSTRING FILE-NAME 0 (FINDSTRING ".WK1" FILE-NAME)) "TXT"))
 (OPEN-OUTPUT-FILE OFILE-NAME)
 
 (WRITE-STRING FILE-NAME) 
 (WRITE-STRING (ASCII 13))(WRITE-STRING (ASCII 10)) 
 (WRITE-STRING "============") 
 (WRITE-STRING (ASCII 13))(WRITE-STRING (ASCII 10)) 
  
 (SETQ RECNO 0)
 (LOOP
  ((EQ RECNO 500)) ; DEBUG break
  (INCQ RECNO)
  (SETQ RTYPE (LOGIOR (READ-BYTE)(SHIFT (READ-BYTE) 8)))
  (SETQ RLEN (LOGIOR (READ-BYTE)(SHIFT (READ-BYTE) 8)))
  ; collect bytes
  (SETQ BYTES '())
  (LOOP
   ((ZEROP RLEN))
   (SETQ BYTE (READ-BYTE))
   (SETQ BYTES (CONS BYTE BYTES))
   (DECQ RLEN)
  )
  (SETQ BYTES (REVERSE BYTES))
  (SETQ RLEN (LENGTH BYTES))
  ; BYTES contains the record data without type and length words
 
  ; Lotus 1-2-3 and Symphonie only record types
  (TERPRI)
  (PRINC "RTYPE=")(PRIN1 RTYPE)(PRINC ": ")
  (COND
   ((EQ RTYPE 0)(PRINC "BOF")
    (COND
     ((EQ (CAR BYTES) 4)(PRINC " (R1.x)"))
     ((EQ (CAR BYTES) 5)(PRINC " (Symphony)"))
     ((EQ (CAR BYTES) 6)(PRINC " (R2.x)"))
   ))
   ((EQ RTYPE 1)(PRINC "EOF"))
   ((EQ RTYPE 2)(PRINC "CALC MODE"))
   ((EQ RTYPE 3)(PRINC "CALC ORDER"))
   ((EQ RTYPE 4)(PRINC "WINDOW SPLIT"))
   ((EQ RTYPE 5)(PRINC "WINDOW SYNC"))
   ((EQ RTYPE 6)(PRINC "SAVE RANGE")(SETQ TOP-LEFT(CELLREF BYTES 0))
                                    (SETQ BOT-RIGHT(CELLREF BYTES 4)))
   ((EQ RTYPE 7)(PRINC "WINDOW W1"))
   ((EQ RTYPE 8)(PRINC "COLUMN WIDTH W1"))
   ((EQ RTYPE 9)(PRINC "WINDOW W2"))
   ((EQ RTYPE 10)(PRINC "COLUMN WIDTH W2"))
   ((EQ RTYPE 11)(PRINC "NAME"))
   ((EQ RTYPE 12)(PRINC "BLANK"))
   ((EQ RTYPE 13)(PRINC "INTEGER")(CELLHDR BYTES)(INTEGER BYTES 5))
   ((EQ RTYPE 14)(PRINC "NUMBER") (CELLHDR BYTES)(NUMBER BYTES 5))
   ((EQ RTYPE 15)(PRINC "LABEL") (CELLHDR BYTES)(PRINC ", ")(ASCIIZ BYTES 5))
   ((EQ RTYPE 16)(PRINC "FORMULA")(CELLHDR BYTES)(FORMULA BYTES 5 FUNCS))
   ; 11h-17h undefined
   ((EQ RTYPE 24)(PRINC "TABLE"))
   ((EQ RTYPE 25)(PRINC "QUERY RANGE"))
   ((EQ RTYPE 26)(PRINC "PRINT RANGE"))
   ((EQ RTYPE 27)(PRINC "SORT RANGE"))
   ((EQ RTYPE 28)(PRINC "FILL RANGE"))
   ((EQ RTYPE 29)(PRINC "KEY RANGE 1"))
   ; undefined
   ((EQ RTYPE 32)(PRINC "H RANGE"))
   ; undefined
   ((EQ RTYPE 35)(PRINC "KEY RANGE 2"))
   ; if PROTECT == 1 then all cell data will be nonsense because
   ; they are encrypted with the password
   ((EQ RTYPE 36)(PRINC "PROTECT")(PRINC ": ")(PRINC (CAR BYTES))) ; 30d
   ((EQ RTYPE 37)(PRINC "FOOTER"))
   ((EQ RTYPE 38)(PRINC "HEADER"))
   ((EQ RTYPE 39)(PRINC "SETUP"))
   ((EQ RTYPE 40)(PRINC "MARGINS"))
   ((EQ RTYPE 41)(PRINC "LABEL FORMAT"))
   ((EQ RTYPE 42)(PRINC "TITLES"))
   ; undefined
   ((EQ RTYPE 45)(PRINC "GRAPH"))
   ((EQ RTYPE 46)(PRINC "NAMED GRAPH"))
   ((EQ RTYPE 47)(PRINC "CALC COUNT"))
   ((EQ RTYPE 48)(PRINC "UNFORMATTED"))
   ((EQ RTYPE 49)(PRINC "CURSOR W1+W2"))           
   ((EQ RTYPE 50)(PRINC "WINDOW"))                 ; Symphonie only
   ((EQ RTYPE 51)(PRINC "STRING"))                 ; Symphonie only
   ; undefined
   ((EQ RTYPE 55)(PRINC "LOCK PASSWORD"))          ; Symphonie only
   ((EQ RTYPE 56)(PRINC "LOCKED"))                 ; Symphonie only
   ; undefined
   ((EQ RTYPE 60)(PRINC "QUERY"))                  ; Symphonie only
   ((EQ RTYPE 61)(PRINC "QUERY NAME"))             ; Symphonie only
   ((EQ RTYPE 62)(PRINC "PRINT"))                  ; Symphonie only
   ((EQ RTYPE 63)(PRINC "PRINT NAME"))             ; Symphonie only
   ((EQ RTYPE 64)(PRINC "GRAPH 2"))                ; Symphonie only
   ((EQ RTYPE 65)(PRINC "GRAPH NAME"))             ; Symphonie only
   ((EQ RTYPE 66)(PRINC "ZOOM"))                   ; Symphonie only
   ((EQ RTYPE 67)(PRINC "SYMPHONY SPLIT"))         ; Symphonie only
   ((EQ RTYPE 68)(PRINC "NUMBER SCREEN ROWS"))     ; Symphonie only
   ((EQ RTYPE 69)(PRINC "NUMBER SCREEN COLUMNS"))  ; Symphonie only
   ((EQ RTYPE 70)(PRINC "RULER"))                  ; Symphonie only
   ((EQ RTYPE 71)(PRINC "NAMED RANGE")             ; Symphonie only
    (ASCIIZ BYTES 0)(CELLREF BYTES 16)(CELLREF BYTES 20))
   ((EQ RTYPE 72)(PRINC "AUTO COMM"))              ; Symphonie only
   ((EQ RTYPE 73)(PRINC "AUTO MACRO"))             ; Symphonie only
   ((EQ RTYPE 74)(PRINC "PARSE"))                  ; Symphonie only
   ((EQ RTYPE 75)(PRINC "PASSWORD")(PRIN1 BYTES)) ; 2 data bytes (docs say: 4), password for record data?
   ; undefined
   ((EQ RTYPE 100)(PRINC "HIDDEN COL VECTOR W1")) ; 64h, 1 bit per column which is hidden
   ((EQ RTYPE 101)(PRINC "HIDDEN COL VECTOR W2")) ; 65h
   ((EQ RTYPE 102)(PRINC "PARSE RANGES"))
   ((EQ RTYPE 103)(PRINC "REGRESS RANGES"))
   ((EQ RTYPE 105)(PRINC "MATRIX RANGES"))
   ; undefined
   ((EQ RTYPE 150)(PRINC "MATRIX RANGES")) ; 96h
   ; undefined
   (T (PRINC "UNKNOWN, DATA=")(PRIN1 BYTES))
  )
  ;(TERPRI)

  ; DEBUG
  ;(PRINC "  DATA[")(PRIN1 RLEN)(PRINC "] = ")(PRIN1 BYTES)
    
  ((EQ RTYPE 1)) ; EOF: break
 ) ; record loop

 (TERPRI)
 
 (CLOSE-INPUT-FILE FILE-NAME)
 (CLOSE-OUTPUT-FILE OFILE-NAME)
 
 ; used range in worksheet
 (TERPRI)
 (PRINC "Range used in spreadsheet:") (PRIN1 TOP-LEFT)(PRINT BOT-RIGHT)

 ; compact memory
 (RECLAIM)
)

; ------------------------------------------------------------------
(READ-WK1 "TEST.WK1")
;(READ-WK1 "PROTECTE.WK1")
;(READ-WK1 "EXCEL.WK1")