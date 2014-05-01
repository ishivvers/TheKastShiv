pro womcatchoice

print, ' '
repeat begin
    print, 'Do you want to define spectral regions by entering'
    print, '(w)avelengths by hand, or mark them with (m)ouse?  (w/m)'
    c = get_kbrd(1)
    c = strlowcase(c)
    print, c
endrep until (c EQ 'w') or (c EQ 'm') 
print, ' '
if (c EQ 'w') then womcat
if (c EQ 'm') then wommouse
end
