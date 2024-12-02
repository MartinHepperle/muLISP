;
; Symbolic differentiation program.
;
; muLISP-90 Implementation according to
; Robert D. Cameron, Anthony H. Dixon,
;  "Symbolic Computing with LISP",
;   Prentice Hall, 1992.
;
; Martin Hepperle, 2024
;
; Expressions must be supplied as a nested list of algebraic 
; expressions in monadic or dyadic form.
; monadic operators are followed by one argument 
;   SIN COS TAN EXP LN
; dyadic operators are placed between their two arguments
;   + - * / **
;
; Examples
; (SIN X) (COS X) (EXP 2) (LN 2)
; (1 + X) (1 - X) ( 2 * X) (2 / X) (X ** 2)
;
; Application examples
; ====================
; $ (DERIV '(SIN X) 'X)
; (COS X)
;
; $ (DERIV '(X ** 3) 'X)
; (3 * (X ** 2))
; 
; $ (DERIV '(X ** X) 'X)
; ((X * (X ** (X - 1))) + ((LN X) * (X ** X)))
;
; more complex examples:
; $ (DERIV '((SIN (X ** 2)) + (COS (X ** 2))) 'X)
; (((COS (X ** 2)) * ((2 * 1) * (X ** 1))) + (- ((SIN (X ** 2)) * ((2 * 1) * (X ** 1)))))
; simplified:
; 2 * X * ( COS (X ** 2) - SIN (X ** 2) )
; correct.
;
; $ (DERIV '(((SIN X) ** 2) + ((COS X) ** 2)) 'X)
; $ (((2 * ((COS X) * 1)) * ((SIN X) ** 1)) + ((2 * (- ((SIN X) * 1))) * ((COS X) ** 1)))
; simplified
; 2 * ((COS X) * (SIN X) - (SIN X) * (COS X))
; correct.

; recognizer predicates
(DEFUN CONSTANT-P (EXPR)  (NUMBERP EXPR) )
(DEFUN VARIABLE-P (EXPR)  (SYMBOLP EXPR) )

; (NEGATION-P '(- 12)) -> T
(DEFUN NEGATION-P(EXPR)
 (IF (LISTP EXPR)  (IF (NULL(CDDR EXPR)) (EQ (CAR EXPR) '-)))
)
; (UNARY-MATH-P '(SIN X) 'SIN) -> T
(DEFUN UNARY-MATH-P(EXPR PREFIX)
 (IF (LISTP EXPR)  (IF (NULL(CDDR EXPR)) (EQ (FIRST EXPR) PREFIX)))
)
; (DYADIC-MATH-P '(1 + 2) '+) -> T
(DEFUN DYADIC-MATH-P(EXPR INFIX-SYM)
 (IF (LISTP EXPR)  (IF (NULL(CDDR EXPR)) NIL (EQ (CADR EXPR) INFIX-SYM)))
)

(DEFUN EXPONENTIAL-P(EXPR) (UNARY-MATH-P EXPR 'EXP) )
(DEFUN LOGARITHM-P(EXPR)   (UNARY-MATH-P EXPR 'LN) )
(DEFUN SINE-P(EXPR)        (UNARY-MATH-P EXPR 'SIN) )
(DEFUN COSINE-P(EXPR)      (UNARY-MATH-P EXPR 'COS) )
(DEFUN TAN-P(EXPR)         (UNARY-MATH-P EXPR 'TAN) )

(DEFUN PRODUCT-P    (EXPR) (DYADIC-MATH-P EXPR '*))
(DEFUN QUOTIENT-P   (EXPR) (DYADIC-MATH-P EXPR '/))
(DEFUN SUM-P        (EXPR) (DYADIC-MATH-P EXPR '+))
(DEFUN DIFFERENCE-P (EXPR) (DYADIC-MATH-P EXPR '-))
(DEFUN POWER-P      (EXPR) (DYADIC-MATH-P EXPR '**))

; constructors return lists
(DEFUN MAKE-NEGATION    (EXPR)        (LIST '- EXPR))
(DEFUN MAKE-PRODUCT     (EXPR1 EXPR2) (LIST EXPR1 '* EXPR2))
(DEFUN MAKE-QUOTIENT    (EXPR1 EXPR2) (LIST EXPR1 '/ EXPR2))
(DEFUN MAKE-SUM         (EXPR1 EXPR2) (LIST EXPR1 '+ EXPR2))
(DEFUN MAKE-DIFFERENCE  (EXPR1 EXPR2) (LIST EXPR1 '- EXPR2))
(DEFUN MAKE-POWER       (EXPR1 EXPR2) (LIST EXPR1 '** EXPR2))
(DEFUN MAKE-EXPONENTIAL (EXPR)        (LIST 'EXP EXPR))
(DEFUN MAKE-SINE        (EXPR)        (LIST 'SIN EXPR))
(DEFUN MAKE-COSINE      (EXPR)        (LIST 'COS EXPR))
(DEFUN MAKE-LOGARITHM   (EXPR)        (LIST 'LN  EXPR))

(DEFUN CONST-VAL     (CONST-EXPR)    CONST-EXPR)
(DEFUN MAKE-CONSTANT (NUMERIC-ATOM)  NUMERIC-ATOM)

(DEFUN VAR-NAME      (VARIABLE)      VARIABLE)
(DEFUN MAKE-VARIABLE (SYMBOLIC-ATOM) SYMBOLIC-ATOM)

; extract operands from (A op B)
; A
(DEFUN OPERAND1(EXPR) (CAR EXPR) )
; B
(DEFUN OPERAND2(EXPR) (CADDR EXPR) )

; first element of BASE ** EXPONENT
(DEFUN BASE (EXPR)    (CAR EXPR))
; 3rd element of BASE ** EXPONENT
(DEFUN EXPONENT(EXPR) (CADDR EXPR))
; 2nd element of monadic function (FUNC ARGUMENT)
(DEFUN ARGUMENT(EXPR) (CADR EXPR))

;
; differentiate algebraic expression E with respect to variable V
; and simplify the result
;
(DEFUN DERIV(E V)
 (SIMP(SIMP(SIMP(_DERIV E V))))
)

;
; main worker function
; apply each differentiation rule until one succeeds
;
(DEFUN _DERIV(E V)
 (COND
  ; d1/dX -> 0
  ((CONSTANT-P E) (MAKE-CONSTANT 0))
  ; dA/dX ->0, dX/dX -> 1
  ((VARIABLE-P E) (IF (EQ (VAR-NAME E) (VAR-NAME V)) 
                      (MAKE-CONSTANT 1)
                      (MAKE-CONSTANT 0)
  ))
  ; d(-A)/dX -> -dA/dX
  ((NEGATION-P E) (MAKE-NEGATION (_DERIV (ARGUMENT E) V)))
  ; d(A * B)/dX -> A*dB/dX + dB*dA/dX
  ((PRODUCT-P E)  (MAKE-SUM (MAKE-PRODUCT (OPERAND1 E) (_DERIV (OPERAND2 E) V))
                            (MAKE-PRODUCT (OPERAND2 E) (_DERIV (OPERAND1 E) V))
  ))
  ; d(A / B)/dX -> (B*(dA/dX) - A*(dB/dX)) / B**2
  ((QUOTIENT-P E) (MAKE-QUOTIENT
                       (MAKE-DIFFERENCE 
                            (MAKE-PRODUCT (OPERAND2 E) (_DERIV (OPERAND1 E) V))
                            (MAKE-PRODUCT (OPERAND1 E) (_DERIV (OPERAND2 E) V)) )
                       (MAKE-POWER (OPERAND2 E) (MAKE-CONSTANT 2) )
  ))
  ; d(A + B)/dX -> dA/dX + dB/dX
  ((SUM-P E)      (MAKE-SUM (_DERIV (OPERAND1 E) V) (_DERIV (OPERAND2 E) V)))
  ; d(A - B)/dX -> dA/dX - dB/dX
  ((DIFFERENCE-P E) (MAKE-DIFFERENCE (_DERIV (OPERAND1 E) V) (_DERIV (OPERAND2 E) V)))
  ; d(A ** B)/dX -> B * A**(B-1) * dA/dX  +  ln(A) * dB/dX * A**B 
  ((POWER-P E) (MAKE-SUM (MAKE-PRODUCT
                           (MAKE-PRODUCT (EXPONENT E) (_DERIV (BASE E) V))
                           (MAKE-POWER (BASE E)
                             (IF (CONSTANT-P (EXPONENT E))
                               (MAKE-CONSTANT (- (CONST-VAL (EXPONENT E)) 1))
                               (MAKE-DIFFERENCE (EXPONENT E) 1))))
                         (MAKE-PRODUCT (MAKE-PRODUCT (MAKE-LOGARITHM (BASE E)) (_DERIV (EXPONENT E) V)) E)
  ))
  ; d(EXP A)/dX -> (EXP A) * dA/dX
  ((EXPONENTIAL-P E) (MAKE-PRODUCT E (_DERIV (ARGUMENT E) V)))
  ; d(LN A)/dX -> dA/dX / A
  ((LOGARITHM-P E)   (MAKE-QUOTIENT (_DERIV (ARGUMENT E) V) (ARGUMENT E)))
  ; d(SIN A)/dX -> (COS X)*dA/dX
  ((SINE-P E)                 (MAKE-PRODUCT (MAKE-COSINE (ARGUMENT E)) (_DERIV (ARGUMENT E) V)))
  ; d(COS A)/dX -> -(SIN X)*dA/dX
  ((COSINE-P E) (MAKE-NEGATION(MAKE-PRODUCT (MAKE-SINE (ARGUMENT E))   (_DERIV (ARGUMENT E) V))))
  ; d(TAN A)/dX -> d((SIN A) / (COS A))/dX
  ((TAN-P E) (_DERIV (MAKE-QUOTIENT (MAKE-SINE (ARGUMENT E)) (MAKE-COSINE (ARGUMENT E))) V))
  ; default
  (T (PRINC "UNKNOWN EXPRESSION: ")(PRINT E) E)
 )
)

; simplifies one level, may leave nested expressions of the form (0 * X)
; therefore may have to be called multiple times.
; $ (SIMP '((0 * 12) + 9))
; (0 + 9)
; $ (SIMP(0 + 9))
; 9
; $ (SIMP(SIMP '((0 * 12) + 9)))
; 9
(DEFUN SIMP(EXPR)

 (COND
  ((CONSTANT-P EXPR) ; (PRIN1 CONST:)(PRINT EXPR)
                     (MAKE-CONSTANT EXPR))
  ((VARIABLE-P EXPR) ; (PRIN1 VAR:)(PRINT EXPR)
                     (MAKE-VARIABLE EXPR))
 
  ((PRODUCT-P EXPR)  ; (PRIN1 PRODUCT:)(prin1 (operand1 expr))(terpri)(spaces 8)(print (operand2 expr))
                     (COND
                        ; A * 1 -> A
                        ((EQ (OPERAND1 EXPR) 1) (SIMP(OPERAND2 EXPR)))
                        ; 1 * A -> A
                        ((EQ (OPERAND2 EXPR) 1) (SIMP(OPERAND1 EXPR)))
                        ; 0 * A -> 0
                        ((ZEROP (OPERAND1 EXPR)) 0)
                        ; A * 0 -> 0
                        ((ZEROP (OPERAND2 EXPR)) 0)
                        ; A * A -> A ** 2
                        ((EQ(OPERAND1 EXPR)(OPERAND2 EXPR) ) (MAKE-POWER (SIMP (OPERAND1 EXPR))(MAKE-CONSTANT 2)))
                        ; number * number -> evaluate
                        ((AND(CONSTANT-P(OPERAND1 EXPR))(CONSTANT-P(OPERAND2 EXPR))) (* (OPERAND1 EXPR)(OPERAND2 EXPR)))
                        ; default
                        (T (MAKE-PRODUCT (SIMP (OPERAND1 EXPR))(SIMP (OPERAND2 EXPR))))
                     )
  )
  ((QUOTIENT-P EXPR) ; (PRIN1 QUOTIENT:)(prin1 (operand1 expr))(terpri)(spaces 9)(print (operand2 expr))
                     (COND
                        ; 0 / A -> 0
                        ((ZEROP (OPERAND1 EXPR)) 0)
                        ; number / number -> evaluate (may lead to fractional numbers)
                        ((AND(CONSTANT-P(OPERAND1 EXPR))(CONSTANT-P(OPERAND2 EXPR))) (/ (OPERAND1 EXPR)(OPERAND2 EXPR)))
                        ; default
                        (T (MAKE-QUOTIENT (SIMP (OPERAND1 EXPR))(SIMP (OPERAND2 EXPR))))
                     )
  )
  ((SUM-P EXPR)     ; (PRIN1 SUM:)(prin1 (operand1 expr))(terpri)(spaces 4)(print (operand2 expr))
                     (COND
                        ; 0 + A -> A
                        ((ZEROP (OPERAND1 EXPR)) (SIMP(OPERAND2 EXPR)))
                        ; A + 0 -> A
                        ((ZEROP (OPERAND2 EXPR)) (SIMP(OPERAND1 EXPR)))
                        ; number + number -> evaluate
                        ((AND(CONSTANT-P(OPERAND1 EXPR))(CONSTANT-P(OPERAND2 EXPR))) (+ (OPERAND1 EXPR)(OPERAND2 EXPR)))
                        ; A + A -> 2 * A
                        ((EQ (OPERAND1 EXPR)(OPERAND2 EXPR)) (MAKE-PRODUCT (MAKE-CONSTANT 2)(SIMP (OPERAND1 EXPR))))
                        ; default
                        (T (MAKE-SUM (SIMP (OPERAND1 EXPR))(SIMP (OPERAND2 EXPR))))
                     )
  )
  ((DIFFERENCE-P EXPR) ; (PRIN1 DIFFERENCE:)(prin1 (operand1 expr))(terpri)(spaces 11)(print (operand2 expr))
                     (COND
                        ; 0 - A -> -A
                        ((ZEROP (OPERAND1 EXPR)) (MAKE-NEGATION (SIMP(OPERAND2 EXPR))) )
                        ; A - 0 -> A
                        ((ZEROP (OPERAND2 EXPR)) (SIMP(OPERAND1 EXPR)) )
                        ; A - A -> 0
                        ((EQ (OPERAND1 EXPR)(OPERAND2 EXPR)) 0)
                        ; number - number -> evaluate
                        ((AND(CONSTANT-P(OPERAND1 EXPR))(CONSTANT-P(OPERAND2 EXPR))) (- (OPERAND1 EXPR)(OPERAND2 EXPR)))
                        (T (MAKE-DIFFERENCE (SIMP(OPERAND1 EXPR)) (SIMP(OPERAND2 EXPR))))
                     )
  )
  ((POWER-P EXPR)  ; (PRIN1 POWER:)(prin1 (operand1 expr))(terpri)(spaces 6)(print (operand2 expr))
                     (COND
                        ; A ** 1 -> A
                        ((EQ (OPERAND2 EXPR) 1) (SIMP (OPERAND1 EXPR)))
                        ; A ** 0 -> 1
                        ((ZEROP(OPERAND2 EXPR)) (MAKE-CONSTANT 1))
                        ; default
                        (T (MAKE-POWER (SIMP (OPERAND1 EXPR))(SIMP(OPERAND2 EXPR))))
                     )
  )
  ((LOGARITHM-P EXPR) ; (PRIN1 LN:)(print (ARGUMENT expr))
                     (MAKE-LOGARITHM (SIMP (ARGUMENT EXPR)))
  )
  ((SINE-P EXPR)     ; (PRIN1 SIN:)(print (ARGUMENT expr))
                     (MAKE-SINE (SIMP (ARGUMENT EXPR)))
  )
  ((COSINE-P EXPR)   ; (PRIN1 COS:)(print (ARGUMENT expr))
                     (MAKE-COSINE (SIMP (ARGUMENT EXPR)))
  )
  ((NEGATION-P EXPR) ; (PRIN1 NEG:)(print (ARGUMENT expr))
                     (COND
                        ; - number -> -number
                        ((CONSTANT-P(ARGUMENT EXPR)) (- 0 (ARGUMENT EXPR)))
                        (T(MAKE-NEGATION (SIMP(ARGUMENT EXPR))))
                        )
  )
  ; default
  (T                 ; (PRINT default:)(print (operand1 expr))(print (operand2 expr)) 
   EXPR)
 ) ; COND
)
