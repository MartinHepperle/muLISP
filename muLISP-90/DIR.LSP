;
; Return a list of files with properties:
;
; NAME   string file name, up to 8 characters
; EXT    string extension, up to 3 characters
; SIZE   integer number of bytes or string <DIR>
; ISDIR  T if this is a directory, else NIL
; DATE   string dd.mm.yyyy (country-specific)
; TIME   string hh:mm      (country-specific)
;
; The list will start with '.' and '..' followed by
; entries for directories and regular files;
;
; Application Examples
; ====================
; Accessing the attributes of the nth file: (0-based)
; get a list with all attribtes of the entry 5:
; (CDR (NTH 5 (DIR)))
;
; Get the entry 5 and access its properties:
; (SETQ THE-ENTRY (CDR (NTH 5 (DIR))))
; (GET THE-ENTRY 'NAME)
; (GET THE-ENTRY 'SIZE)
;
; Get SIZE of entry 3:
;(GET (NTH 3 (DIR)) 'SIZE)
; or, as DIR is slow because it uses the COMMAND interpreter
; so that saving its result is more efficient:
;(SETQ THEDIR (DIR))
;(GET (NTH 3 THEDIR) 'SIZE)
;
(DEFUN DIR(FILES IDX LINE THEFILE NAME EXT SIZE DATE TIME)

; use environment variable COMSPEC
(EXECUTE (GETSET 'COMSPEC) "/C DIR > DIR.TXT")

(OPEN-INPUT-FILE "DIR.TXT")
; skip header lines                                     ; and "." and ".."
(READ-LINE)(READ-LINE)(READ-LINE)(READ-LINE)(READ-LINE) ; (READ-LINE)(READ-LINE)
(SETQ FILES NIL)
(SETQ IDX 0)
(LOOP
 ((NOT (LISTEN)))
 (SETQ LINE (READ-LINE))
 ((EQ (SUBSTRING LINE 0 0) " ")) ; end of list
 
 ; parse directory list entry
 (SETQ NAME (STRING-TRIM " " (SUBSTRING LINE  0  7)))
 (SETQ EXT  (STRING-TRIM " " (SUBSTRING LINE  9 11)))
 (SETQ SIZE (STRING-TRIM " " (SUBSTRING LINE 13 30)))
 (SETQ DATE (STRING-TRIM " " (SUBSTRING LINE 32 41)))
 (SETQ TIME (STRING-TRIM " " (SUBSTRING LINE 43 47)))
 
 ; if NAME is not . or .. and if EXT is not blank, then append EXT to THEFILE
 (SETQ THEFILE (IF(OR(EQ NAME ".")(EQ NAME "..")(EQ EXT "")) NAME (PACK* NAME "." EXT)))
 (PUT THEFILE 'TIME TIME)
 (PUT THEFILE 'DATE DATE)
 ; remove 1000' separators, leaves <DIR> in SIZE
 (PUT THEFILE 'SIZE (READ-FROM-STRING(PACK (REMOVE "." (UNPACK SIZE)))))
 (COND
  ((EQ "<DIR>" SIZE)
    (PUT THEFILE 'SIZE 0)
    (PUT THEFILE 'ISDIR T))
 )
 (PUT THEFILE 'EXT  EXT)
 (PUT THEFILE 'NAME NAME)
 (PUT THEFILE 'IDX IDX)

 ; append to list
 (SETQ FILES (APPEND FILES (LIST THEFILE)))
 (INCQ IDX)
)
 (CLOSE-INPUT-FILE "DIR.TXT")
 (DELETE-FILE "DIR.TXT")
 
 ; return the list of files
 FILES
)

; not very efficient because of LENGTH
(DEFUN RIGHT-PAD (S N)
 ((>= (LENGTH S) N)S)
 (RIGHT-PAD (PACK* S " ") N)
)
(DEFUN LEFT-PAD (S N)
 ((>= (LENGTH S) N)S)
 (LEFT-PAD (PACK* " " S) N)
)

; Print a directory listing similar to the DIR command in COMMAND.COM.
; (LS(DIR))
(DEFUN LS(LST N
          THEFILE)

 ((NULL LST)(PRIN1 N)(PRINC " files")(TERPRI)) ; end of list
 
 (IF(NULL N)(SETQ N 1); first invocation without N
            (INCQ N)) ; subsequent invocation with N
 (SETQ THEFILE (CAR LST))
 (PRINC (PACK* (RIGHT-PAD (GET THEFILE 'NAME) 9) 
               (RIGHT-PAD (GET THEFILE 'EXT)  4)
               (LEFT-PAD  (IF (GET THEFILE 'ISDIR) "DIR" (GET THEFILE 'SIZE)) 12) 
               (LEFT-PAD  (GET THEFILE 'DATE) 11) 
               (LEFT-PAD  (GET THEFILE 'TIME)  6)))
 (TERPRI)
 ; handle the rest of the file list
 (LS(CDR LST)N)
)
