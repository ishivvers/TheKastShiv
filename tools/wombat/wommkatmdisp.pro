PRO wommkatmdisp
common wom_active, active
COMMON wom_col, col
; this routine is to give the arcsecond deviation OF light FOR 
; dispersion by the atmosphere.  all the formulae AND data come from 
; flipper's paper, 1982, PASP, 94, 715.
light = 2.99792458E10
h = 6.6260755E-27
k = 1.380658E-16
print, 'This routine will create a curve of the dispersion of light'
print, 'by the atmosphere in arc seconds per 1 Angstrom bin'
print, ' '
airmass = ''
temp = ''
press = ''
water = ''
print, 'Enter airmass for the calculation: '
read,  '(default = 1.5): ', airmass
IF (airmass EQ '') THEN airmass =  1.5
airmass = double(airmass)
IF (airmass LT 1.0) OR (airmass GT 7.0) THEN airmass = 1.5
print, ' '
print, 'Enter temperature at telescope in degrees Celsius: '
read,  '(default = 7 C [xx F]): ', temp
IF (temp EQ '') THEN temp = 7.0
temp = double(temp)
IF (temp LE -100) THEN temp = 7.0
print, ' '
print, 'Enter barometric pressure at telescope in mm of Hg: '
read,  '(default = 600 mm Hg): ', press
IF (press EQ '') THEN press =  600.0
press = double(press)
IF (press LE 0) THEN press = 600.0
print, ' '
print, 'Enter water vapor pressure at telescope in mm of Hg: '
read,  '(default = 8 mm Hg): ', water
IF (water EQ '') THEN water = 8.0
water = double(water)
IF (water LT 0) THEN water = 8.0
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
ws = wavestring[0]+' '+wavestring[1]
print,  ' '
print, 'OK, calculating dispersion of light in arc seconds over the'
print, strcompress('range '+ws+' at temperature '+string(temp)+$
                   ' C, ')
print, strcompress('pressure '+string(press)+' mm Hg, and water vapor'+$
                   ' pressure '+string(water)+' mm Hg.')
print, 'Zero is set at 5000 A'
          

wave0 = double(wavestring[0])
waven = double(wavestring[1])
wave = dindgen((waven-wave0)) + wave0
wavevac = wave
airtovac, wavevac
wavemic = wavevac/1.0E4
npix = (size(wave))[1]
flux = dblarr(npix)
err  = dblarr(npix) + 1.
nstp = dblarr(npix)
n = dblarr(npix)
lfactor = 1.0/wavemic^2
waterfactor = water*((0.0624-0.000680*lfactor)/(1.0+0.003661*temp))
nstp = 1E-6*(64.328+(29498.1/(146.0-lfactor))+(255.4/(41-lfactor)))
n = (nstp)*((press*(1.0+(1.049-0.0157*temp)*1E-6*press))/ $
                        (720.883*(1.0+0.003661*temp)))-$
  waterfactor*1.0E-6
n = n+1.0
five = 5000.0
five = double(five)
airtovac, five
five = five/1.0E4
fivefact = 1.0/five^2
wfive = water*((0.0624-0.000680*fivefact)/(1.0+0.003661*temp))
nstpfive = 1E-6*(64.328+(29498.1/(146.0-fivefact))+(255.4/(41-fivefact)))
nfive = (nstpfive)*((press*(1.0+(1.049-0.0157*temp)*1E-6*press))/ $
                        (720.883*(1.0+0.003661*temp)))-wfive*1.0E-6
nfive = nfive+1.0
; airmass is sec z, we need tan z for formula
cosz = 1.0/airmass
tanz = (sqrt(1-cosz^2))/cosz
flux = 206265.0*(n-nfive)*tanz
spectxt = strcompress('atmospheric dispersion curve z='+string(airmass))


active.wave = wave
active.flux = flux
active.err  = err
active.nbin = npix
active.obname = spectxt

print, ' '
print, 'Plotting atmospheric dispersion curve'
print, ' '
plot, wave, flux, xst = 3, yst = 3, psym = 10, xtitle =  'Wavelength', $
  ytitle = 'Arcseconds', title = spectxt, color = col.white
print, ' '
print, 'Active spectrum is atmospheric dispersion curve'
print, ' '
wshow
end
