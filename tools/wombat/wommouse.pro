pro wommouse
common wom_hopper, hoparr, hopsize
common wom_active, active
common wom_arraysize, arraysize
common wom_ulog, ulog
COMMON wom_col, col
device, cursor_standard = 33
!Y.STYLE = 16
us = findgen(48)*(!PI*2/48.0)
usersym, cos(us), sin(us), /fill

print, 'This will combine blue and red pieces from two hoppers'
repeat begin
    print, ' '
    hopchoice1 = ''
    read, 'Enter the first hopper? ', hopchoice1
    hopnum1 = fix(hopchoice1)
endrep until ((hopnum1 GT 0) and (hopnum1 LT hopsize))
repeat begin
    print, ' '
    hopchoice2 = ''
    read, 'Enter the second hopper? ', hopchoice2
    hopnum2 = fix(hopchoice2)
endrep until ((hopnum2 GT 0) and (hopnum2 LT hopsize))

if (hoparr[hopnum1].wave[0] GT hoparr[hopnum2].wave[0]) then begin
    temp = hopnum1
    hopnum1 = hopnum2
    hopnum2 = temp
endif
womdestruct, hoparr[hopnum1], waveblue, fluxblue, errblue, nameblue, npixblue, headblue
womdestruct, hoparr[hopnum2], wavered, fluxred, errred, namered, npixred, headred

if (waveblue[npixblue-1] LT wavered[0]) then begin
    print, 'Spectra do not overlap'
    print, ' '
    return
endif
wdeltblue = waveblue[1]-waveblue[0]
wdeltred = wavered[1]-wavered[0]
if (abs(wdeltblue-wdeltred) GT .00001) then begin
    print, 'Spectra do not have same Angstrom/pixel'
    print, strcompress('Blue side: '+string(wdeltblue))
    print, strcompress('Red side: '+string(wdeltred))
    return
endif


print, ' '
print, strcompress('Overlap range is '+string(wavered[0])+ $
                   ' to '+string(waveblue[npixblue-1]))
print, ' '

print, 'Plotting blue side as blue, red side as red'
fluxtemp = fluxred
womget_element, waveblue, wavered[0], indexblue
womget_element, wavered, waveblue[npixblue-1], indexred
momentblue = moment(fluxblue[indexblue:npixblue-1])
momentred = moment(fluxred[0:indexred])
if (((momentblue[0] / momentred[0]) GT 1.2) or $
    ((momentblue[0] / momentred[0]) LT 0.8)) then begin
    print, 'Averages very different, scaling red to blue for plot'
    print, strcompress('Red multiplied by: '+$
                       string(momentblue[0] / momentred[0]))
    fluxtemp = fluxred*(momentblue[0]/momentred[0])
endif

plot, waveblue[indexblue:npixblue-1], fluxblue[indexblue:npixblue-1], $
  xst = 3, yst = 3, psym = 10, xtitle =  'Wavelength', $
  ytitle = 'Flux', title = 'Overlap region', /nodata, color = col.white
wshow
oplot, waveblue[indexblue:npixblue-1], fluxblue[indexblue:npixblue-1], $
  color = col.blue, psym = 10
oplot, wavered[0:indexred], fluxtemp[0:indexred], color = col.red, $
  psym = 10

repeat begin
    repeat begin
        print, ' '
        print, 'Change y-scale? (y/n, default=n)'
        c = get_kbrd(1)
        if ((byte(c))[0] EQ 10) then c = 'n'
        c = strlowcase(c)
        print, c
    endrep until (c EQ 'y') OR (c EQ 'n')
    if (c EQ 'y') then begin
        womscaleparse, ymin, ymax
        plot, waveblue[indexblue:npixblue-1], fluxblue[indexblue:npixblue-1], $
          xst = 3, yst = 3, psym = 10, xtitle =  'Wavelength', $
          yrange = [ymin, ymax], ytitle = 'Flux', title = 'Overlap region', $
          /nodata, color = col.white
        wshow
        oplot, waveblue[indexblue:npixblue-1], fluxblue[indexblue:npixblue-1],$
          color = col.blue, psym = 10
        oplot, wavered[0:indexred], fluxtemp[0:indexred], color = col.red, $
          psym = 10
        repeat begin
            print, ' '
            print, 'Do again? (y/n, default=n)'
            c = get_kbrd(1)
            if ((byte(c))[0] EQ 10) then c = 'n'
            c = strlowcase(c)
            print, c
        endrep until (c EQ 'y') OR (c EQ 'n')
    endif
endrep until (c EQ 'n')
repeat begin
    okflag = 0
    print, 'Mark the two end points of the region to compute average'
    wait,  0.5 
    cursor, element1, flux1, /data, /wait
    print, element1, flux1
    oplot,[element1],[flux1],psym=8,color=col.red
    wait,  0.5 
    cursor, element2, flux2, /data, /wait
    print, element2, flux2
    oplot,[element2],[flux2],psym=8,color=col.red
    if (element1 GT element2) then begin
        temp = element1
        element1 = element2
        element2 = temp
    endif
    womget_element, waveblue, element2, bine
    womget_element, waveblue, element1, binb
    if (bine GT npixblue-1) then bine = npixblue-1
    if (binb LT indexblue) then binb = indexblue
;     redloc = where((waveblue GT element2), nred)
;     blueloc = where((waveblue LT element1), nblue)
;     npixbluecur = n_elements(blueloc)
;     binb = blueloc[npixbluecur-1]
;     bine = redloc[0]
    repeat begin
        print, 'Are these points ok? (y/n, default=y)'
        yesno = get_kbrd(1)
        if ((byte(yesno))[0] EQ 10) then yesno = 'y'
        yesno = strlowcase(yesno)
        print, yesno
    endrep until (yesno EQ 'y') or (yesno EQ 'n')
    if (yesno EQ 'y') then begin
        okflag = 1
    endif
endrep until (okflag EQ 1)

repeat begin
    goflag = 1

    waveb = waveblue[binb]
    wavee = waveblue[bine]
    print, strcompress('Average for range '+string(waveb)+' to '$
                       +string(wavee))
    womget_element, waveblue, waveb, indexblue1
    womget_element, waveblue, wavee, indexblue2
    womget_element, wavered, waveb, indexred1
    womget_element, wavered, wavee, indexred2
    if (indexblue1 LT 0) or (indexblue2 LT 0) or (indexred1 LT 0) or $
      (indexred2 LT 0) then begin
        print, 'Wavelengths are not proper bins--try again'
        goflag = 0
    endif
    if (waveb LT wavered[0]) or (wavee GT waveblue[npixblue-1]) or $
      (waveb GE wavee) then begin
        print, 'Incorrect range--try again'
        goflag = 0
    endif
endrep until (goflag EQ 1)

momentblue = moment(fluxblue[indexblue1:indexblue2])
momentred = moment(fluxred[indexred1:indexred2])
print, ' '
print, strcompress('Average for '+string(waveb)+':'+string(wavee))
print, strcompress('Blue side:  '+string(momentblue[0]))
print, strcompress('Red side:   '+string(momentred[0]))
print, ' '

repeat begin
    print, ' '
    print, 'Scale to blue or red? (b/r)'
    brscale = get_kbrd(1)
    brscale = strlowcase(brscale)
    print, brscale
endrep until (brscale EQ 'b') OR (brscale EQ 'r')
if (brscale EQ 'b') then begin
    print, strcompress('scale to blue by '+$
                       string(momentblue[0]/momentred[0]))
    brlabel = 'blue'
    brscalefac =  momentblue[0]/momentred[0]
    fluxred = fluxred*momentblue[0]/momentred[0]
    errred = errred*momentblue[0]/momentred[0]
endif
if (brscale EQ 'r') then begin
    print, strcompress('scale to red by '+$
                       string(momentred[0]/momentblue[0]))
    brlabel = 'red'
    brscalefac = momentred[0]/momentblue[0]
    fluxblue = fluxblue*momentred[0]/momentblue[0]
    errblue = errblue*momentred[0]/momentblue[0]
endif


print, ' '
print, 'Plotting blue side as blue, red side as red'

plot, waveblue[indexblue1:indexblue2], fluxblue[indexblue1:indexblue2], $
  xst = 3, yst = 3, psym = 10, xtitle =  'Wavelength', $
  ytitle = 'Flux', title = 'Overlap region--scaled', /nodata, $
  color = col.white
wshow
oplot, waveblue[indexblue1:indexblue2], fluxblue[indexblue1:indexblue2], $
  color = col.blue, psym = 10
oplot, wavered[indexred1:indexred2], fluxred[indexred1:indexred2], $
  color = col.red, psym = 10

repeat begin
    repeat begin
        print, ' '
        print, 'Change y-scale? (y/n, default=n)'
        c = get_kbrd(1)
        if ((byte(c))[0] EQ 10) then c = 'n'
        c = strlowcase(c)
        print, c
    endrep until (c EQ 'y') OR (c EQ 'n')
    if (c EQ 'y') then begin
        womscaleparse, ymin, ymax
        plot, waveblue[indexblue1:indexblue2], $
          fluxblue[indexblue1:indexblue2], xst = 3, yst = 3, $
          psym = 10, xtitle =  'Wavelength', yrange = [ymin, ymax], $
          ytitle = 'Flux', title = 'Overlap region--scaled', /nodata, $
          color = col.white
        wshow
        oplot, waveblue[indexblue1:indexblue2], $
          fluxblue[indexblue1:indexblue2], color = col.blue, psym = 10
        oplot, wavered[indexred1:indexred2], fluxred[indexred1:indexred2], $
          color = col.red,  psym = 10
        repeat begin
            print, ' '
            print, 'Do again? (y/n, default=n)'
            c = get_kbrd(1)
            if ((byte(c))[0] EQ 10) then c = 'n'
            c = strlowcase(c)
            print, c
        endrep until (c EQ 'y') OR (c EQ 'n')
    endif
endrep until (c EQ 'n')
repeat begin
    okflag = 0
    print, 'Mark the two end points of the region to combine'
    wait,  0.5 
    cursor, element1, flux1, /data, /wait
    print, element1, flux1
    oplot,[element1],[flux1],psym=8,color=col.red
    wait,  0.5 
    cursor, element2, flux2, /data, /wait
    print, element2, flux2
    oplot,[element2],[flux2],psym=8,color=col.red
    if (element1 GT element2) then begin
        temp = element1
        element1 = element2
        element2 = temp
    endif
    womget_element, waveblue, element2, bine
    womget_element, waveblue, element1, binb
    if (bine GT indexblue2) then bine = indexblue2
    if (binb LT indexblue1) then binb = indexblue1
;     redloc = where((waveblue GT element2), nred)
;     blueloc = where((waveblue LT element1), nblue)
;     npixbluecur = n_elements(blueloc)
;     binb = blueloc[npixbluecur-1]
;     bine = redloc[0]
    repeat begin
        print, 'Are these points ok? (y/n, default=y)'
        yesno = get_kbrd(1)
        if ((byte(yesno))[0] EQ 10) then yesno = 'y'
        yesno = strlowcase(yesno)
        print, yesno
    endrep until (yesno EQ 'y') or (yesno EQ 'n') 
    if (yesno EQ 'y') then begin
        okflag = 1
    endif
endrep until (okflag EQ 1)

repeat begin
    goflag = 1
    waveb = waveblue[binb]
    wavee = waveblue[bine]
    print, strcompress('Combining over range '+string(waveb)+' to '+ $
                       string(wavee))
    womget_element, waveblue, waveb, indexblue1
    womget_element, waveblue, wavee, indexblue2
    womget_element, wavered, waveb, indexred1
    womget_element, wavered, wavee, indexred2
    if (indexblue1 LT 0) or (indexblue2 LT 0) or (indexred1 LT 0) or $
      (indexred2 LT 0) then begin
        print, 'Wavelengths are not proper bins--try again'
        goflag = 0
    endif
    if (waveb LT wavered[0]) or (wavee GT waveblue[npixblue-1]) or $
      (waveb GE wavee) then begin
        print, 'Incorrect range--try again'
        goflag = 0
    endif
endrep until (goflag EQ 1)

repeat begin
    print, ' '
    print, 'Add overlap region (e)qually, with (w)eights, or by (v)ariance? (e/w/v)'
    ewadd = get_kbrd(1)
    ewadd = strlowcase(ewadd)
    print, ewadd
endrep until ((ewadd EQ 'w') OR (ewadd EQ 'e') OR (ewadd EQ 'v'))

if (ewadd EQ 'e') then begin
  weiblue = 0.5
  weired = 0.5
  overflux = (weiblue*fluxblue[indexblue1:indexblue2] + $
              weired*fluxred[indexred1:indexred2])/(weiblue + weired)
  overerr = sqrt((weiblue*errblue[indexblue1:indexblue2])^2. + $
            (weired*errred[indexred1:indexred2])^2.)
endif

if (ewadd EQ 'w') then begin
;    repeat begin
;        weiflag = 1
        weiblue = ''
        weired = ''
        print, ' '
        read, 'Enter fractional weight for blue side: ', weiblue
        weiblue = float(weiblue)
        print, ' '
        read, 'Enter fractional weight for red side: ', weired
        weired = float(weired)
        weitot = weiblue + weired
        weiblue = weiblue / weitot
        weired = weired / weitot
;        if (abs((weiblue+weired)-1.0) GT 0.00001) then begin
;            print, 'Weights do not add to 1.0'
;            weiflag = 0
;        endif
;    endrep until (weiflag EQ 1)
  overflux = (weiblue*fluxblue[indexblue1:indexblue2] + $
              weired*fluxred[indexred1:indexred2])/(weiblue + weired)
  overerr = sqrt((weiblue*errblue[indexblue1:indexblue2])^2. + $
            (weired*errred[indexred1:indexred2])^2.)
endif

if (ewadd EQ 'v') then begin
    factor = 1d/(errblue[indexblue1:indexblue2]^2. + $
                 errred[indexred1:indexred2]^2.)
    factor2 = 1d/(errblue[indexblue1:indexblue2]^(-2.) + $
                 errred[indexred1:indexred2]^(-2.))
    overflux = factor2*(errblue[indexblue1:indexblue2]^(-2.)*$
               fluxblue[indexblue1:indexblue2] + $
               errred[indexred1:indexred2]^(-2.)*$
               fluxred[indexred1:indexred2])
    overerr = errblue[indexblue1:indexblue2] * errred[indexred1:indexred2] $
              * sqrt(factor)
endif


overnpix = indexblue2-indexblue1 + 1
nrc = npixred-indexred2-1
newwave = fltarr(arraysize)
newflux = fltarr(arraysize)
newerr  = fltarr(arraysize)

newwave[0:indexblue1-1] = waveblue[0:indexblue1-1]
newflux[0:indexblue1-1] = fluxblue[0:indexblue1-1]
newerr[0:indexblue1-1]  = errblue[0:indexblue1-1]

newwave[indexblue1:indexblue1+overnpix-1] = waveblue[indexblue1:indexblue1+overnpix-1]
newflux[indexblue1:indexblue1+overnpix-1] = overflux[0:overnpix-1]
newerr[indexblue1:indexblue1+overnpix-1]  = overerr[0:overnpix-1]

newwave[indexblue2+1:indexblue2+nrc] = wavered[indexred2+1:npixred-1]
newflux[indexblue2+1:indexblue2+nrc] = fluxred[indexred2+1:npixred-1]
newerr[indexblue2+1:indexblue2+nrc]  = errred[indexred2+1:npixred-1]

newpix = indexblue2+npixred-indexred2
!p.multi =  [0, 1, 2]
plot, waveblue[indexblue1:indexblue2], $
  overflux[0:overnpix-1], xst = 3, yst = 3, $
  psym = 10, color = col.white, $
  position =  [0.1, 0.55, 0.99, 0.95],  /normal,  $
  ytitle = 'Flux', title = 'Overlap region--with average'
wshow
oplot, waveblue[indexblue1:indexblue2], $
  fluxblue[indexblue1:indexblue2], color = col.blue, psym = 10
oplot, wavered[indexred1:indexred2], fluxred[indexred1:indexred2], $
  color = col.red, psym = 10
plot, newwave[0:newpix-1], newflux[0:newpix-1], title = namered, $
  xst = 3, yst = 3, psym = 10, xtitle =  'Wavelength', $
  ytitle = 'Flux', $
  position =  [0.1, 0.1, 0.99, 0.49],  /normal, color = col.white
oplot, newwave[indexblue1:indexblue1+overnpix-1], $
  newflux[indexblue1:indexblue1+overnpix-1],  color = col.red,  psym = 10
!p.multi = 0
wshow



repeat begin
    print, ' '
    hopchoice3 = ''
    read, 'Store in which hopper? ', hopchoice3
    hopnum3 = fix(hopchoice3)
endrep until (hopnum3 GT 0) and (hopnum3 LT hopsize)
womheaderfix, headred, newwave, newpix


hoparr[hopnum3].wave = newwave[0:newpix-1]
hoparr[hopnum3].nbin = newpix
hoparr[hopnum3].flux = newflux[0:newpix-1]
hoparr[hopnum3].err  = newerr[0:newpix-1]
hoparr[hopnum3].obname = namered
hoparr[hopnum3].head = headred
active = hoparr[hopnum3]
printf, ulog, systime()
printf, ulog, strcompress('File: '+nameblue+' and')
printf, ulog, strcompress('file: '+namered+' concatenated')
printf, ulog, strcompress('over wavelength range: '+$
                        string(waveblue[indexblue1])+' to '+$
                        string(waveblue[indexblue2]))
printf, ulog, strcompress('Scaled to '+brlabel+' by factor '+$
                        string(brscalefac))
if (ewadd EQ 'e') then $
    printf, ulog, 'Blue and red added together equally'
if (ewadd EQ 'w') then begin
    printf, ulog, strcompress('Blue added with weight '+string(weiblue))
    printf, ulog, strcompress('Red added with weight '+string(weired))
endif
if (ewadd EQ 'v') then $
    printf, ulog, 'Blue and red added together with variance for weight'

device, /cursor_crosshair
end
