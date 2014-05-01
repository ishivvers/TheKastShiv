pro womwfits
common wom_active, active
womdestruct, active, wave, flux, err, name, npix, spechead

print, strcompress('The object is '+name)
print, ' '
specfits = ''

print, 'Enter the name for the output file: (.fits will be added,' $
  + 'if necessary): '
read, ': ',  specfits
if (specfits EQ '') then return
specfits = strtrim(specfits, 2)
    if (rstrpos(specfits, '.fits') EQ -1) then begin
specfits = strcompress(specfits+'.fits', /remove_all)
endif
test = sxpar(spechead, 'SIMPLE')
errflag = 0
if (total(err[0:npix-1]) ne npix) then begin
  erflag = 1
  splits = strsplit(specfits,'-[0-9]+.+[0-9]+-',/extract,/regex)
  date = stregex(specfits,'-[0-9]+.+[0-9]+-',/extract)
  errfits = strcompress(splits[0]+date+'variance-'+splits[1],/remove_all)
endif

if (test EQ 1) then begin
    sxaddpar, spechead,  'CRPIX1', 1
    sxaddpar,  spechead,  'CRVAL1',  wave[0]
    sxaddpar,  spechead,  'CDELT1', wave[1] - wave[0]
    sxaddpar,  spechead,  'CTYPE1', 'LINEAR' 
    sxaddpar, spechead, 'NAXIS1', npix
    flux = flux[0:npix-1]
    writefits, specfits, flux, spechead
    if (errflag eq 1) then begin
      err = 1d/err[0:npix-1]
      writefits, errfits, err, spechead
    endif
endif else begin
    mkhdr, newhead, flux
    sxaddpar, newhead,  'CRPIX1', 1
    sxaddpar,  newhead,  'CRVAL1',  wave[0]
    sxaddpar,  newhead,  'CDELT1', wave[1] - wave[0]
    sxaddpar,  newhead,  'CTYPE1', 'LINEAR' 
    sxaddpar, newhead, 'NAXIS1', npix
    flux = flux[0:npix-1]
    writefits, specfits, flux, newhead
    if (errflag eq 1) then begin
      err = err[0:npix-1]
      writefits, errfits, err, spechead
    endif
endelse

end
