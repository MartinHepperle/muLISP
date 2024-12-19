; 
; Martin Hepperle, 2024
;
; muLISP-90
;
; ========================================
; decimal-hexadecimal conversion functions
; ========================================
; Convert a decimal 4-bit nibble to its ASCII hexadecimal character code (upper case)
(DEFUN NIB>HEX ( N )
 (ASCII (+ N (IF (> N 9) 55 48)))  ; 0=>48('0') 10=>65('A')
)
; Convert a decimal 8-bit byte to a string of two ASCII hexadecimal characters
(DEFUN BYTE>HEX ( N )
 (PACK* (NIB>HEX (LOGAND (SHIFT N -4) 15))
        (NIB>HEX (LOGAND N 15)))
)
; Convert a decimal 16-bit word to a string of four ASCII hexadecimal characters
(DEFUN WORD>HEX ( N )
 (PACK* (BYTE>HEX (LOGAND (SHIFT N -8) 255))
        (BYTE>HEX (LOGAND N 255)))
)
; Convert a decimal 32-bit word to a string of eight ASCII hexadecimal characters
(DEFUN DWORD>HEX ( N )
 (PACK* (WORD>HEX (LOGAND (SHIFT N -16) 65535))
        (WORD>HEX (LOGAND N 65535)))
)

; Convert a 4-bit nibble from single hex digit ASCII character to its decimal value
(DEFUN HEX>NIB ( C N )
 (SETQ N (ASCII C)) ; get ASCII code
 ((< 47 N 58)  (- N 48)) ; 0-9
 ((< 64 N 71)  (- N 55)) ; A-F
; ((< 96 N 103) (- N 87)) ; a-f
 NIL
)
; Convert a string of two hex ASCII characters to its decimal nibble value
(DEFUN HEX>BYTE ( C N )
 ((NEQ (LENGTH C) 2) NIL)
 (SETQ N (UNPACK C))
 ( + (* 16 (HEX>NIB (CAR N))) (HEX>NIB (CADR N)))
)
; Convert a string of four hex ASCII characters to its decimal word value
(DEFUN HEX>WORD ( C N )
 ((NEQ (LENGTH C) 4) NIL)
 (+ (* 256 (HEX>BYTE(SUBSTRING C 0 1))) (HEX>BYTE(SUBSTRING C 2 3)))
)
; Convert a string of eight hex ASCII characters to its decimal dword value
(DEFUN HEX>DWORD ( C N )
 ((NEQ (LENGTH C) 8) NIL)
 (+ (* 65536 (HEX>WORD(SUBSTRING C 0 3))) (HEX>WORD(SUBSTRING C 4 7)))
)

; Concatenate two strings into a single string
(DEFUN STR2CAT (S1 S2)
 (PACK* S1 S2)
)
; concatenate a list of strings into a single string
; loop
(DEFUN STRLCAT-LOOP (SLIST)
 (SETQ RES "")
 (LOOP
  ((ZEROP (LENGTH SLIST)))
  (SETQ RES (PACK* RES (CAR SLIST)))
  (SETQ SLIST (CDR SLIST))
 )
 RES
)

; concatenate a list of strings into a single string
; recursive
(DEFUN STRLCAT (SLIST)
 ((NULL SLIST) NIL) ; done
 (CONS (CAR SLIST) (STRLCAT (CDR SLIST)))
 (PACK SLIST) 
)

; FILENAME string
(DEFUN DUMP-FILE ( FILENAME 
 BYTE LINE ASCI FILOFF) ; local

 ((IF (EQ NIL (OPEN-INPUT-FILE FILENAME)) (PROG1(PRINC "Cannot open input file")(TERPRI))))
 
 (WRITE-STRING (STRLCAT (LIST "File: '" FILENAME "'")))
 (TERPRI)

 ; offset into file
 (SETQ FILOFF 0)
 ; over the complete file
 (LOOP
  ((NOT (LISTEN)) NIL) ; break at EOF
  ; build one line of 16 hex bytes and ASCII characters
  (SETQ LINE (STR2CAT (DWORD>HEX FILOFF) ": "))
  (SETQ ASCI ": ") ; preset with separator
  ; read up to 16 bytes per line
  (SETQ NUM 16)
  (LOOP
   ((NOT (LISTEN)) NIL) ; break at EOF
   ((ZEROP NUM))        ; break when NUM == 0
   (SETQ BYTE (READ-BYTE))
   (SETQ LINE (STRLCAT (LIST LINE (BYTE-HEX BYTE) " ")))
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
  (WRITE-STRING(PACK* LINE ASCI))
  (TERPRI)
  ; prepare for next line
  (SETQ FILOFF (+ FILOFF 16))
 )
 ; done
 (CLOSE-INPUT-FILE FILENAME)
)

(DEFUN DUMP-DS ( FILOFF BYTES
  LINE BYTE NUM ASCI LEN ) ; local
 ; hex dump BYTES in data segment, starting from offset FILOFF
 (LOOP
  ((ZEROP BYTES) NIL) ; break
  ; build one line of 16 hex bytes and ASCII characters
  (SETQ LINE (STR2CAT (DWORD>HEX FILOFF) ": "))
  (SETQ ASCI ": ") ; preset with separator
  ; read up to 16 bytes per line
  (SETQ NUM 16)
  (LOOP
   ((ZEROP BYTES) NIL)    ; break at end
   ((ZEROP NUM))          ; break when end of 16 byte line NUM == 0
   (SETQ BYTE (DSMEMORY FILOFF))
   (INCQ FILOFF)
   (DECQ BYTES)
   (SETQ LINE (STRLCAT (LIST LINE (BYTE-HEX BYTE) " ")))
   (SETQ ASCI (STR2CAT ASCI (IF (OR (< BYTE 32) 
                                    (> BYTE 128)) "." (ASCII BYTE))))
   (DECQ NUM)
  ) 
  ; pad to 16 bytes per line
  (SETQ LEN (- (LENGTH ASCI) 2))
  (LOOP
   ((= LEN 16)) ; break if 16 bytes per line
   (SETQ LINE (STR2CAT LINE "   ")) ; add 1 hex byte
   (SETQ ASCI (STR2CAT ASCI " "))   ; add 1 ASCII character
   (INCQ LEN)
  )
  (WRITE-STRING(PACK* LINE ASCI))
  (TERPRI)
 )
)

(DEFUN WDUMP-DS ( FILOFF WORDS
  LINE HIBYTE LOBYTE NUM ASCI LEN ) ; local
 ; hex dump WORDS in data segment, starting from offset FILOFF
 ; (word display has bytes swapped c.f. ASCII display)
 (LOOP
  ((ZEROP WORDS) NIL) ; break
  ; build one line of 8 hex words and ASCII characters
  (SETQ LINE (STR2CAT (DWORD>HEX FILOFF) ": "))
  (SETQ ASCI ": ") ; preset with separator
  ; read up to 8 words per line
  (SETQ NUM 8)
  (LOOP
   ((ZEROP WORDS) NIL)    ; break at end
   ((ZEROP NUM))          ; break when end of 8 word line NUM == 0
   (SETQ LOBYTE (DSMEMORY FILOFF))   ; Intel: little endian
   (INCQ FILOFF)
   (SETQ HIBYTE (DSMEMORY FILOFF))
   (INCQ FILOFF)
   (DECQ WORDS)
   ; (SETQ LINE (STRLCAT (LIST LINE (WORD>HEX (+ (* HIBYTE 256) LOBYTE)) " ")))
   ; equivalent:
   (SETQ LINE (STRLCAT (LIST LINE (BYTE-HEX HIBYTE) (BYTE-HEX LOBYTE) " ")))
   (SETQ ASCI (STR2CAT ASCI (IF (OR (< LOBYTE 32) 
                                    (> LOBYTE 128)) "." (ASCII LOBYTE))))
   (SETQ ASCI (STR2CAT ASCI (IF (OR (< HIBYTE 32) 
                                    (> HIBYTE 128)) "." (ASCII HIBYTE))))
   (DECQ NUM)
  ) 
  ; pad to 16 ASCII bytes per line
  (SETQ LEN (- (LENGTH ASCI) 2))
  (LOOP
   ((= LEN 16)) ; break if 16 ASCII bytes per line
   (SETQ LINE (STR2CAT LINE "     ")) ; add 1 hex word
   (SETQ ASCI (STR2CAT ASCI "  "))    ; add 2 ASCII characters
   (INCQ LEN)
   (INCQ LEN)
  )
  (WRITE-STRING(PACK* LINE ASCI))
  (TERPRI)
 )
)

; data segment muLISP-90 7.20
;                  0100    ; start of symbols
;                          ... symbols, grows upwards
; 0000  ENDSYM     : 0712    ; end of symbols

; 0002  ENDNUM     : 2DA8    ; end of numbers?
;                          ... numbers, grows downwards
; 0004  ENDATM     : 2E40    ; end of numbers
;                          ... conses, grows upwards
; 0006  ENDCNS     : 4952    ; end of cons
;                          ... free
; 0008  MAXCNS     : 0000    ; maximum size of cons space
; ...
; 0010  DEFSEG     : 34C1    ; Segment pointer function/longueur
; 0012  PNPSEG     : 37A5    ; Segment pointer Pname/vector
; 0014  PNSSEG     : 14CF    ; Segment des Pnames
; 0016  VECSEG     : 24C1    ; Segment des vecteurs   num,riques
; dump the above memory items
(DEFUN DUMP-MEM ()
 (PRINC "BEG SYM =         : 0100")(TERPRI)
 (PRINC "END SYM = ") (WDUMP-DS 2 1)
 (PRINC "END NUM = ") (WDUMP-DS 2 1)
 (PRINC "END ATM = ") (WDUMP-DS 4 1)
 (PRINC "END CNS = ") (WDUMP-DS 6 1)
 (PRINC "MAX CNS = ") (WDUMP-DS 8 1)
 (PRINC "DEF SEG = ") (WDUMP-DS 16 1)
 (PRINC "PNP SEG = ") (WDUMP-DS 18 1)
 (PRINC "PNS SEG = ") (WDUMP-DS 20 1)
 (PRINC "VEC SEG = ") (WDUMP-DS 22 1)
)

(DEFUN DUMP-CS ( FILOFF BYTES
  LINE BYTE NUM ASCI LEN ) ; local
 ; hex dump BYTES in data segment, starting from offset FILOFF
 (LOOP
  ((ZEROP BYTES) NIL) ; break
  ; build one line of 16 hex bytes and ASCII characters
  (SETQ LINE (STR2CAT (DWORD>HEX FILOFF) ": "))
  (SETQ ASCI ": ") ; preset with separator
  ; read up to 16 bytes per line
  (SETQ NUM 16)
  (LOOP
   ((ZEROP BYTES) NIL)    ; break at end
   ((ZEROP NUM))          ; break when end of 16 byte line NUM == 0
   (SETQ BYTE (CSMEMORY FILOFF))
   (INCQ FILOFF)
   (DECQ BYTES)
   (SETQ LINE (STRLCAT (LIST LINE (BYTE-HEX BYTE) " ")))
   (SETQ ASCI (STR2CAT ASCI (IF (OR (< BYTE 32) 
                                    (> BYTE 128)) "." (ASCII BYTE))))
   (DECQ NUM)
  ) 
  ; pad to 16 bytes per line
  (SETQ LEN (- (LENGTH ASCI) 2))
  (LOOP
   ((= LEN 16)) ; break if 16 bytes per line
   (SETQ LINE (STR2CAT LINE "   ")) ; add 1 hex byte
   (SETQ ASCI (STR2CAT ASCI " "))   ; add 1 ASCII character
   (INCQ LEN)
  )
  (WRITE-STRING(PACK* LINE ASCI))
  (TERPRI)
 )
)

; wait for key press and return key/ASCII code
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


; HEX input
; (SETQ *READ-BASE* 16)
; (SETQ *READ-BASE* 0A)
; HEX output
; (SETQ *PRINT-BASE* 16)
; (SETQ *PRINT-BASE* 10)


; ----------------------------------------------------------------------
; memory allocation test
; ALLOCATE nBytes
; ... Allocates bytes in code segment and returns the even offset.
; Can be accessed with CSMEMORY.
; Note: a function must start at an ODD address, therefore we 
; increment this offset by one before calling BINARY-LOAD
;
; Example binary file which starts with this function:
; This does nothing and
; a) if one parameter was given it is returned, 
; b) otherwise returns NIL.
;
; 83 F9 02 CMP CX,2    ; exactly one parameter? (CX==2)
; 75 04    JNE NONE    ; no: error
; OKAY:
; BF 02 01 MOV DI,[BP] ; return address of first parameter
; C3       RET
; NONE:
; BF 00 01 MOV DI,100  ; return address of LISP NIL variable
; C3       RET
;
; defines a binary function MYFUNC
(DEFUN GOGO( OFFSET
  BYTES OFFSET ) ; local
 (SETQ BYTES 398)                      ; ALLOCATE block
 (SETQ OFFSET (ALLOCATE BYTES))         ; TODO: should test allocation for NIL
 (INCQ OFFSET)
 (IF (NEQ (BINARY-LOAD "TEST.COM" OFFSET) BYTES)
  (PROGN((WRITE-STRING "Oops cannot BINARY-LOAD file TEST.COM")
         (TERPRI))
  )
  ; else
  (PROGN
   (PUTD 'MYFUNC OFFSET)  ; obviously argument must be < 32768?
   (PRINT (GETD MYFUNC))  ; the rest is just for debugging
   (PRINT 
   (STRLCAT
    (LIST 
     "Read from file to address "
     (WORD>HEX OFFSET) ":" 
     (BYTE-HEX (CSMEMORY OFFSET)) " "
     (BYTE-HEX (CSMEMORY (+ OFFSET 1))) " "
     (BYTE-HEX (CSMEMORY (+ OFFSET 2))) " "
     (BYTE-HEX (CSMEMORY (+ OFFSET 3))) " "
     (BYTE-HEX (CSMEMORY (+ OFFSET 4))) " "
     (BYTE-HEX (CSMEMORY (+ OFFSET 5))) " "
     (BYTE-HEX (CSMEMORY (+ OFFSET 6)))
     )
    )
   )
  )
 )
 OFFSET
)


; test MAPC function (apply a function to a list of parameters)
;(MAPC '(LAMBDA (FUN) (PRINT (PACK* '* FUN '*)))
;      '(WRITE PRIN1 PRINT PRINC WRITE-STRING WRITE-LINE SYSTEM LOAD))

; ; set properties of Z
; (PUT Z FREQ 100)
; (PUT Z DURATION 10)
; ; and retrieve them
; (GET Z FREQ)
; (GET Z DURATION)
; ; remove properties
; (REMPROP Z FREQ)
; (REMPROP Z KEY)

;
; TRIG functions approximation requires floating point
;
; Taylor series approximation for -pi/2 <= a <= pi/2
;
; sin(a) = a - 1/6*a^3 + 1/120*a^5 - 1/5040*a^7 + 1/362880*a^9
; sin(a) = a * (1 - a^2*(1/6 - a^2*(1/120 - a^2*(1/5040 - a^2*1/362880))))
;
; (nested sum accumulates small terms first which reduced loss of accuracy)
;
(DEFUN SIN1( A
 A2 ) ; local
 (SETQ A2 (* A A))
 (* A (- 1 (* A2 (- 0.1666666666667 
           (* A2 (- 0.0083333333333 
           (* A2 (- 0.0001984126984 
           (* A2 0.000002755731922
           )))))))
      )
 )
)

; Taylor series approximation SIN(ARAD) 
(DEFUN SIN(A)
 ; reduce A to below upper bounds of 2*pi
 (LOOP
  ((< A 6.283185307))
  (SETQ A (- A 6.283185307))
 )
 ; reduce A to above lower bounds of -2*pi
 (LOOP
  ((> A -6.283185307))
  (SETQ A (+ A 6.283185307))
 )
 ; map to first 1/4 circle
 (IF (< A -1.570796327) 
  (SETQ A (- -3.141592654 A))
  (IF (> A 1.570796327)
   (SETQ A (- 3.141592654 A))))
 (SIN1 A)
)
; COS(ARAD)
(DEFUN COS(A)
 (SIN (+ A 1.570796327))
)
; TAN(ARAD) (less accurate due to division of approximations)
(DEFUN TAN(A
 C) ; local
 ; singularity at +/-PI/2
 (SETQ C (COS A))
 (IF (ZEROP C)
  NIL
  (/ (SIN A) C))
)

; INTEGER exponent power function x^y
; dumb algorithm performs repeated multiplication
(DEFUN POW1(X Y)
 (COND ( (EQ 0 Y) 1 )
       ( T (DECQ Y) (* X (POW X Y))))
)

; INTEGER exponent power function x^y
; (should be) a faster power algorithm (Knuth algorithm A)
(DEFUN POW(X Y
  R Z) ; local
 (SETQ R 1)
 (SETQ Z X)

 (LOOP
  ((ZEROP Y) Z)
  (IF (ODDP Y) (PROGN ( (DECQ Y) (SETQ Y (/ Y 2)) (SETQ R (* R Z)) ) )
               (PROGN ( (SETQ Y (/ Y 2)) ) )
  )
  (SETQ Z (* Z Z))
 )
 R ; return
)

; Heron's iterative Square Root algorithm
(DEFUN SQRT(X
 R0 R1 MAXIT) ; local
 (SETQ R0 (* 0.5 X))
 (SETQ R1 R0)
 (SETQ MAXIT 50)
 (LOOP
  ((ZEROP MAXIT)) ; abort
  (SETQ R1 (* 0.5 (+ R0 (/ X R0))))
  ((ZEROP (- R1 R0))) ; no change
  (SETQ R0 R1)
  (DECQ MAXIT)
 )
 R0
)

; Dump textual content of VGA Text 25 x 80 screen
(DEFUN SNAP( FILE-NAME ; optional, default: "SNAP.TXT"
 RAM R C) ; local
 ((ZEROP FILE-NAME)(SETQ FILE-NAME "SNAP.TXT"))
 (OPEN-OUTPUT-FILE FILE-NAME)
 (SETQ *AUTO-NEWLINE* NIL) ; otherwise muLISP inserts CR/LF after 78 characters
 ; grab the screen memory which contains words of (Character|Attribute) pairs
 ; 20-bit start address VGA: 0xB800:0000 = 0xB8000 = 753664 decimal
 (SETQ RAM (UNPACK (SNAPSHOT 753664 (* 80 25 2))))
 (SETQ R 0)
 (LOOP
  ((EQ 25 R))   ; end of screen
  (SETQ C 0)
  (LOOP
   ((EQ 80 C))   ; end of row
   (WRITE-STRING (CAR RAM))
   (SETQ RAM (CDR RAM))
   (SETQ RAM (CDR RAM)) ; skip attribute byte
   (INCQ C)
  )
 (INCQ R)
 (WRITE-BYTE 13)
 (WRITE-BYTE 10)
 )
 (CLOSE-OUTPUT-FILE FILE-NAME)
 (SETQ *AUTO-NEWLINE* T)   ; back to default
)

; using ARRAY.LSP:
; $ (LOAD ARRAY)
; $ (SETQ V1 (VECTOR 1 2 3) )
; (ARRAY (1 2 3) (1))
; $ (SETQ A1 (MAKE-ARRAY '(2 3) :INITIAL-CONTENTS '((1 2 3) (4 5 6)) ) )
; (ARRAY ((1 2 3) (4 5 6)) (2 3))
; $ (AREF A1 0 1)
; 2
; $ (AREF A1 1 2)
; 6

