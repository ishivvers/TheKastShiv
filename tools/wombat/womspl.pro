pro womspl
common wom_hopper, hoparr, hopsize
common wom_active, active
COMMON wom_col, col
womdestruct, active, wave, flux, err, name, npix, spechead

print, ' '
print, strcompress('Object is '+name)
print, ' '

device, cursor_standard = 33
wshow
plot, wave, flux, xst = 3, yst = 3, psym = 10, ytitle = 'Flux', $
  xtitle = 'Wavelength', title = name, color = col.white


ymin = min(flux, MAX = ymax)


;   This makes a user symbol of a filled circle    
us = findgen(48)*(!PI*2/48.0)
usersym, cos(us)*1.25, sin(us)*1.25, /fill
nsplinepoints = 0
tmpsplinepoints =  fltarr(2, 500)
secondflag = 0
repeat begin
    c = ''
    wshow
    repeat begin
        print, 'Change y-scale? (y/n, default=n)'
        c = get_kbrd(1)
        if ((byte(c))[0] EQ 10) then c = 'n'
        c = strlowcase(c)
        print, c
    endrep until (c EQ 'y') OR (c EQ 'n')
    if (c EQ 'y') then begin
        womscaleparse, ymin, ymax
    endif
    plot, wave, flux, xst = 3, yst = 3, psym = 10, $
      yrange = [ymin, ymax], ytitle = 'Flux', $
      xtitle = 'Wavelength', title = name, color = col.white
    if (secondflag EQ 1) then begin
        oplot, tmpsplinepoints[0, 0:nsplinepoints-1], $
          tmpsplinepoints[1, 0:nsplinepoints-1], psym = 8, color = col.red
        oplot, wave, splineresult, color = col.green, psym = 10
    endif
    print, 'Click on continuum points for spline fit (up to 500).'
    print, 'Left button    = add point'
    print, 'Middle button  = delete point'
    print, 'Right button   = done'
    print

    element =  1
    fvalue =  1

    repeat begin
        wait, 0.5
        cursor,  element,  fvalue, /data,  /wait
        button =  !mouse.button
        print, element, fvalue
        
        if (button eq 1) then begin
            oplot,[element],[fvalue],psym=8,color=col.red
            tmpsplinepoints[0, nsplinepoints] = element
            tmpsplinepoints[1, nsplinepoints] =  fvalue
            nsplinepoints =  nsplinepoints + 1
        endif
        
        if (button eq 2) and (nsplinepoints gt 0) then begin
;  first, look for point nearest cursor for deletion
            minsep = 10000000.0
            for i = 0, nsplinepoints-1 do begin
                deltaw = (tmpsplinepoints[0, i]-element)/element
                deltaf = (tmpsplinepoints[1, i]-fvalue)/fvalue
                delta = sqrt( (deltaw)^2 + (deltaf)^2)
                if (delta LT minsep) then begin
                    minsep = delta
                    dpoint = i
                endif
            endfor
;  adjust array when point is removed
            oplot, [tmpsplinepoints[0, dpoint]], $
              [tmpsplinepoints[1, dpoint]], $
              psym = 7, color = col.green,  symsize = 1.5, thick = 2.0
            nsplinepoints = nsplinepoints - 1
            for i = dpoint, nsplinepoints-1 do begin
                tmpsplinepoints[*, i] = tmpsplinepoints[*, i+1]
            endfor
        endif        
    endrep until (button eq 4)
    secondflag = 1
;  sort to get increasing values for wavelength 
    if (nsplinepoints EQ 0) then return
    splinepoints =  fltarr(2, nsplinepoints)
    splinepoints =  tmpsplinepoints[*, 0:nsplinepoints-1]
    sortorder =  sort(splinepoints[0, *])

    splinepoints[0, *] = splinepoints[0, sortorder]
    splinepoints[1, *] = splinepoints[1, sortorder]
    y2 =  spl_init(splinepoints[0, *], splinepoints[1, *])

    splineresult = $
      spl_interp(splinepoints[0, *], splinepoints[1, *], y2, wave)
    oplot, wave, splineresult, color = col.green, psym = 10
    repeat begin
        print, 'Is this ok? (y/n, default=y)'
        b = get_kbrd(1)
        if ((byte(b))[0] EQ 10) then b = 'y' 
        b = strlowcase(b)
        print, b
    endrep until (b EQ 'y') OR (b EQ 'n')
endrep until (b EQ 'y')
print, ' '
repeat begin
    print, 'Subtract continuum from spectrum? (y/n) '
    c = get_kbrd(1)
    c = strlowcase(c)
    print, c
endrep until (c EQ 'y') or (c EQ 'n')
if (c EQ 'y') then begin
    flux = flux-splineresult
    plot, wave, flux, xst = 3, yst = 3, psym = 10, ytitle = 'Flux', $
      xtitle = 'Wavelength', title = name, color = col.white
endif

active.wave = wave
active.flux = flux
print, ' '
repeat begin
    print, 'Store spline in hopper? (y/n) '
    c = get_kbrd(1)
    c = strlowcase(c)
    print, c
endrep until (c EQ 'y') or (c EQ 'n')
if (c EQ 'y') then begin
    repeat begin
        print, ' '
        hopchoice = ''
        read, 'Store in which hopper? ', hopchoice
        hopnum = fix(hopchoice)
    endrep until (hopnum GT 0) and (hopnum LT hopsize)
    hoparr[hopnum].wave = wave
    hoparr[hopnum].flux = splineresult
    hoparr[hopnum].err  = err
    hoparr[hopnum].nbin = npix
    hoparr[hopnum].obname = strcompress(name+' spline')
    hoparr[hopnum].head = spechead
endif
; back to normal cursor
device, /cursor_crosshair
end
