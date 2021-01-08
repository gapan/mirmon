#! /usr/bin/perl -w

# Copyright (c) 2003-2016 Henk Penning, all rights reserved.
# penning@uu.nl, http://www.staff.science.uu.nl/~penni101/
# Version 1.1 was donated to the Apache Software Foundation 2003 Jan 28.
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.
#
# Thanks to Klaus Heinz <heinz@NetBSD.org> for sugestions ao htm_head ;
# Peter Pöml for MirrorBrain support ; Jeremy Olexa, Karl Berry, Roland
# Pelzer for suggestions regarding rsync support.

use strict ;

our $PRG = 'mirmon' ;
our $VER = "2.11" ;

our $DEF_TIMEOUT = 300 ;
our $HIST        = 14 ;
our $TIM_PAT     = '^(\d+)([smhd])$' ;
our %APA_TYPES   = () ; $APA_TYPES { $_ } ++ for qw(backup ftp http rsync) ;
our %GET_OPTS    = () ; $GET_OPTS  { $_ } ++ for qw(all update url) ;
our $HIST_DELTA  = 24 * 60 * 60 ;
our $APRX_DELTA  = 300 ;
our $HOME        = 'http://www.staff.science.uu.nl/~penni101/mirmon/' ;

package Base ; #####################################################

use base 'Exporter' ;

our ( @ISA, @EXPORT ) ;
BEGIN
  { @ISA = qw(Exporter) ;
    @EXPORT =
      qw(aprx_eq aprx_ge aprx_le aprx_gt aprx_lt
         URL NAM SMA BLD NSS TAB BQ TR TH TD TDr RED GRN H1 H2 H3
         s4tim pr_interval pr_diff
        ) ;
  }

sub Version { "$PRG version $VER" ; }
sub version { "$PRG-$VER" ; }
sub DEF_TIMEOUT { $DEF_TIMEOUT ; }
sub is_get_opt  { my $opt = shift ; exists $GET_OPTS { $opt } ; }

sub getset
  { my $self = shift ;
    my $attr = shift ;
    if ( @_ ) { $self -> { $attr } = shift ; }
    die "no attr '$attr'" unless exists $self -> { $attr } ;
    $self -> { $attr } ;
  }

sub mk_method
  { my $self = shift ;
    my $attr = shift ;
    sprintf 'sub %s { my $self = shift ; $self -> getset ( "%s",  @_ ) ; }'
      , $attr, $attr ;
  }

sub mk_methods
  { my $self = shift ;
    join "\n", map { Base -> mk_method ( $_ ) ; } @_ ;
  }

sub aprx_eq { my ( $t1, $t2 ) = @_ ; abs ( $t1 - $t2 ) < $APRX_DELTA ; }
sub aprx_ge { my ( $t1, $t2 ) = @_ ; $t1 > $t2 or      aprx_eq $t1, $t2 ; }
sub aprx_le { my ( $t1, $t2 ) = @_ ; $t1 < $t2 or      aprx_eq $t1, $t2 ; }
sub aprx_gt { my ( $t1, $t2 ) = @_ ; $t1 > $t2 and not aprx_eq $t1, $t2 ; }
sub aprx_lt { my ( $t1, $t2 ) = @_ ; $t1 < $t2 and not aprx_eq $t1, $t2 ; }

sub URL { sprintf '<A HREF="%s">%s</A>', $_[0], $_[1] ; }
sub NAM { sprintf '<A NAME="%s">%s</A>', $_[0], $_[1] ; }
sub SMA { sprintf "<FONT SIZE=\"-1\">%s</FONT>", $_[0] ; }
sub BLD { sprintf "<B>%s</B>", $_[0] ; }
sub NSS { sprintf SMA('%s&nbsp;site%s'), $_[0], ( $_[0] == 1 ? '' : 's' ) ; }
sub TAB { sprintf "<TABLE BORDER=2 CELLPADDING=3>%s</TABLE>", $_[0] ; }
sub BQ  { sprintf "<BLOCKQUOTE>\n%s\n</BLOCKQUOTE>\n", $_[0] ; }
sub TR  { sprintf "<TR>%s</TR>\n", $_[0] ; }
sub TH  { sprintf "<TH>%s</TH>\n", $_[0] ; }
sub TD  { sprintf "<TD>%s</TD>\n", $_[0] ; }
sub H1  { sprintf "<H1>%s</H1>\n", $_[0] ; }
sub H2  { sprintf "<H2>%s</H2>\n", $_[0] ; }
sub H3  { sprintf "<H3>%s</H3>\n", $_[0] ; }
sub TDr { sprintf "<TD ALIGN=\"RIGHT\">%s</TD>\n", $_[0] ; }
sub RED { sprintf "<FONT COLOR=\"RED\">%s</FONT>", $_[0] ; }
sub GRN { sprintf '<FONT COLOR="GREEN">%s</FONT>', $_[0] ; }

sub s4tim
  { my $tim = shift ;
    my %tab = ( 's' => 1, 'm' => 60, 'h' => 60 * 60, 'd' => 60 * 60 * 24 ) ;
    die "wrong time '$tim'" unless $tim =~ /$TIM_PAT/o ;
    my $m = $1 ; my $u = $2 ;
    return $m * $tab { $u } ;
  }

sub pr_interval
  { my $s = shift ;
    my ( $magn, $unit ) ;
    my $mins  = $s / 60          ; my $m = int ( $mins + 0.5 ) ;
    my $hours = $s / ( 60 * 60 ) ; my $h = int ( $hours + 0.5 ) ;

    if ( $s < 50 )
      { $magn = $s ; $unit = 'second' ; }
    elsif ( $m < 50 )
      { $magn = $m ; $unit = 'minute' ; }
    elsif ( $h < 36 )
      { $magn = $h ; $unit = 'hour' ; }
    else
      { $magn = sprintf "%.1f", $hours / 24 ; $unit = 'day' ; }

    $unit .= 's' unless $magn == 1 ;

    return "$magn $unit" ;
  }

sub pr_diff
  { my $time = shift ;
    my $max  = shift ;
    my $res ;

    if ( $time == $^T )
      { $res = BLD 'renewed' ; }
    else
      { $res = pr_interval $^T - $time ;
        $res = BLD RED $res if aprx_lt $time, $max ;
      }
    return $res ;
  }

sub exp_date
  { my @day = qw(Sun Mon Tue Wed Thu Fri Sat) ;
    my @mon = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec) ;
    my @gmt = gmtime time + 3600 ;
    sprintf "%s, %02d %s %4d %02d:%02d:%02d GMT"
      , $day [ $gmt [ 6 ] ]
      , $gmt [ 3 ]
      , $mon [ $gmt [ 4 ] ]
      , $gmt [ 5 ] + 1900
      , @gmt [ 2, 1, 0 ]
      ;
  }

sub htmlquote
  { my $x = shift ;
    $x =~ s/&/&amp;/g ;
    $x =~ s/</&lt;/g ;
    $x =~ s/>/&gt;/g ;
    return $x ;
  }

package Mirmon ; ###################################################

BEGIN { use base 'Base' ; Base -> import () ; }

use IO::Select ;
use Net::hostent ;

  { my %opt = ( v => 0 , d => 0 , q => 0 ) ;
    sub _opt
      { my ( $key, $val ) = @_ ;
        my $res ;
        unless ( exists $opt { $key } )
          { warn "unknown Mirmon option '$key'\n" ; }
        else
          { $res = $opt { $key } ;
            $opt { $key } = $val if defined $val ;
          }
        $res ;
      }
  }

sub verbose { _opt ( 'v', shift ) ; }
sub quiet   { _opt ( 'q', shift ) ; }
sub debug   { _opt ( 'd', shift ) ; }

eval Base -> mk_methods ( qw(conf state regions) ) ;

sub config_list
  { my $self = shift ;
    my $home = ( getpwuid $< ) [ 7 ] or die "can get homedir '$<' ($!)" ;
    ( 'mirmon.conf', "$home/.mirmon.conf", '/etc/mirmon.conf' ) ;
  }

sub new
  { my $self = shift ;
    my $path = shift ;
    my $res  = bless {}, $self ;
    $res -> get_config ( $path ) ;
    $res -> get_state ;
    $res -> get_regions ;
    $res ;
  }

sub find_config
  { my $self = shift ;
    my $arg = shift ;
    my @LIST = $arg ? ( $arg ) : Mirmon -> config_list ;
    for my $conf ( @LIST ) { return $conf if -r $conf and ! -d $conf ; }
    die sprintf "can't find a config file :\n  %s\n" , join "\n  ", @LIST ;
  }

sub get_config
  { my $self = shift ;
    my $path = shift ;
    my $file = $self -> find_config ( $path ) ; # or die
    $self -> conf ( Mirmon::Conf -> new ( $file ) ) ;
  }

sub get_state
  { my $self = shift ;
    my $conf = $self -> conf ;
    my $name = $conf -> project_name ;
    my $state = $conf -> state ;
    my $res = {} ;
    open STATE, $state or die "can't open $state ($!)" ;
    for my $line ( <STATE> )
      { chop $line ;
        my $mirror = Mirmon::Mirror -> new ( $self, $line ) ;
        $res -> { $mirror -> url } = $mirror ;
      }
    close STATE ;

    my $mlist = $conf -> mirror_list ;
    my $style = $conf -> list_style ;
    my %in_list = () ;
    my $changes = '' ;
    open MLIST, $mlist or die "can't open $mlist ($!)" ;
    for my $line ( <MLIST> )
      { chop $line ;
        next if $line =~ /^#/ ;
        next if $line =~ /^\s*$/ ;
        my ( $reg, $url, $mail ) ;
        if ( $style eq 'plain' )
          { ( $reg, $url, $mail ) = split ' ', $line ; }
        elsif ( $style eq 'apache' )
          { my $apache_type ;
            ( $apache_type, $reg, $url, $mail ) = split ' ', $line ;
            unless (  defined $APA_TYPES { $apache_type } )
              { print "*** strange type in $url ($apache_type)\n"
                  unless Mirmon::quiet ;
                next ;
              }
          }

        if ( $conf -> add_slash and $url !~ m!/$! )
          { print "*** appended '/' to $url\n" unless Mirmon::quiet ;
            $url .= '/' ;
          }

        $in_list { $url } ++ ;

        unless ( exists $res -> { $url } )
          { $changes .= sprintf "added %s\n", $url unless Mirmon::quiet ;
            $res -> { $url } = Mirmon::Mirror -> init ( $self, $url ) ;
          }
        my $mirror = $res -> { $url } ;
        $mirror -> region ( $reg ) ;
        $mirror -> mail ( $mail || '' ) ;
      }
    close MLIST ;

    for my $url ( sort keys %$res )
      { # printf "%s\n", $res -> { $url } -> state ;
        unless ( exists $in_list { $url } )
          { $changes .= sprintf "removed %s\n", $url unless Mirmon::quiet ;
            delete $res -> { $url } ;
          }
      }
    printf "changes in mirror-list for '%s':\n%s", $name, $changes
      if $changes ;
    $self -> state ( $res ) ;
  }

sub put_state
  { my $self  = shift ;
    my $state = $self -> state ;
    my $file  = $self -> conf -> state ;
    my $TMP = "$file.tmp" ;
    open TMP, ">$TMP" or die "can't write '$TMP' ($!)" ;
    for my $url ( sort keys %$state )
      { printf TMP "%s\n", $state -> { $url } -> state
          or die "can't print $url to $TMP ($!)" ;
      }
    close TMP ;

    if ( -z $TMP )
      { warn "wrote empty state file; keeping previous version" ; }
    else
      { rename $TMP, $file or die "can't rename '$TMP', '$file' ($!)" ; }
  }

sub get_regions
  { my $self = shift ;
    my $file =  $self -> conf -> countries ;
    open REGS, $file or die "can't open countries '$file' ($!)" ;
    while ( <REGS> )
      { chop ;
        next if /^#/ ;
        my ( $code, $dash, $reg ) = split ' ', $_, 3 ;
        $self -> { regions } { lc $code } = $reg ;
      }
    close REGS ;
  }

sub _cmp_ccs
  { my $ccs = shift ;
    my $x  = shift ;
    my $y  = shift ;
    my $xx = $ccs -> { $x } ;
    my $yy = $ccs -> { $y } ;
    if ( ! defined $xx and ! defined $yy )
      { $x cmp $y ; }
    elsif ( ! defined $xx )
      { -1 ; }
    elsif ( ! defined $yy )
      { +1 ; }
    else
      { $xx cmp $yy ; }
  }

sub _pr_round
  { my $x = shift ;
    my $i = int $x ;
    my $f = $x - $i ;
    $i + ( rand 1 < $f ? 1 : 0 ) ;
  }

sub _diag_qs
  { my $qs = shift ;
    join ', ', map { sprintf "%s %s" , $_, scalar @{ $qs -> { $_ } } ; }
      sort keys %$qs ;
  }

sub _rpick
  { my $row = shift ;
    die "_rpick : row empty" unless @$row ;
    my $idx = int rand @$row ;
    my $res = $row -> [ $idx ] ;
    $row -> [ $idx ] = $row -> [ $#{$row} ] ;
    pop @$row ;
    $res ;
  }

sub _buck_split
  { my $que = shift ;
    my $tmp = [] ;
    for my $mirr ( @$que )
      { my $lp = $mirr -> last_probe ;
        my $hr = int ( ( $^T - $lp ) / 60 / 60 + 0.5 ) ;
        push @{ $tmp -> [ $hr ] }, $mirr ;
      }
    [ grep defined $_, @$tmp ] ;
  }

sub _buck_join
  { my $bucks = shift ;
    my $res = [] ;
    push @$res, @$_ for @$bucks ;
    $res ;
  }

sub _buck_pick
  { my $bucks = shift ;
    die "buck_pick : bucks empty" unless @$bucks ;
    my $buck = ( sort { @$b <=> @$a } @$bucks ) [ 0 ] ;
    _rpick $buck ;
  }

sub _randomize
  { my $ques = shift ;
    my $poll = shift ;
    my $hrs  = int ( $poll / 60 / 60 + 0.5 ) ;

    my $diag1 = _diag_qs $ques ;

    my $todos = $ques -> { todo } ;
    my $dones = $ques -> { done } ;
    my $cnt   = @$todos + @$dones ;
    my $avg   = $hrs ? $cnt / $hrs : 0 ;
    my $iavg  = _pr_round $avg ;
    my $pick  = 0 ;
    my $bucks = _buck_split $dones ;

    while ( @$todos < $iavg and $pick < @$dones )
      { push @$todos, _buck_pick $bucks ;
        $pick ++ ;
      }

    $ques -> { done } = _buck_join $bucks ;

    sprintf ''
      . "  hrs %s, %s\n"
      . "  avg %.2f -> %d , picked %d ; queued %s\n"
      . "  hrs %s, %s\n"
      , $hrs, $diag1
      , $avg, $iavg, $pick, scalar @$todos
      , $hrs, _diag_qs ( $ques )
      ;
  }

sub get_dates
  { my $self  = shift ;
    my $get   = shift ;
    my $URL   = shift ;
    my $state = $self -> state ;
    my $conf  = $self -> conf ;
    my $CMD   = $conf -> probe ;
    my $PAR   = $conf -> max_probes ;
    my %m4h   = () ;
    my @QUE   = () ;
    my $GET   = IO::Select -> new () ;
    my $ques  = {} ;
    for my $col ( qw(new red grn xtr) )
      { $ques -> { $col } { $_ } = [] for qw(done todo) ; }
    my $max_poll = s4tim $conf -> max_poll ;
    my $min_poll = s4tim $conf -> min_poll ;

    if ( Mirmon::verbose ) { printf "mirrors %d\n", scalar keys %$state ; }

    if ( $get eq 'all' )
      { @QUE = sort { $a -> url cmp $b -> url } values %$state ; }
    elsif ( $get eq 'url' )
      { @QUE = ( $state -> { $URL } ) ; }
    elsif ( $get eq 'update' )
      { my $maxp = $^T - $max_poll ;
        my $minp = $^T - $min_poll ;

if ( Mirmon::verbose )
  { printf "max_poll %s\n", scalar localtime $maxp ;
    printf "min_poll %s\n", scalar localtime $minp ;
  }
        for my $url ( sort keys %$state )
          { my $mirror = $state -> { $url } ;
            my $stat = $mirror -> last_status ;
            my $vrfy = $mirror -> last_ok_probe ;
            my $lprb = $mirror -> last_probe ;
            my $col ;
            my $que ;
            if ( $stat eq 'undef' ) # never probed ; new mirror ; todo
              { $col = 'new' ; $que = 'todo' ; }
            elsif ( $conf -> get_xtr ( $mirror -> region ) )
              { $col = 'xtr' ; $que = 'todo' ; }
            else
              { my $poll = $stat eq 'ok' ? $maxp : $minp ;
                $col     = $stat eq 'ok' ? 'grn' : 'red' ;
                $que     = ( aprx_le $lprb, $poll ) ? 'todo' : 'done' ;
              }
            push @{ $ques -> { $col } { $que } }, $mirror ;
          }

        if ( $conf -> randomize )
          { my $msg = "randomize green\n" ;
            $msg .= _randomize $ques -> { grn }, $max_poll ;
            $msg .= "randomize red\n" ;
            $msg .= _randomize $ques -> { red }, $min_poll ;
            print $msg if Mirmon::verbose ;
          }
        @QUE =
          ( @{ $ques -> { new } { todo } }
          , @{ $ques -> { red } { todo } }
          , @{ $ques -> { grn } { todo } }
          , @{ $ques -> { xtr } { todo } }
          ) ;
      }
    else
      { die "unknown opt_get '$get'" ; }

    if ( Mirmon::verbose ) { printf "queued %d\n\n", scalar @QUE ; }

    while ( @QUE )
      { my $started = 0 ;
        while ( $GET -> count () < $PAR and @QUE )
          { my $mirror = shift @QUE ;
            if ( gethost $mirror -> site )
              { my $handle = $mirror -> start_probe ;
                $m4h { $handle } = $mirror ;
                $GET -> add ( $handle ) ;
                $started ++ ;
              }
            else
              { $mirror -> update ( 0, 'site_not_found', undef ) ; }
          }

        my @can_read = $GET -> can_read ( 0 ) ;

        printf "queue %d, started %d, probes %d, can_read %d\n",
          scalar @QUE, $started, $GET -> count (), scalar @can_read
            if Mirmon::verbose ;

        for my $handle ( @can_read )
          { # order is important ; wget's hang if/when actions are reversed
            $GET -> remove ( $handle ) ;
            $m4h { $handle } -> finish_probe ( $handle ) ;
          }

        sleep 1 ;
      }

    my $stop = time + $conf -> timeout + 10 ;

    while ( $GET -> count () and time < $stop )
      { my @can_read = $GET -> can_read ( 0 ) ;

        printf "wait %2d, probes %d, can_read %d\n",
          $stop - scalar time, $GET -> count (), scalar @can_read
            if Mirmon::verbose ;

        for my $handle ( @can_read )
          { $GET -> remove ( $handle ) ;
            $m4h { $handle } -> finish_probe ( $handle ) ;
          }

        sleep 10 ;
      }

    for my $handle ( $GET -> handles () )
      { $m4h { $handle } -> update ( 0, 'hangs', undef ) ; }
  }

sub img_sf_cnt
  { my $self = shift ;
    my $prf  = shift ;
    my $cnt  = shift ;
    my $res ;
    if ( $prf eq 'x' )
      { sprintf
          ( '<IMG BORDER=1 SRC="%s/bar.gif" ALT="">'
          , $self -> conf -> icons
          ) x $cnt ;
      }
    else
     { sprintf '<IMG BORDER=1 SRC="%s/mm%s%02d.gif" ALT="">'
         , $self -> conf -> icons, $prf, $cnt ;
     }
  }

sub img_sf { my $self = shift ; $self -> img_sf_cnt ( $_[0], 1 ) ; }

sub show_hist
  { my $self = shift ;
    my $hst = shift ;
    if ( $hst =~ /-(.*)$/ ) { $hst = $1 ; }
    return '' unless $hst =~ m/^[sbfzx]+$/ ;
    if ( length $hst == $HIST and $hst =~ /^(s*b)s*$/ )
      { return $self -> img_sf_cnt ( 'sb',  length $1 ) ; }
    elsif ( length $hst == $HIST and $hst =~ /^(s*f)s*$/ )
      { return $self -> img_sf_cnt ( 'sf',  length $1 ) ; }
    elsif ( length $hst == $HIST and $hst =~ /^(s*b)fs*$/ )
      { return $self -> img_sf_cnt ( 'sbf', length $1 ) ; }
    my $res = '' ;
    my $cnt = 1 ;
    my $prf = substr $hst, 0, 1 ;
    $hst = substr $hst, 1 ;
    while ( $hst ne '' )
      { if ( substr ( $prf, 0, 1 ) eq substr ( $hst, 0, 1 ) )
          { $cnt ++ ;
            $hst = substr $hst, 1 ;
          }
        else
          { $res .= $self -> img_sf_cnt ( $prf, $cnt ) ;
            $prf = substr $hst, 0, 1 ;
            $hst = substr $hst, 1 ;
            $cnt = 1 ;
          }
      }
    $res .= $self -> img_sf_cnt ( $prf, $cnt ) if $cnt ;
    $res ;
  }

sub gen_histogram_probes
  { my $self = shift ;
    my $state = $self -> state ;
    my %tab = () ;
    my %bad = () ;
    my $res = '' ;
    my $s_cnt = 0 ;
    my $f_cnt = 0 ;
    my $hr_min ;
    my $hr_max ;
    for my $url ( keys %$state )
      { my $mirror = $state -> { $url } ;
        my $lprb = $mirror -> last_probe ;
        my $stat = $mirror -> last_status ;
        next if $lprb eq 'undef' ;
        my $hr = int ( ( $^T - $lprb ) / 3600 + 0.5 ) ;
        $hr_min = $hr if ! defined $hr_min or $hr < $hr_min ;
        $hr_max = $hr if ! defined $hr_max or $hr > $hr_max ;
        if ( $stat eq 'ok' )
          { $tab { $hr } ++ ; $s_cnt ++ ; }
        else
          { $bad { $hr } ++ ; $f_cnt ++ ; }
      }
    return BQ 'nothing yet' unless scalar keys %tab ;

    $res = TR
      ( TH ( 'hours ago' )
      . TH ( 'succ' )
      . TH ( 'fail' )
      . TH sprintf
          ( '%s %s, %s %s'
          , $s_cnt , GRN ( 'successful' )
          , $f_cnt , RED ( 'failed' )
          )
      ) ;

    my $max = 0 ;
    for my $x ( keys %tab )
      { my $tot = $tab { $x } + ( $bad { $x } || 0 ) ;
        $max = $tot if $max < $tot ;
      }

    return BQ "nothing yet" unless $max ;

    for my $hr ( $hr_min .. $hr_max )
      { my $x = $tab { $hr } || 0 ;
        my $y = $bad { $hr } || 0 ;
        my $n = int ( $x / $max * $HIST ) ;
        my $b = int ( $y / $max * $HIST ) ;
        $res .= TR
          ( TDr ( $hr )
          . TDr ( $x )
          . TDr ( $y )
          . TD
              ( ( $n ? $self -> img_sf_cnt ( 's', $n ) : '' )
              . ( $b ? $self -> img_sf_cnt ( 'f', $b ) : '' )
              . ( ( $n + $b ) ? '' : '&nbsp;' )
              )
          ) ;
      }
    return BQ TAB $res ;
  }

sub age_avg
  { my $self = shift ;
    my $state = $self -> state ;
    my @tab = () ;
    for my $url ( keys %$state )
      { my $time = $state -> { $url } -> age ;
        push @tab, $^T - $time if $time =~ /^\d+$/ ;
      }
    my $cnt = @tab ;

    return undef if $cnt == 0 ;

    @tab = sort { $a <=> $b } @tab ;

    my $tot = 0 ;
    for my $age ( @tab ) { $tot += $age ; }
    my $mean = $tot / $cnt ;

# @tab   0  1  2  3  4  5  6  7
# $#tab -1  0  1  2  3  4  5  6
# mid    U  0  0  1  1  2  2  3
# res    U  0 0+1 1 1+2 2 2+3 3

    my $median ;
    if ( $cnt == 1 )
      { $median = $tab [ 0 ] ; }
    elsif ( $cnt % 2 ) # cnt is odd ; $#tab is even
      { my $mid = int ( $#tab / 2 + 0.5 ) ;
        $median = $tab [ $mid ] ;
      }
    else # cnt is even ; $#tab is odd
      { my $mid = int ( $#tab / 2 ) ;
        $median = ( $tab [ $mid ] + $tab [ $mid + 1 ] ) / 2 ;
      }

    if ( @tab < 2 )
      { return $mean, $median, undef ; }

    my $sum = 0 ;
    for my $age ( @tab )
      { $sum += ( $age - $mean ) ** 2 ; }
    my $stddev = sqrt ( $sum / ( $cnt - 1 ) ) ;

    return $mean, $median, $stddev ;
  }

sub legend
  { my $self = shift ;
    my $conf = $self -> conf ;
    my $min_sync = $conf -> min_sync ;
    my $max_sync = $conf -> max_sync ;
    my $min_poll = $conf -> min_poll ;
    my $max_poll = $conf -> max_poll ;

    return <<LEGENDA ;
<H3>legend</H3>

<H4><I>project</I> site -- home</H4>

<BLOCKQUOTE>
<B><I>project</I> site</B> is an url.
The <B>href</B> is the href for the site in the list of mirrors,
usually the root of the mirrored file tree.
The <B>text</B> is the <I>site</I> of that url.
<P>
<B>home</B> (represented by the <B>@</B>-symbol) is an url
pointing to the document root of the site. This pointer is
useful if the <B><I>project</I> site</B> url is invalid,
possibly because the mirror site moved the archive.
</BLOCKQUOTE>

<H4>type</H4>

<BLOCKQUOTE>
Indicates the type (<B>ftp</B> or <B>http</B>) of
the <B><I>project</I> site</B> and <B>home</B> urls.
</BLOCKQUOTE>

<H4>mirror age, daily stats</H4>

<BLOCKQUOTE>
The <B>mirror age</B> is based upon the last successful probe.
<P>
Once a day the status of a mirror site is determined.
The status (represented by a colored block) is appended
to the <B>right</B> of the status history (<I>right</I>
is <I>recent</I>). More precise, the status block is appended
if the last status block was appended 24 (or more) hours ago.
<P>The status of a mirror depends on its age and a few
configuration parameters :
<BLOCKQUOTE>
<TABLE BORDER=1 CELLPADDING=5>
<TR>
  <TH ROWSPAN=3>status</TH>
  <TH COLSPAN=4>age</TH>
</TR>
<TR>
  <TH COLSPAN=2 BGCOLOR=YELLOW>this project</TH>
  <TH COLSPAN=2 BGCOLOR=AQUA>in general</TH>
</TR>
<TR>
  <TH BGCOLOR=YELLOW>min</TH>
  <TH BGCOLOR=YELLOW>max</TH>
  <TH BGCOLOR=AQUA>min</TH>
  <TH BGCOLOR=AQUA>max</TH>
</TR>
<TR>
  <TH><FONT COLOR=GREEN>fresh</FONT></TH>
  <TD BGCOLOR=YELLOW ALIGN=CENTER>0</TD>
  <TD BGCOLOR=YELLOW ALIGN=CENTER>$min_sync + $max_poll</TD>
  <TD BGCOLOR=AQUA   ALIGN=CENTER>0</TD>
  <TD BGCOLOR=AQUA   ALIGN=CENTER>min_sync + max_poll</TD>
</TR>
<TR>
  <TH><FONT COLOR=BLUE>oldish</FONT></TH>
  <TD BGCOLOR=YELLOW ALIGN=CENTER>$min_sync + $max_poll</TD>
  <TD BGCOLOR=YELLOW ALIGN=CENTER>$max_sync + $max_poll</TD>
  <TD BGCOLOR=AQUA   ALIGN=CENTER>min_sync + max_poll</TD>
  <TD BGCOLOR=AQUA   ALIGN=CENTER>max_sync + max_poll</TD>
</TR>
<TR>
  <TH><FONT COLOR="RED">old</FONT></TH>
  <TD BGCOLOR=YELLOW ALIGN=CENTER>$max_sync + $max_poll</TD>
  <TD BGCOLOR=YELLOW ALIGN=CENTER>&infin;</TD>
  <TD BGCOLOR=AQUA   ALIGN=CENTER>max_sync + max_poll</TD>
  <TD BGCOLOR=AQUA   ALIGN=CENTER>&infin;</TD>
</TR>
<TR>
  <TH><FONT COLOR=BLACK>bad</FONT></TH>
  <TH COLSPAN=4 BGCOLOR=BLACK>
    <FONT COLOR=WHITE>the site or mirror tree was never found</FONT></TH>
</TR>
</TABLE>
</BLOCKQUOTE>
</BLOCKQUOTE>

<H4>last probe, probe stats</H4>

<BLOCKQUOTE>
<B>Last probe</B> indicates when the last successful probe was made.
<B>Probe stats</B> gives the probe history (<I>right</I> is <I>recent</I>).
A probe is either a
<FONT COLOR=GREEN><B>success</B></FONT> or a
<FONT COLOR=RED><B>failure</B></FONT>.
</BLOCKQUOTE>

<H4>last stat</H4>

<BLOCKQUOTE>
<B>Last stat</B> gives the status of the last probe.
</BLOCKQUOTE>

LEGENDA
  }

sub _ths
  { return '' unless my $ths = shift ;
    $ths == 1 ? TH '' : "<TH COLSPAN=$ths></TH>\n" ;
  }

sub gen_histogram
  { my $self  = shift ;
    my $where = shift ;
    my $conf  = $self -> conf ;
    my $state = $self -> state ;

    return '' if $where ne $conf -> put_histo ;

    my $MAX_H = $conf -> max_age1 ;
    my $MAX_h = 1 +
      ( ( 20 * 3600 <= $MAX_H and $MAX_H <= 36 * 3600 )
      ? int ( $MAX_H / 3600 )
      : 25
      ) ;
    my $MAX_O = $conf -> max_age2 ;
    my $MAX_o = int ( $MAX_O / 3600 + 0.5 ) ;
    my $H = 18 ;
    my %W   = ( 'old' => 1, 'ded' => 1, 'bad' => 1 ) ;
    my %Wmx = ( 'old' => 5, 'ded' => 3, 'bad' => 3 ) ;
    my %tab ;
    my %hst ;
    my $res ;
    for ( my $x = 0 ; $x < $MAX_h ; $x ++ ) { $tab { $x } = 0 ; }
    $tab { old } = 0 ; $tab { ded } = 0 ; $tab { bad } = 0 ;
    for my $url ( keys %$state )
      { my $time = $state -> { $url } -> age ;
        if ( $time =~ /^\d+$/ )
          { my $s  = $^T - $time ;
            my $hr = int ( $s / $MAX_H * ( $MAX_h - 1 ) + 0.5 ) ;
            if    ( $s <= $MAX_H ) { $tab { $hr  } ++ ; }
            elsif ( $s <= $MAX_O ) { $tab { old } ++ ; }
            else                   { $tab { ded } ++ ; }
          }
        else
          { $tab { bad } ++ ; }
      }
    my $max = 0 ;
    for ( grep ! exists $Wmx { $_ }, keys %tab )
      { $max = $tab { $_ } if $tab { $_ } > $max ; }

    my %bad ;

    for my $aux ( keys %Wmx )
      { $bad { $aux } = $tab { $aux } ;
        if ( $bad { $aux } > $max )
          { $W { $aux } = $Wmx { $aux } ;
            my $d = int ( $bad { $aux } / $W { $aux } ) ;
            for ( my $i = 1 ; $i < $W { $aux } ; $i++ )
              { $tab { $aux . $i } = $d ;
                if ( $bad { $aux } % $Wmx { $aux } > $i )
                  { $tab { $aux . $i } ++ ;
                    $tab { $aux } -- ;
                  }
              }
            $tab { $aux } -= ( $W { $aux } - 1 ) * $d ;
            $max = $tab { $aux } if $max < $tab { $aux } ;
          }
      }

#   if ( $opt{v} )
#     { for my $hr ( keys %tab )
#         { printf "tab '%s' = '%s'\n", $hr, $tab { $hr } ; }
#     }

    return 'nothing yet' unless $max ;
    $H = $max if 8 <= $max and $max <= 26 ;
    for ( keys %tab )
      { $hst { $_ } = int ( $H * $tab { $_ } / $max + 0.5 ) ; }
    my @keys = sort { $a <=> $b } grep /^\d+$/, keys %hst ;
    my $tab_hr = 0 ;
    for my $hr ( @keys ) { $tab_hr += $tab { $hr } ; }
    push @keys
      , grep ( m/^old/, sort keys %tab )
      , grep ( m/^ded/, sort keys %tab )
      , grep ( m/^bad/, sort keys %tab )
      ;
    my $img_bar = sprintf '<IMG SRC="%s/bar.gif" ALT="" BORDER=0>'
      , $conf -> icons ;
    my %img = ( bar => $img_bar ) ;
    for my $col ( qw(s b f z) ) { $img { $col } = $self -> img_sf ( $col ) ; }

    for ( my $h = $H ; $h > 0 ; $h -- )
      { $res .= "<TR>\n" ;
        $res .= sprintf "<TH ROWSPAN=3 VALIGN=\"TOP\">&uarr;</TH>\n"
          if $h == $H ;
        $res .= sprintf '<TD ROWSPAN=%d ALIGN="CENTER">%s</TD>' . "\n"
          , $H-6, NSS ( $max ) if $h == $H - 3 ;
        $res .= sprintf "<TH ROWSPAN=3 VALIGN=\"BOTTOM\">&darr;</TH>\n"
          if $h == 3 ;
        my $ths = 0 ;
        for my $x ( @keys )
          { my $col =
              ( ( $hst { $x } >= $h )
              ? ( $x =~ /^\d+$/
                ? 's'
                : ( $x =~ /^old/ ? 'b' : ( $x =~ /^ded/ ? 'f' : 'z' ) )
                )
              : ( ( $h == 1 and $hst { $x } == 0 ) ? 'bar' : '' )
              ) ;
            if ( $col )
              { $res .= _ths $ths ; $ths = 0 ; $res .= TH $img { $col } ; }
            else
              { $ths ++ ; }
          }
        $res .= _ths ( $ths ) . "</TR>\n" ;
      }

    my $HR = '<HR SIZE=2 WIDTH="95%%" NOSHADE>' ;

    $res .= "<TR>\n" ;
    $res .= sprintf "<TD COLSPAN=%d>$HR</TD>\n", 1 ;
    $res .= sprintf "<TD COLSPAN=%d>$HR</TD>\n", $MAX_h ;
    $res .= sprintf "<TD COLSPAN=%d>$HR</TD>\n", $W { old } ;
    $res .= sprintf "<TD COLSPAN=%d>$HR</TD>\n", $W { ded } ;
    $res .= sprintf "<TD COLSPAN=%d>$HR</TD>\n", $W { bad } ;
    $res .= "</TR>\n" ;

    $res .= "<TR>\n" ;
    $res .= '<TD ALIGN="CENTER">&nbsp;<B>age</B>&nbsp;&rarr;&nbsp;</TD>' ;

    $res .= "<TH>|</TH>\n" ;
    $res .= sprintf
      ( '<TD COLSPAN=%d ALIGN="CENTER">'
      . '&larr;&nbsp; 0 &le; <B>age</B> &le; %s &nbsp;&rarr;'
      . "</TD>\n"
      , $MAX_h - 2, pr_interval ( $MAX_H )
      )
      ;
    $res .= "<TH>|</TH>\n" ;
    $res .= sprintf
      ( '<TD ALIGN="CENTER" COLSPAN=%d>'
      . '&nbsp;%sh&nbsp;&lt;&nbsp;%s&nbsp;&le;&nbsp;%sh&nbsp;'
      . "</TD>\n"
      , $W { old }, int($MAX_H/60/60) , BLD ( 'age' ), $MAX_o
      ) ;
    $res .= sprintf
      ( '<TD ALIGN="CENTER" COLSPAN=%d>'
      . '&nbsp;<FONT COLOR="RED">old</FONT>&nbsp;'
      . "</TD>\n"
      , $W { ded }
      ) ;
    $res .= sprintf
      ( '<TD ALIGN="CENTER" COLSPAN=%d>'
      . '&nbsp;<FONT COLOR="RED">bad</FONT>&nbsp;'
      . "</TD>\n"
      , $W { bad }
      ) ;
    $res .= "</TR>\n" ;

    my $FRMT = '<TD ALIGN="CENTER" COLSPAN=%d>&nbsp;%s&nbsp;</TD>' ;

    $res .= "<TR>\n" ;
    $res .= sprintf "$FRMT\n", 1,  NSS scalar keys %$state ;
    $res .= "<TH>|</TH>\n" ;
    $res .= sprintf "$FRMT\n", $MAX_h - 2, NSS $tab_hr ;
    $res .= "<TH>|</TH>\n" ;
    $res .= sprintf "$FRMT\n", $W { old }, NSS $bad { old } ;
    $res .= sprintf "$FRMT\n", $W { ded }, NSS $bad { ded } ;
    $res .= sprintf "$FRMT\n", $W { bad }, NSS $bad { bad } ;
    $res .= "</TR>\n" ;

    $res = "<TABLE CELLSPACING=0 CELLPADDING=1 BORDER=0>\n$res\n</TABLE>\n" ;
    $res = sprintf "<TABLE CELLPADDING=5 BORDER=4>%s</TABLE>\n"
       , "<TR><TH>\n$res\n</TH></TR>" ;
    my $units = join ' '
      , $self -> img_sf ( 's' ) , $self -> img_sf ( 'b' )
      , $self -> img_sf ( 'f' ) , $self -> img_sf ( 'z' )
      ;
    if ( $max == $H )
      { $res .= sprintf "<BR>units %s represent one mirror site.\n"
          , $units ;
      }
    else
      { $res .= sprintf "<BR>each %s unit represents %s mirror sites.\n"
          , $units, sprintf ( "%.1f", $max / $H ) ;
      }
    return H2 ( NAM 'age-histogram', 'age histogram' )
      . BQ $res ;
  }

sub gen_page
  { my $self    = shift ;
    my $get     = shift ;
    my $VERSION = shift ;
    my $conf  = $self -> conf ;
    my $PPP   = $conf -> web_page ;
    my $state = $self -> state ;
    my $CCS   = $self -> regions ;
    my $TMP = "$PPP.tmp" ;
    my %tab ;
    my $refs ;

    for my $url ( keys %$state )
      { my $mirror = $state -> { $url } ;
        my $reg = $mirror -> region ;
        push @{ $tab { $reg } }, $mirror ;
      }

    my $bad = 0 ; my $old = 0 ; my $unr = 0 ;
    my %stats ;
    my @stats ;
    my $ok = 0 ;

    for my $url ( keys %$state )
      { my $mirror = $state -> { $url } ;
        my $time = $mirror -> age ;
        my $stat = $mirror -> last_status ;
        my $vrfy = $mirror -> last_ok_probe ;
        if ( $stat eq 'ok' ) { $ok ++ ; } else { $stats { $stat } ++ ; }
        if ( $time eq 'undef' )
          { $bad ++ ; }
        elsif ( 'f' eq $conf -> age_code ( $time ) )
          { $old ++ ; }
        if ( $vrfy eq 'undef' or aprx_lt $vrfy, $^T - $conf -> max_vrfy )
          { $unr ++ ; }
      }

    my $STAT = sprintf
        "%d bad -- %d older than %s -- %s unreachable for more than %s"
      , $bad
      , $old
      , pr_interval ( $conf -> max_age2 )
      , $unr
      , pr_interval ( $conf -> max_vrfy )
      ;

    my $PROB = 'last probes : ' ;
    push @stats, "$ok were ok" if $ok ;
    for my $stat ( sort keys %stats )
      { ( my $txt = $stat ) =~ s/_/ /g ;
        push @stats, sprintf "%s had %s" , $stats { $stat } , RED $txt ;
      }
    $PROB .= join ', ', @stats ;

    my ( $mean, $median, $stddev ) = $self -> age_avg ;
    my $AVGS = "mean mirror age is " ;
    unless ( defined $mean )
       { $AVGS = "<I>undefined</I>" ; }
    else
       { $AVGS .= sprintf "%s", pr_interval $mean ;
         if ( defined $stddev )
           { $AVGS .= sprintf ", std_dev %s", pr_interval $stddev ; }
         $AVGS .= sprintf ", median %s", pr_interval $median ;
       }

    for my $reg ( sort keys %tab )
      { $refs .= sprintf "&nbsp;%s&nbsp;\n"
          , URL "#$reg", "<FONT SIZE=\"+1\">$reg</FONT>"
          ;
      }

    my $COLS = 5 ;
    my $NAME = $conf -> project_name ;
    my $LOGO = $conf -> project_logo
      ? URL
          ( $conf -> project_url
          , sprintf
              ( '<IMG SRC="%s" ALT="%s" ALIGN="RIGHT" BORDER=0>'
              , $conf -> project_logo
              , $conf -> project_name
              )
          )
      : ''
      ;
    my $HEAD = $conf -> htm_head . "\n" ;
    my $HTOP = $conf -> htm_top  . "\n" ;
    my $FOOT = $conf -> htm_foot . "\n" ;
    my $TITL = URL $conf -> project_url, $NAME ;
    my $EXPD = Base::exp_date ;
    my $DATE = scalar gmtime $^T ;
    my $LAST = scalar gmtime ( $get ? $^T : ( stat $conf -> state ) [9] ) ;

    my $histo_top = $self -> gen_histogram ( 'top' ) ;
    my $histo_bot = $self -> gen_histogram ( 'bottom' ) ;

    open PPP, ">$TMP" or die "can't write $TMP ($!)" ;
    my $prev_select = select PPP ;

    my $attr1 = "COLSPAN=$COLS BGCOLOR=LIME" ;
    my $attr2 = 'BGCOLOR=AQUA' ;
    my $attr3 = "COLSPAN=$COLS BGCOLOR=YELLOW" ;

    my $num_mirrors = scalar keys %$state ;
    my $num_regions = scalar keys %tab ;

    print <<HEAD ;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<HTML>
<HEAD>
<TITLE>the status of $NAME mirrors</TITLE>
<META HTTP-EQUIV="content-type" CONTENT="text/html; charset=utf-8">
<META HTTP-EQUIV=refresh CONTENT=3600>
<META HTTP-EQUIV=Expires CONTENT=\"$EXPD\">
$HEAD
</HEAD>
<BODY BGCOLOR=\"#FFFFFF\">
$LOGO
<H2>the status of $TITL mirrors</H2>
<TABLE BORDER=0 CELLPADDING=2>
<TR><TD>date</TD><TD>:</TD><TD>$DATE (UTC)</TD></TR>
<TR><TD>last&nbsp;check</TD>
  <TD>:</TD>
  <TD>$LAST (UTC)</TD>
</TR>
</TABLE>
$HTOP
$histo_top
<H2>regions</H2>
<BLOCKQUOTE><CENTER>\n$refs\n</CENTER></BLOCKQUOTE>
<H2>report</H2>
<BLOCKQUOTE>
<TABLE BORDER=2 CELLPADDING=5>
<TR><TH $attr1>$num_mirrors sites in $num_regions regions</TH></TR>
<TR><TH $attr1>$STAT</TH></TR>
<TR><TH $attr1>$PROB</TH></TR>
<TR><TH $attr1>$AVGS</TH></TR>
<TR>
  <TH $attr2>$NAME site -- home</TH>
  <TH $attr2>type</TH>
  <TH $attr2>mirror age,<BR>daily stats</TH>
  <TH $attr2>last probe,<BR>probe stats</TH>
  <TH $attr2>last stat</TH>
</TR>
HEAD

    for my $reg
      ( sort { _cmp_ccs $CCS, $a, $b } keys %tab )
#      { ( $CCS -> { $a } ? lc ( $CCS -> { $a } ) : $a )
#    cmp ( $CCS -> { $b } ? lc ( $CCS -> { $b } ) : $b )
#      } keys %tab
#     )
      { my $mirrors = $tab { $reg } ;

        my $ccs = exists $CCS -> { $reg } ? $CCS -> { $reg } : $reg ;
        $ccs = NAM $reg,
          ( scalar @{ $mirrors } > 6
          ? sprintf "%s&nbsp;&nbsp;-&nbsp;&nbsp;%d sites"
              , $ccs, scalar @{ $mirrors }
          : $ccs
          ) ;
        printf "<TR><TH $attr3>$ccs</TH></TR>\n" ;

        for my $mirror ( sort { $a -> cmp ( $b ) } @$mirrors )
          { print "<TR>\n" ;
            printf "  <TD ALIGN=RIGHT>%s&nbsp;&nbsp;%s</TD>\n  <TD>%s</TD>\n"
              , $mirror -> url_site
              , $mirror -> url_home
              , $mirror -> type
              ;

            my ( $url, $time, $stat, $vrfy, $hstp, $hsts ) =
              $mirror -> as_list ;
            my $pr_time = $time =~ /^\d+$/
              ? pr_diff $time, $^T - $conf -> max_age2 : '&nbsp;' ;
            my $pr_last = $vrfy =~ /^\d+$/
              ? pr_diff $vrfy, $^T - $conf -> max_vrfy : '&nbsp;' ;
            my $pr_hstp = $self -> show_hist ( $hstp ) ;
            my $pr_hsts = $self -> show_hist ( $hsts ) ;

            if ( $stat ne 'ok' ) { $stat =~ s/_/ /g ; $stat = RED $stat ; }
            printf "  <TD ALIGN=RIGHT>%s<BR>%s</TD>\n" , $pr_time, $pr_hsts ;
            printf "  <TD ALIGN=RIGHT>%s<BR>%s</TD>\n" , $pr_last, $pr_hstp ;
            printf "  <TD>%s</TD>\n", $stat ;
            print "</TR>\n" ;
          }
      }

    my $legend = $self -> legend ;
    my $probes = $self -> gen_histogram_probes ;
    my $mir_img = sprintf
      '<IMG BORDER=2 ALT=mirmon SRC="%s/mirmon.gif">' , $conf -> icons ;

    print <<TAIL ;
</TABLE>
</BLOCKQUOTE>
$histo_bot
$legend
<H3>probe results</H3>
$probes
<H3>software</H3>
<BLOCKQUOTE>
<TABLE>
<TR>
  <TH><A HREF=\"$HOME\">$mir_img</A></TH>
  <TD>$VERSION</TD>
</TR>
</TABLE>
</BLOCKQUOTE>
$FOOT
</BODY>
</HTML>
TAIL

    select $prev_select ;

    if ( print PPP "\n" )
      { close PPP ;
        if ( -z $TMP )
          { warn "wrote empty html file; keeping previous version" ; }
        else
          { rename $TMP, $PPP or die "can't rename $TMP, $PPP ($!)" ; }
      }
    else
      { die "can't print to $TMP ($!)" ; }
  }

package Mirmon::Conf ; #############################################

BEGIN { use base 'Base' ; Base -> import () ; }

our %CNF_defaults =
  ( project_logo => ''
  , timeout      => $DEF_TIMEOUT
  , max_probes   => 25
  , min_poll     => '1h'
  , max_poll     => '4h'
  , min_sync     => '1d'
  , max_sync     => '2d'
  , list_style   => 'plain'
  , put_histo    => 'top'
  , randomize    => 1
  , add_slash    => 1
  , htm_top      => ''
  , htm_foot     => ''
  , htm_head     => ''
  , always_get   => ''
  ) ;

our @REQ_KEYS =
  qw( web_page state countries mirror_list probe
      project_name project_url icons
    ) ;
our %CNF_KEYS ;
for ( @REQ_KEYS, keys %CNF_defaults ) { $CNF_KEYS { $_ } ++ ; }

my @LIST_STYLE = qw(plain apache) ;
my @PUT_HGRAM  = qw(top bottom nowhere) ;

eval Base -> mk_methods ( keys %CNF_KEYS, qw(root site_url) ) ;

sub get_xtr
  { my $self = shift ;
    my $reg  = shift ;
    scalar grep { $_ eq $reg } split ' ', $self -> always_get ;
  }

sub new
  { my $self = shift ;
    my $FILE = shift ;
    my $res = bless { %CNF_defaults }, $self ;
    $res -> root ( $FILE ) ;
    $res -> site_url ( {} ) ;
    $res -> get_conf () ;
  }

sub get_conf
  { my $self = shift ;
    my $FILE = ( @_ ? shift : $self -> root ) ;

    if ( grep $_ eq $FILE,  @{ $self -> {_include} } )
      { die "already included : '$FILE'" ; }
    else
      { push @{ $self -> {_include} }, $FILE ; }

    open FILE, $FILE or die "can't open '$FILE' ($!)" ;
    my $CONF = join "\n", grep /./, <FILE> ;
    close FILE ;

    $CONF =~ s/\t/ /g ;           # replace tabs
    $CONF =~ s/^[+ ]+// ;         # delete leading space, plus
    $CONF =~ s/\n\n\s+/ /g ;      # glue continuation lines
    $CONF =~ s/\n\n\+\s+//g ;     # glue concatenation lines
    $CONF =~ s/\n\n\./\n/g ;      # glue concatenation lines

    chop $CONF ;
    print "--$CONF--\n" if Mirmon::debug ;
    for ( grep ! /^#/, split /\n\n/, $CONF )
      { my ($key,$val) = split ' ', $_, 2 ;
        $val = '' unless defined $val ;
        print "conf '$FILE' : key '$key', val '$val'\n" if Mirmon::debug ;
        if ( exists $CNF_KEYS { $key } )
          { $self -> $key ( $val ) ; }
        elsif ( $key eq 'site_url' )
          { my ( $site, $url ) = split ' ' , $val ;
            $url .= '/' if $self -> add_slash and $url !~ m!/$! ;
            $self -> site_url -> { $site } = $url ;
#           printf "config : for site '%s' use instead\n   '%s'\n",
#             $site, $url if Mirmon::verbose ;
          }
        elsif ( $key eq 'no_add_slash' )
          { $self -> add_slash ( 0 ) ; }
        elsif ( $key eq 'no_randomize' )
          { $self -> randomize ( 0 ) ; }
        elsif ( $key eq 'show' )
          { $self -> show_conf if Mirmon::verbose ; }
        elsif ( $key eq 'exit' )
          { die 'exit per config directive' ; }
        elsif ( $key eq 'include' )
          { $self -> get_conf ( $val ) ; }
        elsif ( $key eq 'env' )
          { my ( $x, $y ) = split ' ' , $val ;
            $ENV { $x } = $y ;
            printf "config : setenv '%s'\n   '%s'\n", $x, $y
              if Mirmon::verbose ;
          }
        else
          { $self -> show_conf ;
            die "unknown keyword '$key' (value '$val')\n" ;
          }
      }
    my $err = $self -> check ;
    die $err if $err ;
    $self ;
  }

sub check
  { my $self = shift ;
    my $err = '' ;
    for my $key ( @REQ_KEYS )
      { unless ( exists $self -> { $key } )
          { $err .= "error: missing config for '$key'\n" ; }
      }
    for my $key ( qw(min_poll max_poll max_sync min_sync) )
      { my $max = $self -> $key ;
        unless ( $max =~ /$TIM_PAT/o )
          { $err .= "error: bad timespec for $key ($max)\n" ; }
      }
    unless ( grep $self -> { list_style } eq $_, @LIST_STYLE )
      { $err .= sprintf "error: unknown 'list_style' '%s'\n",
          $self -> list_style ;
      }
    unless ( grep $self -> put_histo eq $_, @PUT_HGRAM )
      { $err .= sprintf "%s : error: unknown 'put_histo' '%s'\n",
          $self -> put_histo ;
      }
    $err ;
  }

sub show_conf
  { my $self = shift ;
    print "vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv\n" ;
    for my $key ( sort keys %$self )
      { next if $key =~ m/^_/ ;
        my $val = $self -> { $key } ;
        print "show_conf : $key = '$val'\n" ;
      }
    for my $key ( sort keys %{ $self -> site_url } )
      { printf "show_conf : for site '%s' use instead\n   '%s'\n"
          , $key, $self -> site_url -> { $key } if Mirmon::verbose ;
      }
    printf "show_conf : included '%s'\n"
      , join "', '", @{ $self -> {_include} } ;
    print "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^\n" ;
  }

sub max_age1
  { my $self = shift ;
    ( s4tim $self -> min_sync ) + ( s4tim $self -> max_poll ) ;
  }

sub max_age2
  { my $self = shift ;
    ( s4tim $self -> max_sync ) + ( s4tim $self -> max_poll ) ;
  }

sub max_vrfy
  { my $self = shift ;
    ( s4tim $self -> min_poll ) + ( s4tim $self -> max_poll ) ;
  }

sub age_code
  { my $self = shift ;
    my $time = shift ;
    return 'z' unless $time =~ /^\d+$/ ;
    return
      ( ( aprx_ge ( $time, $^T - $self -> max_age1 ) )
      ? 's'
      : ( aprx_ge ( $time, $^T - $self -> max_age2 ) ? 'b' : 'f' )
      ) ;
  }

package Mirmon::Mirror ; ###########################################

BEGIN { use base 'Base' ; Base -> import () ; }

use IO::Pipe ;

my @FIELDS =
  qw(url age last_status last_ok_probe probe_history state_history last_probe) ;

eval Base -> mk_methods ( @FIELDS, qw(mirmon region mail) ) ;

sub state_history_time
  { my $self = shift ;
    my $res = ( split /-/, $self -> state_history ) [ 0 ] ;
    $res ;
  }

sub state_history_hist
  { my $self = shift ;
    my $res = ( split /-/, $self -> state_history ) [ 1 ] ;
    $res ;
  }

sub _parse
  { my $self = shift ;
    my $url  = $self -> url ;
    my ( $type, $site, $home, $path ) ;
    if ( $url =~ m!^(ftp|https?|rsync)://([^/:]+)(:\d+)?/! )
      { $type = $1 ; $site = $2 ; $home = $& ; $path = $' ; }
    else
      { warn "can't parse url ($url)" ; }
    return $type, $site, $home, $path ;
  }

sub type { my $self = shift ; ( $self -> _parse ) [ 0 ] ; }
sub site { my $self = shift ; ( $self -> _parse ) [ 1 ] ; }
sub home { my $self = shift ; ( $self -> _parse ) [ 2 ] ; }
sub path { my $self = shift ; ( $self -> _parse ) [ 3 ] ; }

sub age_in_days
  { my $self = shift ;
    my $res = 'undef' ;
    my $age = $self -> age ;
    if ( $age eq 'undef' )
      { $res = length $self -> state_history_hist
          if $self -> last_probe ne 'undef' ;
      }
    else
      { $res = ( $^T - $age ) / 24 / 60 / 60 ; }
    $res ;
  }

sub init
  { my $self   = shift ;
    my $mirmon = shift ;
    my $url    = shift ;
    my $res = bless { mirmon => $mirmon }, $self ;
    @{ $res } { @FIELDS } = ( 'undef' ) x scalar @FIELDS ;
    $res -> url ( $url ) ;
    $res -> probe_history ( '' ) ;
    $res -> state_history ( "$^T-z" ) ;
    $res -> mail ( '' ) ;
    $res ;
  }

sub new
  { my $self   = shift ;
    my $mirmon = shift ;
    my $line   = shift ;
    my $res = bless { mirmon => $mirmon }, $self ;
    @{ $res } { @FIELDS } = split ' ', $line ;
    $res -> mail ( '' ) ;
    $res ;
  }

sub update
  { my $self = shift ;
    my $succ = shift ;
    my $stat = shift ;
    my $time = shift ;
    my $probe_hist = $self -> probe_history ;
    if ( $succ )
      { $self -> age ( $time ) ;
        $self -> last_ok_probe ( $^T ) ;
        $probe_hist .= 's' ;
      }
    else
      { $probe_hist .= 'f' ;
        $time = $self -> age ;
      }

    my $h = $self -> state_history_hist ;
    my $t = $self -> state_history_time ;

    if ( aprx_ge ( $^T - $t, $HIST_DELTA ) )
      { my $n = int ( ( $^T - $t ) / $HIST_DELTA ) ;
        $h .= 'x' x ( $n - 1 ) ;
        $t = ( $n == 1 ? $t + $HIST_DELTA : $^T ) ;
      }
    else
      { chop $h ; }
    $h .= $self -> mirmon -> conf -> age_code ( $time ) ;
    $h = substr $h, - $HIST ;
    $h =~ s/^x+// ;

    $self -> last_status ( $stat ) ;
    $self -> probe_history ( substr $probe_hist, - $HIST ) ;
    $self -> last_probe ( $^T ) ;
    $self -> state_history ( "$t-$h" ) ;
  }

sub as_list { my $self = shift ; @{ $self } { @FIELDS } ; }
sub state { my $self = shift ; join ' ', $self -> as_list ; }

sub start_probe
  { my $self = shift ;
    my $conf = $self -> mirmon -> conf ;
    my $probe = $conf -> probe ;
    my $timeout = $conf -> timeout ;
    $probe =~ s/%TIMEOUT%/$timeout/g ;
    my $url = $self -> url ;
    my $new = $conf -> site_url -> { $self -> site } ;
    if ( defined $new )
      { printf "*** site_url : site %s\n  -> url %s\n"
          , $self -> site, $new if Mirmon::verbose ;
        $url = $new ;
      }
    $probe =~ s/%URL%/$url/g ;
    my $pipe = new IO::Pipe ;
    my $handle = $pipe -> reader ( split ' ', $probe ) ;
    if ( $handle )
      { $pipe -> blocking ( 0 ) ; }
    else
      { die "start_probe : no pipe for $url" ; }
    printf "start %s\n", $url if Mirmon::verbose ;
    printf "  %s\n", $probe if Mirmon::debug ;
    $handle ;
  }

sub finish_probe
  { my $self   = shift ;
    my $handle = shift ;
    my $res ;
    my $succ = 0 ;
    my $stat ;
    my $time ;

    $handle -> blocking ( 1 ) ;
    if ( $handle -> eof () )
      { printf "finish eof %s\n", $self -> url if Mirmon::verbose ; }
    else
      { $res = $handle -> getline () ; }
    $handle -> flush ;
    $handle -> close ;

    unless ( defined $res )
      { $stat = 'no_time' ; }
    elsif ( $res =~ /^\s*$/ )
      { $stat = 'empty' ; }
    else
      { $res = ( split ' ', $res ) [ 0 ] ;

        if ( $res !~ /^\d+$/ )
          { $res =~ s/ /_/g ;
            $res = Base::htmlquote $res ;
            $res = substr ( $res, 0, 15 ) . '..' if length $res > 15 ;
            $stat = "'$res'" ;
          }
        else
          { $succ = 1 ; $stat = 'ok' ; $time = $res ; }
      }

    printf "finish %s\n  succ(%s) stat(%s) time(%s)\n"
      , $self -> url
      , $succ
      , $stat
      , ( defined $time ? $time : 'undef' )
        if Mirmon::verbose ;

    $self -> update ( $succ, $stat, $time ) ;
  }

sub revdom { my $dom = shift ; join '.', reverse split /\./, $dom ; }

sub cmp
  { my $a = shift ;
    my $b = shift ;
    ( revdom $a -> site ) cmp ( revdom $b -> site )
    or
    ( $a -> type cmp $b -> type )
    ;
  }

sub _url
  { my $hrf = shift ;
    my $txt = shift ;
    $hrf =~ /^rsync/ ? $txt : URL $hrf, $txt ;
  }

sub url_site
  { my $self = shift ;
    my $type = $self -> type ;
    if ( $type eq 'rsync' )
      { my $path = $self -> path ;
        chop $path if $path =~ m!/$! ;
        sprintf '%s::%s', $self -> site , $path ;
      }
    else
      { URL $self -> url , $self -> site ; }
  }

sub url_home
  { my $self = shift ;
    my $type = $self -> type ;
    if ( $type eq 'rsync' )
      { '@' ; }
    else
      { URL $self -> home, '@' ; }
  }

=pod

=head1 NAME

Mirmon - OO interface for mirmon objects

=head1 SYNOPSIS

  use Mirmon ;

  $m = Mirmon -> new ( [ $path-to-config ] )

  $conf  = $m -> conf  ; # a Mirmon::Conf object
  $state = $m -> state ; # the mirmon state

  for my $url ( keys %$state )
    { $mirror = $state -> { $url } ; # a Mirmon::Mirror object
      $mail = $mirror -> mail ;      # contact address
      $mirror -> age ( time ) ;      # set mirror age
    }

Many class and object methods can be used to get or set attributes :

  $object -> attribute           # get an atttibute
  $object -> attribute ( $attr ) # set an atttibute

=head1 Mirmon class methods

=over 4

=item B<new ( [$path] )>

Create a Mirmon object from a config file found in $path,
or (by default) in the default list of possible config files.
Related objects (config, state) are created and initialised.

=item verbosity

Mirmon always reports errors. Normally it only reports
changes (inserts/deletes) found in the mirror_list ;
in I<quiet> mode, it doesn't. In I<verbose> mode, it
reports progress: the startup and finishing of probes.

  Mirmon::verbose ( [ $bool ] ) # get/set verbose
  Mirmon::quiet   ( [ $bool ] ) # get/set quiet
  Mirmon::debug   ( [ $bool ] ) # get/set debug

=back

=head1 Mirmon object methods

=over 4

=item B<conf>

Returns Mirmon's Mirmon::Conf object.

=item B<state>

Returns a hashref C<< { url => mirror, ... } >>,
where I<url> is as specified in the mirror list
and I<mirror> is a Mirmon::Mirror object.

=item B<regions>

Returns a hashref C<< { country_code =E<gt> country_name, ... } >>.

=item B<config_list>

Returns the list of default locations for config files.

=item B<get_dates ( $get [, $URL] )>

Probes all mirrors if $get is C<all> ; or a subset if $get is C<update> ;
or only I<$URL> if $get is C<url>.

=back

=head1 Mirmon::Conf object methods

A Mirmon::Conf object represents a mirmon conguration.
It is normaly created by Mirmon::new().
A specified (or default) config file is read and interpreted.

=over 4

=item attribute methods

For every config file entry, there is an attribute method :
B<web_page>, B<state>, B<countries>, B<mirror_list>, B<probe>,
B<project_name>, B<project_url>, B<icons>, B<project_logo>,
B<timeout>, B<max_probes>, B<min_poll>, B<max_poll>, B<min_sync>,
B<max_sync>, B<list_style>, B<put_histo>, B<randomize>, B<add_slash>.

=item B<root>

Returns the file name of (the root of) the configuration file(s).

=item B<site_url>

Returns a hashref C<< { site => url, ... } >>,
as specified in the mirmon config file.

=back

=head1 Mirmon::Mirror object methods

A Mirmon::Mirror object represents the last known state of a mirror.
It is normaly created by Mirmon::new() from the state file,
as specified in the mirmon config file.
Mirmon::Mirror objects can be used to probe mirrors.

=head2 attribute methods

=over 4

=item B<url>

The url as given in the mirror list.

=item B<age>

The mirror's timestamp found by the last successful probe,
or 'undef' if no probe was ever successful.

=item B<last_status>

The status of the last probe, or 'undef' if the mirror was never probed.

=item B<last_ok_probe>

The timestamp of the last successful probe or 'undef'
if the mirror was never successfully probed.

=item B<probe_history>

The probe history is a list of 's' (for success) and 'f' (for failure)
characters indicating the result of the probe. New results are appended
whenever the mirror is probed.

=item B<state_history>

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
One or more 'skip's are inserted, if the timestamp is two or more days old
(when mirmon hasn't run for more than two days).

=item B<last_probe>

The timestamp of the last probe, or 'undef' if the mirror was never probed.

=back

=head2 object methods

=over 4

=item B<mirmon>

Returns the parent Mirmon object.

=item B<state_history_time>

Returns the I<time> part of the state_history attribute.

=item B<state_history_hist>

Returns the I<history> part of the state_history attribute.

=item B<type>, B<site>, B<home>

For an url like I<ftp://www.some.org/path/to/home>,
the B<type> is I<ftp>,
the B<site> is I<www.some.org>,
and B<home> is I<ftp://www.some.org/>.

=item B<age_in_days>

Returns the mirror's age (in fractional days), based on the mirror's
timestamp as found by the last successful probe ; or based on the
length of the state history if no probe was ever successful.
Returns 'undef' if the mirror was never probed.

=item B<mail>

Returns the mirror's contact address as specified in the mirror list.

=item B<region>

Returns the mirror's country code as specified in the mirror list.

=item B<start_probe>

Start a probe for the mirror in non-blocking mode ;
returns the associated (IO::Handle) file handle.
The caller must maintain an association between
the handles and the mirror objects.

=item B<finish_probe ( $handle )>

Sets the (IO::Handle) B<$handle> to blocking IO ;
reads a result from the handle,
and updates the state of the mirror.

=back

=head1 SEE ALSO

=begin html

<p>
<a href="mirmon.html">mirmon(1)</a>
</p>

=end html

=begin man

mirmon(1)

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

1 ;
