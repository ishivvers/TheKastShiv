pro xcor, spec1, spec2, xfactor, npoints, result

;---------------------------------------------------------------------
; Routine to find what value of the lag maximizes the
; cross-correlation between 2 spectra.
;
; Input spectra are just 1-d vectors, and all calculations are
; done in pixel coordinates.
;
; Since the c_correlate routine only does integer pixel shifts,
; we need to go to a finer grid for the calculation.
; The xfactor parameter gives the expansion.
; npoints is the number of grid points to calculate.
;
; AB, 1/8/98
;---------------------------------------------------------------------


if (n_params() NE 5) then begin
	print, 'xcor, spec1, spec2, xfactor, npoints, result'
	retall
endif

npix = (size(spec1))[1]

espec1 = congrid (spec1,npix*xfactor,/interp)
espec2 = congrid (spec2,npix*xfactor,/interp)

c = fltarr(npoints)
lagarr = (findgen(npoints) - (npoints/2)) 


c = c_correlate(espec1, espec2, lagarr)

;Plot the cross-correlation peak
;plot, lagarr / xfactor, c, xtitle = 'Pixel shift', ytitle = 'X-cor'

;a = get_kbrd(1)
maxcor = max(c, shiftpix)

result = lagarr(shiftpix) / xfactor

if (shiftpix EQ 0) or (shiftpix EQ npoints-1) then begin
	print, 'Cross-correlation failed!  Use larger npoints?'
        print, 'Setting shift to zero...'
        print
        result = 0.0
endif

end

	

