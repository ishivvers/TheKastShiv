pro mkbstar, intera

;-----------------------------------------------------------------------
; mkbstar.pro
;
; This program reads in an IRAF format multispec extraction for a
; B-star.  Spline fit to continuum done manually.
; The regions not affected by atmospheric absorption
; are set to 1, and the wavelength scale is binned to the standard
; wavelength scale for the run.
; The result is written out to bstar.fits, and is used as an input
; to the routine that actually removes the continuum bands.
;
; This routine will use the 1st beam of the spectrum, whether this is
; a normal or an optimal extraction. 
; If there are multiple apertures, it will plot each aperture and
; prompt the user for which one to use as the B-star.  
;
; AB, 1/22/98, modified 4/30/98 for continuum fitting
; TM, 11/15/98 repeat fits to B-star if mistakes
; TM, now realmkbstar, called by mkbstar so that you can choose an
; interactive or non-interactive option
;------------------------------------------------------------------------

IF (n_params() EQ 0) THEN BEGIN
    realmkbstar, '', '', 'n'
ENDIF ELSE IF (n_params() GT 0) THEN BEGIN
    realmkbstar, '', '', 'y'
ENDIF

end
