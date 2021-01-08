#! /usr/bin/perl -w

use strict ;

# if Mirmon.pm lives in directory DIR,
# change . to DIR in the next line :
use lib '.' ; # Mirmon.pm lives here

use Mirmon ;

use IO::Pipe ;
use IO::Select ;
use Net::hostent ;

my $VERSION = Base::Version . ' - Sat Jul 23 09:12:31 2016 - henkp' ;
my $DEF_CNF = join ', ', Mirmon -> config_list ;
my $TIMEOUT = Base::DEF_TIMEOUT ;

my $prog = substr $0, rindex ( $0, '/' ) + 1 ;
my $Usage = <<USAGE ;
Usage: $prog [-v] [-q] [-t timeout] [-c conf] [-get all|update|url <url>]
option v   : be verbose
option q   : be quiet
option t   : set timeout ; default $TIMEOUT
option get : get all       : probe all sites
           : get update    : probe a selection of the sites (see doc)
           : get url <url> : probe some <url> (in the mirror-list).
option c   : configuration file ; default search :
             ( $DEF_CNF )
-------------------------------------------------------------------
Mirmon normally only reports errors and changes in the mirror list.
This is $VERSION.
-------------------------------------------------------------------
USAGE
sub Usage { die "$_[0]$Usage" ; }
sub Error { die "$prog: $_[0]\n" ; }
sub Warn  { warn "$prog: $_[0]\n" ; }

# usage: &GetOptions(ARG,ARG,..) defines $opt_ID as 1 or user spec'ed value
# usage: &GetOptions(\%opt,ARG,ARG,..) defines $opt{ID} as 1 or user value
# ARG = 'ID' | 'ID=SPC' | 'ID:SPC' for no-arg, required-arg or optional-arg
# ID  = perl identifier
# SPC = i|f|s for integer, fixedpoint real or string argument

use Getopt::Long ;
Getopt::Long::config ( 'no_ignore_case' ) ;
my %opt = () ;
Usage '' unless GetOptions ( \%opt, qw(v q t=i get=s c=s version) ) ;
Usage "Arg count\n" if @ARGV > 1 ;
Usage "Arg count\n" if $opt{get} and $opt{get} eq 'url' and ! @ARGV ;

if ( $opt{version} ) { printf "%s\n", Base::version () ; exit ; }

$opt{v} ||= $opt{d} ;

my $URL = shift ;

my $M = Mirmon -> new ( $opt{c} ) ;
$M -> conf -> timeout ( $opt{t} ) if $opt{t} ;

my $get = $opt{get} ;
if ( $get )
  { Error "url $URL not in list"
      if $get eq 'url' and ! $M -> state -> { $URL } ;
    Error "unknown 'get option' '$get'" unless Base::is_get_opt ( $get ) ;
  }

Mirmon::verbose ( $opt{v} ) ;
Mirmon::debug   ( $opt{d} ) ;
Mirmon::quiet   ( $opt{q} ) ;

if ( $get ) { $M -> get_dates ( $get, $URL ) ; $M -> put_state ; }
$M -> gen_page ( $get, $VERSION ) ;

__END__

=pod

=head1 NAME

mirmon - monitor the state of mirrors

=head1 SYNOPSIS

  mirmon [-v] [-q] [-t timeout] [-c conf] [-get all|update|url url]

=head1 OPTIONS

=over 4

=item B<-v>

Be verbose ; B<mirmon> normally only reports
errors and changes in the mirror list.

=item B<-q>

Be quiet.

=item B<-t> I<timeout>

Set the timeout ; the default is I<300>.

=item B<-get> all | update | url <url>

With B<all>, probe all sites.
With B<update>, probe a selection of the sites ; see option C<max_poll> below.
With B<url>, probe only the given I<url>, which must appear in the mirror-list.

=item B<-c> I<name>

Use config file I<name>. The default list is

  ./mirmon.conf $HOME/.mirmon.conf /etc/mirmon.conf

=back

=head1 USAGE

The program is intended to be run by cron every hour.

  42 * * * * perl /path/to/mirmon -get update

It quietly probes a subset of the sites in a given list,
writes the results in the 'state' file and generates a web page
with the results. The subset contains the sites that are new, bad
and/or not probed for a specified time.

When no 'get' option is specified, the program just generates a
new web page from the last known state.

The program checks the mirrors by running a (user specified)
program on a pipe. A (user specified) number of probes is
run in parallel using nonblocking IO. When something can be
read from the pipe, it switches the pipe to blocking IO and
reads one line from the pipe. Then it flushes and closes the
pipe. No attempt is made to kill the probe.

The probe should return something that looks like

  1043625600 ...

that is, a line of text starting with a timestamp. The exit status
of the probe is ignored.

=head1 CONFIG FILE

=head2 location

A config file can be specified with the -c option.
If -c is not used, the program looks for a config file in

=over

=item * B<./mirmon.conf>

=item * B<$HOME/.mirmon.conf>

=item * B</etc/mirmon.conf>

=back

=head2 syntax

A config file looks like this :

  +--------------------------------------------------
  |# lines that start with '#' are comment
  |# blank lines are ignored too
  |# tabs are replaced by a space
  |
  |# the config entries are 'key' and 'value' pairs
  |# a 'key' begins in column 1
  |# the 'value' is the rest of the line
  |somekey  A_val B_val ...
  |otherkey X_val Y_val ...
  |
  |# indented lines are glued
  |# the next three lines mean 'somekey part1 part2 part3'
  |somekey part1
  |  part2
  |  part3
  |
  |# lines starting with a '+' are concatenated
  |# the next three lines mean 'somekey part1part2part3'
  |somekey part1
  |+ part2
  |+ part3
  |
  |# lines starting with a '.' are glued too
  |# don't use a '.' on a line by itself
  |# 'somekey' gets the value "part1\n part2\n part3"
  |somekey part1
  |. part2
  |. part3
  +--------------------------------------------------

=head2 required entries

=over 4

=item project_name I<name>

Specify a short plaintext name for the project.

  project_name Apache
  project_name CTAN

=item project_url I<url>

Specify an url pointing to the 'home' of the project.

  project_url http://www.apache.org/

=item mirror_list I<file-name>

Specify the file containing the mirrors to probe.

  mirror_list /path/to/mirror-list

If your mirror list is generated by a program, use

  mirror_list /path/to/program arg1 ... |

Two formats are supported :

=over

=item * plain : lines like

  us http://www.tux.org/ [email] ...
  nl http://apache.cs.uu.nl/dist/ [email] ...
  nl rsync://archive.cs.uu.nl/apache-dist/ [email] ...

=item * apache : lines like those in the apache mirrors.list

  ftp  us ftp://ftp.tux.org/pub/net/apache/dist/ user@tux.org ...
  http nl http://apache.cs.uu.nl/dist/ user@cs.uu.nl ...

=back

Note that in style 'plain' the third item is reserved for an
optional email address : the site's contact address.

Specify the required format with option C<list_style> (see below).
The default style is 'plain'.

=item web_page I<file-name>

Specify where the html report page is written.

=item icons I<directory-name>

Specify the directory where the icons can be found,
relative to the I<web_page>, or relative to the
DOCUMENTROOT of the web server.

If/when the I<web_page> lives in directory C<.../mirmon/> and
the icons live in directory C<.../mirmon/icons/>,
specify

  icons icons

If/when the icons live in C</path/to/DOCUMENTROOT/icons/mirmon/>, specify

  icons /icons/mirmon

=item probe I<program + arguments>

Specify the program+args to probe the mirrors. Example:

  probe /usr/bin/wget -q -O - -T %TIMEOUT% -t 1 %URL%TIME.txt

Before the program is started, %TIMEOUT% and %URL% are
substituted with the proper timeout and url values.

Here it is assumed that each hour the root server writes
a timestamp in /path/to/archive/TIME.txt, for instance with
a crontab entry like

  42 * * * * perl -e 'print time, "\n"' > /path/to/archive/TIME.txt

Mirmon reads one line of output from the probe and interprets
the first word on that line as a timestamp ; for example :

  1043625600
  1043625600 Mon Jan 27 00:00:00 2003
  1043625600 www.apache.org Mon Jan 27 00:00:00 2003

Mirmon is distributed with a program C<probe> that handles
ftp, http and rsync urls.

=item state I<file-name>

Specify where the file containing the state is written.

The program reads this file on startup and writes the
file when mirrors are probed (-get is specified).

=item countries I<file-name>

Specify the file containing the country codes;
The file should contain lines like

  us - United States
  nl - Netherlands

The mirmon package contains a recent ISO list.

I<Fake> domains like I<Backup>, I<Master> are allowed,
and are listed first in the report ; lowercase-first
fake domains (like I<backup>) are listed last.

=back

=head2 optional entries

=over 4

=item max_probes I<number>

Optionally specify the number of parallel probes (default 25).

=item timeout I<seconds>

Optionally specify the timeout for the probes (default 300).

After the last probe is started, the program waits for
<timeout> + 10 seconds, cleans up and exits.

=item project_logo I<logo>

Optionally specify (the SRC of the IMG of) a logo to be placed
top right on the page.

  project_logo /icons/apache.gif
  project_logo http://www.apache.org/icons/...

=item htm_head I<html>

Optionally specify some HTML to be placed before </HEAD>.

  htm_head
    <link REL=StyleSheet HREF="/style.css" TYPE="text/css">

=item htm_top I<html>

Optionally specify some HTML to be placed near the top of the page.

  htm_top testing 1, 2, 3

=item htm_foot I<html>

Optionally specify HTML to be placed near the bottom of the page.

  htm_foot
    <HR>
    <A HREF="..."><IMG SRC="..." BORDER=0></A>
    <HR>

=item put_histo top|bottom|nowhere

Optionally specify where the age histogram must be placed.
The default is 'top'.

=item min_poll I<time-spec>

For 'min_poll' see next item. A I<time-spec> is a number followed by
a unit 's' (seconds), or 'm' (minutes), or 'h' (hours), or 'd' (days).
For example '3d' (three days) or '36h' (36 hours).

=item max_poll I<time-spec>

Optionally specify the maximum probe interval. When the program is
called with option '-get update', all sites are probed which are :

=over 4

=item * new

the site appears in the list, but there is no known state

=item * bad

the last probe of the site was unsuccessful

=item * old

the last probe was more than 'max_poll' ago.

=back

Sites are not probed if the last probe was less than 'min_poll' ago.
So, if you specify

  min_poll 4h
  max_poll 12h

the 'reachable' sites are probed twice daily and the 'unreachable'
sites are probed at most six times a day.

The default 'min_poll' is '1h' (1 hour).
The default 'max_poll' is '4h' (4 hours).

=item min_sync I<time-spec>

Optionally specify how often the mirrors are required to make an update.

The default 'min_sync' is '1d' (1 day).

=item max_sync I<time-spec>

Optionally specify the maximum allowable sync interval.

Sites exceeding the limit will be considered 'old'.
The default 'max_sync' is '2d' (2 days).

=item always_get I<region ...>

Optionally specify a list of regions that must be probed always.

  always_get Master Tier1

This is intended for I<fake regions> like I<Master> etc.

=item no_randomize

Mirmon tries to balance the probe load over the hourly mirmon runs.
If the current run has a below average number of mirrors to probe,
mirmon probes a few extra, randomly chosen mirrors, picked from the
runs that have the highest load.

If you don't want this behaviour, use B<no_randomize>.

=item no_add_slash

If the url part of a line in the mirror_list doesn't end
in a slash ('/'), mirmon adds a slash and issues a warning
unless it is in quiet mode.

If you don't want this behaviour, use B<no_add_slash>.

=item list_style plain|apache

Optionally specify the format ('plain' or 'apache') of the mirror-list.

See the description of 'mirror_list' above.
The default list_style is 'plain'.

=item site_url I<site> I<url>

Optionally specify a substitute url for a site.

When access to a site is restricted (in Australia, for instance),
another (sometimes secret) url can be used to probe the site.
The <site> of an url is the part between '://' and the first '/'.

=item env I<key> I<value>

Optionally specify an environment variable.

=item include I<file-name>

Optionally specify a file to include.

The specified file is processed 'in situ'. After the specified file is
read and processed, config processing is resumed in the file where the
C<include> was encountered.
The include depth is unlimited. However, it is a fatal error to
include a file twice under the same name.

=item show

When the config processor encounters the 'show' command, it
dumps the content of the current config to standout, if option
C<-v> is specified. This is intented for debugging.

=item exit

When the config processor encounters the 'exit' command, it
terminates the program. This is intented for debugging.

=back

=head1 STATE FILE FORMAT

The state file consists of lines; one line per site.
Each line consists of white space separated fields.
The seven fields are :

=over 4

=item * field 1 : url

The url as given in the mirror list.

=item * field 2 : age

The mirror's timestamp found by the last successful probe,
or 'undef' if no probe was ever successful.

=item * field 3 : status last probe

The status of the last probe, or 'undef' if the mirror was never probed.

=item * field 4 : time last successful probe

The timestamp of the last successful probe or 'undef'
if the mirror was never successfully probed.

=item * field 5 : probe history

The probe history is a list of 's' (for success) and 'f' (for failure)
characters indicating the result of the probe. New results are appended
whenever the mirror is probed.

=item * field 6 : state history

The state history consists of a timestamp, a '-' char, and a list of
chars indicating a past status: 's' (fresh), 'b' (oldish), 'f' (old),
'z' (bad) or 'x' (skip).
The timestamp indicates when the state history was last updated.
The current status of the mirror is determined by the mirror's age and
a few configuration parameters (min_sync, max_sync, max_poll).
The state history is updated when the mirror is probed.
If the last update of the history was less than 24 hours ago,
the last status is replaced by the current status.
If the last update of the history was more than 24 hours ago,
the current status is appended to the history.
One or more 'skip's is inserted, if the timestamp is two or more days old
(when mirmon hasn't run for more than two days).

=item * field 7 : last probe

The timestamp of the last probe, or 'undef' if the mirror was never probed.

=back

=head1 INSTALLATION

=head2 general

=over 4

=item * Note: The (empty) state file must exist before mirmon runs.

=item * The mirmon repository is here :

  https://svn.science.uu.nl/repos/project.mirmon/trunk/

=item * The mirmon tarball is here :

  http://www.staff.science.uu.nl/~penni101/mirmon/mirmon.tar.gz

=back

=head2 installation suggestions

To install and configure mirmon, take the following steps :

=over 2

=item * First, make the webdir :

  cd DOCUMENTROOT
  mkdir mirmon

For I<DOCUMENTROOT>, substitute the full pathname
of the document root of your webserver.

=item * Check out the mirmon repository :

  cd /usr/local/src
  svn checkout REPO mirmon

where

  REPO = https://svn.science.uu.nl/repos/project.mirmon/trunk/

or download the package and unpack it.

=item * Chdir to directory mirmon :

  cd mirmon

=item * Create the (empty) state file :

  touch state.txt

=item * Install the icons in the webdir :

  mkdir DOCUMENTROOT/mirmon/icons
  cp icons/* DOCUMENTROOT/mirmon/icons

=item * Create a mirror list C<mirror_list> ;

Use your favorite editor, or genererate the list from an
existing database.

  nl http://archive.cs.uu.nl/your-project/ contact@cs.uu.nl
  uk http://mirrors.this.org/your-project/ mirrors@this.org
  us http://mirrors.that.org/your-project/ mirrors@that.org

The email addresses are optional.

=item * Create a mirmon config file C<mirmon.conf> with your favorite editor.

  # lines must start in the first column ; no leading white space
  project_name ....
  project_url  ....
  mirror_list mirror_list
  state state.txt
  countries countries.list
  web_page DOCUMENTROOT/mirmon/index.html
  icons /mirmon/icons
  probe /usr/bin/wget -q -O - -T %TIMEOUT% -t 1 %URL%TIME.txt

This assumes the project's timestamp is in file C<TIME.txt>.

=item * If you have rsync urls, change the probe line to :

  probe perl /usr/local/src/mirmon/probe -t %TIMEOUT% %URL%TIME.txt

=item * Run mirmon :

  perl mirmon -v -get all

The mirmon report should now be in 'DOCUMENTROOT/mirmon/index.html'

  http://www.your.project.org/mirmon/

=item * If/when, at a later date, you want to upgrade mirmon :

  cd /usr/local/src/mirmon
  svn status -u
  svn up

=back

=head1 SEE ALSO

=begin html

<p>
<a href="mirmon.pm.html">mirmon.pm(3)</a>
</p>

=end html

=begin man

mirmon.pm(3)

=end man

=head1 AUTHOR

=begin html

  <p>
  &copy; 2003-2016
  <a href="http://www.staff.science.uu.nl/~penni101/">Henk P. Penning</a>,
  <a href="http://www.uu.nl/faculty/science/EN/">Faculty of Science</a>,
  <a href="http://www.uu.nl/">Utrecht University</a>
  <br />
  mirmon-2.11 - Sat Jul 23 09:12:31 2016 ; henkp ;
  <a href="http://validator.w3.org/check?uri=referer">verify html</a>
  </p>

=end html

=begin man

  (c) 2003-2016 Henk P. Penning
  Faculty of Science, Utrecht University
  http://www.staff.science.uu.nl/~penni101/ -- penning@uu.nl
  mirmon-2.11 - Sat Jul 23 09:12:31 2016 ; henkp

=end man

=begin text

  (c) 2003-2016 Henk P. Penning
  Faculty of Science, Utrecht University
  http://www.staff.science.uu.nl/~penni101/ -- penning@uu.nl
  mirmon-2.11 - Sat Jul 23 09:12:31 2016 ; henkp

=end text

=cut
