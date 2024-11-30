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
; Expressions are supplied as list of algebraic expressions in
; monadic or dyadic form:
; monadic operators are followed by one argument 
;   SIN COS TAN EXP LN
; dyadic operators are placed between their two arguments
;   + - * / **
;
; Examples
; (SIN X) (COS X) (EXP 2) (LN 2)
; (1 + X) (1 - X) ( 2 * X) (2 / X) (X ** 2)
;
; more complex tests:
; $ DERIV '((SIN (X ** 2)) + (COS (X ** 2))) 'X)
; $ (((COS (X ** 2)) * ((2 * 1) * (X ** 1))) + (- ((SIN (X ** 2)) * ((2 * 1) * (X ** 1)))))
; simplified:
; 2 * X * ( COS (X ** 2) - SIN (X ** 2))
; correct.
;
; $ (DERIV '(((SIN X) ** 2) + ((COS X) ** 2)) 'X)
; $ (((2 * ((COS X) * 1)) * ((SIN X) ** 1)) + ((2 * (- ((SIN X) * 1))) * ((COS X) ** 1)))
; simplified
; 2 * (COS X) * (SIN X) - 2 * (SIN X) * (COS X)
; which is zero as sin(x)**2 + cos(x)**2 = 1
; correct.

; recognizer predicates
(DEFUN CONSTANT-P (EXPR)  (NUMBERP EXPR) )
(DEFUN VARIABLE-P (EXPR)  (SYMBOLP EXPR) )

; (NEGATION-P '(- 12)) -> T
(DEFUN NEGATION-P(EXPR)
 (IF (LISTP EXPR) 
  (IF (NULL(CDDR EXPR)) (EQ (CAR EXPR) '-))
 )
)
; (UNARY-MATH-P '(SIN X) 'SIN) -> T
(DEFUN UNARY-MATH-P(EXPR PREFIX)
 (IF (LISTP EXPR) 
  (IF (NULL(CDDR EXPR)) (EQ (FIRST EXPR) PREFIX))
 )
)
; (DYADIC-MATH-P '(1 + 2) '+) -> T
(DEFUN DYADIC-MATH-P(EXPR INFIX-SYM)
 (IF (LISTP EXPR) 
  (IF (NULL(CDDR EXPR)) NIL (EQ (CADR EXPR) INFIX-SYM))
 )
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
(DEFUN MAKE-LN          (EXPR)        (LIST 'LN  EXPR))

(DEFUN CONST-VAL     (CONST-EXPR)    CONST-EXPR)
(DEFUN MAKE-CONSTANT (NUMERIC-ATOM)  NUMERIC-ATOM)

(DEFUN VAR-NAME      (VARIABLE)      VARIABLE)
(DEFUN MAKE-VARIABLE (SYMBOLIC-ATOM) SYMBOLIC-ATOM)

; extract operands from (A B C)
; B
(DEFUN OPERAND(EXPR)  (CADR EXPR) )
; A
(DEFUN OPERAND1(EXPR) (CAR EXPR) )
; C
(DEFUN OPERAND2(EXPR) (CADDR EXPR) )

; first element of BASE ** EXPONENT
(DEFUN BASE (EXPR)    (CAR EXPR))
; 3rd element of BASE ** EXPONENT
(DEFUN EXPONENT(EXPR) (CADDR EXPR))
; 2nd element of monadic function (FUNC ARGUMENT)
(DEFUN ARGUMENT(EXPR) (CADR EXPR))

;
; main worker function
; apply each differentiation rule until one succeeds
;
(DEFUN DERIV(E V)
 (COND
  ; d1/dX -> 0
  ((CONSTANT-P E) (MAKE-CONSTANT 0))
  ; dA/dX ->0, dX/dX -> 1
  ((VARIABLE-P E) (IF (EQ (VAR-NAME E) (VAR-NAME V)) 
                      (MAKE-CONSTANT 1)
                      (MAKE-CONSTANT 0)
  ))
  ; d(-A)/dX -> -dA/dX
  ((NEGATION-P E) (MAKE-NEGATION (DERIV (OPERAND E) V)))
  ; d(A * B)/dX -> A*dB/dX + dB*dA/dX
  ((PRODUCT-P E)  (MAKE-SUM (MAKE-PRODUCT (OPERAND1 E) (DERIV (OPERAND2 E) V))
                            (MAKE-PRODUCT (OPERAND2 E) (DERIV (OPERAND1 E) V))
  ))
  ; d(A / B)/dX -> (B*(dA/dX) - A*(dB/dX)) / B**2
  ((QUOTIENT-P E) (MAKE-QUOTIENT
                       (MAKE-DIFFERENCE 
                            (MAKE-PRODUCT (OPERAND2 E) (DERIV (OPERAND1 E) V))
                            (MAKE-PRODUCT (OPERAND1 E) (DERIV (OPERAND2 E) V)) )
                       (MAKE-POWER (OPERAND2 E) (MAKE-CONSTANT 2) )
  ))
  ; d(A + B)/dX -> dA/dX + dB/dX
  ((SUM-P E)      (MAKE-SUM (DERIV (OPERAND1 E) V) (DERIV (OPERAND2 E) V)))
  ; d(A - B)/dX -> dA/dX - dB/dX
  ((DIFFERENCE-P E) (MAKE-DIFFERENCE (DERIV (OPERAND1 E) V) (DERIV (OPERAND2 E) V)))
  ; d(A ** B)/dX -> B * A**(B-1) * dA/dX  +  ln(A) * dB/dX * A**B 
  ((POWER-P E) (MAKE-SUM (MAKE-PRODUCT
                            (MAKE-PRODUCT (EXPONENT E) (DERIV (BASE E) V))
                            (MAKE-POWER (BASE E)
                             (IF (CONSTANT-P (EXPONENT E))
                               (MAKE-CONSTANT (- (CONST-VAL (EXPONENT E)) 1))
                               (MAKE-DIFFERENCE (EXPONENT E) 1))))
                         (MAKE-PRODUCT (MAKE-PRODUCT (MAKE-LN (BASE E)) (DERIV (EXPONENT E) V)) E)
  ))
  ; d(EXP A)/dX -> (EXP A) * dA/dX
  ((EXPONENTIAL-P E) (MAKE-PRODUCT E (DERIV (ARGUMENT E) V)))
  ; d(LN A)/dX -> dA/dX / A
  ((LOGARITHM-P E)   (MAKE-QUOTIENT (DERIV (ARGUMENT E) V) (ARGUMENT E)))
  ; d(SIN A)/dX -> (COS X)*dA/dX
  ((SINE-P E)                 (MAKE-PRODUCT (MAKE-COSINE (ARGUMENT E)) (DERIV (ARGUMENT E) V)))
  ; d(COS A)/dX -> -(SIN X)*dA/dX
  ((COSINE-P E) (MAKE-NEGATION(MAKE-PRODUCT (MAKE-SINE (ARGUMENT E))   (DERIV (ARGUMENT E) V))))
  ; d(TAN A)/dX -> d((SIN A) / (COS A))/dX
  ((TAN-P E) (DERIV (MAKE-QUOTIENT (MAKE-SINE (ARGUMENT E)) (MAKE-COSINE (ARGUMENT E))) V))
 )
)
