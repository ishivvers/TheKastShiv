pro womzap

; by AJB 3/22/99
; modifications by TM 3/23/99

common wom_active, active
common wom_ulog, ulog
COMMON wom_col, col
womdestruct, active, wave, flux, err, name, npix, header

plot, wave, flux, xst = 3, yst = 3, psym = 10, color = col.white, $
  xtitle = 'Wavelength', ytitle = 'Flux', title = name
nsig = ''
repeat begin
    read, 'Enter zapping threshold in sigmas (0=replace all with median): ', nsig
    nsig = float(nsig)
endrep until (nsig GE 0) 
boxsize = ''
repeat begin
    read, 'Enter box size for computing statistics: (odd integer < 45) ', $
      boxsize
    boxsize = fix(boxsize)
endrep until (boxsize GE 3) and (boxsize LE 45)
boxsize = fix(boxsize)

if ( (boxsize / 2.) EQ float(boxsize / 2) ) then boxsize = boxsize + 1

half = fix(boxsize/2)
newflux = flux
if (nsig GT 0) then begin
    repeat begin
        print, 'Use inter(q)uartile or (m)edian variance (q/m)? '
        answer = get_kbrd(1)
        answer = strlowcase(answer)
        print, answer
    endrep until (answer EQ 'q') or (answer EQ 'm')
    if (answer EQ 'm') then begin
        for i = half, npix-half-1 do begin
            s = flux[i-half:i+half]
            medval = median(s)
            varpix = (s[half]-medval)^2
            sum = -1.0*varpix
            for k = 0, boxsize-1 do begin
                diff = s[k]-medval
;    This is to prevent overflow, not sure we need it
                if (abs(diff) GT 1.0E10) then begin
                    diff = 1.0E10
                endif
                sum = sum+diff^2
            endfor
            sum = sum/float(boxsize-1)
            if (varpix GT nsig*nsig*sum) then begin
                newflux[i] = medval
            endif
;  below is code for deviation using mean value
;     sigma = stdev(s)
;     if (s[half] GT (medval+nsig*sigma)) or $
;       (s[half] LT (medval-nsig*sigma)) then begin
;         newflux[i] = medval
;     endif
        endfor
    endif
    if (answer EQ 'q') then begin
        for i = half, npix-half-1 do begin
            s = flux[i-half:i+half]
            medval = median(s)
            ss = sort(s)
            quart = fix((boxsize+1)/4)
            q25 = s(ss[half-quart])
            q75 = s(ss[half+quart])
            qsig = 0.7414272*(q75-q25)
            diff = abs(s[half]-medval)
            if (diff GT nsig*qsig) then begin
                newflux[i] = medval
            endif
        endfor
    endif
endif
if (nsig EQ 0) then begin
    newflux = median(flux, boxsize)
endif

oplot, wave, newflux, psym = 10, color = col.red
wshow
if (nsig NE 0) then begin
    w = where(newflux NE flux,  nw)
    print, strcompress('Number of pixels zapped: '+string(nw))
endif
answer =  ''
repeat begin
    print, 'Does this zapping look good (y/n, default=y)? '
    answer = get_kbrd(1)
    if ((byte(answer))[0] EQ 10) then answer = 'y'
    answer = strlowcase(answer)
    print, answer
endrep until (answer EQ 'y') or (answer EQ 'n')
if (answer EQ 'y') then begin
    active.flux =  newflux
    printf, ulog, systime()
    printf, ulog, strcompress('File: '+name+' zapped with sigma = ' + $ 
                              string(nsig) + ' and boxsize = ' + $
                              string(boxsize))
    print, 'OK. Active spectrum is now the zapped spectrum.'
endif

if (answer EQ 'n') then begin
    print,  'OK, active spectrum unchanged in memory.'
endif

end
