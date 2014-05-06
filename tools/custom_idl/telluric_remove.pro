pro telluric_remove, bstarwave, bstar, bairmass, wave, spect, $
                     airmass, newspect, angshift, col


;-----------------------------------------------------------------------
; telluric_remove.pro
;
; Program to take a B-star spectrum and remove absorption bands
; from an object spectrum.
;----------------------------------------------------------------------
;  color is passed by structure col from final


; Rebin b-star to wave scale

bonashrebin, bstarwave, bstar, wave, bstartmp

print
print,  'The ratio of airmasses (object/B-star) is ', (airmass / bairmass), '.'
print

; Warn if airmasses are wildly different

if ((airmass / bairmass) GT 3.0) or ((airmass / bairmass) LT 0.33) then begin
    print, 'WARNING: OBJECT AND B-STAR HAVE WILDLY DIFFERENT'
    print, 'AIRMASSES: ATMOSPHERIC BAND DIVISION MAY BE LOUSY'
endif


wmin = wave[0]
npix = n_elements(spect)
wmax = wave[npix - 1]
wdelt = wave[1] - wave[0]

; If the spectrum includes bands with a sharp bandhead, then
; cross-correlate and shift bstartmp spectrum to match spect

lag =  fltarr(3)
lagflag =  fltarr(3)
xfactor = 10
npoints = 200

print,  'Cross-correlating object with B-star spectrum...'
print
lag[*] = 0
if (wmin LT 6200) AND (wmax GT 6400) AND (wmax LT 6900) then begin
    get_element,  wave, 6200, emin
    get_element,  wave, 6400, emax
    xcor,  spect[emin:emax],  bstartmp[emin:emax], xfactor, npoints, tmp
    lag[0] =  tmp
    lagflag[0] = 1
    print,  'The shift at the 6250 A band is ', lag[0] * wdelt, ' Angstroms.'
endif

if (wmin LT 6800) AND (wmax GT 6950) then begin
    get_element,  wave, 6800, emin
    get_element,  wave, 6950, emax
    xcor,  spect[emin:emax],  bstartmp[emin:emax], xfactor, npoints, tmp
    lag[1] =  tmp
    lagflag[1] = 1
    print,  'The shift at the B band is      ', lag[1] * wdelt, ' Angstroms.'
endif

;if (wmin LT 7500) AND (wmax GT 8000) then begin
;    get_element,  wave, 7500, emin
if (wmin LT 7500) AND (wmax GT 7800) then begin
    get_element,  wave, 7500, emin
    get_element,  wave, 7800, emax
    xcor,  spect[emin:emax],  bstartmp[emin:emax], xfactor, npoints, tmp
    lag[2] =  tmp
    lagflag[2] = 1
    print,  'The shift at the A band is      ', lag[2] * wdelt, ' Angstroms.'
endif

; Calculate mean shift over all bands and shift b-star spectrum

avglag = 0
w = where(lagflag EQ 1,  nlag)
if (nlag GT 0) then avglag =  total(lag(w)) / nlag

angshift =  avglag * wdelt
if (nlag GT 0) then print,  'The mean shift is               ', $
  angshift, ' Angstroms.'

bstartmpcopy =  bstartmp

print
answer =  ''
repeat begin
    
    bstartmp =  bstartmpcopy
    bonashrebin,  wave - angshift,  bstartmp,  wave,  tmp

    bstartmp = tmp

    bstartmp = (bstartmp)^((airmass/bairmass)^0.55)

;    bands =  where (bstartmp LT 1,  nw)
;    if (nw GT 0) then begin
;    bstartmp(bands) =  $
;      1 - ( (1 - bstartmp(bands)) * (airmass/bairmass)^0.55)
;    endif
    
    newspect =  spect / bstartmp
    
    print,  'Plotting spectrum before and after atmospheric band correction...'
    finalscaler, spect, ymin, ymax
    plot,  wave, spect,  xst = 3,  yst = 3, psym = 10, $
      xtitle =  'Wavelength', ytitle = 'Flux', color = col.white, $
      yrange = [ymin, ymax], /nodata
    oplot,  wave, spect, psym = 10, color = col.red
    
    oplot,  wave,  newspect,  psym = 10, color = col.white
    
    if (nlag GT 0) then begin
        read, 'Is this ok? (y/n/w, default=y, w to change window size) ', answer
        answer = strlowcase(answer)
        if (answer EQ 'n') then begin
            angshift = ''
            read,  'Enter B-star shift in Angstroms: ',  angshift
            angshift = float(angshift)
        endif
        if (answer eq 'w') then begin
            print
            print, '  Choose your window :  '
            myplot2, wave, spect, wave, newspect, color = col.red, $
              ocolor = col.white, xrange = [xmin, xmax], $
              yrange = [ymin, ymax]
            xmax = !x.crange[1]
            xmin = !x.crange[0]
            ymax = !y.crange[1]
            ymin = !y.crange[0]
            ok = 0
        endif
    endif

endrep until (answer EQ 'y') OR (answer EQ '') OR (nlag EQ 0)


end

