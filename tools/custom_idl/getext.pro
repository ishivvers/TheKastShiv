pro getext, extwave, extvals, obs

; extinction terms from Allen, 3rd ed.  via lolita
  extwave = [2400., 2600., 2800., 3000., 3200., 3400., 3600., 3800., $
             4000., 4500., 5000., 5500., 6000., 6500., 7000., 8000., $
             9000., 10000., 12000., 14000.]
  extvals = [68.0, 89.0, 36.0, 4.5, 1.30, 0.84, 0.68, 0.55, 0.46, 0.31, $
             0.23, 0.195, 0.170, 0.126, 0.092, 0.062, 0.048, 0.039, $
             0.028, 0.021]

  if obs eq 'lick' then begin
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
    endif

  if obs eq 'keck' then begin
; extinction terms from
;http://www.astro.caltech.edu/mirror/keck/realpublic/inst/lris/atm_trans.html
; Beland, S., Boulade, O., & Davidge, T. 1988, CFHT Info. Bull. 19, 16 
      extwave = [3100, 3200, 3300, 3390, 3509, 3600, 3700, 3800, $
                 3900, 4000, 4250, 4500, 4700, 5000, 5250, 5500, $
                 5750, 6000, 6500, 7000, 8000, $
                 9000, 10000, 12000]
      extvals = [1.37, 0.82, 0.57, 0.51, 0.42, 0.37, 0.33, 0.30, $
                 0.27, 0.25, 0.21, 0.17, 0.14, 0.13, 0.12, 0.12, $
                 0.12, 0.11, 0.11, 0.10, 0.07, 0.05, 0.04, 0.03]
      extvals = extvals/1.086
    endif

end
