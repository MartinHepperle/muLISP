;
; VGA mode  Testimage
;
; Martin Hepperle, 2024
;
;(VIDEO-MODE 14) ; 640 x 200 x 16 colors
;(VIDEO-MODE 16) ; 640 x 350 x 16 colors
(VIDEO-MODE 18) ; 640 x 480 x 16 colors

; Note: all plotting coordinates must be integer
(SETQ XRES 640)
(SETQ YRES 480)
(SETQ XMAX (- XRES 1))	; 639
(SETQ YMAX (- YRES 1))	; 479
(SETQ DX (/ XRES 16))	; 40
(SETQ DX1 (- DX 1))		; 39
(SETQ DY (/ YRES 12))	; 30
(SETQ DY1 (- DY 1))		; 29

;
; fill a rectangle by drawing horizontal lines
; (FILL X0 Y0 W H [C])
; X0, Y0 ... upper left corner
; W, H ..... width and height
; C ........ optional color index (otherwise use the current color)
;            becomes current colot
(DEFUN FILL(X0 Y0 W H C X1 Y1)
	(IF (NEQ NIL C) (SETQ *PLOT-COLOR* C))
	(SETQ X1 (+ X0 W))
	(SETQ Y1 (+ Y0 H))
	(LOOP
	 ((EQ Y0 Y1))
	 (PLOT-LINE X0 Y0 X1 Y0)
	 (INCQ Y0)
	)
)

; A = additive
(DEFUN GRIDN(DELTA N A)
 (+ (* DELTA N) A)
)
; A) draw grid ==================
; draw horizontal lines
(SETQ Y 0)
(SETQ *PLOT-COLOR* 15)
(LOOP
 ((EQ YRES Y))
 (PLOT-LINE 0 Y XMAX Y)
 (INCQ Y DY)
)
; draw vertical lines
(SETQ X 0)
(SETQ *PLOT-COLOR* 15)
(LOOP
 ((EQ XRES X))
 (PLOT-LINE X 0 X YMAX)
 (INCQ X DX)
)

; B) draw 16 colored rectangles 0...15 ==================
(SETQ C 0)
(SETQ X (GRIDN DX 2 1))
(SETQ Y (GRIDN DY 2 1)) 
(SETQ H (GRIDN DY 2 -1)) 
(SETQ W (/ (- XRES (* 4 DX)) 16))
(SETQ W1 (- W 1))
(LOOP
 ((EQ 16 C))
 (FILL X Y W1 H C)
 (INCQ X W)
 (INCQ C)
)

; C) draw 4 grayscale rectangles ==================
(SETQ X (GRIDN DX 2 1))
(INCQ Y DY)
(INCQ Y DY)
(SETQ W (GRIDN DX 3 -2))
(FILL X Y W H 15)
(INCQ X (* DX 3))
(FILL X Y W H 7)
(INCQ X (* DX 3))
(FILL X Y W H 8)
(INCQ X (* DX 3))
(FILL X Y W H 0)

; D) draw two white rectangles ==================
(SETQ X (GRIDN DX 2 1))
(INCQ Y DY)
(INCQ Y DY)
(SETQ H (- DY 1))
(SETQ W (GRIDN DX 2 -2))
(FILL X Y W H 15)
(INCQ X (* DX 10))
(FILL X Y W H)

; D) draw lt gray bands of reducing width ==================
(INCQ Y DY)
(SETQ *PLOT-COLOR* 7)
(SETQ X (* DX 2))
(SETQ DX1 20)
(LOOP
 ((< DX1 1))
 (FILL X Y DX1 H)
 (INCQ X DX1)
 (DECQ DX1 2)
 (INCQ X DX1)
)
; E) draw white bands of equal width ==================
(SETQ *PLOT-COLOR* 15)
(SETQ X (GRIDN DX 9 0))
(SETQ DX1 4)
(LOOP
 ((> X (GRIDN DX 14 -1)))
 (FILL X Y DX1 H)
 (INCQ X DX1)
 (INCQ X DX1)
)

; F) draw two rows with violet and blue rectangles ==================
; upper row
(INCQ Y DY)
; light
(SETQ W (- (* DX 6) 2)) ; 119
(SETQ X1 (+ (* DX 2) 1))
(SETQ X2 (+ (* DX 8) 1))
(FILL X1 Y W H 13)
(FILL X2 Y W H 9)
; lower row
; dark
(INCQ Y DY)
(FILL X1 Y W H 5)
(FILL X2 Y W H 1)

(SETQ W (/ DX 4))
(SETQ X1 1)
(SETQ X2 (- XMAX W))
(SETQ Y 1)
(LOOP
 ((>= Y YMAX))
 (FILL X1 Y W H 15)
 (FILL X2 Y W H 15)
 (INCQ Y DY)
 (INCQ Y DY)
)

; G) PLOT-CIRCLE center x, center y, radius [, color]
(PLOT-CIRCLE (/ XRES 2) (/ YRES 2) (/ YRES 2) 15)


; $ (dump-cs 928 32)
; 000003A0: 00 0F 06 00 0A 00 14 00 10 00 4B 00 4B 00 15 00 : ..........K.K...
;   CS:928: 00=orientation landscape for WRITE-SCREEN and PRINT-SCREEN
;   CS:929:    0F=dump color 15 to black&white TIFF file for WRITE-SCREEN
; 000003B0: 11 00 3C 00 3C 00 15 00 11 00 B4 00 B4 00 00 00 : ..<.<...........
; 
; $ (dump-cs 856 32)
; 00000358: 04 00 05 00 00 24 20 00 00 00 00 4C 53 50 FF 00 : .....$ ....LSP..
;   CS:856: 04=color DeskJet, printer type for PRINT-SCREEN
; 00000368: FF 2E 11 10 01 00 00 00 00 00 00 00 00 00 00 00 : ................

; TIFF file format
; WRITE-SCREEN always creates a monochrome image with one plane?
; Only the pixels with the given color index (at CS:929) are dumped.
(CSMEMORY 928 0) ; affects TIF orientation: 0 640x480, 1: 480x640
(CSMEMORY 929 0) ; affects TIF output: 0: only color index 0 (black) -> white
(OPEN-OUTPUT-FILE "VIDEO0.TIF")
(WRITE-SCREEN (OUTPUT-FILE))
(CLOSE-OUTPUT-FILE)
; 
(CSMEMORY 929 15) ; output only color 15 (white) -> white
(OPEN-OUTPUT-FILE "VIDEO15.TIF")
(WRITE-SCREEN (OUTPUT-FILE))
(CLOSE-OUTPUT-FILE)
; 
; (CSMEMORY 856 4) ; color deskjet
;(PRINT-SCREEN)

; pause
(SETQ I 32000)
(LOOP
 ((EQ 0 I))
 (DECQ I)
)


; text mode
(VIDEO-MODE 3)

; independent of video mode: always text screen size
(SETQ X (COLUMNS))
(SETQ Y (ROWS))

(PRINC "Text Resolution: ")
(PRIN1 X)
(PRINC " x ")
(PRINT Y)

; (SYSTEM)