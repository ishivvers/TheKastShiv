pro womheaderfix, header, wave, npix

headerexist = 0
headerexist = sxpar(header, 'SIMPLE')
if (headerexist EQ 1) then begin
    sxaddpar, header,  'CRPIX1', 1
    sxaddpar,  header,  'CRVAL1',  wave[0]
    sxaddpar,  header,  'CDELT1', wave[1] - wave[0]
    sxaddpar,  header,  'CTYPE1', 'LINEAR' 
    sxaddpar, header, 'NAXIS1', npix
endif
end
