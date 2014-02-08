backup-script
=============

A bash script that uses rsync and ssh to produce remote backups that resemble time machine

# Backup script number one
Posted on January 27, 2011 by Keith

I have been using my own home grown backup solution for several months now. I
am writing about it now because I am getting the itch to modify it, and want to
document what I’ve done so far before it changes too much.

####For my first iteration, my requirements were as follows:

 *  The backup destination is a NAS hard drive array. This NAS has been hacked so it has ssh and rsync capabilities, but not much more advanced than that. It is a very basic low power linux server.
 *  Some of the machines being backed up are laptops, and therefore are not always on my LAN.
 *  The backups are intended to backup data, not systems. There is no intention of being able to bring a system back from a crash or restoring programs or the operating system. The intention is to not lose data.
 *  The backup filesystem structure was inspired by Apple’s Time Machine backup system. Each backup gets its own top level directory named based on the date and time of the backup. Inside the directories look like complete copied of the backed up data. Hard links are used to save space when files have not changed.

####Design decisions that were not necessarily requirements:

 *  The machines being backed up are responsible for pushing their backups to the NAS. Cron is used on the client machines to schedule their backups. This was done mostly because the linux install on the NAS is extremely bare and low power.
 *  The machines I intended to backup included a macbook and 2 linux machines. I decided to write a bash script that would be able to run on either OSX or Ubuntu.
 *  Logging was limited to cron emailing the output of the script to the account that ran the script. This is an issue I plan to change in a future backup solution. These emails are mostly ignored, so detection of problems is almost nonexistent.

## So tell me how to use your script.

First, I should point out that this script is not really intended for use by
people who don’t already have some basic knowledge of rsync and bash scripting.
If you’ve never edited a bash script before, this may not be the right solution
for you.

The script should be relatively easy for someone to configure and use for their
own backups. There is a configuration section at the top of the script.
Configuration is based off the current hostname. For each host there are only a
few configuration options. Each of these must be defined for every host.

variable | description
---------|------------
source | the root directory to be backed up
dest_host | the hostname of the destination server. You should be able to run "ssh" and get a bash prompt on the server machine without entering a password. If you can’t, you will need to do some work to configure ssh. That is beyond the scope of this post, and google is your friend.
dest_path | the path to the backup storage location on the destination server. This should be unique for the machine you are backing up. In my case they were all the same except for the final directory level which was the hostname of the machine being backed up.
exclude_file | full path to an rsync exclude file, or "" if you don’t need an exclude file.
keep_x_hourlys | the number of most recent backups to keep, regardless of how old they are.

You will probably also want to make sure the “enable_growling” option is set to
“false”. The growling function is rather specific to my setup.

The next step would be to configure cron to run the script on a schedule. On my macbook I added the following line to my crontab. (From a terminal run “crontab -e”)

	0 */2 * * * ~/bin/backup.sh 2>&1 | tee /tmp/backup.log

This line will run the backup script every 2 hours, redirects stderr to stdout and logs the current stdout to /tmp/backup.log so I can watch its progress while it runs. Using the tee command to log stdout allows me to log the current run to a file while the output still gets emailed to me when the cron job is done.

At this point the backup should run on a schedule and your data should be backed up.

## What will my backups look like?

After a few days you will have a few backups to look at. What has this script
really done for you? If you go look inside your dest_path directory on
dest_host you will see a set of directories similar to the following.

	backup.2011-01-01-020001
	backup.2011-01-02-000001
	backup.2011-01-03-000000
	backup.2011-01-04-000000
	backup.2011-01-04-220000
	backup.2011-01-05-000000
	backup.2011-01-05-020000
	backup.2011-01-05-040000
	backup.2011-01-05-060000
	backup.2011-01-05-080001
	backup.2011-01-05-100000
	backup.2011-01-05-120000
	backup.2011-01-05-140000
	Latest -> backup.2011-01-05-140000

If you configured it the same as I did to backup every 2 hours and keep 24 of
the latest, you probably have a lot more directories than that. This is just a
sample. Each backup is named with the year, month, day and time the backup
started. You should also have a symbolic link named “Latest” that points to the
most recent completed backup. Each backup directory should appear to be a
complete copy of the source directory you are backing up. Files that have not
changed will use hard links to drastically reduce the storage space
requirements while allowing it to look like you have many copies of the files.

## When does the script remove old backups?

After your backups have been running for a while, the script will start to look
for older backups it can delete. The script as it sits now will look for the
    oldest backup that is not the first backup on the date it was made. This
    means that if you look at older backups, you should end up with one backup
    per day no matter how many backups were actually done each day. At the
    moment the script should never delete the first backup from any date, and
    should always keep the keep_x_hourlys most recent backups. The script will
    delete no more than 2 old backups each time it runs.

## Interesting idea, but I want more information or someone else’s solution:

No problem. This is a script that I wrote for myself and I am putting it out
there because it might be useful to someone else. There are plenty of other
rsync backup script out there. Some links to get some more information:

 * [Do-It-Yourself Backup System Using Rsync](http://www.sanitarium.net/golug/rsync_backups_2010.html)
 * [Easy Automated Snapshot-Style Backups with Linux and Rsync](http://www.mikerubel.org/computers/rsync_snapshots/)

