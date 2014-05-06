PRO pacheck, head
bell = string(7B)
observat = ''
observat =  strcompress(sxpar(head, 'OBSERVAT'), /remove_all)
airmass = float(sxpar(head, 'AIRMASS'))
optpa = float(sxpar(head, 'OPT_PA'))
;if observat eq 'keck' then optpa = float(sxpar(head, 'PARANG'))+90.0
if optpa eq 0.000 then optpa = float(sxpar(head, 'PARANG'))+90.0
case observat of
    'keck': pa = float(sxpar(head, 'ROTPOSN'))+90.0
    'lick': pa = float(sxpar(head, 'TUB'))
    'palomar': pa = 90.0
    'mcdonald': pa = float(sxpar(head, 'PARANGLE'))-float(sxpar(head, 'RHO_OFFS'))
    else: pa = 1000.0
endcase
sxaddpar, head, 'OBS_PA', pa, 'observed position angle'
diffpa = abs(optpa-pa)

IF (pa GE 999) THEN diffpa = 0.0
IF (airmass GT 1.1) AND (((diffpa GT 10) AND (diffpa LT 170)) OR $
                         ((diffpa GT 190) AND (diffpa LT 350)) OR $
                         ((diffpa GT 370) AND (diffpa LT 530))) THEN BEGIN
    print, '************WARNING***************'
    print, bell
    print, 'Observed position angle: '+string(pa)
    print, 'Optimal parallactic angle: '+string(optpa)
    print, 'Airmass: '+string(airmass)
    print, ' '
    print, 'Relative flux may be compromised'
    print, 'Hit any key to indemnify me against any and all'
    print, 'problems that may arise from this'
    c = get_kbrd(1)
ENDIF
end
