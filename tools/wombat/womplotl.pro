pro womplotl
common wom_active, active
COMMON wom_col, col
womdestruct, active, wave, flux, err, name, npix, header

print, ' '
print, strcompress('Object is '+name)
print, ' '
print, strcompress('Spectrum runs from '+string(wave[0])+' to '+ $
                   string(wave[npix-1])+'.')
womwaverange, wave, flux, indexblue, indexred, npix, 0
print, ' '
repeat begin
    print, 'Do you want log scale on x, y, or (b)oth axes? (x/y/b) '
    a = get_kbrd(1)
    a = strlowcase(a)
    print, a
endrep until (a EQ 'x') or (a EQ 'y') or (a EQ 'b')
print, ' '
if (a EQ 'x') then begin
    plot, wave, flux, xst = 3, yst = 3, psym = 10, $
      xtitle =  'Wavelength', /xlog, $
      ytitle = 'Flux', title = name, color = col.white
    wshow
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
        plot, wave, flux, xst = 3, yst = 3, psym = 10, $
          xtitle =  'Wavelength', /xlog, color = col.white, $
          ytitle = 'Flux', title = name, yrange = [ymin, ymax]
        wshow
    endif
endif
if (a EQ 'y') then begin
    plot, wave, flux, xst = 3, yst = 3, psym = 10, $
      xtitle =  'Wavelength', /ylog, color = col.white, $
      ytitle = 'Flux', title = name
    wshow
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
        plot, wave, flux, xst = 3, yst = 3, psym = 10, $
          xtitle =  'Wavelength', /ylog, color = col.white, $
          ytitle = 'Flux', title = name,  yrange = [ymin, ymax]
        wshow
    endif
endif
if (a EQ 'b') then begin
    plot, wave, flux, xst = 3, yst = 3, psym = 10, $
      xtitle =  'Wavelength', /xlog, /ylog, color = col.white, $
      ytitle = 'Flux', title = name
    wshow
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
        plot, wave, flux, xst = 3, yst = 3, psym = 10, $
          xtitle =  'Wavelength', /xlog, /ylog, color = col.white, $
          ytitle = 'Flux', title = name,  yrange = [ymin, ymax]
        wshow
    endif
endif

end
