pro final, inputfile, gratcode, intera

;------------------------------------------------------------------------
; Program to read in a calibrated iraf multispec file, perform B-star
; division, do final wavelength shifts, and write out a fits spectrum
; for each individual aperture.
;
; AB, 4/24/98, last modified 5/13/98
; TM, 11/15/98, fixed plot problem, keeps track of object name,
; apertures now reported as in iraf but still numbered in program as
; in idl, now read from list of input files
; rebins to even wavelength scale
;-------------------------------------------------------------------------

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
doneonceflag = 0
if (!d.window GE 0) then begin
    device, get_window_position = place
    window, title = 'Final Reductions', xsize = !d.x_size, ysize = !d.y_size, $
      xpos = place[0]-5, ypos = place[1]+25
endif
if (!d.window LT 0) then begin
    device, get_screen_size = si
    window, title = 'Final Reductions',  xsize = fix(si[0]*.78125), $
      ysize = fix(si[1]*.7222222), xpos = fix(si[0]*.2083333), $
      ypos = fix(si[1]*.277777)
endif
; Read in the B-star spectrum
bfile = 'bstar'
if (n_params() GT 0) then begin
    bfile = strcompress(bfile+gratcode, /remove_all)
endif
bfile = strcompress(bfile+'.fits', /remove_all)
bstar = readfits(bfile, bstarhead)
bstarpix =  float(sxpar(bstarhead, 'CRVAL1'))
bstardelt =  float(sxpar(bstarhead, 'CDELT1'))
bstarnpix = n_elements(bstar)
bstarwave = (findgen(bstarnpix) * bstardelt) + bstarpix
bairmass = float(sxpar(bstarhead, 'AIRMASS'))
bstarname = sxpar(bstarhead, 'OBJECT')
bstarnum = fix(sxpar(bstarhead, 'OBSNUM'))
bobservat = strlowcase(strcompress(sxpar(bstarhead, 'OBSERVAT'), /remove_all))

; Read in the master sky spectrum
mskyfile = 'mastersky.fits'
isfile = findfile(mskyfile, COUNT = count)
if (count EQ 0) then begin
    if (bobservat EQ 'lick') then begin
        mskyfile =  '/Users/jsilv/idl/lib/licksky.fits'
    endif else if (bobservat EQ 'keck') then begin
        mskyfile = '/Users/jsilv/idl/lib/kecksky.fits'
    endif else if (bobservat EQ 'sso') then begin
        mskyfile = '/Users/jsilv/idl/lib/licksky.fits'
    endif else if (bobservat EQ 'mcdonald') then begin
        mskyfile = '/Users/jsilv/idl/lib/licksky.fits'
    endif else begin
        print, 'Cannot find mastersky file and observatory unknown'
        repeat begin
            existflag = 1
            read, 'Enter name of mastersky file (include .fits)', mskyfile
            mskyfile = strtrim(mskyfile, 2)
            isfile = findfile(mskyfile, COUNT = count)
            if (count EQ 0) then begin
                print, strcompress('File '+mskyfile+' does not exist.')
                existflag = 0
            endif
        endrep until (existflag EQ 1)
    endelse
endif
mastersky =  readfits(mskyfile, masterskyhead)
masterpix =  float(sxpar(masterskyhead, 'CRVAL1'))
masterdelt = float(sxpar(masterskyhead, 'CDELT1'))
masternpix = n_elements(mastersky)
masterwave =  (findgen(masternpix) * masterdelt) + masterpix
if (abs(avg(mastersky)) LT 1e-7) then mastersky =  mastersky * 1e15

; identify user
user = ''
spawn, 'whoami', user, /noshell
print, ' '
print, strcompress('Hello, '+user)

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
get_lun, ufin
openr,  ufin,  inputfile
wavesave = 'No range yet'
deltsave = 'No resolution yet'
waverange = ''
objname =  ''
msfile =  ''
while not EOF(ufin) do begin

    readf, ufin, msfile
    msfile =  strcompress('c'+msfile, /remove_all)
    if (rstrpos(msfile, '.ms') EQ -1) then begin
        msfile =  strcompress(msfile + '.ms.fits', /remove_all)
    endif
    if (rstrpos(msfile, '.fits') EQ -1) then begin
        msfile =  strcompress(msfile + '.fits', /remove_all)
    endif
    multispec = readfits(msfile, mshead)
    objectname = sxpar(mshead, 'OBJECT')
    print, strcompress('The object is '+objectname)
    pacheck, mshead
    airmass = float(sxpar(mshead, 'AIRMASS'))
    stringra = sxpar(mshead, 'RA')
    stringdec =  sxpar(mshead, 'DEC')
    radec =  stringra + ' ' + stringdec
;    stringad, radec, ra, dec
;    above replaced by get_coords, but ra now returned as decimal
;    HOURS, multiply by 15 to get decimal degrees
    get_coords, coords, instring = radec
    ra = coords[0]*15.0
    dec = coords[1]

    ra =  ra / !radeg
    dec =  dec / !radeg

    stringha =  strcompress(sxpar(mshead, 'HA'),  /remove_all)
    if ( (strmid(stringha, 0, 1) ne '+') and (strmid(stringha, 0, 1) ne '-') ) $
      then begin
        stringha = strcompress('+' + stringha, /remove_all)
    endif

    hahour = fix(strmid(stringha, 0, 3))
    hamin =  fix(strmid(stringha, 4, 2))
    hasec =  fix(strmid(stringha, 7, 5))

    ha =  ten(hahour, hamin, hasec) * (360 / 24) / !radeg

; get latitude (in radians) of observatory
    latitude = 0.0
    observat =  strlowcase(strcompress(sxpar(mshead, 'OBSERVAT'), /remove_all))
    case observat of
        'keck': latitude = 19.8283 / !radeg
        'lick': latitude = 37.3414 / !radeg
        'palomar': latitude = 33.35611 / !radeg
        'mcdonald': latitude = 30.6717 / !radeg
        'sso': latitude = (-31. - 16./60. - 24.1/3600.) / !radeg
        else: print, 'OBSERVATORY UNKNOWN!!!!!!!!'
    endcase


; Get julian date and earth's velocity toward target
    epoch = float(sxpar(mshead, 'EPOCH'))
    date =  strtrim(sxpar(mshead, 'DATE-OBS'), 2)
    if (date eq '0') then date = strtrim(sxpar(mshead,'DATE',/SILENT),2)

; check date for new ISO Y2K format YYYY-MM-DDThh:mm:ss.ssss
; the time following the T is optional, so I left time as
; found in UTMIDDLE, but, as the commented lines below show,
; I am prepared to deal with this.  We would need to read in exposure
; time and correct to the middle of the exposure as well.
    if (strpos(date, '-') eq 4) then begin
        temp = date
        year = fix(gettok(temp,'-'))
        month = fix(gettok(temp, '-'))
        day=gettok(temp,' ')
        if strlen(temp) eq 0 then begin
            dtmp=gettok(day,'T')
            temp=day
            day=dtmp
        end
        day = fix(day)
;        hour = fix(gettok(temp,':'))
;        minute = fix(gettok(temp,':'))
;        second = float(strtrim(strmid(temp,0,5)))
    endif else begin
;        ut = strtrim(sxpar(mshead, 'UTMIDDLE'), 2)
;  old date format is DD/MM/YY
        month =  fix(strmid(date, 3, 2))
        day =  fix(strmid(date, 0, 2))
        year =  fix(strmid(date, 6, 2))
;this is to catch data written after
;2000 in old format, at least until
;2050, after that, you're on your own
        if (year GT 50) then begin
            year = year + 1900
        endif else begin
            year = year +2000
        endelse
;        hour = fix(gettok(ut,':'))
;        minute = fix(gettok(ut,':'))
;        second = float(strtrim(strmid(ut,0,5)))
    endelse

    month_str =  strmid(date, 5, 2)
    day_str =  strmid(date, 8, 2)
    year_str =  strmid(date, 0, 4)

    ; grab beginning UT of exposure
    ut = strtrim(sxpar(mshead, 'DATE-STA'), 2)
    if (ut EQ 0) OR (strlen(ut) EQ 10) then begin
       ut = strtrim(sxpar(mshead, 'DATE_BEG'), 2)
       if (ut EQ 0) then begin
          ut = strtrim(sxpar(mshead, 'DATE-OBS'), 2)
          blah = gettok(ut,'T')
       endif else blah = gettok(ut,'T')
    endif else blah = gettok(ut,'T')
    if float(ut) EQ 0 then ut = strtrim(sxpar(mshead,'UTC'), 2)
    if float(ut) EQ 0 then ut = strtrim(sxpar(mshead,'UT'), 2)

    exptime = fix(strtrim(sxpar(mshead, 'EXPTIME'), 2))
    hour = fix(gettok(ut,':'))
    minute = fix(gettok(ut,':'))
    second = float(strtrim(strmid(ut,0,5)))
    print, year, month, day, hour, minute, second
    jdcnv, year, month, day, (hour + (minute/60.0) + (second/3600.0) + (exptime/3600.0/2.0)), julian
    baryvel, julian, epoch, vh, vb

    decday = round((hour + (minute/60.0) + (second/3600.0) + (exptime/3600.0/2.0))/24.*1d4)/1d4
    decday = round(1000.*decday)/1000.
    decdaystr = strmid(strcompress(string(decday),/remove_all),1,4)
    utdate = strcompress(year_str+month_str+day_str+decdaystr,/remove_all)

; v is earth's velocity toward the object.
    v = vb(0)*cos(dec)*cos(ra) + vb(1)*cos(dec)*sin(ra) + vb(2)*sin(dec)

; Correct for earth's rotation.
; Note that this isn't strictly correct because ha is set to
; the beginning of the observation, while it really should be
; the middle.  But this is a small difference and doesn't affect
; the results in any way that we would notice...
    v =  v - ( 0.4651 * cos(latitude) * sin(ha) * cos(dec) )

    print
    print, strcompress('The velocity of the Earth toward the target is '+ string(v) + ' km/s.')
    print

    naps = (size(multispec))[2]

    print
    print,  $
      strcompress('There are ' + string(naps) + ' apertures in this spectrum.')
    print
    print
;  uncomment for multi ap extractions when you only want to reduce
;  some of them
;    repeat begin
;        print,  'Which aperture do you want reduce?'
;        read,  ap
;        ap =  fix(ap)
;    endrep until (ap GE 0) and (ap LE naps-1)

; Make a copy of the multispec header for the final files, and remove
; unwanted stuff.

    head = mshead
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
    sxdelpar,  head,  'CD1_1'
    sxdelpar,  head,  'CD2_2'
    sxdelpar,  head,  'CD3_3'
    sxdelpar,  head,  'LTM1_1'
    sxdelpar,  head,  'LTM2_2'
    sxdelpar,  head,  'LTM3_3'
    sxdelpar,  head,  'WCSDIM'



    extract =  ''
    extractstring =  ''

; Update this sometime so that we don't need to pass npix to
; getmswave.  For now, it's fine.


; comment out for loop to specify apertures (see above)
    for i = 0, naps-1 do begin
;    i = ap
        print,  strcompress('Aperture ' + string(i+1) + ':')
        npix = n_elements(multispec[*, i, 0])
        getmswave, mshead, npix, i, wave
        wdelt =  wave[1] - wave[0]

;   Plot the normal and optimal extractions
;         !p.multi =  [0, 1, 2]
;         plot, wave, multispec[*, i, 0], xst = 3, yst = 3, psym = 10, $
;           title = 'Optimal',                                         $
;           position =  [0.1, 0.55, 0.99, 0.95],  /normal
;         plot, wave, multispec[*, i, 1], xst = 3, yst = 3, psym = 10, $
;           xtitle = 'Wavelength', title = 'Normal',                   $
;           position =  [0.1, 0.1, 0.99, 0.49],  /normal
;         !p.multi = 0
        !p.multi =  [0, 1, 2]
        mean = moment(multispec[*, i, 0])
        finalscaler, multispec[*, i, 0], ymin, ymax
        plot, wave, multispec[*, i, 0], xst = 3, yst = 3, psym = 10, $
          title = objectname, /nodata, yrange = [ymin, ymax], $
          position =  [0.1, 0.25, 0.99, 0.95],  /normal, $
          color = col.white
        oplot, wave, multispec[*, i, 1], psym = 10,  color = col.red
        oplot, wave, multispec[*, i, 0], psym = 10, color = col.white

        plot, wave, abs((multispec[*, i, 1]-multispec[*, i, 0]))/mean[0], $
          psym = 10, /ylog, color = col.white, $
          xst = 3, yst = 3, xtitle = 'Wavelength', $
          title = 'Log of Fractional Residuals (normal - optimal)', $
          position =  [0.1, 0.05, 0.99, 0.20],  /normal
        !p.multi = 0

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
                object = multispec[*, i, 0]
                extractstring = 'optimal'
            end
            'n': begin
                object = multispec[*, i, 1]
                extractstring = 'normal'
            end
         endcase

                                ;RTC NEW
        if strcompress(sxpar(head, 'INSTRUME'),/rem) NE 'deimos' then $
           err = multispec[*, i, 3] $;
        else err = multispec[*, i, 1]*0.;
                                ;

;   assume data are in f-lambda, and scale by 10^15 if necessary
        if (abs(avg(object)) LT 1e-7) then begin
            print
            print,  'Scaling data up by a factor of 10^15...'
            object =  object * 1e15
                                ;RTC NEW
          err = err * 1d15      ;
                                ;
        endif

;   Fit the continuum underlying the sky spectrum,
;   and subtract it off to leave a pure emission-line spectrum.

        sky = multispec[*, i, 2]

        envelope_size = 25
        envelope, sky, envelope_size, mn, mx, ind
        contin = congrid(mn, npix, /cubic)
        wshow
        plot, wave, sky, xst = 3, yst = 3, psym = 10, color = col.white
        oplot, wave, contin, color = col.red
        sky =  sky - contin
        if (abs(avg(sky)) LT 1e-7) then sky =  sky * 1e15

;   Rebin master sky spectrum to object's wavelength scale
        bonashrebin, masterwave, mastersky, wave, msky

;   Cross-correlate the master sky spectrum with the object's sky,
;   and shift the object's wavelength scale

        xfactor =  10
        npoints =  200
        if observat eq 'keck' then begin
            cut = where(wave ge 3500.)
            newcor, msky[cut], sky[cut], xfactor, npoints, result
          endif else newcor, msky, sky, xfactor, npoints, result
        angshift =  result * wdelt
        print, 'The x-cor shift in Angstroms is ', angshift
        wave = wave - angshift

;---Routine to check sky line wavelength shifting---------------
;   Comment this routine out after shifting is fully debugged
        answer = ''
        !p.multi =  [0, 1, 2]
        repeat begin
            sky =  sky * avg(msky) / avg(sky)
            wshow
            plot, (wave + angshift)[0: fix(npix/2)], msky[0: fix(npix/2)], $
              xst = 3, yst = 3, psym = 10, color = col.white
            finalscaler, sky[where(finite(sky[0: fix(npix/2)]) eq 1)], miny, maxy
            axis, /yaxis, /save, yrange = [0, maxy], ys = 3
            oplot, wave[0: fix(npix/2)], sky[0: fix(npix/2)], psym = 10, $
              color = col.red

            plot, (wave + angshift)[fix(npix/2)+1: npix-1], $
              color = col.white, msky[fix(npix/2)+1: npix-1], $
              xst = 3, yst = 3, psym = 10
            finalscaler, sky[fix(npix/2)+where(finite(sky[fix(npix/2)+1: npix-1]) eq 1)], miny, maxy
            axis, /yaxis, /save, yrange = [0, maxy], ys = 3
            oplot, wave[fix(npix/2)+1: npix-1], sky[fix(npix/2)+1: npix-1], $
              psym = 10, color = col.red

            print
            print, 'White spectrum = master sky'
            print, 'Red spectrum   = object sky shifted to match master sky'
            read, 'Is this ok (y/n, default=y)? ', answer
            if (answer EQ 'n') then begin
                wave =  wave + angshift
                read, 'Enter desired shift in Angstroms: ', angshift
                wave =  wave - angshift
            endif

        endrep until ((answer EQ 'y') OR (answer EQ ''))
        !p.multi = 0
;------------------------------------------------------------------


;   Remove the redshift due to earth's motion

        print
        print,  'Removing redshift due to motion of the Earth...'
        print

        z = -1 * v / 2.997925e5
        wave =  wave / (1 + z)


;   Do the B-star removal

        telluric_remove, bstarwave, bstar, bairmass, wave, object, $
          airmass, bobj, bangshift, col
                                ; RTC NEW
      quadterp, bstarwave - bangshift, bstar, wave, bstartmp
      bstartmp = (bstartmp)^((airmass/bairmass)^0.55)
      err =  err / bstartmp
                                ;

;print, 'bangshift', bangshift
;   bin to even wavelength scale
        !p.multi = [0, 2, 0]
        wshow
        finalscaler, bobj[0:100], ymin, ymax
        plot, wave[0:100], bobj[0:100], xst = 3,  yst = 3, psym = 10, $
          xtitle =  'Wavelength', ytitle = 'Flux', yrange = [ymin, ymax], $
          color = col.white
        if (doneonceflag EQ 1) then begin
            print, newwave0save, !y.crange[0]
            plots, [newwave0save, !y.crange[0]], color = col.white, $
	psym = 0
            plots, [newwave0save, !y.crange[1]], /continue, $
	color = col.red, psym = 0
        ENDIF
        finalscaler, bobj[npix-101:npix-1], ymin, ymax
        plot, wave[npix-101:npix-1], bobj[npix-101:npix-1], xst = 3,  $
          yst = 3, psym = 10, xtitle =  'Wavelength', ytitle = 'Flux', $
          yrange = [ymin, ymax], color = col.white
        if (doneonceflag EQ 1) then begin
            print, newwave0save, !y.crange[0]
            plots, [newwavensave, !y.crange[0]], color = col.white, $
	psym = 0
            plots, [newwavensave, !y.crange[1]], /continue, $
	color = col.red, psym = 0
        endif
        !p.multi = 0

        repeat begin
            print, strcompress('Current A/pix is '+string(wave[1]-wave[0]))
            rflag = 0
            newdelt = ''
            if (doneonceflag EQ 1) then begin
                print, ' '
                print, strcompress('Previous resolution: '+deltsave)
            endif
            print, ' '
            print, 'Rebin to how many Angstroms per pixel? '
            read,  '         <CR> selects previous choice: ', newdelt
            if (newdelt EQ '') then newdelt = deltsave
            newdelt = float(newdelt)
            if (newdelt LE 0) or (newdelt GT wave[npix-1]) then begin
                print, 'Need positive resolution and smaller than '
                print, 'entire spectrum.  Try again.'
                rflag = 1
                goto, ESCAPE
            endif
            print, ' '
            print, strcompress('Current range: '+string(wave[0])+$
                               ' '+string(wave[npix-1]))
            print, ' '
            if (doneonceflag EQ 1) then begin
                print, strcompress('Previous selection was: '+wavesave)
                print, '(marked in red on plot)'
            endif
            print, ' '
            print, 'Enter the new wavelength range desired: '
            read,  '          <CR> selects previous choice: ', waverange
            if (waverange EQ  '') then waverange = wavesave
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
            endif
            wavestrsize = size(wavestring)
            if (wavestrsize[1] LT 2) then begin
                print, 'Enter two numbers'
                rflag = 1
                goto, ESCAPE
            endif
            newwave0 = float(wavestring[0])
            newwaven = float(wavestring[1])
            if (newwave0 LE 0) or (newwaven LE 0) or $
              (newwave0 GT wave[npix-1]) or (newwaven GT wave[npix-1]) $
              or (newwave0 LT wave[0]) or (newwaven LT wave[0]) or $
              (newwave0 GE newwaven) then begin
                print, 'Could not understand your numbers'
                print, 'either literally or figuratively'
                rflag = 1
                goto, ESCAPE
            endif
            nbin = (newwaven-newwave0)/newdelt +1.0
            intnbin = fix(nbin)
;            intnbin = round(nbin)

;            nbin = abs(nbin-float(intnbin))
;;            if (nbin GE 0.000001) then begin
;            if (nbin GE 0.001) then begin
;                print, 'NON-INTEGER number of bins'
;                rflag = 1
;            endif

            deltsave = string(newdelt)
            newwave0save = newwave0
;            newwavensave = intnbin*newdelt+newwave0;
            newwavensave = newwaven
;            wavesave =
;            strcompress(string(newwave0save)+','+string(newwavensave), /remove_all);
            wavesave = waverange
ESCAPE:

        endrep until (rflag EQ 0)
        doneonceflag = 1
        nwave = (findgen(intnbin)*newdelt)+newwave0
        bonashrebin, wave, bobj, nwave, finalobj
                                ;
        newwavensave = max(nwave) ; to fix the commented out bits above
                                ;

                                ;RTC NEW
          bonashrebin, wave, err*err, nwave, temperr
          newerr = sqrt(temperr) * sqrt(wdelt/newdelt)

          output = fltarr(n_elements(finalobj), 2)
          output[*, 0] = finalobj
          output[*, 1] = newerr
                                ;

        wshow
        finalscaler, finalobj, ymin, ymax
        plot,  nwave,  finalobj,  xst = 3,  yst = 3, psym = 10, $
          xtitle =  'Wavelength', ytitle = 'Flux', title = objectname, $
          yrange = [ymin, ymax], color = col.white
        repeat begin
            c = 'y'
            print, ' '
            print, strcompress('The file is '+msfile)
            print, strcompress('The object is '+objectname)
            print, strcompress('The DATE-OBS is '+date)
            print, strcompress('The UT Date is '+utdate)
            print, strcompress('The aperture is '+string(i+1))
            print, strcompress('Previous name was '+objname)
            REPEAT BEGIN
            print, 'Enter the object name for the final fits file: '
            read, strcompress('(-'+utdate+'-'+gratcode+'.ms.fits will be added): '), objname
            ENDREP UNTIL (objname NE '')
            objname = strlowcase(strtrim(objname, 2))
            objname = repstr(objname,'#','')
            objname = repstr(objname,'ngc','n')
            objname = repstr(objname,'ugc','u')
            fname = objname
            if (rstrpos(objname, '.ms.fits') EQ -1) then begin
                fname = strcompress(objname+'-'+utdate+'-'+gratcode+'.ms.fits',  /remove_all)
            endif
            if (rstrpos(fname, '.fits') EQ -1) then begin
                fname = strcompress(fname+'-'+utdate+'-'+gratcode+'.fits',  /remove_all)
            endif
            isfile = findfile(fname, COUNT = count)
            if (count NE 0) then begin
                print, strcompress('File '+fname+' already exists!')
                repeat begin
                    print, 'Do you wish to overwrite it? (y/n, default=y) '
                    c = get_kbrd(1)
                    c = strlowcase(c)
                    if ((byte(c))[0] EQ 10) then c = 'y'
                    print, c
                endrep until (c EQ 'y') or (c EQ 'n')
            endif
        endrep until (c EQ 'y')

        sxaddpar,  head,  'CRPIX1', 1
        sxaddpar,  head,  'CRVAL1',  nwave[0]
        sxaddpar,  head,  'CDELT1', nwave[1] - nwave[0]
        sxaddpar,  head,  'CTYPE1', 'LINEAR'
        sxaddpar,  head,  'W_RANGE', waverange
        sxaddpar, head, 'BSTAR_Z', bairmass
        sxaddpar, head, 'BSTARNUM', bstarnum
        sxaddpar, head, 'BSTAROBJ', bstarname
        sxaddpar, head, 'BARYVEL', v
        sxaddpar, head, 'SKYSHIFT', angshift
        sxaddpar, head, 'ATMSHIFT', bangshift
        sxaddpar, head, 'EXTRACT', extractstring
        sxaddpar, head, 'REDUCER', user[0]
        rtime = systime()
        sxaddpar, head, 'RED_DATE', rtime, 'EPOCH OF REDUCTION'

                                ;RTC NEW
;          writefits, fname, finalobj, head
          writefits, fname, output, head
                                ;

    endfor


endwhile
close,  ufin
free_lun, ufin

!p.multi = 0
end
