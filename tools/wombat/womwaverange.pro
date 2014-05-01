pro womwaverange, wave, flux, indexblue, indexred, npix, selectmode
COMMON wom_col, col
; if selectmode is 0,  then ask whether to use mouse or enter wavelengths
; if      "     is 1,  use wavelengths
; if      "     is 2,  use mouse
; note that this info is passed back to the calling routine,  so 
; subsequent calls to womwaverange will use the first time choice
; within any given routine
device, cursor_standard = 33
!Y.STYLE = 16
us = findgen(48)*(!PI*2/48.0)
usersym, cos(us), sin(us), /fill
if (selectmode EQ 0) then begin
    repeat begin
        print, ' '
        print, 'Do you want to select wavelength range by
        print, 'entering (w)avelengths or marking with the (m)ouse? (w/m) '
        select = get_kbrd(1)
        print, select
        select = strlowcase(select)
    endrep until (select EQ 'w') or (select EQ 'm')
endif
if (selectmode EQ 1) then select = 'w'
if (selectmode EQ 2) then select = 'm'
case select of
    'w':selectmode = 1
    'm':selectmode = 2
endcase
print, ' '
print, strcompress('Spectrum runs from '+string(wave[0])+' to '+ $
                   string(wave[npix-1])+'.')
print, ' '
plot, wave, flux, xst = 3, yst = 3, psym = 10, xtitle = 'Wavelength', $
  ytitle = 'Flux', color = col.white
wshow
if (selectmode EQ 1) then begin
    repeat begin
        wavestring = ''
        goflag = 1
        womwaveparse, wave, wavestring, npix
        waveblue = float(wavestring[0])
        wavered = float(wavestring[1])
; this is to catch a second word entered that is not a number, but
; it can't just be that wavered is 0 (which is what float(string)
; returns if the string is not a number), because the wavelength
; can be zero for spectra on a velocity scale  this should catch
; most errors, but it still won't crash if it misses the error
        if (wavered EQ 0) and (wavered LE waveblue) $
          then wavered = wave[npix-1]

        if (wavered LE waveblue) then begin
            temp = waveblue
            waveblue = wavered
            wavered = temp
        endif
        if (waveblue LT wave[0]) then waveblue = wave[0]
        if (wavered GT wave[npix-1]) then wavered = wave[npix-1]
        if (goflag EQ 1) then begin
            womget_element, wave, waveblue, indexblue
            womget_element, wave, wavered, indexred
            print,strcompress('Range selected: '+$
                              string(wave[indexblue])+$
                              ' to '+string(wave[indexred]))
        endif
        if (not( (indexblue EQ 0) and (indexred EQ (npix-1)))) then begin
            oplot, wave[indexblue:indexred], flux[indexblue:indexred], $
              psym = 10, color = col.red
            repeat begin
                print, 'Is this range correct? (y/n, default y) '
                c = get_kbrd(1)
                if ((byte(c))[0] EQ 10) then c = 'y'
                c = strlowcase(c)
                print, c
            endrep until (c EQ 'y') or (c EQ 'n')
            if (c EQ 'n') then begin
                plot, wave, flux, xst = 3, yst = 3, psym = 10, $
                  xtitle = 'Wavelength', ytitle = 'Flux', color = col.white
                wshow
                goflag = 0
            endif
        endif
    endrep until (goflag EQ 1)
endif else if (selectmode EQ 2) then begin
    repeat begin
        goflag = 1
        print, 'Mark the two end points of the region'
        wait,  0.5 
        cursor, waveblue, flux1, /data, /wait
        print, waveblue, flux1
        oplot,[waveblue],[flux1],psym=8,color=col.red
        wait,  0.5 
        cursor, wavered, flux2, /data, /wait
        print, wavered, flux2
        oplot,[wavered],[flux2],psym=8,color=col.red
        if (waveblue GT wavered) then begin
            temp = waveblue
            waveblue = wavered
            wavered = temp
        endif
        womget_element, wave, waveblue, indexblue
        womget_element, wave, wavered, indexred
        print,strcompress('Range selected: '+string(wave[indexblue])+$
                          ' to '+string(wave[indexred]))
        
        oplot, wave[indexblue:indexred], flux[indexblue:indexred], $
          psym = 10, color = col.red

        repeat begin
            print, 'Is this range correct? (y/n, default y) '
            c = get_kbrd(1)
            if ((byte(c))[0] EQ 10) then c = 'y'
            c = strlowcase(c)
            print, c
        endrep until (c EQ 'y') or (c EQ 'n')
        if (c EQ 'n') then begin
            plot, wave, flux, xst = 3, yst = 3, psym = 10, $
              xtitle = 'Wavelength', ytitle = 'Flux', color = col.white 
            wshow
            goflag = 0
        endif
    endrep until (goflag EQ 1)

endif
wave = wave[indexblue:indexred]
flux = flux[indexblue:indexred]
npix = indexred-indexblue+1
end
