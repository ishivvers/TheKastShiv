"""
The Kast Shiv: a Kast spectrocscopic reduction pipeline
 written by I.Shivvers (modified from the K.Clubb/J.Silverman/T.Matheson
 pipeline and the B.Cenko pipeline - thanks everyone).


Notes:
 - for now simply incorporate IDL routines, do not replace them
 - automate absolutely everything you can
 - have a switch with three options:
  1) show every plot and confirm along the way
  2) save every plot for later inspection
  3) create no plots, just do everything
 - include a decorator that logs every step
 - use log to make it so you can pick up and resume
   a reduction from any failure point
 - automate the file structure management
"""

from shivutils import *