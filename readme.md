## The Kast Shiv ##

_fast, easy, effective_


This is an attempt to build the Isaac version of the
Flipper group's Kast/Shane reduction pipeline.

Right now, the quicklooks Cenko pipeline works well (with
the UREKA python/pyraf/iraf installation), and I am running
into significant problems with the silverclubb full pipeline.


# goals of this new code #

- highly automated
- cuts no corners
- does not require a complicated environment
- lots of documentation
- easy to start/stop/resume at any point in the reduction
- robust to errors

- secondary: does not require IDL


------------------------------------

## to do: ##

- make sure the blue side apertures are the same as the red (which we fit for)
- incorporate and understand last (IDL) steps of silverclubb pipeline
- wrap kastshiv and put a handle on it
