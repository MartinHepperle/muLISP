;
; A simple muLISP HP-GL plotter simulator.
; 
; Martin Hepperle, 2024
;

;
; HPGL-PLOT.
; 
; Usage:
;    (HPGL-PLOT "file.gl")
; Purpose:
;    Plot a vector drawing in HP-GL format on the VGA screen.
;
;    Interprets just the PA, PU, PD, SP commands. Other commands
;    are skipped.
;    Each HP-GL command must be terminated by a semi-color ';'.
;    Concatenated commands must be sparated, i.e. "PAPU12,13;"
;    must be written as "PA;PU12,13;"
;
; Global/Static:
;    ORIGIN-X, ORIGIN-Y, SCALE-X, SCALE-Y, PEN-STATE, PEN-COLOR
(DEFUN HPGL-PLOT(FILE-NAME
                 ELEMENT CR LF XRES YRES LOOP-COUNT BYTE)

 ; debug: use default name
 (IF (NULL FILE-NAME)(SETQ FILE-NAME "TEST.GL"))
 
 ((NULL (OPEN-INPUT-FILE FILE-NAME))
  (PRINC "Cannot open input file '")(PRINC FILE-NAME)(PRINC "'.")(TERPRI))

 (VIDEO-MODE 18) ; VGA: 640 x 480 x 16 colors
 (SETQ XRES 640)
 (SETQ YRES 480)
 
 (SETQ XMAX (- XRES 1))	; 639
 (SETQ YMAX (- YRES 1))	; 479
 
 ; define scale factors for HP-GL to screen coordinates transformation
 (SETQ SCALE-X (/ XRES 10900))
 (SETQ SCALE-Y (/ YRES  7650))
 
 ; move origin in screen coordinates (adjust for HP-GL image)
 (SETQ ORIGIN-X -90) ; shift image right by 90 pixels
 (SETQ ORIGIN-Y 110) ; shift image down by 110 pixels

 (SETQ CR (ASCII 13))
 (SETQ LF (ASCII 10))
 
 (SETQ PEN-STATE 0)
 (SETQ PEN-COLOR 0)

 ; VGA colors
 ;  0 = black            8 = dark grey
 ;  1 = dark blue        9 = bright blue
 ;  2 = dark green      10 = bright green
 ;  3 = dark cyan       11 = bright cyan
 ;  4 = dark red        12 = bright red
 ;  5 = dark violet     13 = bright violet
 ;  6 = dark orange     14 = yellow
 ;  7 = light grey      15 = white
 ;
 ; Plotter pens: 8 pens in carousel
 ;  pen #0 = none SP0;
 (SETQ PEN-COLORS (LIST 0 15 12 10 9 14 6 13 3))
 
 (SETQ LOOP-COUNT 0) ; for triggering garbage collection
 (SETQ ELEMENT "")
 
 (LOOP
   ((NOT (LISTEN))) ; break at EOF
   (SETQ BYTE (READ-CHAR))
   (COND ((EQ BYTE CR) )
         ((EQ BYTE LF) )
         ((EQ BYTE ";") (GLEVAL ELEMENT)(SETQ ELEMENT ""))
         (T             (SETQ ELEMENT (PACK* ELEMENT BYTE))))

   ; trigger garbage collection to avoid memory overflow
   (COND ((EQ 5000 LOOP-COUNT) (RECLAIM)(SETQ LOOP-COUNT 0))
         (T (INCQ LOOP-COUNT)))
 )

 (CLOSE-INPUT-FILE FILE-NAME)
 
 ; done
 (TONE 880 25) 

 (RECLAIM)
 
 ; wait for key
 (READ-BYTE) ; swallow CR from execution of GLPLOT
 (IF (EQ 255 (READ-BYTE)) (READ-BYTE)) ; get one key, incl 2-byte function keys

 ; back to text mode
 (VIDEO-MODE 3)
 T
)

;
; HPGL-PLOT Helper.
;
; Purpose:
;    Convert a string consisting of characters "0123456789" to 
;    a decimal integer number.
; Parameters:
;    TEXT a string with an integer number e.g. "1098".
; Local:
;    None
(DEFUN STRING-TO-DECIMAL(TEXT)
 (DECODE-REV-ARRAY (REVERSE (UNPACK TEXT)))
)
;
; HPGL-PLOT Helper.
;
; Purpose:
;    Decode a reversed list of characters "0123456789" to a decimal integer number.
;    Used by STRING-TO-DECIMAL.
; Parameters:
;    TEXT a reversed list of digit characters e.g. "1098" -> (\8 \9 \0 \1).
; Local:
;    None
(DEFUN DECODE-REV-ARRAY( TEXT )
 ((NULL TEXT) 0) ; done
 (+ (- (ASCII (CAR TEXT)) 48) (* 10 (DECODE-REV-ARRAY (CDR TEXT))))
)

;
; HPGL-PLOT Helper.
;
; Purpose:
;    Walk through the list of X Y point coordinates and draw a
;    line if the pen is down.
;    Update the current pen position.
; Parameters:
;    POINTS: a list of numbers (x0 y0 x1 y1 ...)
; Global/Static:
;    CURRENT-X, CURRENT-Y
; Local:
;    X, Y
(DEFUN GLMOVE( POINTS 
               X Y )
 ((NULL POINTS)) ; done

; (PRIN1 (CAR POINTS)) (PRINC ",")(PRINT (CADR POINTS))
 ; screen coordinates must be integer
 ; screen origin is located in upper left corner
 (SETQ X         (TRUNCATE(- (* SCALE-X (CAR  POINTS)) ORIGIN-X) 1))
 (SETQ Y (- YMAX (TRUNCATE(- (* SCALE-Y (CADR POINTS)) ORIGIN-Y) 1)))
; (PRIN1 X) (PRINC ",")(PRINT Y)
 (IF (EQ 1 PEN-STATE)  ; if PEN is down: draw line to X,Y
  (PLOT-LINE CURRENT-X CURRENT-Y X Y PEN-COLOR)
 )
 ; update position
 (SETQ CURRENT-X X) 
 (SETQ CURRENT-Y Y)
 
 ; recurse down to next set of points
 (GLMOVE (CDDR POINTS))
)

;
; HPGL-PLOT Helper.
;
; Purpose:
;    Extract the (optional) numeric parameters from the given element, 
;    If more than one parameter is given, they must be separated by commas or blanks.
; Parameters:
;    ELEMENT string, starting with a two-character HP-GL mnemonics, exluding the trailing ';'.
; Global/Static:
;    None
; Local:
;    LST, I, J, NUM, RET
(DEFUN GLNUM(ELEMENT
             LST I J NUM RET)
 ; remove leading mnemonics, append a trailing ',' character and replace ' ' by ','
 (SETQ LST (PACK(APPEND (SUBST "," " " (UNPACK (SUBSTRING ELEMENT 2))) '(","))))
; (PRINC LST)(TERPRI)

 (SETQ I 0)
 (LOOP
  (SETQ J (FINDSTRING "," LST I))
  ((NULL J))
  ((EQ 0 J))
;  (PRIN1 I)(PRINC ",")(PRIN1 J)(PRINC ":")
  (SETQ NUM (SUBSTRING LST I (- J 1)))
;  (PRINT NUM)
;  (PRINT (STRING-TO-DECIMAL NUM))
  (SETQ RET (CONS (STRING-TO-DECIMAL NUM) RET))
  (SETQ I (+ J 1))
 )
 (REVERSE RET)
)

;
; HPGL-PLOT Helper.
;
; Purpose:
;    Evaluate a ELEMENT string.
; Parameters:
;    ELEMENT string, starting with a two-character HP-GL mnemonics, exluding the trailing ';'.
; Global/Static:
;    PEN-STATE, PEN-COLOR
; Local:
;    MNEMONICS
(DEFUN GLEVAL (ELEMENT
               MNEMONICS)
 (SETQ MNEMONICS (SUBSTRING ELEMENT 0 1))
;(PRINT MNEMONICS)

 (COND ((EQ MNEMONICS "PA")                   (GLMOVE(GLNUM ELEMENT)))
       ((EQ MNEMONICS "PU") (SETQ PEN-STATE 0)(GLMOVE(GLNUM ELEMENT)))
       ((EQ MNEMONICS "PD") (SETQ PEN-STATE 1)(GLMOVE(GLNUM ELEMENT)))
       ((EQ MNEMONICS "SP") (SETQ PEN-STATE 0)
                            (SETQ PEN-COLOR (NTH (CAR(GLNUM ELEMENT)) PEN-COLORS)))
 ) 
)

