pro womnewrebin, oldwave, oldspect, newwave, newspect

; Assumes both wavelength scales are linear!!!

oldwdelt = oldwave[1]-oldwave[0]
newwdelt = newwave[1]-newwave[0]


; If new wavelength bin size is equal or smaller than old bin size,
; then just quadterp it.
if (newwdelt LE oldwdelt) then begin
    quadterp, oldwave, oldspect, newwave, newspect
    return
endif

; If new wavelength bin size is bigger, then it's time to do something
; different.

nbins = n_elements(newwave)
newspect = fltarr(nbins)

; Shift newwave by 1/2 pix to get fractional bin counting right. 
; Then shift it back at the end of the routine.
newwave = newwave - newwdelt/2.

; Find effective indices in oldwave for elements of newwave
mino = min(oldwave)
maxo = max(oldwave)

tabinv, oldwave, newwave, tabs

for i=0, nbins-2 do begin
   
; find limits of the bin in the old grid
    bottom = mino > newwave[i] < maxo
    top    = mino > newwave[i+1] < maxo
    bottombin = tabs[i]
    topbin = tabs[i+1]
   
    fullbins = where( (oldwave LT top) AND $
                      (oldwave GT bottom), nfullbins)
    if (nfullbins GE 1) then fullbinsum = total(oldspect(fullbins)) $
      else fullbinsum = 0.0
    
; Calculate fractional old bin contributions at left and right edge of new bin.
; To improve this routine, put in quadratic interpolation here for the
; left and right fractional bins.

    leftfraction = ceil(bottombin) - bottombin
    rightfraction = topbin - floor(topbin)
       
    leftsum = leftfraction * oldspect(floor(bottombin))
    rightsum = rightfraction * oldspect(floor(topbin))

; add it up and divide by bin size ratio

    newspect[i] = (fullbinsum + leftsum + rightsum) / $
     ((nfullbins + leftfraction + rightfraction) > 1.0)

endfor
;Fix the wavelength scale
newwave = newwave + newwdelt/2.

end
