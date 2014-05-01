pro womstat
common wom_active, active

womdestruct, active, wave, flux, err, name, npix, header

print, ' '
print, strcompress('Object is '+name)
print, ' '
print, 'Enter range for statistics'
print, ' '
womwaverange, wave, flux, indexblue, indexred, npix, 0
print, ' '
stat = moment(flux, MDEV = md, SDEV = sd)
med = median(flux)
print, 'Mean: ', stat[0]
print, 'Variance: ', stat[1]
print, 'Std. Dev.: ', sd
print, 'Mean Dev.: ', md
;this is the IRAF S/N number 
print, 'S/N: ', stat[0]/sd
print, 'Skewness: ', stat[2]
print, 'Kurtosis: ', stat[3]
print, 'Median: ', med
print, 'No. points: ', npix
print, ' '
end
