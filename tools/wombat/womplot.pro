pro womplot

common wom_active, active
COMMON wom_col, col
womdestruct, active, wave, flux, err, name, npix, header
print, ' '
print, strcompress('Object is '+name)
print, ' '
plot, wave, flux, xst = 3, yst = 3, psym = 10, $
  xtitle =  'Wavelength', ytitle = 'Flux', title = name, color = col.white
wshow
ymin = min(flux, MAX = ymax)
xmin = min(wave, max = xmax)
repeat begin
    print, 'Change scale? (y/n)'
    c = get_kbrd(1)
    if ((byte(c))[0] EQ 10) then c = 'n'
    c = strlowcase(c)
    print, c
endrep until (c EQ 'y') OR (c EQ 'n')
if (c EQ 'y') then BEGIN
    okflag = 0
    REPEAT begin
;            print, 'Enter your new ymin and ymax values: '
;            read, ymin, ymax
;   changed this so you can zoom in.  Ryan wrote this code for esi and
;   it is too good not to use here
        ymin = min(flux, MAX = ymax)
        xmin = min(wave, max = xmax)
        
        plot, wave, flux, xst = 3, yst = 3, psym = 10, $
          xtitle =  'Wavelength', ytitle = 'Flux', title = name,  $
          color = col.white, yrange = [ymin, ymax], $
          xrange = [xmin, xmax]
        print
      
        print, '  Mark the corners of your boxxx...'
        wait, 0.3
        cursor, xmin, ymin, /data, /wait
        wait, 0.3
        plots, xmin, ymin, psym = 7, col = col.red, thick = 2
        ;wait, 0.2
        cursor, xmax, ymax, /wait, /data
        ;plots, xmax, ymax, psym = 7, col = col.red, thick = 2
        plot, wave, flux, xst = 3, yst = 3, psym = 10, color = col.white, $
          xtitle =  'Wavelength', ytitle = 'Flux', title = name, $
          yrange = [ymin, ymax], xrange = [xmin, xmax]
        REPEAT begin
            print, 'Is this ok? (y/n, default=y)'
            c = get_kbrd(1)
            if ((byte(c))[0] EQ 10) then c = 'y'
            c = strlowcase(c)
            print, c
        endrep until (c EQ 'y') or (c EQ 'n')
        if (c EQ 'y') then begin
            okflag = 1
        endif
    ENDREP UNTIL (okflag EQ 1)
endif

; repeat begin
;     print, ' '
;     print, 'Change wavelength scale? (y/n default n)'
;     b = get_kbrd(1)
;     if ((byte(b))[0] EQ 10) then b = 'n'
;     b = strlowcase(b)
;     print, b
; endrep until (b EQ 'y') OR (b EQ 'n')
; if (b EQ 'y') then begin
; womwaverange, wave, flux, indexblue, indexred, npix, 0
; endif
; plot, wave, flux, xst = 3, yst = 3, psym = 10, color = col.white, $
;   xtitle =  'Wavelength', ytitle = 'Flux', title = name
; wshow
; repeat begin
;     print, ' '
;     print, 'Change y-scale? (y/n default n)'
;     c = get_kbrd(1)
;     if ((byte(c))[0] EQ 10) then c = 'n'
;     c = strlowcase(c)
;     print, c
; endrep until (c EQ 'y') OR (c EQ 'n')
; if (c EQ 'y') then begin
;     womscaleparse, ymin, ymax
;     plot, wave, flux, xst = 3, yst = 3, psym = 10, $
;       xtitle =  'Wavelength', ytitle = 'Flux', title = name,  $
;       yrange = [ymin, ymax], color = col.white
;     wshow
; endif
end
