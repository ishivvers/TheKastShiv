## The Kast Shiv ##

_fast, easy, effective_


This is the Isaac version of the
Flipper group's Kast/Shane reduction pipeline.


### goals of this new code ###

- highly automated
- cuts no corners
- does not require a complicated environment
- lots of documentation
- easy to start/stop/resume at any point in the reduction
- robust to errors
- secondary: does not require IDL


### include path in environment variables ###

You need to include the following commands in your `bash` login file (e.g., `~/.bashrc`):

    export IDL_PATH=$IDL_PATH:+<KAST_SHIV_DIRECTORY>/tools
    export PYTHONPATH=$PYTHONPATH:<KAST_SHIV_DIRECTORY>:<KAST_SHIV_DIRECTORY>/tools


### modified files ###

- path to licksky.fits in final.pro
- path to asthedit.cmd in kastfixhead.cl
- various paths in login.cl


### to do ###

- clean up iraf, idl routines
- write an install script that takes template files and
  inserts into them the proper paths for all files that require
  modification.