pro womfnuflam
common wom_active, active
womdestruct, active, wave, flux, err, name, npix, header

print, ' '
repeat begin
    print, 'Is the input spectrum in f-(n)u, f(l)ambda, (a)b magnitudes,'
    print, 'or (s)t magnitudes? (n/l/a/s) '
    is = get_kbrd(1)
    is = strlowcase(is)
    print, is
endrep until (is EQ 'n') or (is EQ 'l') or (is EQ 'a') or (is EQ 's')
momentflux = moment(flux)
mn = momentflux[0]
scale = 0
if (is EQ 'n') then begin
    if (mn GT 1E-5) then begin
        flux = flux/1E26
        if (total(err[0:npix-1]) ne npix) then err = err/1E26
        scale = 1
    endif
    flux = flux*2.997925E18/wave/wave
    if (total(err[0:npix-1]) ne npix) then err = err*2.997925E18/wave/wave
endif

if (is EQ 'a') then begin
    flux = 10^(-0.4*flux-19.44)
    flux = flux*2.997925E18/wave/wave
    if (total(err[0:npix-1]) ne npix) then begin
      err = 10^(-0.4*err-19.44)
      err = err*2.997925E18/wave/wave
    endif
endif

if (is EQ 's') then begin
    flux = 10^(-0.4*flux-8.44)
    if (total(err[0:npix-1]) ne npix) then err = 10^(-0.4*err-8.44)
endif
if (is EQ 'l') then begin
    if (mn GT 1E-5) then begin
        flux = flux/1E15
        scale = 1
        if (total(err[0:npix-1]) ne npix) then err = err/1E15
    endif
endif
print, ' '
repeat begin
    print, 'Convert to f-(n)u, f(l)ambda, (a)b magnitudes, or'
    print, '(s)t magnitudes? (n/l/a/s) '
    os = get_kbrd(1)
    os = strlowcase(os)
    print, os
endrep until (os EQ 'n') or (os EQ 'l') or (os EQ 'a') or (os EQ 's')

if (os EQ 'n') then begin
    flux = flux*wave*wave/2.997925E18
    if (total(err[0:npix-1]) ne npix) then err = err*wave*wave/2.997925E18
    if (scale EQ 1) then begin
        flux = flux*1E26
        if (total(err[0:npix-1]) ne npix) then err = err*1E26
    endif
endif
if (os EQ 'a') then begin
    flux = flux*wave*wave/2.997925E18
    flux = flux*10^19.44
    if (total(err[0:npix-1]) ne npix) then begin
      err = err*wave*wave/2.997925E18
      err = err*10^19.44
    endif
    zero = where((flux LE 0), nneg)
    if (nneg GT 0) then begin
        flux(zero) = 1.0
        err(zero) = 1.0
    endif
    flux = -2.5*alog10(flux)
    if (total(err[0:npix-1]) ne npix) then err = -2.5*alog10(err)
endif
if (os EQ 's') then begin
     zero = where((flux LE 0), nneg)
    if (nneg GT 0) then begin
        flux(zero) = 3.63E-19
        if (total(err[0:npix-1]) ne npix) then err = 3.63E-19
    endif   
    flux = -2.5*alog10(flux)-21.10
    if (total(err[0:npix-1]) ne npix) then err = -2.5*alog10(err)-21.10
endif
if (os EQ 'l') then begin
    if (scale EQ 1) then begin
        flux = flux*1E15
        if (total(err[0:npix-1]) ne npix) then err*1E15
    endif
endif
active.flux = flux
active.err = err


end
