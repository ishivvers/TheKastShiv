## The Kast Shiv ##

This is the Isaac version of the
Flipper group's Kast/Shane reduction pipeline.


### goals of this code ###

- as automated as is reasonable
- cuts no corners
- does not require a complicated environment
- lots of documentation
- easy to start/stop/resume at any point in the reduction
- secondary goal: does not require IDL

## Getting it running ##

First, install the [Ureka Python/IRAF](http://ssb.stsci.edu/ureka/) system.
Or, if you're feeling very brave, install Python, IRAF, and pyraf yourself, and get
them to all cooperate.

There are some additional packages required too: Python will notify you the 
first time it's run.  Install them using 'pip install' from within the Ureka environment.

### run setup.py ###

The setup.py code inserts appropriate paths into files where needed.
You should place the code into its permanent home and then run this script.
The script must be run every time the code is moved.

    # from KastShiv root folder
    python setup.py


### include path in environment variables ###

You need to include the following commands in your `bash` login file (e.g., `~/.bashrc`):

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


### to do ###

 - should average ~50 columns for the trim section definition, to smooth it out better
 - stop doing cosmic ray removal on the blue side
 - do a better job with seeing calculations? Calculate if possible from observation.
 - put all of the lists into dictionaries that allow user to add/remove entries at will
 - track file names per image with a dictionary?