pro calibrate, inputfile, gratcode, intera

;------------------------------------------------------------------------
; copied final.pro format to make routine that will flux calibrate 
; multispec files from IRAF.  must have run mkfluxstar first
; TM 11/21/98
; Extinction in too,
;-------------------------------------------------------------------------

  loadct, 2
; if (!d.window GE 0) then begin
;     device, get_window_position = place
;     window, title = 'Calibrate', xsize = !d.x_size, ysize = !d.y_size, $
;       xpos = place[0]-5, ypos = place[1]+25
; endif
; if (!d.window LT 0) then begin
;     device, get_screen_size = si
;     window, title = 'Calibrate',  xsize = fix(si[0]*.78125), $
;       ysize = fix(si[1]*.7222222), xpos = fix(si[0]*.2083333), $
;       ypos = fix(si[1]*.277777)
; endif

; Read in the flux star spectrum
  ffile = 'fluxstar'
  if (n_params() GT 0) then begin
      ffile = strcompress(ffile+gratcode, /remove_all)
    endif
  ffile = strcompress(ffile+'.fits', /remove_all)
  fluxstar = readfits(ffile, fluxstarhead)
  fluxstarpix =  float(sxpar(fluxstarhead, 'CRVAL1'))
  fluxstardelt =  float(sxpar(fluxstarhead, 'CDELT1'))
  fluxstarnpix = n_elements(fluxstar)
  fluxstarwave = (findgen(fluxstarnpix) * fluxstardelt) + fluxstarpix
  fluxairmass = float(sxpar(fluxstarhead, 'AIRMASS'))
  fluxname = sxpar(fluxstarhead, 'OBJECT')
  fluxnum = fix(sxpar(fluxstarhead, 'OBSNUM'))

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
;extinction corrections from Allen, 3rd ed. via lolita
;extwave = [2400.,2600.,2800.,3000.,3200.,3400.,3600.,3800., $
;           4000.,4500.,5000.,5500.,6000.,6500.,7000.,8000.,9000.,10000., $
;           12000.,14000.]
;extvals = [68.0,89.0,36.0,4.5,1.30,0.84,0.68,0.55,0.46,0.31, $
;           0.23,0.195,0.170,0.126,0.092,0.062,0.048,0.039,0.028,0.021]

; uncomment this block and comment next to switch to single file mode
;msfile = ''
;read,  'Input name of multispec file (suffix .ms.fits assumed): ', msfile
;
;if (msfile EQ '') then retall
  repeat begin
      existflag = 1
      if (n_params() EQ 0) then begin
          inputfile = ''
          print, ' '
          read,  'Enter name of input file: ', inputfile
        endif
      if (inputfile EQ '') then retall
      isfile = findfile(inputfile, COUNT = count)
      if (count EQ 0) then begin
          print, strcompress('File '+inputfile+' does not exist.')
          existflag = 0
        endif
    endrep until (existflag EQ 1)
  get_lun, ucal
  openr,  ucal,  inputfile
  msfile =  ''
  while not EOF(ucal) do begin

      readf, ucal, msfile

      if (rstrpos(msfile, '.ms') EQ -1) then begin
          msfile =  strcompress(msfile + '.ms.fits', /remove_all)
        endif
      if (rstrpos(msfile, '.fits') EQ -1) then begin
          msfile =  strcompress(msfile + '.fits', /remove_all)
        endif
      multispec = readfits(msfile, mshead)
      objectname = sxpar(mshead, 'OBJECT')
      print, strcompress('The object is '+objectname)
      airmass = float(sxpar(mshead, 'AIRMASS'))
      exptime = float(sxpar(mshead, 'EXPTIME'))
      if (exptime eq 0) then exptime = 1
; get height (meters)
      height = 0.0
      observat =  strlowcase(strcompress(sxpar(mshead, 'OBSERVAT'), /remove_all))
      case observat of
          'keck': height = 4160.0
          'lick': height = 1285.0
          'palomar': height = 1706.0
          'mcdonald': height = 2075.0
          'sso': height = 1149.0
          else: print, 'OBSERVATORY UNKNOWN!!!!!!!!'
        endcase
; 8300.0 meters is scale height of troposphere (according to lolita)
;
      getext, extwave, extvals, observat
;      height = 0.
;
      if observat eq 'lick' or observat eq 'keck' then height = 0.0
      sitefactor = exp(-1.0*height/8300.0)


      naps = (size(multispec))[2]
      nbands = (size(multispec))[3]


; Update this sometime so that we don't need to pass npix to
; getmswave.  For now, it's fine.


      for i = 0, naps-1 do begin
          print,  strcompress('Aperture ' + string(i+1) + ':')
          npix = n_elements(multispec[*, i, 0])
          getmswave, mshead, npix, i, wave
; find extinction corrections
          quadterp, extwave, extvals, wave, extinct
          extfactor = exp(extinct*sitefactor*airmass)
          quadterp, fluxstarwave, fluxstar, wave, fluxstartmp
          wdelt =  wave[1] - wave[0]
          for j = 0, nbands-1 do begin
              multispec[*, i, j] = multispec[*, i, j]*extfactor ;extinction
              multispec[*, i, j] = multispec[*, i, j]/fluxstartmp ;flux
              multispec[*, i, j] = multispec[*, i, j]/exptime ;adjust to time
              multispec[*, i, j] = multispec[*, i, j]*10^(-19.44) ;AB->fnu
              multispec[*, i, j] = multispec[*, i, j]*2.997925E18/wave/wave
                                ; fnu -> flam
            endfor
        endfor
;   add c to beginning of filename (c)alibrated, get it?
      msfile = strcompress('c'+msfile)
      sxaddpar, mshead, 'FLUX_Z', fluxairmass
      sxaddpar, mshead, 'FLUX_NUM', fluxnum
      sxaddpar, mshead, 'FLUX_OBJ', fluxname

      writefits, msfile, multispec, mshead



    endwhile
  close,  ucal
  free_lun, ucal

  !p.multi = 0
end
