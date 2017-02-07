pro realmkfluxstar, infile, gratcode, intera

;-----------------------------------------------------------------------
; mkfluxstar.pro
;
; Program to read in an iraf multispec file, and then let the user
; fit the continuum manually.  Writes out fluxstar.fits.
;
; AB, 5/20/98
; Adapted code by Aaron, now fits spline, removes extinction, and
; calibrates with AB values.  The output is used by calibrate for
; the obvious purpose
; TM, 11/21/98
;------------------------------------------------------------------------
; sets up calls for color in all plots

   col = {black: 0L, red: 255L, green: 65280L, blue: 16711680L, $
          aqua: 16776960L, violet: 16711935L, yellow: 65535L, white: 16777215L}
;;;  col = {black: 0L, red: 1L, green: 2L, blue: 3L, $
;;;         aqua: 4L, violet: 5L, yellow: 6L, white:7L}
;            b  r  g  b  a  v  y  w
;            l  e  r  l  q  i  e  h
;            a  d  e  u  u  o  l  i
;            c     e  e  a  l  l  t
;            k     n        e  o  e
;                           t  w
  rtiny  =  [0, 1, 0, 0, 0, 1, 1, 1]
  gtiny  =  [0, 0, 1, 0, 1, 0, 1, 1]
  btiny  =  [0, 0, 0, 1, 1, 1, 0, 1]
  tvlct, 255*rtiny, 255*gtiny, 255*btiny
;  Ordered Triple to long number: COLOR = R + 256 * (G + 256 * B)

;loadct, 2
  if (!d.window GE 0) then begin
      device, get_window_position = place
      window, title = 'MkFluxStar', xsize = !d.x_size, ysize = !d.y_size, $
        xpos = place[0]-5, ypos = place[1]+25
    endif
  if (!d.window LT 0) then begin
      device, get_screen_size = si
      window, title = 'MkFluxStar',  xsize = fix(si[0]*.78125), $
        ysize = fix(si[1]*.7222222), xpos = fix(si[0]*.2083333), $
        ypos = fix(si[1]*.277777)
    endif
; extinction terms from Rem Stone
;http://www.ucolick.org/~mountain/mthamilton/techdocs/info/lick_mean_extinct.html
      extwave = [320.0, 325.0, 330.0, 335.0, 340.0, 345.0, 350.0, $
                 357.1, 363.6, 370.4, 386.2, 403.6, 416.7, 425.5, $
                 446.4, 456.6, 478.5, 500.0, 526.3, 555.6, 584.0, $
                 605.6, 643.6, 679.0, 710.0, 755.0, 778.0, 809.0, $
                 837.0, 870.8, 983.2, 1025.6, 1040.0, 1061.0, $
                 1079.6, 1087.0]

      extvals = [1.084, .948, .858, .794, .745, .702, .665, .617, $
                 .575, .532, .460, .396, .352, .325, .279, .259, $
                 .234, .203, .188, .177, .166, .160, .123, .098, $
                 .094, .080, .076, .080, .077, .057, .080, .050, $
                 .051, .053, .056, .064]
      extwave = extwave*10.
      extvals = extvals/1.086
; extinction terms from Allen, 3rd ed.  via lolita

;extwave = [2400.,2600.,2800.,3000.,3200.,3400.,3600.,3800., $
;           4000.,4500.,5000.,5500.,6000.,6500.,7000.,8000.,9000.,10000., $
;           12000.,14000.]
;extvals = [68.0,89.0,36.0,4.5,1.30,0.84,0.68,0.55,0.46,0.31, $
;           0.23,0.195,0.170,0.126,0.092,0.062,0.048,0.039,0.028,0.021]


  repeat begin
      existflag = 1
      if (n_params() EQ 0) OR (infile EQ '') then begin
          infile = ''
          print, ' '
          print, 'Enter the filename of the flux star: (suffix .ms.fits assumed) '
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
  pacheck, head
  objectname = sxpar(head, 'OBJECT')
  airmass = float(sxpar(head, 'AIRMASS'))
  exptime = fix(sxpar(head, 'EXPTIME'))
  if (exptime eq 0) then exptime = 1
  print, exptime
; get height (meters)
  height = 0.0
  observat =  strcompress(sxpar(head, 'OBSERVAT'), /remove_all)
  case observat of
      'keck': height = 4160.0
      'lick': height = 1285.0
      'palomar': height = 1706.0
      'mcdonald': height = 2075.0
      else: print, 'OBSERVATORY UNKNOWN!!!!!!!!'
    endcase
; 8300.0 meters is scale height of troposphere (according to lolita)
;
  if observat eq 'lick' or observat eq 'keck' then height = 0.0
  getext, extwave, extvals, observat
;  height = 0.
;
  sitefactor = exp(-1.0*height/8300.0)



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



  if (naps EQ 1) then begin
      ap = 0

    endif else begin

; If there are multiple apertures, prompt for which one to use

        !p.multi = [0, 1, naps]
        wshow
        for i =  0, naps-1 do begin
            plot,  wavearr[*, i],  rawdata[*, i, 0], yst = 3, xst = 3, $
              psym = 10, xtickname = replicate(' ', 40),  color = col.white, $
              position =  [0.06,  ((1.0 - (float(i+1)/float(naps))) * 0.9) + 0.05,  0.99,  ((1.0 - (float(i)/float(naps))) * 0.90) + 0.05], /normal, ytitle = strcompress('Aperture '+ string(i))
          endfor
        !p.multi =  0


        print
        repeat begin
            ap = ''
            print,  'Which aperture do you want to use as the flux star?'
            read,  ap
            ap =  fix(ap)
          endrep until (ap GE 0) and (ap LE naps-1)

      endelse
  IF (intera EQ 'y') THEN BEGIN
      finalscaler, rawdata[*, ap, 0], ymin, ymax
      plot, wavearr[*, ap], rawdata[*, ap, 0], xst = 3, yst = 3, psym = 10, $
        title = objectname, /nodata, yrange = [ymin, ymax], $
        color = col.white
      oplot, wavearr[*, ap], rawdata[*, ap, 1], psym = 10,  color = col.red
      oplot, wavearr[*, ap], rawdata[*, ap, 0], psym = 10, color = col.white
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
              star = rawdata[*, ap, 0]
            end
        'n': begin
            star = rawdata[*, ap, 1]
          end
    endcase
ENDIF ELSE BEGIN
    star =  rawdata[*, ap, 0]
  ENDELSE
; iraf wavelength fits can give negative data numbers at ends
nneg = 0
neg = where((star LT 0), nneg)
if (nneg GT 0) then star(neg) = 0.01
wave = wavearr[*, ap]
quadterp, extwave, extvals, wave, extinct
; extinction correction
extfactor = exp(extinct*sitefactor*airmass)
star = star*extfactor
; get abnumbers for this star
abcalc, wave, objectname, abcurve
;derive curve to transform data numbers to flux
wdata = 10.0^(0.4*abcurve)
fstar = star*wdata/exptime
; Fit the continuum manually

print, 'Time to fit the continuum manually.'
print
airlimit = 1.5
fitspline, wave, fstar, airmass, splineresult, airlimit, col
;fitspline,  wave, alog10(fstar), airmass, splineresult, airlimit, col

splineresult = splineresult
;splineresult = 10.^(splineresult)

wshow
plot,  wave, splineresult, xst = 3, yst = 3, psym = 10, $
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

outfile = 'fluxstar'
if (n_params() GT 0) then begin
    outfile = strcompress(outfile+gratcode, /remove_all)
  endif
outfile = strcompress(outfile+'.fits', /remove_all)
print, strcompress('Writing data to '+outfile)
writefits,  outfile, splineresult, head

end
