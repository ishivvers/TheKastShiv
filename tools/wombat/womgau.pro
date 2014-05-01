pro womgau
common wom_active, active
common wom_ulog, ulog
COMMON wom_col, col
device, cursor_standard = 33
!Y.STYLE = 16
us = findgen(48)*(!PI*2/48.0)
usersym, cos(us), sin(us), /fill
womdestruct, active, wave, flux, err, name, npix, header
oldwave = wave
oldflux = flux
oldnpix = npix
print, ' '
print, strcompress('Object is '+name)
print, ' '
print, strcompress('Spectrum runs from '+string(wave[0])+' to '+ $
                   string(wave[npix-1])+'.')
print, ' '
print, 'This routine expects an f-lambda spectrum.  If you feed it'
print, 'something else, we cannot be responsible for the results.'
print, ' '
print, 'Select a subset of the spectrum'
selmode = 0
womwaverange, wave, flux, indexblue, indexred, npix, selmode


plot, wave, flux, xst = 3, yst = 3, psym = 10, xtitle =  'Wavelength', $
  ytitle = 'Flux', title = name, color = col.white
wshow
nwave = wave
nflux = flux
newbin = npix
print, ' '
print, 'Now pick the exact range for the fit.'

womwaverange, wave, flux, indexblue, indexred, npix, selmode
if (selmode EQ 1) then begin
    repeat begin
        goflag = 1
        wavec = ''
        read, 'Enter approximate center of line : ', wavec
        wavec = float(wavec)
        womget_element, nwave, wavec, indexcen

        if (indexcen LE 0)  then begin
            print, 'Wavelength is not a proper bin--try again'
            goflag = 0
        endif
        if (wavec LT nwave[indexblue]) or (wavec GT nwave[indexred]) $
          then begin
            print, 'Out of range--try again'
            goflag = 0
        endif
    endrep until (goflag EQ 1)
endif
if (selmode EQ 2) then begin
    repeat begin
        okflag = 0
        print, 'Mark the approximate center of the gaussian'
        wait,  0.5 
        cursor, element1, flux1, /data, /wait
        print, element1, flux1
        oplot,[element1],[flux1],psym=8,color=col.red
        womget_element, nwave, element1, indexcen

        print, ' '
        print, strcompress('Approximate center at: '+$
                           string(nwave[indexcen]))
        
        print, ' '
        repeat begin
            print, 'Is this ok? (y/n, default=y)'
            c = get_kbrd(1)
            if ((byte(c))[0] EQ 10) then c = 'y'
            c = strlowcase(c)
            print, c
        endrep until (c EQ 'y') or (c EQ 'n')
        if (c EQ 'y') then begin
            okflag = 1
        endif
    endrep until (okflag EQ 1)
endif
fitregionbin = indexred-indexblue+1
fitwave = nwave[indexblue:indexred]
fitregionflux = nflux[indexblue:indexred]
weights = fitwave
weights[*] = 1.0
repeat begin
    print, ' '
    print, 'Do you want to fit gaussian with (c)ontinuum, or (n)o continuum? '
    f = get_kbrd(1)
    f = strlowcase(f)
    print, f
endrep until (f EQ 'c') or (f EQ 'n')
if (f EQ 'c') then begin
; a is the vector of function coefficients, guess height at center
; marked as a[0], height of gaussian, center as marked center, a[1],
; and 2 is a typical width, but not that crucial.  line parameters, 
; a[3] (y-intercept), and a[4] (slope) start at zero.  this seems to work


; fluxfit = curvefit(fitwave, fitregionflux, weights, a, sigma, chisq = ch, $
;                    iter = it, function_name = 'womgaufun', itmax=100, $
;                   tol = 1E-10)
; fluxfit = curvefit(fitwave, fitregionflux, weights, aa, sigma, chisq = ch, $
;                    iter = it, function_name = 'bgf', itmax=100, $
;                   tol = 1E-10)
; print, sigma
; print, ch
; print, aa
; nfit = (size(fitwave))[1]
; fw = dblarr(nfit)
; ff = dblarr(nfit)
; fmax = max(fitregionflux, min = fmin)
; wmax = max(fitwave, min = wmin)
; fsc = fmax -fmin
; wsc = wmax -wmin
; fm = moment(fitregionflux)
; wm = moment(fitwave)
; fw = (fitwave-wmin)/wsc
; ff = (fitregionflux-fmin)/fsc
a = dblarr(5)
; corrfac = [[fsc], [wsc], [wsc], [fsc/wsc], [fsc]]
; a[0] = (nflux[indexcen]-fmin)/fsc
; a[1] = (nwave[indexcen]-wmin)/wsc
a[0] = nflux[indexcen]
a[1] = nwave[indexcen]
a[2] = 2.0
; aa = a
print, ' '

fluxfit = mylmfit(fitwave, fitregionflux, a, chisq = ch, /double, $
                function_name = 'womgaufun', iter = it, itmax = 200, $
                sigma = sigma, tol = 1E-12)
; print, aa
; print, sigma
;, weights = 1/fitregionflux)

; print, sigma
; print, ch
; print, a
; yow = get_kbrd(1)
; a = corrfac*aa
; a[1] = a[1]+wmin
; a[4] = a[4]+fmin-a[3]*wmin
; sigma = corrfac*sigma
;print, sigma
; sigma[4] = sqrt(sigma[4]^2+(sigma[3]*wmin)^2)
;print, a
;print, sigma
;yow = get_kbrd(1)
plot, nwave[0:newbin-1], nflux[0:newbin-1], xst = 3, yst = 3, $
  psym = 10, xtitle =  'Wavelength', $
  ytitle = 'Flux', title = name, color = col.white
wshow
;oplot, fitwave, fluxfit, psym = 10, color = col.blue
nbinfit = long(2*5*50*abs(a[2]))
wavecalc = fltarr(nbinfit)
fluxcalc = fltarr(nbinfit)
fluxcont = fluxcalc
; use returned fitting parameters to create finer resolution gaussian
; and line to calculate fluxes and EW

for i = 0L, nbinfit-1 do begin
    wavecalc[i] = (a[1]-0.2*5*50*abs(a[2])+0.2*i)
    fluxcalc[i] = a[0]*exp(-1.0*((wavecalc[i]-a[1])^2)/2.0/(a[2]^2))+ $
      wavecalc[i]*a[3]+a[4]
    fluxcont[i] = wavecalc[i]*a[3]+a[4]
endfor
; testwave = fltarr(fitregionbin)
; testflux = fltarr(fitregionbin)
; for i = 0, fitregionbin-1 do begin
;     testwave[i] = fitwave[i]
;     testflux[i] = a[0]*exp(-1.0*((testwave[i]-a[1])^2)/2.0/(a[2]^2)) + $
;       (testwave[i]*a[4]+a[3])  
; endfor   
fluxgaussian = fluxcalc - fluxcont
fitfluxcalc = 0.0
fitfluxgaussian = 0.0
fitfluxcont = 0.0
deltafit = wavecalc[1]-wavecalc[0]
; this below is to add up calculated fluxes, but only in marked region
redloc = where((wavecalc GT fitwave[fitregionbin-1]), nred)
blueloc = where((wavecalc LT fitwave[0]), nblue)
npixbluecur = n_elements(blueloc)
indexblue = blueloc[npixbluecur-1]
indexred = redloc[0]
for i = indexblue, indexred do begin
    fitfluxcalc = fitfluxcalc+fluxcalc[i]*deltafit
    fitfluxgaussian = fitfluxgaussian+fluxgaussian[i]*deltafit
    fitfluxcont = fitfluxcont+fluxcont[i]*deltafit
endfor
fitallfluxcalc = 0.0
fitallfluxgaussian = 0.0
fitallfluxcont = 0.0
for i = 0L, nbinfit-1 do begin
    fitallfluxcalc = fitallfluxcalc+fluxcalc[i]*deltafit
    fitallfluxgaussian = fitallfluxgaussian+fluxgaussian[i]*deltafit
    fitallfluxcont = fitallfluxcont+fluxcont[i]*deltafit
endfor
ymin = min(nflux, max = ymax)
plots, [wavecalc[indexblue], !y.crange[0]], color = col.white, psym = 0
plots,  [wavecalc[indexblue], !y.crange[1]], linestyle = 1, /continue, $
  color = col.white, psym = 0
plots, [wavecalc[indexred], !y.crange[0]], color = col.white, psym = 0
plots,  [wavecalc[indexred], !y.crange[1]], linestyle = 1, /continue, $
  color = col.white, psym = 0
oplot, wavecalc, fluxcalc, psym = 10, color = col.blue
oplot, wavecalc, fluxgaussian, psym = 10, color = col.red
oplot, wavecalc, fluxcont, psym = 10, color = col.green
alabel = ['Height', 'Center', 'Sigma', 'Slope', 'Y-intercept']
format = '(A11,":  ",f16.8,"   +/- ",f16.8)'
printf, ulog, systime()
printf, ulog, strcompress('File: '+name)
for i = 0, 4 do begin
print, alabel[i], a[i], sigma[i], format = format
printf, ulog, alabel[i], a[i], sigma[i], format = format
endfor
print, ' '
;print, 'a', a
;print, 'sigma', sigma
print, 'FWHM', 2.35482*abs(a[2]), 2.35482*(sigma[2]), format = format
printf, ulog, 'FWHM', 2.35482*abs(a[2]), 2.35482*(sigma[2]), format = format
;print, 'fwhm', 2.35482*abs(a[2])
print, ' '
print, 'X^2: ', ch
print, '# Iterations: ', it
printf, ulog, 'X^2: ', ch
printf, ulog, '# Iterations: ', it
print, ' '
delta = fitwave[1]-fitwave[0]
lineflux = 0.0


for i = 0, fitregionbin-1 do begin
    lineflux = lineflux + fitregionflux[i]*delta
endfor
lineflux = lineflux
; print, 'flux-add up region', lineflux
; print, 'fitflux-addup calc fit', fitfluxcalc
; print, 'fitflux-addup calc fit-line', fitfluxgaussian
cenvec = where(wavecalc GT a[1])
indexcen = cenvec[0]
linecont = fluxcont[indexcen]
; print, 'cont', linecont
; print, 'EW', fitfluxgaussian/linecont
; print, 'fitflux-cont', fitfluxcont
; print, 'last two added', fitfluxcont+fitfluxgaussian
; print, 'fitflux-addup calc fit-all', fitallfluxcalc
; print, 'fitflux-addup calc fit-line-all', fitallfluxgaussian
; print, 'fitflux-cont-all', fitallfluxcont
; print, 'EWall', fitallfluxgaussian/linecont
a0pct = sigma[0]/a[0]
a2pct = sigma[2]/a[2]
fpct = sqrt(a0pct*a0pct + a2pct*a2pct)
fitfluxgaussiansig = fitfluxgaussian*fpct
fitallfluxgaussiansig = fitallfluxgaussian*fpct
format = '(A26,":  ",f16.8,"   +/- ",f16.8)'
print, 'Data = White, Fit = Blue, Continuum = Green, Fit - Continuum = Red'
print, ' '
print, 'Note that all the following fluxes may need to be scaled by
print, '1E-15.'
print, ' '
print, 'Flux between dotted lines', fitfluxgaussian, $
  fitfluxgaussiansig, format = format
print, 'EW between dotted lines: ', fitfluxgaussian/linecont, format = format
print,  ' '
print, 'Flux in full gaussian', fitallfluxgaussian, $
  fitallfluxgaussiansig, format = format
print, 'EW of full gaussian: ', fitallfluxgaussian/linecont, format = format
print, ' '
print, 'Continuum flux at line center: ', linecont
print, ' '
printf, ulog,  'Note that all the following fluxes may need to be scaled by'
printf, ulog,  '1E-15.'
printf, ulog,  'Flux between dotted lines', fitfluxgaussian, $
  fitfluxgaussiansig, format = format
printf, ulog,  'EW between dotted lines: ', fitfluxgaussian/linecont, format = format
printf, ulog,  'Flux in full gaussian', fitallfluxgaussian, $
  fitallfluxgaussiansig, format = format
printf, ulog,  'EW of full gaussian: ', fitallfluxgaussian/linecont, format = format
printf, ulog,  'Continuum flux at line center: ', linecont
endif
if (f EQ 'n') then begin
; a is the vector of function coefficients, guess height at center
; marked as a[0], height of gaussian, center as marked center, a[1],
; and 2 is a typical width, but not that crucial. 

; fmax = max(fitregionflux, min = fmin)
; wmax = max(fitwave, min = wmin)
; fsc = fmax -fmin
; wsc = wmax -wmin
; fm = moment(fitregionflux)
; wm = moment(fitwave)
; fw = double((fitwave-wmin)/wsc)
; ff = double((fitregionflux-fmin)/fsc)
a = dblarr(3)
; corrfac = [[fsc], [wsc], [wsc]]
; a[0] = (nflux[indexcen]-fmin)/fsc
; a[1] = (nwave[indexcen]-wmin)/wsc
a[0] = nflux[indexcen]
a[1] = nwave[indexcen]
a[2] = 5.0
;aa = a
print, ' '
; fluxfit = curvefit(fitwave, fitregionflux, weights, a, sigma, chisq = ch, $
;                    iter = it, function_name = 'womgaufun2', itmax=200, $
;                   tol = 1E-20)

print, a

fluxfit = mylmfit(fitwave, fitregionflux, a, chisq = ch, /double, $
                function_name = 'womgaufun2', iter = it, itmax = 200, $
                sigma = sigma)
plot, nwave[0:newbin-1], nflux[0:newbin-1], xst = 3, yst = 3, $
  psym = 10, xtitle =  'Wavelength', $
  ytitle = 'Flux', title = name, color = col.white
wshow
;print, aa
;print, sigma
;a = corrfac*aa
;a[1] = a[1]+wmin
;sigma = corrfac*sigma
print, sigma
print, a

;oplot, fitwave, fluxfit, psym = 10, color = col.blue
nbinfit = long(2*5*50*abs(a[2]))
wavecalc = fltarr(nbinfit)
fluxcalc = fltarr(nbinfit)
fluxcont = fluxcalc
; use returned fitting parameters to create finer resolution gaussian
; and line to calculate fluxes and EW

for i = 0L, nbinfit-1 do begin
    wavecalc[i] = a[1]-0.2*5*50*abs(a[2])+0.2*i
    fluxcalc[i] = a[0]*exp(-1.0*((wavecalc[i]-a[1])^2)/2.0/(a[2]^2))
endfor

fluxgaussian = fluxcalc
fitfluxcalc = 0.0
fitfluxgaussian = 0.0
fitfluxcont = 0.0
deltafit = wavecalc[1]-wavecalc[0]
; this below is to add up calculated fluxes, but only in marked region
redloc = where((wavecalc GT fitwave[fitregionbin-1]), nred)
blueloc = where((wavecalc LT fitwave[0]), nblue)
npixbluecur = n_elements(blueloc)
indexblue = blueloc[npixbluecur-1]
indexred = redloc[0]
for i = indexblue, indexred do begin
    fitfluxcalc = fitfluxcalc+fluxcalc[i]*deltafit
    fitfluxgaussian = fitfluxgaussian+fluxgaussian[i]*deltafit
endfor
fitallfluxcalc = 0.0
fitallfluxgaussian = 0.0
for i = 0L, nbinfit-1 do begin
    fitallfluxcalc = fitallfluxcalc+fluxcalc[i]*deltafit
    fitallfluxgaussian = fitallfluxgaussian+fluxgaussian[i]*deltafit
endfor
ymin = min(nflux, max = ymax)
plots, [wavecalc[indexblue], !y.crange[0]], color = col.white, psym = 0
plots,  [wavecalc[indexblue], !y.crange[1]], linestyle = 1, /continue, $
  color = col.white, psym = 0
plots, [wavecalc[indexred], !y.crange[0]], color = col.white, psym = 0
plots,  [wavecalc[indexred], !y.crange[1]], linestyle = 1, /continue, $
  color = col.white, psym = 0
oplot, wavecalc, fluxcalc, psym = 10, color = col.blue
oplot, wavecalc, fluxgaussian, psym = 10, color = col.red
alabel = ['Height', 'Center', 'Sigma']
format = '(A11,":  ",f16.8,"   +/- ",f16.8)'
printf, ulog, systime()
printf, ulog, strcompress('File: '+name)
for i = 0, 2 do begin
print, alabel[i], a[i], sigma[i], format = format
printf, ulog, alabel[i], a[i], sigma[i], format = format
endfor
print, ' '
print, 'FWHM', 2.35482*abs(a[2]), 2.35482*(sigma[2]), format = format
print, ' '
print, 'X^2: ', ch
print, '# Iterations: ', it
printf, ulog, 'FWHM', 2.35482*abs(a[2]), 2.35482*(sigma[2]), format = format
printf, ulog, 'X^2: ', ch
printf, ulog, '# Iterations: ', it
print, ' '
 delta = fitwave[1]-fitwave[0]
lineflux = 0.0


for i = 0, fitregionbin-1 do begin
    lineflux = lineflux + fitregionflux[i]*delta
endfor
lineflux = lineflux
cenvec = where(wavecalc GT a[1])
indexcen = cenvec[0]
a0pct = sigma[0]/a[0]
a2pct = sigma[2]/a[2]
fpct = sqrt(a0pct*a0pct + a2pct*a2pct)
fitfluxgaussiansig = fitfluxgaussian*fpct
fitallfluxgaussiansig = fitallfluxgaussian*fpct
format = '(A26,":  ",f16.8,"   +/- ",f16.8)'
print, 'Data = White, Fit = Blue'
print, ' '
print, 'Note that all the following fluxes may need to be scaled by
print, '1E-15.'
print, ' '
print, 'Flux between dotted lines', fitfluxgaussian, $
  fitfluxgaussiansig, format = format
print,  ' '
print, 'Flux in full gaussian', fitallfluxgaussian, $
  fitallfluxgaussiansig, format = format
print, ' '
printf, ulog, 'Note that all the following fluxes may need to be scaled by
printf, ulog, '1E-15.'
printf, ulog, 'Flux between dotted lines', fitfluxgaussian, $
  fitfluxgaussiansig, format = format
printf, ulog, 'Flux in full gaussian', fitallfluxgaussian, $
  fitallfluxgaussiansig, format = format
endif
end
