#!/usr/bin/env perl
use strict;
use warnings;
use Getopt::Long::Descriptive;
use Math::Trig;
use Time::Local;
use Time::Piece;

my $asr_factor = 1;

my ($opt, $usage) = describe_options(
	'namaz [options]',
	[ 'lang=s', "the language to print the prayer time names in", { default => 'lat'  } ],
	[ 'lat=f',  "the user's latitude",                            { default => 0      } ],
	[ 'lng=f',  "the user's longitude",                           { default => 0      } ],
	[ 'alt=f',  "the user's altitude",                            { default => 0      } ],
	[ 'fajr=i', "the angle of the sun at the time of fajr",       { default => 15     } ],
	[ 'isha=i', "the angle of the sun at the time of isha",       { default => 15     } ],
	[],
	[ 'ansi!',      "whether or not to use ansi color codes",     { default => 1      } ],
	[ 'asr_hanafi', "whether to use the Hanafi factor for asr prayer (2) instead of the Shafi'i one (1)."      
                                                                                            ],
	[ 'help|h',     "display this message and exit",              { shortcircuit => 1 } ]);

print($usage->text), exit if $opt->help;

if ($opt->asr_hanafi) {
	$asr_factor = 2;
}

my $isha_th   = $opt->isha + 0;
my $fajr_th   = $opt->fajr + 0;
my $latitude  = $opt->lat  + 0;
my $longitude = $opt->lng  + 0;
my $altitude  = $opt->alt  + 0;

my %timing_names = (
	lat	=>	[ 'Fajr', 'Shuruq', 'Zuhr', 'Asr', 'Maghrib', 'Isha' ]
);

my @t = localtime(time);
my $offset_seconds= timegm(@t) - timelocal(@t);

my $offset_minutes = $offset_seconds / 60 % 60;
my $offset_hours = $offset_seconds / 3600;
my $offset = $offset_hours * 100 + $offset_minutes;

# Credit to 'https://radhifadlillah.com/blog/2020-09-06-calculating-prayer-times/' for the formulae
my $d = localtime;
my $jd = $d->julian_day;
my $u = ($jd - 2451545) / 365.25;
my $th = 2 * pi * $u;
my $dt = 0.37877 + 23.264  * sin(deg2rad(1 * 57.297 * $th - 79.547))
                + 0.17132 * sin(deg2rad(3 * 57.297 * $th - 59.722));

my $alt_fajr    = -($fajr_th);
my $alt_shuruq  = -0.8333 - (0.0347 * sqrt($altitude));
my $alt_asr     = rad2deg(acot($asr_factor + tan(abs(deg2rad($dt - $latitude)))));
my $alt_maghrib = $alt_shuruq;
my $alt_isha    = -$isha_th;

my $l0   = 280.46607 + 36000.7698 * $u;
my $t_eq = (-(1789 + 237 * $u) * sin(deg2rad($l0))
            - (7146 - 62 * $u) * cos(deg2rad($l0))
            + (9934 - 14 * $u) * sin(deg2rad(2 * $l0))
            - (29 + 5 * $u)    * cos(deg2rad(2 * $l0))
            + (74 + 10 * $u)   * sin(deg2rad(3 * $l0))
            + (320 - 4 * $u)   * cos(deg2rad(3 * $l0))
            - 212              * sin(deg2rad(4 * $l0))) / 1000;

my $z = $offset_hours + $offset_minutes / 60;
my $tran = 12 + $z - $longitude / 15 - $t_eq / 60;

my $fajr    = $tran - alt2h($alt_fajr) / 15;
my $shuruq  = $tran - alt2h($alt_shuruq) / 15;
my $zuhr    = $tran;
my $asr     = $tran + alt2h($alt_asr) / 15;
my $maghrib = $tran + alt2h($alt_maghrib) / 15;
my $isha    = $tran + alt2h($alt_isha) / 15;

my $cur_h = $d->hour + $d->minute / 60;

my @times_h = ($fajr, $shuruq, $zuhr, $asr, $maghrib, $isha);
my @times   = map { hour2text($_) } @times_h;

my $widths = [0, 0, 0, 0, 0, 0];

my $next = 0;

for (my $i = 0; $i < 6; $i++) {
	my $time = $times[$i];
	my $name = $timing_names{$opt->lang}->[$i];

	if ($opt->ansi && ! $next && $cur_h < $times_h[$i]) {
		print "\033[1m";
		$next = 1;
	}

	$widths->[$i] = (length($time) + length($name) + abs(length($time) - length($name))) / 2;
	print_center($name, $widths->[$i]);

	if (($i + 1) % 6 != 0) {
		printf "\t";
	} else {
		printf "\n";
	}

	if ($opt->ansi) {
		print "\033[0m";
	}
}

$next = 0;

for (my $i = 0; $i < 6; $i++) {
	my $time = $times[$i];

	if ($opt->ansi && ! $next && $cur_h < $times_h[$i]) {
		print "\033[1m";
		$next = 1;
	}

	print_center($time, $widths->[$i]);

	if (($i + 1) % 6 != 0) {
		printf "\t";
	} else {
		printf "\n";
	}

	if ($opt->ansi) {
		print "\033[0m";
	}
}


sub alt2h {
	my ($alt) = @_;

	return rad2deg(acos((sin(deg2rad($alt)) - sin(deg2rad($latitude)) * sin(deg2rad($dt)))
	               / (cos(deg2rad($latitude)) * cos(deg2rad($dt)))));
}

sub hour2text {
    my ($raw) = @_;

    my $hour  = int($raw);
    my $min_f = ($raw - $hour) * 60;
    my $min   = int($min_f);
    my $sec   = int(($min_f - $min) * 60);

    my $text  = sprintf "%02d:%02d", $hour, ($sec < 30 ? $min : $min + 1);

    return $text;
}

sub print_center {
	my ($text, $width) = @_;

	my $pad = (($width - length($text)) / 2);
	$pad = ($pad > 0) ? $pad : 0;

	printf "%*s%s%*s", $pad, "", $text, $pad, "";
}
