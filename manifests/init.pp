# == Class: xtrabackup
#
# Configures xtrabackup to take MySQL database backups
#
# === Parameters
#
# [*dbuser*]
#   Database username (Required)
# [*dbpass*]
#   Database password (Required)
# [*hour*]
#   Hour to run at.  Cron format, */3 or 3,6,9,12,18,21 are valid examples.
#   (Required, unless cronjob is set to false))
# [*minute*]
#   Minute to run at.  Cron format.
#   (Required, unless cronjob is set to false)
# [*workdir*]
#   Working directory.  The volume it is on needs at least as much free space as
#   total database size on disk.  Must already exist.
#   (Optional, uses /tmp by default)
# [*outputdir*]
#   Directory to write backups to.  If sshdest is also specified, will be the
#   remote database host.  Must already exist.
#   (Required)
# [*sshdest*]
#   Destination host to send to via SSH.  Assumes keys already set up.
#   Prefix with username if not root.
#   (Optional, writes to local machine if not set)
# [*sshkey*]
#   SSH private key to use, if not default /root/.ssh/id_rsa or similar
#   (Optional if sshdest is specified)
# [*keeydays*]
#   Delete backups older than this age in days.  THIS WILL CLEAR ALL FILES IN
#   outputdir!!
#   (Optional, disabled by default)
# [*gzip*]
#   Whether to compress backups using gzip
#   (Optional, enabled by default)
# [*parallel*]
#   Speed up backup by using this many theads.
#   (Optional, defaults to 1)
# [*slaveinfo*]
#   Record master info so that a slave can be created from this backup.
#   (Optional, disabled by default)
# [*safeslave*]
#   Stop slaving and connections to it whilst taking the backup, re-starting
#   when finished.  Off by default, strongly recommended for slaves.
#   (Optional, disabled by default)
# [*addrepo*]
#   Whether to add the Percona repositories.  Only supported for RedHat
#   presently.
#   Enabled by default, pass 'false' to disable.
#   (Optional, enabled by default)
# [*cronjob*]
#   Whether to install a cronjob to perform a scheduled backup.
#   Enabled by default, pass 'false' to disable.
#   (Optional, enabled by default)
# [*silentcron*]
#   Generate backup output only if there was an error. Setting this
#   to true will surpress all mails from cron unless the backup script
#   failed.
#   (Optional, defaults to send daily emails).
# [*install_20*]
#   Whether to install Xtrabackup 2.0; if set to false installs the latest (2.1)
#   instead.
#   (Optional, disabled by default)
# [*statusfile*]
#   File to touch in case the backup was successfull. Can be used for to monitor
#   the backup status using check_file_age.
#
# === Examples
#
#  A simple example which takes backups at 3am every morning, creates compressed
#  backups on a locally mounted volume and stores them for two weeks:
#
#  class { "xtrabackup":
#    dbuser    => "root",
#    dbpass    => "rootdbpass",
#    hour      => 3,
#    minute    => 0,
#    keepdays  => 14,
#    workdir   => "/root/backupworkdir",
#    outputdir => "/mnt/nfs/mysqlbackups",
#  }
#
# === Authors
#
# Sam Bashton <sam@bashton.com>
#
# === Copyright
#
# Copyright 2013 Bashton Ltd
#
class xtrabackup ($dbuser,              # Database username
                  $dbpass,              # Database password
                  $hour       = undef,  # Cron hour
                  $minute     = undef,  # Cron minute
                  $workdir    = '/tmp', # Working directory
                  $outputdir,           # Directory to output to
                  $sshdest    = undef,  # SSH destination
                  $sshkey     = undef,  # SSH private key to use
                  $keepdays   = undef,  # Keep the last x days of backups
                  $gzip       = true,   # Compress using gzip
                  $parallel   = 1,      # Threads to use
                  $slaveinfo  = undef,  # Record master log pos if true
                  $safeslave  = undef,  # Disconnect clients from slave
                  $addrepo    = true,   # Add the Percona yum/apt repo
                  $cronjob    = true,   # Install a cron job
                  $silentcron = false,  # Send emails always
                  $install_20 = false,  # Install 2.0 instead of latest
                  $statusfile = undef,  # statusfile to touch if cronjob was successfull.
                 ) {

  if ($addrepo) {
      if ($::osfamily == 'RedHat') {
        yumrepo { 'percona':
          name     => 'Percona-Repository',
          descr    => 'Percona Repository',
          gpgkey   => 'http://www.percona.com/downloads/RPM-GPG-KEY-percona',
          gpgcheck => '1',
          baseurl  => 'http://repo.percona.com/centos/$releasever/os/$basearch/',
          enabled  => '1',
        }
      } else {
        fail('Repository addition not supported for your distro')
      }
  }

  if ($install_20) {
    ensure_packages(['percona-xtrabackup-20'])
  }
  else {
    ensure_packages(['percona-xtrabackup'])
  }

  file { '/usr/local/bin/mysql-backup':
    owner   => 'root',
    group   => 'root',
    mode    => '0700',
    content => template('xtrabackup/backupscript.sh.erb')
  }

  file { '/usr/local/bin/mysql-backup-restore':
    owner   => 'root',
    group   => 'root',
    mode    => '0700',
    content => template('xtrabackup/restorescript.sh.erb')
  }

  if $cronjob {
    if ( !$hour or !$minute ) {
      fail('Hour and minute parameters are mandatory when cronjob is true.')
    }
    if $silentcron {
        $command_add = ' silent'
    } else {
        $command_add = ''
    }
    cron { 'xtrabackup':
      command => "/usr/local/bin/mysql-backup${command_add}",
      hour    => $hour,
      minute  => $minute,
    }
  }
}
