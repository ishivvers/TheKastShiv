pro realmkbstar, infile, gratcode, intera

;-----------------------------------------------------------------------
; mkbstar.pro
;
; This program reads in an IRAF format multispec extraction for a
; B-star.  Spline fit to continuum done manually.
; The regions not affected by atmospheric absorption
; are set to 1, and the wavelength scale is binned to the standard
; wavelength scale for the run.
; The result is written out to bstar.fits, and is used as an input
; to the routine that actually removes the continuum bands.
;
; This routine will use the 1st beam of the spectrum, whether this is
; a normal or an optimal extraction.
; If there are multiple apertures, it will plot each aperture and
; prompt the user for which one to use as the B-star.
;
; AB, 1/22/98, modified 4/30/98 for continuum fitting
; TM, 11/15/98 repeat fits to B-star if mistakes
; TM, now realmkbstar, called by mkbstar so that you can choose an
; interactive or non-interactive option
;------------------------------------------------------------------------
; sets up calls for color in all plots

   col = {black: 0L, red: 255L, green: 65280L, blue: 16711680L, $
          aqua: 16776960L, violet: 16711935L, yellow: 65535L, white: 16777215L}
;  col = {black: 0L, red: 1L, green: 2L, blue: 3L, $
;         aqua: 4L, violet: 5L, yellow: 6L, white: 7L}
;            b  r  g  b  a  v  y  w
;            l  e  r  l  q  i  e  h
;            a  d  e  u  u  o  l  i
;            c     e  e  a  l  l  t
;            k     n        e  o  e
;                           t  w
;  rtiny  =  [0, 1, 0, 0, 0, 1, 1, 1]
;  gtiny  =  [0, 0, 1, 0, 1, 0, 1, 1]
;  btiny  =  [0, 0, 0, 1, 1, 1, 0, 1]
;  tvlct, 255*rtiny, 255*gtiny, 255*btiny
;  Ordered Triple to long number: COLOR = R + 256 * (G + 256 * B)

;loadct, 2
if (!d.window GE 0) then begin
    device, get_window_position = place
    window, title = 'MkB-Star', xsize = !d.x_size, ysize = !d.y_size, $
      xpos = place[0]-5, ypos = place[1]+25
endif
if (!d.window LT 0) then begin
    device, get_screen_size = si
    window, title = 'MkB-Star',  xsize = fix(si[0]*.78125), $
      ysize = fix(si[1]*.7222222), xpos = fix(si[0]*.2083333), $
      ypos = fix(si[1]*.277777)
endif

repeat begin
    existflag = 1
    if (n_params() EQ 0) OR (infile EQ '') then begin
        infile = ''
        print, ' '
        print,  'Enter the filename of the b-star: (suffix .ms.fits assumed) '
        read, infile
    endif
    infile = strtrim(infile, 2)
    if (rstrpos(infile, '.ms.fits') EQ -1) then begin
        infile = strcompress(infile + '.ms.fits',  /remove_all)
    endif
    isfile = findfile(infile, COUNT = count)
    if (count EQ 0) then begin
        print, strcompress('File '+infile+' does not exist.')
        existflag = 0
    endif
endrep until (existflag EQ 1)
rawdata = readfits(infile, head)
naps = (size(rawdata))[2]

npix = n_elements(rawdata[*, 0, 0])
wavearr = fltarr(npix, naps)

for i = 0, naps-1 do begin
    getmswave, head, npix, i, tmpwave
    wavearr[*, i] = tmpwave
endfor
if (wavearr[npix-1, 0] LT 3000) then begin
    print, '************************************************'
    print, 'Spectrum not wavelength calibrated---bailing out'
    print, '************************************************'
    retall
endif

pacheck, head
airmass = float(sxpar(head, 'AIRMASS'))
; scale to rational numbers, (as in sane, not opposed to irrational numbers)
if ( abs(avg(rawdata[*, 0, 0])) LT 1e-7) then rawdata =  rawdata * 1e15



if (naps EQ 1) then begin
    ap = 0

endif else begin

; Plot the npix apertures, and prompt for which one to use
; as the B-star.

    !p.multi = [0, 1, naps]
    wshow
    for i =  0, naps-1 do begin
        plot,  wavearr[*, i],  rawdata[*, i, 0], yst = 3, xst = 3, $
          psym = 10, xtickname = replicate(' ', 40), color = col.white, $
          position =  [0.06,  ((1.0 - (float(i+1)/float(naps))) * 0.9) + 0.05,  0.99,  ((1.0 - (float(i)/float(naps))) * 0.90) + 0.05], /normal, ytitle = strcompress('Aperture '+ string(i))
    endfor
    !p.multi =  0


    print
    repeat begin
        ap = ''
        print,  'Which aperture do you want to use as the B-star?'
        read,  ap
        ap =  fix(ap)
    endrep until (ap GE 0) and (ap LE naps-1)

endelse

IF (intera EQ 'y') THEN BEGIN
    finalscaler, rawdata[*, ap, 0], ymin, ymax
    plot, wavearr[*,ap], rawdata[*, ap, 0], xst = 3, yst = 3, psym = 10, $
      title = objectname, /nodata, yrange = [ymin, ymax], $
      color = col.white
    oplot, wavearr[*,ap], rawdata[*, ap, 1], psym = 10,  color = col.red
    oplot, wavearr[*,ap], rawdata[*, ap, 0], psym = 10, color = col.white


    wshow

    repeat begin
        print, 'Plotting optimal as white, normal as red'
        print, 'Do you want to use the (n)ormal or the (o)ptimal extraction?'
        extract = get_kbrd(1)
        extract = strlowcase(extract)
        print, extract
    endrep until (extract EQ 'n') or (extract EQ 'o')

    case extract of
        'o': begin
            bstar = rawdata[*, ap, 0]
        end
        'n': begin
            bstar = rawdata[*, ap, 1]
        end
    endcase
ENDIF ELSE BEGIN
    bstar =  rawdata[*, ap, 0]
ENDELSE

;bstar =  rawdata[*, ap, 0]
wave = wavearr[*, ap]
; iraf wavelength fitting can leave you with negative values for data numbers
nneg = 0
neg = where((bstar LT 0), nneg)
if (nneg GT 0) then bstar(neg) = 0.01
; Fit the continuum manually
print
print, 'Airmass = ', airmass
print
airlimit = 1.5
alimit = ''
IF (intera EQ 'y') THEN BEGIN
    REPEAT BEGIN
        read, 'Above what airmass is considered high? ', alimit
        airlimit = float(alimit)
    ENDREP UNTIL (airlimit GE 1.0) AND (airlimit LT 15.0)
endif
print, 'Time to fit the B-star continuum manually.'
print

fitspline, wave, alog10(bstar), airmass, splineresult, airlimit, col


splineresult = 10^(splineresult)

;print, 'Hit a key to continue...'
;print
;a =  get_kbrd(1)


bstar =  bstar / splineresult



; Set continuum to 1 in regions not affected by absorption bands



if (airmass GT airlimit) then begin

    w =  where( (wave GE 3190) AND (wave LE 3216),  nw)
    if (nw GT 0) then bstar(w) =  1
;    w =  where( (wave GE 3420) AND (wave LE 5600),  nw)
    w =  where( (wave GE 3420) AND (wave LE 5500),  nw)
    if (nw GT 0) then bstar(w) =  1
    w =  where( (wave GE 6050) AND (wave LE 6250),  nw)
    if (nw GT 0) then bstar(w) =  1
    w =  where( (wave GE 6360) AND (wave LE 6450),  nw)
    if (nw GT 0) then bstar(w) =  1
    w =  where( (wave GE 6530) AND (wave LE 6840),  nw)
    if (nw GT 0) then bstar(w) =  1
    w =  where( (wave GE 7410) AND (wave LE 7560),  nw)
    if (nw GT 0) then bstar(w) =  1
    w =  where( (wave GE 8410) AND (wave LE 8800),  nw)
    if (nw GT 0) then bstar(w) =  1
    w =  where( (wave GE 9900),  nw)
    if (nw GT 0) then bstar(w) =  1

endif else begin

    w =  where( (wave GE 3190) AND (wave LE 3216),  nw)
    if (nw GT 0) then bstar(w) =  1
    w =  where( (wave GE 3420) AND (wave LE 6250),  nw)
    if (nw GT 0) then bstar(w) =  1
    w =  where( (wave GE 6360) AND (wave LE 6840),  nw)
    if (nw GT 0) then bstar(w) =  1
    w =  where( (wave GE 7410) AND (wave LE 7560),  nw)
    if (nw GT 0) then bstar(w) =  1
    w =  where( (wave GE 8410) AND (wave LE 8800),  nw)
    if (nw GT 0) then bstar(w) =  1
    w =  where( (wave GE 9900),  nw)
    if (nw GT 0) then bstar(w) =  1

endelse


; Clip bstar spectrum at 1
w = where((bstar GT 1), nw)
if (nw GT 0) then bstar(w) = 1

wshow
plot,  wave, bstar, xst = 3, yst = 3, psym = 10, $
  xtitle = 'Wavelength', ytitle = 'Relative Flux', color = col.white



sxdelpar,  head,  'WAT0_001'
sxdelpar,  head,  'WAT1_001'
sxdelpar,  head,  'WAT2_001'
sxdelpar,  head,  'WAT0_002'
sxdelpar,  head,  'WAT1_002'
sxdelpar,  head,  'WAT2_002'
sxdelpar,  head,  'WAT3_001'
sxdelpar,  head,  'WAT2_003'
sxdelpar,  head,  'CTYPE1'
sxdelpar,  head,  'CTYPE2'
sxdelpar,  head,  'CTYPE3'

sxaddpar,  head,  'CRPIX1', 1
sxaddpar,  head,  'CRVAL1',  wave[0]
sxaddpar,  head,  'CDELT1', wave[1] - wave[0]
sxaddpar,  head,  'CTYPE1', 'LINEAR'

outfile = 'bstar'
if (n_params() GT 0) then begin
    outfile = strcompress(outfile+gratcode, /remove_all)
endif
outfile = strcompress(outfile+'.fits', /remove_all)
print, strcompress('Writing data to '+outfile)
writefits,  outfile, bstar, head

end
