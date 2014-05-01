pro womderedden

; by AJB, 5/25/99
; Uses idl library routines ccm_unred, with default r_v = 3.1


common wom_active, active
COMMON wom_col, col
womdestruct, active, wave, flux, err, name, npix, header

print
print, 'Redden or deredden according to Cardelli, Clayton, & Mathis 1989.'

r = 3.1    ; for CCM89 reddening law

redordered = ''
repeat begin
    print, '(r)edden or (d)eredden the spectrum?'
    redordered = get_kbrd(1)
    redordered = strlowcase(redordered)
    print, redordered
endrep until (redordered EQ 'r') or (redordered EQ 'd')

redchoice = ''
repeat begin
    print,  'Do you want to enter the (c)olor excess, or (v)isual extinction?'
    redchoice = get_kbrd(1)
    redchoice = strlowcase(redchoice)
    print, redchoice
endrep until (redchoice EQ 'c') or (redchoice EQ 'v') 
ebv = ''
av = ''
if (redchoice EQ 'c') then begin
    read, 'Enter E(B-V) in magnitudes: ',  ebv
    ebv = float(ebv)
endif else begin
    read, 'Enter A_V in magnitudes: ', av
    ebv = float(av) / r
endelse


if (redordered EQ 'r') then ebv = -1 * abs(ebv)

newflux = flux
newerr = err
ccm_unred, wave, newflux, ebv
ccm_unred, wave, newerr, ebv


minval = min([min(flux), min(newflux)]) * 0.9
maxval = max([max(flux), max(newflux)]) * 1.1


plot, wave, flux, xst = 3, yst = 3, psym = 10, $
  xtitle =  'Wavelength', ytitle = 'Flux', title = name,  $
  yrange = [minval, maxval], color = col.white
oplot, wave, newflux, psym = 10, color = col.red
wshow
print
print, 'White = before, red = after.'

answer = ''
print, 'Is this ok (y/n), default=y?'
repeat begin
    answer = get_kbrd(1)
    if ((byte(answer))[0] EQ 10) then answer = 'y'
    answer = strlowcase(answer)
    print, answer
endrep until (answer EQ 'y') or (answer EQ 'n')


case answer of
    'n': begin
        print, 'OK, sorry to disappoint you.'
        print, 'Active spectrum unchanged in memory.'
    end
    'y': begin
        print, 'OK, active spectrum is now the modified version.'
        active.flux = newflux
        active.err = newerr
    end
endcase

end
