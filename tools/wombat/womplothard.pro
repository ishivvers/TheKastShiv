pro womplothard

common wom_active, active
COMMON wom_col, col
womdestruct, active, wave, flux, err, name, npix, header
print, ' '
print, strcompress('Object is '+name)
print, ' '
plot, wave, flux, xst = 3, yst = 3, psym = 10, color = col.white, $
  xtitle =  'Wavelength', ytitle = 'Flux', title = name
wshow
repeat begin
    print, ' '
    print, 'Change wavelength scale? (y/n default n)'
    b = get_kbrd(1)
    if ((byte(b))[0] EQ 10) then b = 'n'
    b = strlowcase(b)
    print, b
endrep until (b EQ 'y') OR (b EQ 'n')
if (b EQ 'y') then begin
womwaverange, wave, flux, indexblue, indexred, npix, 0
endif
plot, wave, flux, xst = 3, yst = 3, psym = 10, color = col.white, $
  xtitle =  'Wavelength', ytitle = 'Flux', title = name
wshow
repeat begin
    print, ' '
    print, 'Change y-scale? (y/n default n)'
    c = get_kbrd(1)
    if ((byte(c))[0] EQ 10) then c = 'n'
    c = strlowcase(c)
    print, c
endrep until (c EQ 'y') OR (c EQ 'n')

if (c EQ 'y') then begin
    womscaleparse, ymin, ymax
    plot, wave, flux, xst = 3, yst = 3, psym = 10, color = col.white, $
      xtitle =  'Wavelength', ytitle = 'Flux', title = name,  $
      yrange = [ymin, ymax]
    wshow
endif
ymin = !y.crange[0]
ymax = !y.crange[1]
; !p.font = 0
; set_plot, 'ps'
; device, set_font = "Times-Bold", file = 'wombat.ps', $
;   /landscape
; device, /inches, xoffset = 1.0, yoffset = 10.0, $
;   xsize = 9.5, ysize = 7.5
;ps_open, 'wombat', /ps_fonts
psopen, 'wombat', /ps_fonts
device, set_font = "Times-Bold", /inches, ysize = 7.0, xsize = 10.0,  $
  font_size = 15, yoffset = 10.75
 plot, wave, flux, xst = 3, yst = 3, psym = 10, $
      xtitle =  'Wavelength', ytitle = 'Flux', title = name,  $
      yrange = [ymin, ymax], thick = 2, xthick = 2, ythick = 2
; device, /close
; set_plot, 'x'
; !p.font = -1
;ps_close
psclose
spawn,'hprint -d psp5 wombat.ps'
print, ' '
print, 'Printing file now, also on disk as ''wombat.ps''
end
