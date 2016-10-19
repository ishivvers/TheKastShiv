## The Kast Shiv ##

This is the I.Shivvers version of the
Flipper group's Kast/Shane reduction pipeline.

This version of the code is designed to be used on data obtained
after September 2016
with the Kast spectrograph on the Shane telescope at Lick Observatory.
(Using the Fairchild CCD on the blue side and the Hamamatsu on the red.)

For data obtained before that date, see v1.0 of this code.

### goals of this code ###

- as automated as is reasonable
- cuts no corners
- does not require a complicated user environment
- lots of documentation
- every decision about reduction parameters is explicit
- keeps detailed logs of actions taken during reduction
- easy to start/stop/resume at any point in the reduction

## Getting it running ##

First, install the [Ureka Python/IRAF](http://ssb.stsci.edu/ureka/) system.
Or, if you're feeling very brave, install Python, IRAF, and pyraf yourself, and get
them to all cooperate.

Second, make sure you have a working installation of IDL on your machine.
This is only required for the flux calibration and atmospheric absorption
correction step, taken near the end of the reduction, which has not yet
been translated into Python.

There are some additional Python packages required too: Python will notify you the 
first time it's run.  Install them using 'pip install' from within the Ureka environment.

### run setup.py ###

The setup.py code inserts appropriate paths into files where needed.
(Note that this is not a normal python setup script.)
You should place the code into its permanent home and then run this script.
The script must be run every time the code is moved.

    # from KastShiv root folder
    python setup.py


### include path in environment variables ###

The Python and IDL interpreters need to know where to find the KastShiv
codes.  
If you use the bash shell, you can include the following commands in your `bash` login file (e.g., `~/.bashrc`):

    export IDL_PATH=$IDL_PATH:+<KAST_SHIV_DIRECTORY>/tools
    export PYTHONPATH=$PYTHONPATH:<KAST_SHIV_DIRECTORY>

### create the `credentials.py` file ###

There must exist a file named `credentials.py` in the KastShiv/tools folder, and in
that file there must live the credentials for logging into the Kast data repository
and the flipperwiki.  For example:

    >$ echo credentials.py
    wiki_un = 'USERNAME'
	wiki_pw = 'PASSWORD'
	repository_un = 'USERNAME'
	repository_pw = 'PASSWORD'


