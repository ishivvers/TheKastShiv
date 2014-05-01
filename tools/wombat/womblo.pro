pro womblo
; routine to blotch out bad data, can fit line between specific
; wavelengths OR marked points,  OR can fit a spline
; TM
common wom_active, active
common wom_ulog, ulog
COMMON wom_col, col
device, cursor_standard = 33
!Y.STYLE = 16
us = findgen(48)*(!PI*2/48.0)
usersym, cos(us), sin(us), /fill
womdestruct, active, wave, flux, err, name, npix, header
wavestring = ''
print, 'Select regions to blotch'
print, ' '
repeat begin
    bflag = 0
    fluxcor = flux
    wavefix = wave
    fluxfix = flux
    npixfix = npix
    womwaverange, wavefix, fluxfix, indexblue, indexred, npixfix, 0
    plot, wavefix, fluxfix, xst = 3, yst = 3, psym = 10, $
      xtitle =  'Wavelength', ytitle = 'Flux', title = name, $
      color = col.white
    wshow
    repeat begin
        print, 'Do you want to enter blotch wavelengths by hand (w)'
        print, 'mark points (m), fit a spline (s), or quit (q) ?'
        blotchmode = get_kbrd(1)
        blotchmode = strlowcase(blotchmode)
        print, blotchmode
    endrep until (blotchmode EQ 'w') or (blotchmode EQ 's') $
      or (blotchmode EQ 'm') or (blotchmode EQ 'q')

    if (blotchmode EQ 'w') then begin
        repeat begin
            fluxcor = flux
            okflag = 1
            repeat begin
                wavecheck = 1
                womwaveparse, wave, wavestring, npix
                bloblue = float(wavestring[0])
                blored = float(wavestring[1])
                womget_element, wave, bloblue, binblue
                womget_element, wave, blored, binred

                if (binblue LT 0) or (binred LT 0) then begin
                    print, 'Wavelengths incorrect--no bin at given lambda'
                    wavecheck = 0
                endif
                if (binblue EQ 0) or (binred EQ npix) then begin
                    print, 'Wavelengths incorrect--too close to endpoints'
                    wavecheck = 0
                endif
                if (binblue GT binred) then BEGIN
                    print, 'Ending wavelength must be greater than'
                    print, 'or equal to beginning one'
                    wavecheck = 0
                endif
            endrep until (wavecheck EQ 1)  
            contleft = fluxcor[binblue-1]
            contright = fluxcor[binred+1]
            diffcont = contright-contleft
            delta = diffcont/(binred-binblue+1)
            for i = binblue, binred do begin
                fluxcor[i] = contleft + (i-binblue+1)*delta
            endfor
            plot, wavefix, fluxfix,  xst = 3, yst = 3, psym = 10, $
              title = name, xtitle = 'Wavelength', ytitle = 'Flux', $
              color = col.white
            oplot, wave[indexblue:indexred], fluxcor[indexblue:indexred], $
              psym = 10, color = col.red
            wshow
            repeat begin
                print, 'Is this acceptable? (y/n, default=y)'
                yesno = get_kbrd(1)
                if ((byte(yesno))[0] EQ 10) then yesno = 'y'
                yesno = strlowcase(yesno)
                print, yesno
            endrep until (yesno EQ 'y') or (yesno EQ 'n')
            if (yesno EQ 'y') then begin
                printf, ulog, systime()
                printf, ulog, strcompress('File: '+name+' blotched')
                printf, ulog, strcompress('from: '+string(bloblue)+' to ' $
                                        +string(blored))
                flux = fluxcor
                okflag = 1
            endif
        endrep until (okflag EQ 1)
    endif
    if (blotchmode EQ 'm') then begin
        repeat begin
            fluxcor = flux
            okflag = 1
            print, 'Mark the two end points of the blotch region'
            wait,  0.5 
            cursor, waveblue, fluxblue, /data, /wait
            print, waveblue, fluxblue
            oplot,[waveblue],[fluxblue],psym=8,color = col.red
            wait,  0.5 
            cursor, wavered, fluxred, /data, /wait
            print, wavered, fluxred
            oplot,[wavered],[fluxred],psym=8,color= col.red
            if (waveblue GT wavered) then begin
                temp = waveblue
                waveblue = wavered
                wavered = temp
            endif
            womget_element, wave, waveblue, binblue
            womget_element, wave, wavered, binred
            contleft = fluxcor[binblue-1]
            contright = fluxcor[binred+1]
            diffcont = contright-contleft
            delta = diffcont/(binred-binblue+1)
            for i = binblue, binred do begin
                fluxcor[i] = contleft + (i-binblue+1)*delta
            endfor
            plot, wavefix, fluxfix,  xst = 3, yst = 3, psym = 10, $
              title = name, xtitle = 'Wavelength', ytitle = 'Flux', $
              color = col.white
            oplot, wave[indexblue:indexred], fluxcor[indexblue:indexred], $
              psym = 10, color = col.red
            wshow
            repeat begin
                print, 'Is this acceptable? (y/n, default=y)'
                yesno = get_kbrd(1)
                if ((byte(yesno))[0] EQ 10) then yesno = 'y'
                yesno = strlowcase(yesno)
                print, yesno
            endrep until (yesno EQ 'y') or (yesno EQ 'n')
            if (yesno EQ 'y') then begin
                printf, ulog, systime()
                printf, ulog, strcompress('File: '+name+' blotched')
                printf, ulog, strcompress('from: '+string((wave[binblue])) $
                                        +' to '+string((wave[binred])))
                flux = fluxcor
                okflag = 1
            endif
        endrep until (okflag EQ 1)

    endif
    if (blotchmode EQ 's') then begin
        repeat begin
            fluxcor = flux
            okflag = 1
            nsplinepoints = 0
            tmpsplinepoints =  fltarr(2, 500)

            print, 'Click on continuum points for spline fit (up to 500).'
            print, 'Left button    = add point'
            print, 'Middle button  = delete point'
            print, 'Right button   = done'
            print

            element =  1
            flux =  1

            repeat begin
                wait, 0.5
                cursor,  element,  flux, /data,  /wait
                button =  !mouse.button
                print, element, flux
                
                if (button eq 1) then begin
                    oplot,[element],[flux],psym=8,color= col.red
                    tmpsplinepoints[0, nsplinepoints] = element
                    tmpsplinepoints[1, nsplinepoints] =  flux
                    nsplinepoints =  nsplinepoints + 1
                endif
                
                
                if (button eq 2) and (nsplinepoints gt 0) then begin
;  first, look for point nearest cursor for deletion
                    minsep = 10000000.0
                    for i = 0, nsplinepoints-1 do begin
                        deltaw = (tmpsplinepoints[0, i]-element)/element
                        deltaf = (tmpsplinepoints[1, i]-flux)/flux
                        delta = sqrt( (deltaw)^2 + (deltaf)^2)
                        if (delta LT minsep) then begin
                            minsep = delta
                            dpoint = i
                        endif
                    endfor
;  adjust array when point is removed
                    oplot, [tmpsplinepoints[0, dpoint]], $
                      [tmpsplinepoints[1, dpoint]], $
                      psym = 7, color = col.green,  symsize = 1.5, $
                      thick = 2.0
                    nsplinepoints = nsplinepoints - 1
                    for i = dpoint, nsplinepoints-1 do begin
                        tmpsplinepoints[*, i] = tmpsplinepoints[*, i+1]
                    endfor
                endif        
            endrep until (button eq 4)

;  sort to get increasing values for wavelength 

            splinepoints =  fltarr(2, nsplinepoints)
            splinepoints =  tmpsplinepoints[*, 0:nsplinepoints-1]
            sortorder =  sort(splinepoints[0, *])

            splinepoints[0, *] = splinepoints[0, sortorder]
            splinepoints[1, *] = splinepoints[1, sortorder]
            y2 =  spl_init(splinepoints[0, *], splinepoints[1, *])
            womget_element, wave, splinepoints[0, 0], binblue
            womget_element, wave, splinepoints[0, nsplinepoints-1], binred

            wavespl = wave[binblue:binred]
            splineresult = $
              spl_interp(splinepoints[0, *], splinepoints[1, *], y2, wavespl)
            oplot, wavespl, splineresult, color = col.green, psym = 10
            repeat begin
                print, 'Is this acceptable? (y/n, default=y)'
                yesno = get_kbrd(1)
                if ((byte(yesno))[0] EQ 10) then yesno = 'y'
                yesno = strlowcase(yesno)
                print, yesno
            endrep until (yesno EQ 'y') or (yesno EQ 'n')
            if (yesno EQ 'y') then begin
                fluxcor[binblue:binred] = splineresult
                printf, ulog, systime()
                printf, ulog, strcompress('File: '+name+' blotched')
                printf, ulog, strcompress('from: '+string((wave[binblue])) $
                                        +' to '+string((wave[binred])))
                printf, ulog, 'with a spline fit'
                flux = fluxcor
                okflag = 1
            endif
        endrep until (okflag EQ 1)

    endif
;     if (blotchmode EQ 'q') then begin
;         bflag = 1
;     endif
    plot, wave, flux, xst = 3, yst = 3, psym = 10, color = col.white, $
      xtitle =  'Wavelength', ytitle = 'Flux', title = name
    repeat begin
        print, 'Do another region? (y/n, default=n)'
        yesno = get_kbrd(1)
        if ((byte(yesno))[0] EQ 10) then yesno = 'n'
        yesno = strlowcase(yesno)
        print, yesno
    endrep until (yesno EQ 'y') or (yesno EQ 'n')
    if (yesno EQ 'n') then bflag = 1
endrep until (bflag EQ 1)
active.flux = flux
!p.multi = 0
device, /cursor_crosshair
end
