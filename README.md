ETML
====

Script for running eyetracking experiments in MATLAB with Eyelink.

This is a framework for running vision experiments in MATLAB, with an emphasis on simple eyetracking studies (interfacing with Eyelink eyetrackers).

By making just a few tab-delimited config files, you can set up an experiment that presents stimuli, and records gaze data and keypresses.

This is a pre-release that is mostly for personal use. Future releases will actually include instructions, work with different eyetrackers, etc.

To make a new experiment within this framework, download this .git. Then, create a folder with stimuli and config files. Finally, run ETML.m and when prompted for a directory, point it to the folder with the config files. (This second step will actually be explained in future releases, but for now, examples are included.)

This script was originally based on Brock Ferguson's scripts for running studies on infants. See https://github.com/brockf/ORT

Note: this has ONLY been tested on OS X
