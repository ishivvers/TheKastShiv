PRO wommkbb
common wom_active, active
COMMON wom_col, col
light = 2.99792458E10
h = 6.6260755E-27
k = 1.380658E-16
print, 'This routine will create a blackbody curve for a given temperature'
print, 'with 1 Angstrom bins'
print, ' '

temp = ''
read, 'Enter temperature in degrees Kelvin: ', temp
temp = double(temp)
IF (temp LE 0) THEN temp = 1E-10
waverange = ''
REPEAT BEGIN
    goflag = 1
    read, 'Enter wavelength range to calculate curve: ', waverange
    if (waverange EQ '') THEN BEGIN
        goflag = 0
    endif else begin
        waverange = strtrim(strcompress(waverange), 2)
        space = strpos(waverange, ' ')
        comma = strpos(waverange, ',')
        dash = strpos(waverange, '-')
        if (space GT 0) then begin
            wavestring = strcompress(strsplit(waverange,' ',/extract),/rem)
        endif else if (comma GT 0) then begin
            waverange = strcompress(waverange, /remove_all)
            wavestring = strcompress(strsplit(waverange,',',/extract),/rem)
        endif else if (dash GT 0) then begin
            waverange = strcompress(waverange, /remove_all)
            wavestring = strcompress(strsplit(waverange,'-',/extract),/rem)
        endif else begin
            print, strcompress('You entered '+waverange)
            print, 'I can not parse your range, try ### ###,'
            print, 'or ###, ###, or ###-###.'
            goflag = 0
        endelse
    endelse
    if ((size(wavestring))[1] LT 2) then begin
        print, 'You only entered one number'

        goflag = 0
    endif
endrep until (goflag EQ 1)
wave0 = double(wavestring[0])
waven = double(wavestring[1])
wave = dindgen((waven-wave0)) + wave0
wavecm = wave/1.0E8
npix = (size(wave))[1]
flux = dblarr(npix)

repeat begin
    print, ' '
    print, 'Calculate B_nu(n) or B_lambda(l)'
    c = get_kbrd(1)
    c = strlowcase(c)
    print, c
endrep until (c EQ 'l') OR (c EQ 'n')
IF (c EQ 'l') THEN BEGIN
    flux = (2.0*h*light*light/wavecm^5)/(exp((h*light)/(wavecm*k*temp)) -1)
    flux = !PI*flux/1E8
    ext = 'flm'
ENDIF ELSE IF (c EQ 'n') THEN BEGIN
    nu = light/wavecm
    flux = (2*h*nu^3/light/light)/(exp((h*nu)/(k*temp))-1)
    flux = !PI*flux*1E11
    ext = 'fnu'
ENDif

spectxt = 'bb.'+ext


active.wave = wave
active.flux = flux
active.err = fltarr(npix) + 1.
active.nbin = npix
active.obname = spectxt

print, ' '
print, 'Plotting blackbody curve.'
print, ' '
plot, wave, flux, xst = 3, yst = 3, psym = 10, xtitle =  'Wavelength', $
  ytitle = 'Flux', title = spectxt, color = col.white
print, ' '
print, 'Active spectrum is blackbody curve'
print, ' '
wshow
end
