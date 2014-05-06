pro newcor, spec1, spec2, xfactor, npoints, result

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
	print, 'newcor, spec1, spec2, xfactor, npoints, result'
	retall
endif

npix = (size(spec1))[1]

espec1 = congrid (spec1,npix*xfactor,/interp)
espec2 = congrid (spec2,npix*xfactor,/interp)

;c = fltarr(npoints)
lagarr = (findgen(npix*xfactor) - ((npix*xfactor+1)/2)) 

mini = ((npix*xfactor+1)/2) - npoints/2
maxi = ((npix*xfactor+1)/2) + npoints/2

c = mycorrelate(espec1, espec2);c_correlate(espec1, espec2, lagarr)

maxcor = max(c[mini:maxi], shiftpix)
shiftpix = shiftpix+mini

lpix = shiftpix-5
rpix = shiftpix+5

result = poly_fit((lagarr/xfactor)[lpix:rpix], c[lpix:rpix], 2, $
                  yfit = yfit, /double)

;Plot the cross-correlation peak
;plot, (lagarr / xfactor)[lpix:rpix], c[lpix:rpix], xtitle = 'Pixel shift', ytitle = 'X-cor', ps = 10
;oplot,  (lagarr / xfactor)[lpix:rpix], yfit,col = 23, ps = 10
;a = get_kbrd(1)

a = -result[1]/(2.*result[2])

result = a

if (shiftpix eq mini) or (shiftpix eq maxi) then begin
	print, 'Cross-correlation failed!  Use larger npoints?'
        print, 'Setting shift to zero...'
        print
        result = 0.0
endif

end

	

