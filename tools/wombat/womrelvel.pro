PRO womrelvel

; computes velocity for wavelength shift relativistically
lambda0 = ''
lambda = ''


print, 'Relativistic velocity calculation'
print, ' '
read, 'Observed wavelength: ', lambda
print, ' '
read, 'Rest wavelength: ', lambda0
lambda0 = double(lambda0)
lambda = double(lambda)
IF (lambda0 EQ 0) THEN BEGIN
    print, 'Invalid rest wavelength'
    return
ENDIF

z = (lambda-lambda0)/lambda0
print, ' '
print, 'z ', z
sq = (z+1.0)^2
;print, sq
vel = ((sq-1.0)/(sq+1.0))*299792.458

;print, ' '
print, 'Velocity is: '+string(vel)

END
