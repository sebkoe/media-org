#!/usr/bin/perl
use 5.012;

use strict;
use warnings;

use File::Basename;
use File::Path qw(make_path rmtree);

my $MEDIA_EXTENSIONS = ['mkv','avi','mp4'];
my $WATCH_FOLDER = '/home/sk/torrent/download';
my $SHOW_FOLDER = '/data/media/Shows';
my $MOVIE_FOLDER = '/data/media/Filme';


my @COPY_QUEUE = ();
my @DELETE_QUEUE = ();

sub search_media_files {
    my $folder = shift;
    my $ext = shift;
    
    my @files = ();

    opendir(my $dh, $folder);
        my @tmp_file_list = readdir $dh;
    closedir($dh);

    foreach(@tmp_file_list) {
        next if $_ =~ /^\./;

        if(-d "$folder/$_") {
            my $tmp_media_files = search_media_files("$folder/$_", $ext);
            if(@$tmp_media_files) {
                push(@files, @$tmp_media_files);
            } else {
                push(@DELETE_QUEUE, "$folder/$_");
            }
        } else {
            foreach my $tmp_ext (@$ext) {
                push(@files, "$folder/$_") if $_ =~ /\.$tmp_ext$/i;
            }
        }
    }

    return \@files;
}

sub clean_up_name {
    my $name = shift;
    
    $name =~ s/\./ /g;
    $name =~ s/ - / /g;
    $name =~ s/^\s+|\s+$//g;
    $name = join(' ', (map(ucfirst, split(/ /, $name))));

    return $name;    
}

sub delete_item {
    my $item = shift;
    my $tmp = get_user_input("Delete $item? y/n", "y");
    if ($tmp eq "y") {
        if(-d $item) {
            rmtree($item);
        } else {
            unlink($item);
        }
    }
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
    
    my $showname = shift;
    my $season = shift;
    my $episode = shift;


    print "$filename\n";
    $showname = get_user_input("Name of the show", $showname);
    my $first_letter = uc(substr($showname,0,1));
    $first_letter = "#" unless ($first_letter =~ /[A-Z]/);

    my $target_path = "$SHOW_FOLDER/$first_letter/$showname/Season $season/";

    confirm_copy_data($file, $target_path);
}

sub handle_movie_file {
    my $file = shift;
    my $filename = shift;

    my $moviename = shift;
    my $year = shift;

    print "$filename\n";
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

        if ($? == 0) {
            push(@DELETE_QUEUE, $_->{source});
        }
    }
}


my $media_files = search_media_files($WATCH_FOLDER, $MEDIA_EXTENSIONS);
my @sorted_files = sort(@$media_files);

foreach (@sorted_files) {
    my ($filename, $dirs, $suffix) = fileparse($_);

    if($filename =~ /(.*)s(\d\d?)e(\d\d?)/i) {
        handle_show_file($_, $filename, clean_up_name($1), $2, $3);
    } elsif($filename =~ /(.*)(\d\d)x(\d\d)\./i ) {
        handle_show_file($_, $filename, clean_up_name($1), $2, $3);
    } elsif($filename =~ /(.*)\.(\d{4})\./ or $filename =~ /(.*) (\d{4}) / or $filename =~ /(.*) \((\d{4})\)/) {
        handle_movie_file($_, $filename, $1, $2);
    } elsif($filename =~ /^(\d{4})\.(.*)\.1920/) {
    	handle_movie_file($_, $filename, $2, $1);
    } else {
        push(@DELETE_QUEUE, $_);
    }
}
copy_data;

foreach(@DELETE_QUEUE) {
    delete_item($_);
}
