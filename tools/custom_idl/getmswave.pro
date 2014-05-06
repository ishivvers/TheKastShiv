pro getmswave, mshead, npix, i, wave

;-----------------------------------------------------------------------
; Program to read the header of a  multispec-format fits file 
; created by IRAF apall and return a wavelength vector for the ith 
; object.  
;
; For now, this only works for linear wavelength scales.
;
; *****NOTE:  This routine assumes that you want to use idl-style
;             array counting, not iraf-style.
;             Aperture numbers begin at zero!
;             So in the iraf header, spec1 corresponds to ap 0!
;
;
; AJB, 4/24/98, fixed 2/5/99 for more than 2 apertures
; Fixed 10/4/99 for >=10 apertures (hopefully)
;----------------------------------------------------------------------


; Get wavelength vector for ith aperture

  watstringarr = sxpar(mshead, 'WAT2_*', count = nwats)

  watstring = ''

  for j = 0, nwats-1 do begin
      watstring = strcompress(watstring + watstringarr[j])
    endfor

  if (strlen(watstring) GT 12) then begin

      specnum = strcompress('spec' + string(i+1), /remove_all)
      
      specpos = strpos(watstring, specnum)
      substring = strmid(watstring, specpos)
      
      quotepos1 = strpos(substring, '"')
      substring = strmid(substring, quotepos1+1)
      
      quotepos2 = strpos(substring, '"')
      substring = strmid(substring, 0, quotepos2)
      
      reads, substring, a, b, c, d, e, f, g, h, k
      npix = long(f)
      crval = float(d)
      cdelt = float(e)
      wave = findgen(npix) * cdelt + crval

    endif else begin
        crval =  sxpar(mshead, 'CRVAL1')
        cdelt =  sxpar(mshead, 'CD1_1')
        wave =  findgen(npix) * cdelt + crval
        
      endelse

end
