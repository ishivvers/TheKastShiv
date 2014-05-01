pro womlinedepth
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
contreg = fltarr(2, 2)
linepts = fltarr(2, 2)
linedge = fltarr(2)
  ; choose continuum regions

  print, 'Choose continuum regions '
  print, ' '
  repeat begin
  goflag = 1
  for i = 0, 1 do begin
  
  
  selmode = 0
  print, 'Region #'+string(i+1)
    print, ' '
  cwave = wave
  cflux = flux
  cnpix = npix
  womwaverange, cwave, cflux, indexblue, indexred, cnpix, selmode


  contreg[0, i] = wave[indexblue]
  contreg[1, i] = wave[indexred]
  endfor
  plot, wave, flux, xst = 3, yst = 3, psym = 10, xtitle = 'Wavelength', $
  ytitle = 'Flux', color = col.white
  wshow
  print, contreg
  womget_element, wave, contreg[0, 0], wb1
  womget_element, wave, contreg[1, 0], wb2
  womget_element, wave, contreg[0, 1], wr1
  womget_element, wave, contreg[1, 1], wr2
  oplot, wave[wb1:wb2], flux[wb1:wb2], psym = 10, color = col.red
  oplot, wave[wr1:wr2], flux[wr1:wr2], psym = 10, color = col.red
bmed = median(flux[wb1:wb2])
rmed = median(flux[wr1:wr2])
bwmed = median(wave[wb1:wb2])
rwmed = median(wave[wr1:wr2])
cline = linfit([bwmed, rwmed], [bmed, rmed])
print, cline
cf = cline[0]+cline[1]*wave
oplot, wave, cf, color = col.blue
  repeat begin
  print, 'Is this ok? (y/n, default=y)

c = get_kbrd(1)
if ((byte(c))[0] EQ 10) then c = 'y'
c = strlowcase(c)
print, c
endrep until (c EQ 'y') or (c EQ 'n')
if (c EQ 'n') then begin
goflag = 0

endif
endrep until (goflag EQ 1)
print, contreg

print, 'Mark points to define line edges'
print, ' '
  repeat begin
  goflag = 1
  for i = 0, 1 do begin

  print, 'Mark point #'+string(i+1)
    print, ' '
        wait,  0.5 
        cursor, pbw, pbf, /data, /wait
        print, pbw, pbf
        oplot,[pbw],[pbf],psym=8,color=col.yellow
womget_element, wave, pbw, pbwi
   linedge[i] = wave[pbwi]
linepts[i, 0] = pbw
linepts[i, 1] = pbf
endfor
  repeat begin
  print, 'Is this ok? (y/n, default=y)

c = get_kbrd(1)
if ((byte(c))[0] EQ 10) then c = 'y'
c = strlowcase(c)
print, c
endrep until (c EQ 'y') or (c EQ 'n')
if (c EQ 'n') then begin
goflag = 0
for i = 0, 1 do begin
print, linepts[i, 0], linepts[i, 1]
oplot, [linepts[i, 0]], [linepts[i, 1]], psym = 8, color = col.black
endfor
endif
endrep until (goflag EQ 1)
print, linedge
contmidwave = (linedge[0]+linedge[1])/2.0
contmid = cline[0]+cline[1]*contmidwave
womget_element, wave, contmidwave, contmidindex
plots, [wave[contmidindex]], contmid, psym = 10
womget_element, wave, linedge[0], bpi
womget_element, wave, linedge[1], rpi

plots, [wave[contmidindex]], [min(flux[bpi:rpi])], /continue, $
color = col.green, psym = 10
smoothpix = fix((rpi-bpi)/4.0)
wsmooth = wave[bpi+smoothpix:bpi+3*smoothpix]
fsmooth = flux[bpi+smoothpix:bpi+3*smoothpix]
repeat begin
goflag = 1
plot, wsmooth, fsmooth, $
xst = 3, yst = 3, psym = 10, xtitle = 'Wavelength', $
  ytitle = 'Flux', color = col.white
   print, ' '
    boxwidth = ''
    read, 'Enter the width of the boxcar: ', boxwidth
    boxwidth = fix(boxwidth)
    if (boxwidth LT 2) or (boxwidth GE 2*smoothpix-1) then boxwidth = 2
    print, boxwidth
    sflux = smooth(fsmooth, boxwidth, /edge_truncate, /nan)
    oplot, wsmooth, sflux, psym = 10, color = col.red
fsmin = min(sflux, fsminindex)
wsmin = wsmooth[fsminindex]
plots, [wsmin, !y.crange[0]], psym = 0
plots, [wsmin, !y.crange[1]], psym = 0, /continue, color = col.yellow
  repeat begin
  print, 'Is this ok? (y/n, default=y)

c = get_kbrd(1)
if ((byte(c))[0] EQ 10) then c = 'y'
c = strlowcase(c)
print, c
endrep until (c EQ 'y') or (c EQ 'n')
if (c EQ 'n') then begin
goflag = 0

endif
endrep until (goflag EQ 1)
womget_element, wave, wsmin, minindex
fluxmin = flux[minindex]
contmin =  cline[0]+cline[1]*wsmin
deltalam = wave[bpi+1]-wave[bpi]
lineflux = total(flux[bpi:rpi])*deltalam
  plot, wave, flux, xst = 3, yst = 3, psym = 10, xtitle = 'Wavelength', $
  ytitle = 'Flux', color = col.white
for i = 0, 1 do begin
oplot, [linepts[i, 0]], [linepts[i, 1]], psym = 8, color = col.yellow
endfor
oplot, wave, cf, color = col.blue
openw, 69, 'contfit'
for i = 0, npix-1 do begin
    printf, 69, wave[i], cf[i]
endfor
close, 69
print, 'line', wave[minindex], contmin, fsmin
  oplot, wave[wb1:wb2], flux[wb1:wb2], psym = 10, color = col.red
  oplot, wave[wr1:wr2], flux[wr1:wr2], psym = 10, color = col.red
plots, [wave[minindex]], [contmin], psym = 10
plots, [wave[minindex]], [fsmin], /continue, $
color = col.green, psym = 10

print, lineflux
print, lineflux/contmid
print, lineflux/contmin
print, fluxmin
print, fluxmin/contmin
fitflux = cf[bpi:rpi]-flux[bpi:rpi]

a = [max(fitflux), contmidwave, 10.0]
print, a

fluxfit = mylmfit(wave[bpi:rpi], fitflux, a, chisq = ch, /double, $
                function_name = 'womgaufun2', iter = it, itmax = 200, $
                sigma = sigma)
print, sigma
print, a
nbinfit = long(2*5*50*abs(a[2]))
wavecalc = fltarr(nbinfit)
fluxcalc = fltarr(nbinfit)
fluxcont = fluxcalc
; use returned fitting parameters to create finer resolution gaussian
; and line to calculate fluxes and EW

for i = 0L, nbinfit-1 do begin
    wavecalc[i] = a[1]-0.2*5*50*abs(a[2])+0.2*i
    fluxcalc[i] = a[0]*exp(-1.0*((wavecalc[i]-a[1])^2)/2.0/(a[2]^2))
ENDFOR
womidlterp, wave, cf, wavecalc, cfcalc
fluxcalc = cfcalc - fluxcalc
fluxgaussian = fluxcalc
fitfluxcalc = 0.0
fitfluxgaussian = 0.0
fitfluxcont = 0.0
get_lun, uwpl
openw, uwpl, 'gaufit'

for i = 0L, nbinfit-1 do begin
    printf, uwpl, wavecalc[i], fluxcalc[i]
endfor

close, uwpl
free_lun, uwpl
oplot, wavecalc, fluxcalc, psym = 10, color = col.aqua
womget_element, wavecalc, linedge[0], bpic
womget_element, wavecalc, linedge[1], rpic
deltafit = wavecalc[bpic+1]-wavecalc[bpic]
gauflux = total(fluxcalc[bpic:rpic])*deltafit
print, gauflux
print, gauflux/contmid

print, 'Cont. regions: '+string(contreg[0, 0])+' -'+string(contreg[1, 0])+$
'   '+string(contreg[0, 1])+' -'+string(contreg[1, 1])
print, 'Cont. median values: '+string(bwmed)+','+string(bmed)+'   '+$
string(rwmed)+','+string(rmed)
print, 'Cont. line coefficients: '+string(cline[0])+' +'+string(cline[1])+$
' X wave'
print, 'Line endpoints: '+string(linedge[0])+'  '+string(linedge[1])
print, 'Min. value: '+string(wsmin)
print, 'Cont. value at midpoint: '+string(contmid)
print, 'Cont. value at min of smoothed line: '+string(contmin)
print, 'Line depth at min / cont. value (mid, min): '+string(fsmin/contmid)+$
'  '+string(fsmin/contmin)
print, '(Line - cont.)/ cont. (mid, min): '+string((fsmin-contmid)/contmid)+$
'  '+string((fsmin-contmin)/contmin)
print, 'Line sum / cont. (mid, min): '+string(lineflux/contmid)+'  '+$
string(lineflux/contmin)
print, 'Gauss. sum / cont. (mid, min): '+string(gauflux/contmid)+'  '+$
string(gauflux/contmin)
print, 'Gaussian FWHM: '+string(a[2]*2.35482)
printf, ulog, systime()
printf, ulog, strcompress('File: '+name)
printf, ulog, 'Depth finder values: '
printf, ulog, 'Cont. regions: '+string(contreg[0, 0])+' -'+string(contreg[1, 0])+$
'   '+string(contreg[0, 1])+' -'+string(contreg[1, 1])
printf, ulog, 'Cont. median values: '+string(bwmed)+','+string(bmed)+'   '+$
string(rwmed)+','+string(rmed)
printf, ulog, 'Cont. line coefficients: '+string(cline[0])+' +'+string(cline[1])+$
' X wave'
printf, ulog, 'Line endpoints: '+string(linedge[0])+'  '+string(linedge[1])
printf, ulog, 'Min. value: '+string(wsmin)

printf, ulog, 'Cont. value at midpoint: '+string(contmid)
printf, ulog, 'Cont. value at min of smoothed line: '+string(contmin)
printf, ulog, 'Line depth at min / cont. value (mid, min): '+string(fsmin/contmid)+$
'  '+string(fsmin/contmin)
printf, ulog, '(Line - cont.)/ cont. (mid, min): '+string((fsmin-contmid)/contmid)+$
'  '+string((fsmin-contmin)/contmin)
printf, ulog, 'Line sum / cont. (mid, min): '+string(lineflux/contmid)+'  '+$
string(lineflux/contmin)
printf, ulog, 'Gauss. sum / cont. (mid, min): '+string(gauflux/contmid)+'  '+$
string(gauflux/contmin)
printf, ulog, 'Gaussian FWHM: '+string(a[2]*2.35482)
printf, ulog, ' '
end

