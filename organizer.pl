#!/usr/bin/perl

use strict;
use warnings;

use File::Basename;
use File::Path qw(make_path);

my $MEDIA_EXTENSIONS = ['mkv','avi','mp4'];
my $WATCH_FOLDER = '/home/sk/torrent/download';
my $SHOW_FOLDER = '/data/media/Shows';
my $MOVIE_FOLDER = '/data/media/Filme';


my @COPY_QUEUE = ();

sub search_media_files {
    my $folder = shift;
    my $ext = shift;
    
    my @files = ();

    opendir(my $dh, $folder);
        while (readdir $dh) {
            next if $_ =~ /^\./;

            if(-d "$folder/$_") {
                push(@files, @{search_media_files("$folder/$_", $ext)});
            } else {
                foreach my $tmp (@$ext) {
                    push(@files, "$folder/$_") if $_ =~ /\.$tmp$/;
                }
            }
        }

    closedir($dh);

    return \@files;
}

sub clean_up_name {
    my $name = shift;
    
    $name =~ s/\./ /g;
    $name =~ s/^\s+|\s+$//g;

    return $name;    
}

sub get_user_input {
    my $msg = shift;
    my $default = shift;

    print "$msg($default): ";
    my $input = <STDIN>;
    chomp($input);

    return $input eq "" ? $default : $input;
}

sub handle_show_file {
    my $file = shift;
    my $filename = shift;
    
    print "$filename\n";
    my ($showname, $season, $episode) = $filename =~ /(.*)s(\d\d?)e(\d\d?)/i;
    $showname = get_user_input("Name of the show", clean_up_name($showname));
    my $first_letter = uc(substr($showname,0,1));
    my $target_path = "$SHOW_FOLDER/$first_letter/$showname/Season $season/";

    confirm_copy_data($file, $target_path);
}

sub handle_movie_file {
    my $file = shift;
    my $filename = shift;

    print "$filename\n";
    my ($moviename, $year) = $filename =~ /(.*)(\d{4})\./;
    $moviename = get_user_input("Name of the movie", clean_up_name($moviename));
    $year = get_user_input("Year of the movie", $year);

    my $target_path = "$MOVIE_FOLDER/$moviename ($year)/";

    confirm_copy_data($file, $target_path);
}

sub confirm_copy_data {
    my $source = shift;
    my $target = shift;

    my $tmp = get_user_input("Move ${source} to ${target}? y/n", "y");
    if($tmp eq "y") {
        push(@COPY_QUEUE, {source => $source, target => $target});
    }
}

sub copy_data {
    foreach(@COPY_QUEUE) {
        print "Source: $_->{source} Target: $_->{target}\n";
	make_path($_->{target});
	system("/usr/bin/rsync", "-av", "--progress", "$_->{source}", "$_->{target}");
    }
}


my $media_files = search_media_files($WATCH_FOLDER, $MEDIA_EXTENSIONS);

foreach (@$media_files) {
    my ($filename, $dirs, $suffix) = fileparse($_);
    if($filename =~ /s\d\d?e\d\d?/i) {
        handle_show_file($_, $filename);
    } elsif($filename =~ /\d{4}\./) {
        handle_movie_file($_, $filename);
    }
}
copy_data;
