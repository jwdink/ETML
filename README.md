ETML
====
A Framework for Running Eyetracking Experiments in MATLAB

# Author

All original code written by Jacob Dink (jacobwdink@gmail.com)

Structure of this code was originally based on Brock Ferguson's scripts for running studies on infants. See https://github.com/brockf/ORT

# Introduction

This is a framework for running experiments in MATLAB. By making a few spreadsheet files (config.txt, stim_config.txt) to specify your experiment's stucture, you can easily and quickly set up many different types of experiments.

The emphasis is on vision experiments that interface with SR-Research Eyelink Eyetrackers. However, this framework can be helpful in a broader set of cases than that.

Usage  | Solution
------ | --------
You need a quick and ready eyetracking experiment that presents simple instructions, images, and video.  | Simply copy-and-paste the 'Example' folder and adapt it to your needs
You need a fairly simple experiment, but want complete control over the code for a custom need that other experimental software can't accomodate  | Same as above, but tweak the ETML codebase itself to your need. The entire framework is in MATLAB, so you have the full power of MATLAB & PsychToolBox at your disposal
You need to completely customize what happens on each trial, but you want easy management of the trial/block/phase structure (and, optionally, you want an easy, preconfigured interface with the eyetracker). | Same as #1, except also copy the "custom_function.m" template to your folder. Specify what happens on each trial within that function. ETML and the stim_config.txt will handle the ordering of trials, and the sending of data to the eyetracker!

### Key Features:

* Manage experiment structure via a file viewable in Excel, rather than a series of convoluted, nested 'for'-loops inside your experiment code.
* All interfacing with Eyelink eyetracker abstracted and taken care of for you. Worry about making your experiment, not sifting through the eye tracker documentation.
* Detailed, timestamped information sent to eye tracker and to a log text file as experiment runs. Includes all messages, warnings, and keypresses. 
* Key information about trial (condition, stimuli information) sent to a text file, with included R code to parse into 'tidy' R dataframe, ready for analysis. This is important, because it means you can run experiments that don't even use an eyetracker. For those that do, same information is sent to eye tracker.
* Experiment can be terminated at any point by pressing and holding ESC, and data so far will be saved.
* Ability to write your own script for what's presented on each trial. Let ETML handle the eyetracker and the experiment structure, and just worry about scripting the actual trial contents.

# Guide

First, download this git. The easiest way to get going is simply to copy and paste the "Example" folder, renaming it to your experiment's name.

## Getting Set-Up : Config.txt

If you open the example config.txt in Excel, you'll see it has a couple entries, along with a description of what each of these entries is for. I won't relist those here, since the example config.txt explains everything fully (exception is the 'CustomFields', explained in the next paragraph). The only fields that are strictly required are 'StudyName' and 'RecordingPhases' (all others will be supplied a default) but you'll likely want to explicitly set the other fields as well.

The 'CustomFields' entry specifies columns in 'Stim_Config' that you have added yourself (i.e., they aren't the pre-designated ones described below) that you'd liked saved in your data. All columns described in the next section are automatically saved in your data, but you might want to add your own columns--either for convenience (they give descriptions to blocks/trials that are otherwise just numbered) or necessity (they help determine things in a custom trial).

## Getting Set-Up : Stim_Config.txt

Open this file in Excel to follow along with this guide. You'll see a table where each column specifies some details about trial or trials, and each row represents either a single trial, or a sequence of trials.

### Basic Structure:

Here are the required columns:

* **Condition** : between subjects condition
* **PhaseNum** : Phase within experiment
* **BlockNum** : Block within phase
* **TrialNum** : Trial within block
* **Stim** : Path or specification of stimulus. 
* **StimType** : What kind of stimuli is being presented? Supported options described below.

An ETML experiment is structured heirarchically, where phases are composed of blocks, blocks are composed of trials. If you include optional column **"TrialShuffle"**, you can set this to 1 for a block, and this will shuffle the trials in that block. Similarly for the optional column **"BlockShuffle"**. Leave this option blank on a given trial/block, or set it 0, to *not* shuffle. 

*Note that in the data output from the experiment, 'trial' and 'block' numbers will specify the order these trials/blocks were shown in, not the original number from this stim_config.txt. In other words, the trial number specified in the config.txt is not meaningful on those blocks where 'TrialShuffle' is on (and ditto for blocks and blockshuffle).*

A 'trial' should, for the most part, be thought of as a single stimulus presentation. This makes analysis much easier: each trial has its own image/video, its own interest areas, etc. If you suspect you need multiple stimulus presentations within a given trial, first consider whether these presentations can't simply be split into multiple trials. If not, consider the 'custom trial' described in the later section.

### StimTypes

There are several stimuli types supported:

* **Image** : An image or directory of images
* **Video** : A video or directory of videos (requires GStreamer).
* **Slideshow** : Identical to image, except images are advanced using arrow keys, and you can go backwards to previous images. Useful for presenting instructions to experiment.
* **Custom** : A custom script you wrote yourself. Will simply call 'custom_function' on trials with this stim_type. See 'Custom Trials' section below.

ETML knows how to interpret any of the following optional columns (for images and videos):

* **DimX, DimY** : What dimensions in pixels do you want the stim to have? Default is original dimensions
* **StimCenterX, StimCenterY** : What position on the screen do you want the stim to be? (E.g., 400,400 puts the center of the 400 pixels below the top of the screen, and 400 pixels rightwards of the left-side of the screen). Default is centered.
* **FlipX, FlipY** : Mirror the stim? Default no.


### Trial / Stimuli Duration

Trials have a duration, which can be specified (*in units of seconds*) with the **"StimDuration"** column. 

A single number entered here will specify the minimum and maximum duration of this stimulus (i.e., time to keep stim up, regardless of keypress). 

If you enter two numbers (separated by a comma), the first will be used as the minimum duration (i.e., stays up at least this long, regardless of keypress), the second will be used as the maximum duration (i.e., ends by this time even if no keypress registered).

For 'default' behavior, leave blank or enter 0. 'Default' behavior is different for images and videos. For images, default means keep on screen indefinitely until keypress; for videos, default means keep on screen until end of video (and keypress will not terminate video early).

### Repeating Trials with 'TrialNum':

A key feature of ETML is that you don't have to specify every single trial manually. Instead, you can use indexing to specify trials. This follows the same syntax as MATLAB, except you must always wrap the numbers in brackets (otherwise excel will think it's a timestamp).

For example, if I have a row where stim is "repetitive_picture.png", and I want that stim to be shown on trials 1 through 10, I would enter `[1:10]` in the TrialNum column for that row (brackets required!!). Or, if I wanted it presented only on *even* trials, I could enter `[2:2:10]`. Any indexing possible in MATLAB will be obeyed here, making this a powerful tool. For example, I could easily make an image flipped on half of the trials, or change its position every fourth trial, etc.

This feature applies not just to the TrialNum column, but to the Condition, PhaseNum, and BlockNum columns as well.

### Draw Stimuli from a Folder:

The "Stim" column, especially in conjunction with the capacity to repeat trials described above, can be particularly useful. **Instead of specifying a particular stimulus to be repeated, you can specify a folder of stimuli. In this case, stimuli will be drawn from that folder, with a different one presented on each trial.**

___
##### Advanced: Method of Drawing Stim from Folder:

You can specify how to draw stimuli from the folder with the optional column **"StimDrawFromFolderMethod"**.

**Note:** *Some of these options are detailed, and may be confusing if you're just glancing around. If you're simply shuffling your trials (as described above), or if you're simply running your trials in order, these options aren't something you have to worry about-- you can just ignore this column (and this section of the documentation).*

The options for **"StimDrawFromFolderMethod"** are:

- **Ascending ('asc')** : The default. Pick the filenames within the folder in alphabetical/numeric order.
- **Descending ('desc')** : Pick the filenames within the folder in reverse-alphabetical/numeric order.
- **Sample Randomly ('sample')** : Randomly sample without replacement. 
  - If number of stimuli is greater than or equal to number of trials, this has obvious behavior: draw from pool of possible stimuli for each trial.
  - If number of stimuli is less than number of trials, behavior is easiest to explain by example: if there are 10 stimuli, and 20 trials, this will sample without replacement as if there was two of each stimuli. (Number of trials must be an even multiple of number of stimuli.) By default, this does not allow consecutive presentation of the same stim-item (which means if there are only two stim-items, this will not actually shuffle!).
- **Sample Randomly, Allow Consecutive ('sample_consec')** : Same as above, but this *does* allow for consecutive presentation of identical stim-items.
- **Sample Randomly with Replacement ('sample_replace')** : Randomly sample *with* replacement. 

___

### Text Before and After a Trial:

The main focus of a trial is the stimulus being presented. Often, however, we want to ask a question before a stimulus presentation, and/or await a response.

- **BeforeStimText** : Some text you'd like presented before the main stimulus is shown.
- **BSTDuration** : How long this text should be up. See the 'Trial / Stimuli Duration' section for what information to put here.
- **AfterStimText** : Some text you'd like presented after the main stimulus is shown.
- **ASTDuration** : Same as above.

These columns can be ommitted or left blank if these are not needed.
___

##### Advanced: Looping Through Multiple Messages for Same Stimulus:

Both of these fields can either accept a single string, or a cell array of strings, e.g., for 'BeforeStimText' you could enter (all on one line):

```
{"Find the largest object in the following image", 
 "Find the reddest object in the following image", 
 "Find the oddball in this image"}
``` 

When a cell array like this is supplied, the stimulus in the 'Stim' column will be presented once for EACH of these messages. Similarly, if 'Stim' specifies a folder (not a single file), each image will be shown three times in a row, one for each message. So if you want *all* stim-files in a folder to be shown, make sure your TrialNum column reflects this: for example, for ten images in a folder, and three different 'before' messages, the "TrialNum" column should specify `[1:30]` (3 trials for each of the 10 images). 

You can also randomly sample from these question/stim-item pairings with the options described in the previous section ('Method of Drawing Stim from Folder'). One useful option is the non-consecutive option: randomly select an stim-item and a question to show before/after it, with the constraint that the same stim-item can't be shown twice in a row.

BeforeStimText and AfterStimText must match: if one is a cell array of length three, the other must be too. If you'd like to change the before text with a cell array but always have the same after text, you could just make the after text a cell array with the same item in each cell.
___


## Custom Trials

*[This section a work in progress. For now, the 'custom_function.m' file in the Example folder should give you all the information you need.]*

## Running the Experiment

Simply run ETML.m in MATLAB. It will open up a directory-chooser. Navigate to the directory with your experiment in it.

You'll then be asked to enter session information about the participant, condition, etc. After this is done, the experiment will begin. 

___
##### Advanced: Custom Session Information and Calling ETML Programmatically

*[This section a work in progress]*

___

## Getting the Data

*[This section a work in progress.]*











