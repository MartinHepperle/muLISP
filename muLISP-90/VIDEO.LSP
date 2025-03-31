;
; Test-Image
;
; VGA Screencopy to BMP file.
;
; Martin Hepperle, 2024
;

;(VIDEO-MODE 14) ; 640 x 200 x 16 colors
;(VIDEO-MODE 16) ; 640 x 350 x 16 colors
(VIDEO-MODE 18) ; 640 x 480 x 16 colors

; VGA mode 18 colors:
;  0 = black            8 = dark grey
;  1 = dark blue        9 = bright blue
;  2 = dark green      10 = bright green
;  3 = dark cyan       11 = bright cyan
;  4 = dark red        12 = bright red
;  5 = dark violet     13 = bright violet
;  6 = dark orange     14 = yellow
;  7 = light grey      15 = white


; Note: all plotting coordinates must be integer
; get video (base row, base column, rows, columns, height and width of character cell)
(SETQ V (MAKE-WINDOW))
(SETQ XRES (* (NTH 3 V) (NTH 5 V))) ; pixels
(SETQ YRES (* (NTH 2 V) (NTH 4 V))) ; pixels
(SETQ XMAX (- XRES 1)) ; 639
(SETQ YMAX (- YRES 1)) ; 479
(SETQ DX (SHIFT XRES -4)) ; 40 grid width
(SETQ DX1 (- DX 1))  ; 39
(SETQ DY (/ YRES 12)) ; 30 grid height (square grid on VGA 640x480)
(SETQ DY1 (- DY 1))  ; 29

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

; helper for raster steps
; Return N*DELTA + A
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
(SETQ W (SHIFT (- XRES (SHIFT DX 2)) -4))
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
(SETQ X (SHIFT DX 1))
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
(SETQ X1 (+ (SHIFT DX 1) 1))
(SETQ X2 (+ (SHIFT DX 3) 1))
(FILL X1 Y W H 13)
(FILL X2 Y W H 9)
; lower row
; dark
(INCQ Y DY)
(FILL X1 Y W H 5)
(FILL X2 Y W H 1)

; G) draw left and right columns with alternating white rectangles ==================
(SETQ W (SHIFT DX -2))
(SETQ X1 1)
(SETQ X2 (- XMAX W))
(SETQ Y (- DY (SHIFT DY -1)))
(LOOP
 ((>= Y YMAX))
 (FILL X1 Y W H 15)
 (FILL X2 Y W H 15)
 (INCQ Y DY)
 (INCQ Y DY)
)

; H) draw top and bottom rows with alternating white rectangles ==================
(SETQ H (SHIFT DY -2))
(SETQ Y1 1)
(SETQ Y2 (- YMAX H))
(SETQ X (- DX W W))
(SETQ W (* W 4))
(LOOP
 ((>= X XMAX))
 (FILL X Y1 W H 15)
 (FILL X Y2 W H 15)
 (INCQ X DX)
 (INCQ X DX)
)

; I) PLOT-CIRCLE center x, center y, radius [, color]
(PLOT-CIRCLE (SHIFT XRES -1) (SHIFT YRES -1) (SHIFT YRES -1) 15)


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

; muLISP-90:
; CS:57EC ... READ PIXEL: INT 10
; 57EC:
;  PUSH AX
;  PUSH BX
;  PUSH CX
;  PUSH DX
;  MOV BH,00
;  MOV AH,0D
;  INT 10   ; read pixel returns color in AL
;  POP  DX
;  POP  CX
;  POP  BX
;  SHL  BL,1 ; shift, bit 0 <- 0
;  CMP  BYTE PTR CS:[0358],04   ; 856 = 04: color deskjet
;  JZ   5820
;  MOV  AH,CS:[03A1]   ; == 929 = COLOR
;  TEST AH,80          ; COLOR == 128?   (CSMEMORY 929 128)
;  JNZ  5815        
;  CMP  AL,AH
;  POP  AX
;  JZ   5814           ; AL == 128
;  INC  BL             ; -> 
; 5814:
;  RET
; 5815:             ; AH = COLOR != 128
;  AND  AH,7F       ; 01111111
;  CMP  AL,AH       ; 
;  POP  AX
;  JNZ  581F        ; not ame color 
;  INC  BL          ; same color
; 581F:
;  RET
; 5820:
;  AND  AL,[00D6]   ; 214 = 11010110
;  JMP 581A
; 5826:
;  MOV  CX,[00A0]   ; 160
;  MOV  AX,[00A2]   ; 162


; TIFF file format
; WRITE-SCREEN always creates a monochrome image with one plane.
; Only the pixels with the given color index (at CS:929) are dumped.
; (CSMEMORY 929 0)     0: black pixels to white
; (CSMEMORY 929 0)     1: white pixels to white
; (CSMEMORY 929 128) 128: all non black pixels are dumped as white
;
(CSMEMORY 928 0) ; affects TIF orientation: 0 640x480, 1: 480x640
(CSMEMORY 929 0) ; affects TIF output: 0: only color index 0 (black) -> white
(OPEN-OUTPUT-FILE "VIDEO0.TIF" T)
(WRITE-SCREEN (OUTPUT-FILE))
(CLOSE-OUTPUT-FILE "VIDEO0.TIF")
; 
(CSMEMORY 929 15) ; output only color 15 (white) -> white
(OPEN-OUTPUT-FILE "VIDEO15.TIF" T)
(WRITE-SCREEN (OUTPUT-FILE))
(CLOSE-OUTPUT-FILE "VIDEO15.TIF")
; 
; (CSMEMORY 856 4) ; color deskjet
; (PRINT-SCREEN)
; (CSMEMORY 856 0) ; restore


; -----------------------------------------
; helper functions for BMP export
; -----------------------------------------
; Write an integer 16-bit word in Intel format to the open output stream
;
; Parameters:
; W unsigned 16-bit integer
(DEFUN WRITE-WORD(W)
 (WRITE-BYTE (LOGAND W 255))            ; low byte
 (WRITE-BYTE (LOGAND (SHIFT W -8) 255)) ; highbyte
)
; -----------------------------------------
; Write an integer 32-bit word in Intel format to the open output stream
;
; Parameters:
; DW unsigned 32-bit integer
(DEFUN WRITE-DWORD(DW)
 (WRITE-BYTE (LOGAND DW 255)) ; low byte
 (SETQ DW (SHIFT DW -8))
 (WRITE-BYTE (LOGAND DW 255))
 (SETQ DW (SHIFT DW -8))
 (WRITE-BYTE (LOGAND DW 255))
 (SETQ DW (SHIFT DW -8))
 (WRITE-BYTE (LOGAND DW 255)) ; high byte
)
; -----------------------------------------

; -----------------------------------------
; BMP Export
; Write the VGA 16-color screen to a BMP file.
; VIDEO-MODE 18: 640 x 480 x 16 colors.
; (XRES x YRES may be smaller than 640 x 480, in this case
; only a segment of the screen will be saved).
; Requires WRITE-WORD and WRITE-DWORD.
;
; Parameters:
; FILE-NAME  string, output file name
; XRES, YRES integer, screen size: number 
;            of pixels in horz resp. vert direction
; -----------------------------------------
(DEFUN WRITE-BMP ( FILE-NAME XRES YRES 
                   bfHdrSize biHdrSize cmapSize biImageSize 
                   X Y IDX0 IDX1 )
 ; open output stream
 (OPEN-OUTPUT-FILE FILE-NAME T) ; overwrite if output file exists
 
 (SETQ bfHdrSize 14)         ; BITMAP_FILE header size
 (SETQ biHdrSize 40)         ; BITMAP_INFO header size
 (SETQ cmapSize (* 16 4))    ; colormap size
 (SETQ biImageSize (* (/ XRES 2) YRES)) ; bitmap size (4 bits per pixel
 
 ; BITMAP_FILE header 14 bytes
 ; bfType
 (WRITE-BYTE 66) ; 'B'
 (WRITE-BYTE 77) ; 'M'
 ; bfSize file size = 14 + 104 + 640/2*480 = 153718
 (WRITE-DWORD (+ bfHdrSize biHdrSize cmapSize biImageSize)) 
 (WRITE-DWORD 0) ; word reserved1, reserved2
 ; bfOffset
 (WRITE-DWORD (+ bfHdrSize biHdrSize cmapSize)) ; offset to data = 14+104 = 118

 ; BITMAP_INFO header 40 + 4*16 = 104 bytes
 (WRITE-DWORD biHdrSize)     ; biHdrSize
 (WRITE-DWORD XRES)   ; biwidth
 (WRITE-DWORD YRES)   ; biHeight
 (WRITE-WORD 1)       ; biPlanes:      1 bit plane
 (WRITE-WORD 4)       ; biBitCount:    4 bits per pixel
 (WRITE-DWORD 0)      ; biCompression: none
 (WRITE-DWORD biImageSize) ; bytes for bitmap
 ; 110 [dots/inch] / 25.4 [mm/inch] * 1000 [mm] = 4330.7
 (WRITE-DWORD 4331)   ; biXPelsPerMeter
 (WRITE-DWORD 4331)   ; biYPelsPerMeter
 (WRITE-DWORD 0)      ; biClrUsed
 (WRITE-DWORD 0)      ; biClrImportant
 ; offset 54: palette of 16 RGB standard colors  DOSBox
 ; dark colors
 (WRITE-DWORD 0)        ; dk. black    RRGGBB   0   0   0
 (WRITE-DWORD 128)      ; dk. blue   00000080   0   0 168
 (WRITE-DWORD 32768)    ; dk. green  00008000   0 168   0
 (WRITE-DWORD 32896)    ; dk. cyan   00008080   0 168 168
 (WRITE-DWORD 8388608)  ; dk. red    00800000 168   0   0
 (WRITE-DWORD 8388736)  ; dk. violet 00800080 168   0 168
 (WRITE-DWORD 8421376)  ; dk. yellow 00808000 168  84   0
 (WRITE-DWORD 12632256) ; dk. white  00C0C0C0 168 168 168
 ; light colors
 (WRITE-DWORD 8421504)  ; lt. black  00808080  84  84  84
 (WRITE-DWORD 255)      ; lt. blue   000000FF  84  84 252
 (WRITE-DWORD 65280)    ; lt. green  0000FF00  84 252  84
 (WRITE-DWORD 65535)    ; lt. cyan   0000FFFF  84 252 252
 (WRITE-DWORD 16711680) ; lt. red    00FF0000 252  84  84
 (WRITE-DWORD 16711935) ; lt. violet 00FF00FF 252  84 252
 (WRITE-DWORD 16776960) ; lt. yellow 00FFFF00 252 252  84
 (WRITE-DWORD 16777215) ; lt. white  00FFFFFF 252 252 252
 
 ; scan from bottom to top
 (SETQ Y YMAX)
 (LOOP
  ((< Y 0))
  (SETQ X 0)
  (LOOP
   ((> X XMAX))
   ; 2 pixels of 4 bits each packed into one byte
   (SETQ IDX0 (READ-DOT X Y))
;   (PLOT-DOT X Y (+ IDX0 8)) ; show some feedback
   (INCQ X)
   (SETQ IDX1 (READ-DOT X Y))
   (PLOT-DOT X Y (+ IDX1 8)) ; show some feedback
   (INCQ X)
   (WRITE-BYTE (+ (SHIFT IDX0 4) IDX1)) ; pack two 4 bit indices into byte 
  )
  (DECQ Y)
 )
 ; close output stream
 (CLOSE-OUTPUT-FILE FILE-NAME)
)
; -----------------------------------------

(WRITE-BMP "VIDEO.BMP" XRES YRES )

; pause
(SETQ I 32000)
(SETQ I 0)
(LOOP
 ((EQ 0 I))
 (DECQ I)
)


; text mode
(VIDEO-MODE 3)

; independent of video mode: always text screen size
(SETQ X (COLUMNS))
(SETQ Y (ROWS))

(PRINC "Graphics Limits: ")
(PRIN1 XMAX)
(PRINC " x ")
(PRINT YMAX)

(PRINC "Text Resolution: ")
(PRIN1 X)
(PRINC " x ")
(PRINT Y)


; (SYSTEM)