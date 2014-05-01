PRO wombat
;  wombat is a spectral reduction package meant to replace bonnie and
;  sarah
;  written by T. Matheson, Jan. 1999
;  Mar. 1999  all file i/o now controlled through get_lun/free_lun to 
;  avoid confusion with other open files, added wombat.log to record  
;  location of blotches, COMbining (w or w/o weights), scaling of one
;  spectrum to match another (scale2), and the overlap, scaling and 
;  weighting in the cat procedure
;  renamed as wombat June 2001
;  Added variance stuff in Jan 2007


COMMON wom_hopper, hoparr, hopsize
COMMON wom_active, active
COMMON wom_arraysize, arraysize
common wom_aplflag, aplflag
common wom_ulog, ulog
COMMON wom_col, col

version = '1.1a'
; identify user
user = ''
spawn, 'whoami', user, /noshell
print, ' '
print, strcompress('Hello, '+user)


; this sets the spectrum size to 30000, but easily adjusted to
; accommodate specific needs 
arraysize = 30000

hopinit = {hop_struct, wave:fltarr(arraysize), flux:fltarr(arraysize), $
           err:fltarr(arraysize), obname:'', head:strarr(450), nbin:0L}
active = hopinit

; sets up calls for color in all plots

col = {black: 0L, red: 1L, green: 2L, blue: 3L, $
       aqua: 4L, violet: 5L, yellow: 6L, white: 7L}
;this gives 20 hoppers (we don't use 0), alter this number if you want more
hopsize = 21
hoparr = replicate({hop_struct}, hopsize)
aplflag = 1
logfile = 'wombat.log'
SPAWN, 'if test -w . ; then echo "write"; fi', wtest, /SH
IF (wtest[0] EQ '') THEN logfile = '/dev/null'
get_lun, ulog
openu, ulog, logfile, /append
printf, ulog, systime()
printf, ulog, strcompress('Wombat starts, version '+$
                          strtrim(string(version), 2))
printf, ulog, strcompress('User is '+strtrim(user, 2))

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
;print, ' '
print, strcompress('Welcome to Wombat, V'+version+$ 
          '.  ? or help lists commands.')
print, ' '
if (!d.window GE 0) then begin
    device, get_window_position = place
    window, title = 'Wombat', xsize = !d.x_size, ysize = !d.y_size, $
      xpos = place[0]-5, ypos = place[1]+25
ENDIF
if (!d.window LT 0) then begin
    device, get_screen_size = si
    window, title = 'Wombat',  xsize = fix(si[0]*.78), $
      ysize = fix(si[1]*.7), xpos = fix(si[0]*.2), $
      ypos = fix(si[1]*.3)
endif
device, cursor_standard = 33
!Y.STYLE = 16

command = ''
commandarr = strarr(100)
commandarr[*] = command
repeat begin
    print, ' '
    read, 'Enter command: ', command
    command = strtrim(command, 2)
    commandarr = shift(commandarr, 1)
    commandarr[0] = command
    IF (commandarr[0] EQ commandarr[1]) AND (commandarr[1] EQ $
                                             commandarr[2]) THEN BEGIN
        print, ' '
        print, 'Monotonous, isn''t it?'
    ENDIF
    c1 = strmid(command, 0, 1)
    if (c1 EQ '$') then begin
        command = strmid(command, 1, 79)
        spawn, command
        command = ' '
    endif
    command = strlowcase(command)
    if (command EQ 'h') then command = 'hist'
    if (command EQ 'q') then command = 'quit'
    case command of
        'rpl': womrpl ;
        'wpl': womwpl ;
        'rfits': womrfits ;
        'wfits': womwfits ;
        'hop': womhop ;;
        'rh': womrdhop ;;
        'rhop': womrdhop ;;
        'plot': womplot ;
        'p': womplot ;
        'ph':womplothard ;
        'hard':womplothard ;
        'apl': womapl ;
        'oplot':womapl ;
        'blotch':womblo ;
        'b':womblo ;
        'com':womcom ;
        'combine':womcom ;
        'cmw':womcmw ;
        'cme':womcme ;
        'bin':wombin ;
        'pixrebin':wompixrebindriver ;
        'newrebin':womnewrebin ;;
        'ashrebin':womashrebindriver ;
        'cat':womcatchoice
        'buf':wombuf ;;
        'buffer':wombuf ;;
        'stat':womstat ;
        'cho':womcho ;
        'choose':womcho ;
        'e':womexam ;
        'examine':womexam ;
        'smo':womsmo ;
        'smooth':womsmo ;
        'plotlog':womplotl ;
        'plotl':womplotl ;
        'pl':womplotl ;
        'spl':womspl ;
        'spline':womspl ;
        'sca':womsca ;
        'scale':womsca ;
        'w':womredshift ;
        'redshift':womredshift ;
        'ms':womms ;
        'arith':womms ;
        'fnu':womfnuflam ;
        'flux':womfnuflam ;
        'head':womhead ;
        'fitshead':womhead ;
        'help':womhelp ;
        '?':womhelp ;
        'win':womwin ;
        'window':womwin ;
        'avt':womscale2 ;
        'scale2':womscale2 ;
        'velcho':womvelcho ;
        'gau':womgau ;
        'int':womint ;
        'red':womderedden ;
        'ls':spawn,'ls -CF' ;;
        'zap':womzap ;
        'xshift':womxshift ;
        'yshift':womyshift ;
        'linesub':womlinesub ;
        'rmsfits':womrmsfits ;
        'rerrfits':womrerrfits ;
        'join':womjoin ;
        'zcalc':womzcalc ;;
        'bluen':wombluen ;
        'bb':wommkbb ;
        'planck':wommkbb ;
        'atmdisp':wommkatmdisp ;
        'wavescale':womwavescale ;
        'depth':womlinedepth ;
        'relvel':womrelvel ;;
        'filter':womfilters ;;
        'hertz':womhertz ;
        'wb':womblueshift ;
        'avmany':womscalemany ;
        'commany':womcommany ;
        'commanyw':womcommanyw ;
        'commanye':womcommanye ;

        'hist':BEGIN
            FOR i = 99, 1,  -1 DO BEGIN
                print, string(i)+'  '+ commandarr[i]
            ENDFOR
        END
        'quit': begin
            repeat begin
                print, 'Really? (y/n, default y) '
                a = get_kbrd(1)
                if ((byte(a))[0] EQ 10) then a = 'y'
                a = strlowcase(a)
                print, a
            endrep until (a EQ 'y') or (a EQ 'n')
            if (a EQ 'n') then command = '' else print, 'So long'     
        end
        else: print, ' '

    endcase
endrep until (command EQ 'quit')
print, ' '
close, ulog
free_lun, ulog
device, /cursor_crosshair
end
