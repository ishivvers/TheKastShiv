pro fitspline, wave, spectrum, airmass, splineresult, airlimit, col

;----------------------------------------------------------------------
; Procedure to do spline fitting and return the interpolated result. 
;
; AB, 4/30/98, modified 5/20/98 to hilight atmospheric absorption
; bands
; 
; Now fits automated points and allows iterative adjustments, can add
; and delete points anywhere along curve, can adjust yrange
; uses narrow crosshair (finally)
; TM 11/23/1998
;----------------------------------------------------------------------
; sets up calls for color in all plots
 col = {black: 0L, red: 255L, green: 65280L, blue: 16711680L, $
          aqua: 16776960L, violet: 16711935L, yellow: 65535L, white: 16777215L}
;;; col = {black: 0L, red: 1L, green: 2L, blue: 3L, $
;;;        aqua: 4L, violet: 5L, yellow: 6L, white: 7L}
;          b  r  g  b  a  v  y  w
;          l  e  r  l  q  i  e  h
;          a  d  e  u  u  o  l  i
;          c     e  e  a  l  l  t
;          k     n        e  o  e
;                         t  w
 rtiny  =  [0, 1, 0, 0, 0, 1, 1, 1]
 gtiny  =  [0, 0, 1, 0, 1, 0, 1, 1]
 btiny  =  [0, 0, 0, 1, 1, 1, 0, 1]
 tvlct, 255*rtiny, 255*gtiny, 255*btiny

;loadct, 2
;  NOTE: color is now passed to fitspline from mkfluxstar and mkbstar
;  via structure col

; sets ynozero as default
  !Y.STYLE = 16
; sets cursor to narrow crosshair
  device, cursor_standard = 33
  wshow
  plot, wave, spectrum, xst = 3, yst = 3, psym = 10, color = col.white

;  These wavelengths should be ok for spline points, can alter this
;  as we experiment

  bandpts = [3000, 3050, 3090, 3200, 3430, 3450, 3500, 3550, 3600, 3650, $
             3700, 3767, 3863, 3945, 4025, 4144, 4200, 4250, 4280, $
             4390, 4450, 4500, 4600,        $
             4655, 4717, 4750, 4813, 4908, 4950, 5000, 5050, 5100, 5150, $
             5200, 5250, 5280, 5350, 5387, 5439, 5500, 5550, $
             6100, 6150, 6200, 6240, 6400, 6430, 6650, 6700, $
             6750, 6800, 7450, 7500, 7550, 8420, 8460, 8520, $
             8570, 8600, 8725, 8770, 9910, 10000, 10200, 10300, 10400, 10500, $
             10600, 10700]
  npix = (size(wave))[1]
  b = where( (bandpts GT wave[10]) AND (bandpts LT wave[npix-10]))
  useband = bandpts[b]
  nbandpts = (size(useband))[1]
  for i = 0, nbandpts-1 do begin
      get_element, wave, useband[i], pixel
      useband[i] = pixel
    endfor
;  useband now contains index of wavelength positions of band points
;  in spectrum 

  if (airmass GT airlimit) then begin

      w =  where( (wave GE 3216) AND (wave LE 3420),  nw)
      if (nw GT 0) then oplot, wave(w), spectrum(w), psym = 10, color = col.violet
;    w =  where( (wave GE 5600) AND (wave LE 6050),  nw)
      w =  where( (wave GE 5500) AND (wave LE 6050),  nw)
      if (nw GT 0) then oplot, wave(w), spectrum(w), psym = 10, color = col.violet
      w =  where( (wave GE 6250) AND (wave LE 6360),  nw)
      if (nw GT 0) then oplot, wave(w), spectrum(w), psym = 10, color = col.violet
      w =  where( (wave GE 6450) AND (wave LE 6530),  nw)
      if (nw GT 0) then oplot, wave(w), spectrum(w), psym = 10, color = col.violet
      w =  where( (wave GE 6840) AND (wave LE 7410),  nw)
      if (nw GT 0) then oplot, wave(w), spectrum(w), psym = 10, color = col.violet
      w =  where( (wave GE 7560) AND (wave LE 8410),  nw)
      if (nw GT 0) then oplot, wave(w), spectrum(w), psym = 10, color = col.violet
      w =  where( (wave GE 8800) AND (wave LE 9900),  nw)
      if (nw GT 0) then oplot, wave(w), spectrum(w), psym = 10, color = col.violet

    endif 

  if (airmass GE 1.0) AND (airmass LE airlimit) then begin
      w =  where( (wave GE 3216) AND (wave LE 3420),  nw)
      if (nw GT 0) then oplot, wave(w), spectrum(w), psym = 10, color = col.violet
      w =  where( (wave GE 6250) AND (wave LE 6360),  nw)
      if (nw GT 0) then oplot, wave(w), spectrum(w), psym = 10, color = col.violet
      w =  where( (wave GE 6840) AND (wave LE 7410),  nw)
      if (nw GT 0) then oplot, wave(w), spectrum(w), psym = 10, color = col.violet
      w =  where( (wave GE 7560) AND (wave LE 8410),  nw)
      if (nw GT 0) then oplot, wave(w), spectrum(w), psym = 10, color = col.violet
      w =  where( (wave GE 8800) AND (wave LE 9900),  nw)
      if (nw GT 0) then oplot, wave(w), spectrum(w), psym = 10, color = col.violet

    endif 





;try initial fit to automatic set of points

  nsplinepoints = nbandpts
  initsplpts = fltarr(2, nbandpts)
  initsplpts[0, *] = wave[useband]
  w = where(finite(spectrum) ne 1, ww)
  if ww gt 0 then spectrum[w] = 0.0
  initsplpts[1, *] = spectrum(useband)
  y2 =  spl_init(initsplpts[0, *], initsplpts[1, *])

  splineresult = $
    spl_interp(initsplpts[0, *], initsplpts[1, *], y2, wave)
  oplot, wave, splineresult, color = col.green, psym = 10
  wshow
  repeat begin
      print, 'Is this ok? (y/n)'
      a = get_kbrd(1)
    endrep until (a EQ 'y') OR (a EQ 'n')

  ymin = min(spectrum, MAX = ymax)
  xmin = min(wave, max = xmax)

;  if a = n, then interatively fit spline

  if (a EQ 'n') then begin

;   This makes a user symbol of a filled circle    
      us = findgen(48)*(!PI*2/48.0)
      usersym, cos(us), sin(us), /fill

      tmpsplinepoints =  fltarr(2, 500)
      tmpsplinepoints[*, 0:nbandpts-1] = initsplpts
      repeat begin
          c = ''
          wshow
          repeat begin
              print, 'Change y-scale? (y/n)'
              c = get_kbrd(1)
            endrep until (c EQ 'y') OR (c EQ 'n')
          if (c EQ 'y') then begin
              ymin = min(spectrum, MAX = ymax)
              xmin = min(wave, max = xmax)
              
              plot, wave, spectrum, xst = 3, yst = 3, psym = 10, $
                color = col.white, yrange = [ymin, ymax], $
                xrange = [xmin, xmax]
              oplot, wave, splineresult, color = col.green, psym = 10
              print
              print, '  Mark the corners of your box...'
              wait, 0.2
              cursor, xmin, ymin, /data, /wait
              plots, xmin, ymin, psym = 7, col = col.red, thick = 2
              wait, 0.2
              cursor, xmax, ymax, /data, /wait
              plots, xmax, ymax, psym = 7, col = col.red, thick = 2
;              print, 'Enter your new ymin and ymax values: '
;              read, ymin, ymax
            endif
          plot, wave, spectrum, xst = 3, yst = 3, psym = 10, color = col.white, $
            yrange = [ymin, ymax], xrange = [xmin, xmax]
;  we should figure out a better way to do this above and here
          if (airmass GT airlimit) then begin

              w =  where( (wave GE 3216) AND (wave LE 3420),  nw)
              if (nw GT 0) then oplot, wave(w), spectrum(w), psym = 10, $
                color = col.violet
              w =  where( (wave GE 5600) AND (wave LE 6050),  nw)
              if (nw GT 0) then oplot, wave(w), spectrum(w), psym = 10, $
                color = col.violet
              w =  where( (wave GE 6250) AND (wave LE 6360),  nw)
              if (nw GT 0) then oplot, wave(w), spectrum(w), psym = 10, $
                color = col.violet
              w =  where( (wave GE 6450) AND (wave LE 6530),  nw)
              if (nw GT 0) then oplot, wave(w), spectrum(w), psym = 10, $
                color = col.violet
              w =  where( (wave GE 6840) AND (wave LE 7410),  nw)
              if (nw GT 0) then oplot, wave(w), spectrum(w), psym = 10, $
                color = col.violet
              w =  where( (wave GE 7560) AND (wave LE 8410),  nw)
              if (nw GT 0) then oplot, wave(w), spectrum(w), psym = 10, $
                color = col.violet
              w =  where( (wave GE 8800) AND (wave LE 9900),  nw)
              if (nw GT 0) then oplot, wave(w), spectrum(w), psym = 10, $
                color = col.violet

            endif 

          if (airmass GE 1.0) AND (airmass LE airlimit) then begin
              w =  where( (wave GE 3216) AND (wave LE 3420),  nw)
              if (nw GT 0) then oplot, wave(w), spectrum(w), psym = 10, $
                color = col.violet
              w =  where( (wave GE 6250) AND (wave LE 6360),  nw)
              if (nw GT 0) then oplot, wave(w), spectrum(w), psym = 10, $
                color = col.violet
              w =  where( (wave GE 6840) AND (wave LE 7410),  nw)
              if (nw GT 0) then oplot, wave(w), spectrum(w), psym = 10, $
                color = col.violet
              w =  where( (wave GE 7560) AND (wave LE 8410),  nw)
              if (nw GT 0) then oplot, wave(w), spectrum(w), psym = 10, $
                color = col.violet
              w =  where( (wave GE 8800) AND (wave LE 9900),  nw)
              if (nw GT 0) then oplot, wave(w), spectrum(w), psym = 10, $
                color = col.violet

            endif 
          oplot, tmpsplinepoints[0, 0:nsplinepoints-1], $
            tmpsplinepoints[1, 0:nsplinepoints-1], psym = 8, color = col.red
          oplot, wave, splineresult, color = col.green, psym = 10
          print, 'Click on continuum points for spline fit (up to 500).'
          print, 'Left button    = add point'
          print, 'Middle button  = delete point'
          print, 'Right button   = done'
          print

          element =  1
          flux =  1

          repeat begin
              wait, 0.5
              cursor,  element,  flux, /data,  /wait
              button =  !mouse.button
              print, element, flux
              
              if (button eq 1) then begin
                  oplot, [element], [flux], psym = 8, color = col.red
                  tmpsplinepoints[0, nsplinepoints] = element
                  tmpsplinepoints[1, nsplinepoints] =  flux
                  nsplinepoints =  nsplinepoints + 1
                endif
              
              if (button eq 2) and (nsplinepoints gt 0) then begin
;  first, look for point nearest cursor for deletion
                  minsep = 10000000.0
                  for i = 0, nsplinepoints-1 do begin
                      deltaw = (tmpsplinepoints[0, i]-element)/element
                      deltaf = (tmpsplinepoints[1, i]-flux)/flux
                      delta = sqrt( (deltaw)^2 + (deltaf)^2)
                      if (delta LT minsep) then begin
                          minsep = delta
                          dpoint = i
                        endif
                    endfor
;  adjust array when point is removed
                  oplot, [tmpsplinepoints[0, dpoint]], $
                    [tmpsplinepoints[1, dpoint]], $
                    psym = 7, color = col.green,  symsize = 1.5, thick = 2.0
                  nsplinepoints = nsplinepoints - 1
                  for i = dpoint, nsplinepoints-1 do begin
                      tmpsplinepoints[*, i] = tmpsplinepoints[*, i+1]
                    endfor
                endif        
            endrep until (button eq 4)

;  sort to get increasing values for wavelength 

          splinepoints =  fltarr(2, nsplinepoints)
          splinepoints =  tmpsplinepoints[*, 0:nsplinepoints-1]
          sortorder =  sort(splinepoints[0, *])

          splinepoints[0, *] = splinepoints[0, sortorder]
          splinepoints[1, *] = splinepoints[1, sortorder]
          y2 =  spl_init(splinepoints[0, *], splinepoints[1, *])

          splineresult = $
            spl_interp(splinepoints[0, *], splinepoints[1, *], y2, wave)
          oplot, wave, splineresult, color = col.green, psym = 10
          repeat begin
              print, 'Is this ok? (y/n)'
              b = get_kbrd(1)
            endrep until (b EQ 'y') OR (b EQ 'n')
        endrep until (b EQ 'y')
    endif

; back to normal cursor
  device, /cursor_crosshair
end


