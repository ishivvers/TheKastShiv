; $Id: lmfit.pro,v 1.10 1998/02/06 17:00:50 slett Exp $
;
; Copyright (c) 1988-1998, Research Systems, Inc.  All rights reserved.
;       Unauthorized reproduction prohibited.

function mylmfit, x, y, a, weights=weights, fita=fita, $
	                Function_Name = Function_Name, $
                        alpha=alpha,covar=covar,$
                        itmax=itmax,iter=iter,tol=tol,chisq=chisq, $
                        itmin=itmin,double=double,$
                        SIGMA=SIGMA,CONVERGENCE=CONVERGENCE
;+
; NAME:
;       LMFIT
;
; PURPOSE:
;       Non-linear least squares fit to a function of an arbitrary 
;       number of parameters.  The function may be any non-linear 
;       function.  If available, partial derivatives can be calculated by 
;       the user function, else this routine will estimate partial derivatives
;       with a forward difference approximation.
;
; CATEGORY:
;       E2 - Curve and Surface Fitting.
;
; CALLING SEQUENCE:
;       Result = LMFIT(X, Y, A, FITA=FITA, FUNCTION_NAME = name, ITER=ITER,$
;                ITMAX=ITMAX, SIGMA=SIGMA, TOL=TOL, WEIGHTS=WEIGHTS,$
;                CONVERGENCE=CONVERGENCE, ITMIN=ITMIN, DOUBLE=DOUBLE)
;
; INPUTS:
;   X:  A row vector of independent variables.  This routine does
;       not manipulate or use values in X, it simply passes X
;       to the user-written function.
;
;   Y:  A row vector containing the dependent variable.
;
;   A:  A vector that contains the initial estimate for each parameter.  
;
; WEIGHTS: 
;   Set this keyword equal to a vector of fitting weights for Y(i). This 
;   vector must be the same length as X and Y.  If instrumental (Gaussian)
;   weighting is desired, that is the measurement errors or standard deviations 
;   of Y are known (SIGMA), then WEIGHTS should be  set to 1/(SIGMA^2.) 
;   Or if statistical (Poisson) weighting is appropriate, set WEIGHTS=1/Y.
;   If WEIGHTS is not specified then, no weighting is assumed (WEIGHTS=1.0).
;
; FITA:
;   A vector, with as many elements as A, which contains a Zero for
;   each fixed parameter, and a non-zero value for elements of A to 
;   fit. If not supplied, all parameters are taken to be non-fixed.
;
; KEYWORDS:
;       FUNCTION_NAME:  The name of the function (actually, a procedure) to 
;       fit.  If omitted, "LMFUNCT" is used. The procedure must be written as
;       described under RESTRICTIONS, below.
;
;       ALPHA:  The value of the Curvature matrix upon exit.
;       CHISQ:  The value of chi-squared on exit
;       CONVERGENCE: Returns 1 if the fit converges, 0 if it does
;               not meet the convergence criteria in ITMAX iterations,
;               or -1 if a singular matrix is encountered.
;	COVAR:  The value of the Covariance matrix upon exit.
;       DOUBLE: Set this keyword to force the computations to be performed 
;               in double precision.
;       ITMAX:  Maximum number of iterations. Default = 20.
;       ITMAX:  Minimum number of iterations. Default = 5.
;       ITER:   The actual number of iterations which were performed
;       SIGMA:  A vector of standard deviations for the returned parameters.
;       TOL:    The convergence tolerance. The routine returns when the
;               relative decrease in chi-squared is less than TOL in an 
;               interation. Default = 1.e-6.
;
; OUTPUTS:
;       Returns a vector containing the fitted function evaluated at the
;       input X values.  The final estimates for the coefficients are
;       returned in the input vector A.
;
; SIDE EFFECTS:
;
;       The vector A is modified to contain the final estimates for the
;       parameters.
;
; RESTRICTIONS:
;       The function to be fit must be defined and called LMFUNCT,
;       unless the FUNCTION_NAME keyword is supplied.  This function,
;       must accept a single value of X (the independent variable), and A 
;       (the fitted function's  parameter values), and return  an 
;       array whose first (zeroth) element is the evalutated function
;       value, and next n_elements(A) elements are the partial derivatives
;       with respect to each parameter in A.
;
;       If X is passed in as a double, the returned vector MUST be of
;       type double as well. Likewise, if X is a float, the returned
;       vector must also be of type float.
;
;       For example, here is the default LMFUNCT in the IDL User's Libaray.
;       which is called as : out_array = LMFUNCT( X, A )
;
;
;	function lmfunct,x,a
;
;         ;Return a vector appropriate for LMFIT
;         ;
;         ;The function being fit is of the following form:
;         ;  F(x) = A(0) * exp( A(1) * X) + A(2) = bx+A(2)
;         ;
;         ;dF/dA(0) is dF(x)/dA(0) = exp(A(1)*X)
;         ;dF/dA(1) is dF(x)/dA(1) = A(0)*X*exp(A(1)*X) = bx * X
;         ;dF/dA(2) is dF(x)/dA(2) = 1.0
;         ;
;         ;return,[[F(x)],[dF/dA(0)],[dF/dA(1)],[dF/dA(2)]]
;         ;
;         ;Note: returning the required function in this manner
;         ;    ensures that if X is double the returned vector
;         ;    is also of type double. Other methods, such as
;         ;    evaluating size(x) are also valid.
;
;        bx=A(0)*exp(A(1)*X)
;        return,[ [bx+A(2)], [exp(A(1)*X)], [bx*X], [1.0] ]
;	end
;        
;
; PROCEDURE:
;       Based upon "MRQMIN", least squares fit to a non-linear
;       function, pages 683-688, Numerical Recipies in C, 2nd Edition,
;	Press, Teukolsky, Vettering, and Flannery, 1992.
;
;       "This method is the Gradient-expansion algorithm which
;       combines the best features of the gradient search with
;       the method of linearizing the fitting function."
;
;       Iterations are performed until three consequtive iterations fail
;       to chang the chi square changes by greater than TOL, or until
;       ITMAX, but at least ITMIN,  iterations have been  performed.
;
;       The initial guess of the parameter values should be
;       as close to the actual values as possible or the solution
;       may not converge.
;
;       The function may fail to converge, or it can encounter
;       a singular matrix. If this happens, the routine will fail
;       with the Numerical Recipes error message:
;      
;
; EXAMPLE:  
;        Fit a function of the form:
;            f(x)=a(0) * exp(a(1)*x) + a(2) + a(3) * sin(x)
;
;  Define a lmfit return function:
;
;  function myfunct,x,a
;
;       ;Return a vector appropriate for LMFIT
;
;       ;The function being fit is of the following form:
;       ;  F(x) = A(0) * exp( A(1) * X) + A(2) + A(3) * sin(x)
;
;
;       ; dF(x)/dA(0) = exp(A(1)*X)
;       ; dF(x)/dA(1) = A(0)*X*exp(A(1)*X) = bx * X
;       ; dF(x)/dA(2) = 1.0
;       ; dF(x)/dA(3) = sin(x)
;
;        bx=A(0)*exp(A(1)*X)
;        return,[[bx+A(2)+A(3)*sin(x)],[exp(A(1)*X)],[bx*X],[1.0],[sin(x)]]
;     end
;
;   pro run_lmfunct
;         x=findgen(40)/20.		;Define indep & dep variables.
;         y=8.8 * exp( -9.9 * X) + 11.11 + 4.9 * sin(x)
;         sig=0.05 * y
;         a=[10.0,-7.0,9.0,4.0]		;Initial guess
;         fita=[1,1,1,1]
;         ploterr,x,y,sig
;         yfit=lmfit(x,y,a,WEIGHTS=(1/sig^2.),FITA=FITA,$
;                  SIGMA=SIGMA,FUNCTION_NAME='myfunct')
;         oplot,x,yfit
;         for i=0,3 do print,i,a(i),format='("A (",i1,")= ",F6.2)'
;  end
;
; MODIFICATION HISTORY:
;       Written, SVP, RSI, June 1996.
;       Modified, S. Lett, RSI, Dec 1997
;                               Jan 1998
;                               Feb 1998
;           
;-
       inexcept=!except
       !except=1
       eps=1e-7
       on_error,2              ;Return to caller if error
;
;      Enable Math error trapping
;
        j=check_math(0,1)

       ndata = n_elements(x)    ; # of data points
       ma = n_elements(a)       ; # of parameters
       if ma le 0 then begin
           message, 'A must have at least ONE parameter.'
       endif
       nfree = n_elements(y) - ma ; Degrees of freedom
       if nfree le 0 then message, 'LMFIT - not enough data points.'
;
;      Process the keywords
; 
       if n_elements(function_name) le 0 then function_name = "LMFUNCT"
       if n_elements(tol) eq 0 then tol = 1.e-9 ;Convergence tolerance
       if n_elements(itmin) eq 0 then itmin= 5 ;Minimum # iterations
       if n_elements(itmax) eq 0 then itmax= 50	;Maximum # iterations
       if (itmin ge itmax) then itmax=itmin
       do_double = keyword_set(double)
;
;      Prepare the FITA vector
;
       if n_elements(FITA) eq 0 then FITA = replicate(1, ma)
       if n_elements(FITA) ne ma then $
         message, 'The number of elements in FITA must equal those of A'
       FITA=fix(FITA)
;
;      Prepare the SIG vector, this is sqrt(1/WEIGHTS)
;
       if n_elements(WEIGHTS) eq 0 then WEIGHTS = replicate(1.,ndata)
       if n_elements(WEIGHTS) ne ndata then $
         message,'The number of elements in WEIGHTS must equal those of X and Y'
       weights = weights > eps
       SIG=1.0/sqrt(WEIGHTS)
;
;       If x or y or sig or a is double precision, set do_double to true
;
       If (reverse(size(a))) [1] eq 5 or $
         (reverse(size(x))) [1] eq 5 or $
         (reverse(size(y))) [1] eq 5 or $
         (reverse(size(sig))) [1] eq 5  then do_double=1
;
;
       
       if do_double then begin
           chisq=0.0D
           xx=double(x) & yy=double(y) & a=double(a)
           ssig=abs(double(sig)) > 1E-12
       endif else begin
           chisq=0.0
           xx=float(x) & yy=float(y) & a=float(a)
           ssig=abs(float(sig)) > 1E-6
       endelse

;
;       Warning! The following call is to the actual NR recipies code.
;       Direct calls to this by the user are not supported, as this
;       function call will be removed in a future version of IDL
;
       MRQMIN, function_name, xx, yy, ssig, ndata, a, fita, ma, covar, $
         alpha, chisq, alambda, $
         DOUBLE=do_double, itmin=itmin, itmax=itmax, $
         tolerance=tol, niter=iter

       convergence=1
       if alambda lt 0 then begin
           convergence=-1
           message, 'Warning: Singular Covariance Matrix Encountered, LMFIT aborted.', /INFORMATIONAL
       endif else begin
           if (iter ge itmax) then begin
               convergence=0
               message, 'Warning: Failed to Converge.', /INFORMATIONAL
           endif
       endelse
;

       diag=lindgen(ma)*(ma+1)
       SIGMA=sqrt(abs(covar[diag]))
       if do_double then yfit=dblarr(ndata) else yfit=fltarr(ndata)
       for i=0,ndata-1 do $
         yfit[i] = (call_function(function_name,xx[i],a))[0]

;
;    Check for Math Errors
;
       errs=['Divide by 0','Underflow','Overflow','Illegal Operand']
       j=check_math()
       for i=4,7 do if ISHFT(j,-i) and 1 then $
         message, 'Warning: '+errs[i-4]+ ' Occured.',/INFORMATIONAL
       j=check_math(0,0)
;
;  return the result
;
       !except=inexcept
       return,yfit 
;
END
