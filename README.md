This software is open source but not free software. You are not permitted
to distribute, use, or otherwise copy this software unless you meet the
requirements (tl;dr: it's free for other open source projects).
See the LICENSE file for details.

# YouTrack to Github Issues Exporter

This software migrates issues in YouTrack to a Github repository.

## Prerequisites

This software is written in MethodScript, and uses the MSXodus
extension. You'll need to install Java, download and install MethodScript,
and put the MSXodus extension in the extensions folder. Most versions
of Java work, see https://methodscript.com/ for instructions on installation
of MethodScript.
The source for the MSXodus extension can be found [here](example.com) and the
jar should be put in the MethodScript/extensions folder in your installation
of MethodScript.

Next, you'll need to obtain a backup of the YouTrack installation. This is left
as an exercise for the reader. Uncompress this to your file system. You should
see many .xd files within the database.

A YouTrack installation can have multiple projects, and the software will only
import one project at a time, however, you can run the software multiple times,
pointing to a different YouTrack project (but the same Github repo) each time.

## Arguments

The script is generally run with

`mscript main.ms`

The first argument to the script is always the path to the database.

`mscript main.ms /path/to/db`

The second argument is generally the name of the project, but there are some special
names that have different behavior.

If you want to see a list of all projects, use `$list` as the project name, and it
will print out a list of projects and exit. For paid licenses, see the bottom of the readme.

If you want to be able to differentiate between closed and open issues, you need to provide
the basic information that tells the system which field is linked to the states. To find
the list of custom fields, run with the `$customFields` project, and to list the States,
run with the `$states` project.

You also need keys for uploading to GitHub. By default,
the script looks in ~/.youtrack-to-github/config.json for configuration data such as this,
but you may specify the location of this file as the optional third argument.
In any case, if the file does not exist, it will be created with
a template of required information, and then exit. There are a few other parameters you can
modify in this file.

In all, the arguments are:

`mscript main.ms <databse> <project> [<config file location>]`

## Config file
The config file contains a json structure, which is used to provide various other information
to the script.

### Personal Access Token (token)
This is your GitHub personal access token. Generally speaking, you may wish to create a standalone
github account under which to upload the issues under, because all the issues and comments will
be uploaded by this user. In any case, you need to generate a personal access token for the account
you wish to use. In GitHub, go to your profile picture in the top right, Settings, Developer
Settings, Personal Access Tokens, and Generate new token. You must give the token access to "repo".

### Interactive Mode (interactive)
There are a few interactive prompts to help you ensure you're doing the right operations. You can
disable the prompts and generally accept them if you're sure you're doing it right.

### Repo Owner (owner)
This is the name of the owner of the repo, or the organization name. If you visit the repo on github,
it's github.com/OWNER/REPO

You can leave this blank to be prompted for the value.

### Repo Name (repo)
This is the name of the repo itself. If you visit the repo on github, it's github.com/OWNER/REPO

You can leave this blank to be prompted for the value.

### Application Namer (applicationName)
This is the name of the application. This is used in the user agent, and should be a way for github
admins to notify you if you're going over limits.

### Do Upload (doUpload)
If this is set to false, the database won't be uploaded, it will be printed to console instead. This
is useful to take a quick look at the rough results, to ensure that they look more or less correct
before spending the time to actually do the upload.

### Test Limit (testLimit)
If this is non-zero, the code will only process this many issues. This is useful for limited testing, to
ensure the system is correctly configured, without running it against the entire database.

### State Field (stateField)
If you run `$customFields` then you get a list of custom fields linked to the issues. Find the one that
represents the issue state, and put that here.

### Closed States (closedStates)
This is an array of the states that should be considered as "closed". To see the full list, run with `$states`,
but defaults are provided.

### Skipped States (skippedStates)
This is an array of the states for issues that just shouldn't be imported at all. To see the full list, run
with `$states`, but defaults are provided.

### State Table (stateTable)
By default, we use the table named IssueState. If this is not the name of the table where you have the states
listed, you can list all tables with the `$tables` project, then fill in the correct value here. This is only
used to list out the states in the `$states` command.

## Stopping mid-run
It's extremely important to not interrupt the process as it's running. If you need to stop the
process midway, put the word "stop" (in the control.txt file), and it will safely
shut down. If you simply kill the process, you risk getting a duplicate issue, as the tool keeps an
internal database of what has and has not been uploaded already, so the process is generally
resumable midway.

## Estimated time
Due to rate limiting restrictions, this is intentially a slow process. The GitHub API only allows
one POST request per second, and so at a minimum, each issue and comment will take 1 second each.
Generally speaking, this is the bottleneck, though there is also a general request rate limit of 5000
requests per hour. The script will automatically limit itself within these tolerances, and unfortunately
there is no way to speed the script up beyond the programmed limits. The script will constantly display
an estimated time remaining to give you an idea of what's left to be done.

## Resuming from an interrupted state
It is fully supported to resume the upload mid-way. Every action is logged internally, and actions
will not be repeated. Simply restart the script, and it will pick up where it left off.

### Paid license calculation
If you need to buy a license, it is based on the number of users registered in the
YouTrack installation. The number of users that you have is your responsibility
to accurately determine, though there is a shortcut command to find the pricing, by
running

`mscript main.ms '/path/to/database' '$pricing'`

It is your responsibility for ensuring that this number is accurate based on the following
formula:
- Users 1-100: $4 each
- Users 101-200: $3 each
- Users 201-300: $2 each
- Users 301+: $1 each
