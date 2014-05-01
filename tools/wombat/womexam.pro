pro womexam
common wom_active, active
device, cursor_standard = 33
!Y.STYLE = 16
us = findgen(48)*(!PI*2/48.0)
usersym, cos(us), sin(us), /fill
womdestruct, active, wave, flux, err, name, npix, header

print, ' '
print, strcompress('Object is '+name)
print, ' '
print, strcompress('Spectrum runs from '+string(wave[0])+' to '+ $
                   string(wave[npix-1])+'.')
print, ' '

repeat begin
    goflag = 1
    wavesel = wave
    fluxsel = flux
    npixsel = npix
    womwaverange, wavesel, fluxsel, indexblue, indexred, npixsel, 0 
    if ((indexred-indexblue) GT 30) then begin
        print, strcompress('That will be '+ string(indexred-indexblue+1)+ $
                           ' bins.  '+$
                           'Do you want to see that many? (y/n, default=y) ')
        repeat begin
            c = get_kbrd(1)
            if ((byte(c))[0] EQ 10) then c = 'y'
            c = strlowcase(c)
            print, c
        endrep until (c EQ 'y') or (c EQ 'n')
        if (c EQ 'n') then goflag = 0
    endif
endrep until (goflag EQ 1)

print, ' '
print, '      Wavelength      Flux     Error'
print, ' '
for i = indexblue, indexred do begin
    print, wave[i],  flux[i], err[i]
endfor
print, ' '
device, /cursor_crosshair
end
