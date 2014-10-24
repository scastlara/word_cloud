#!/usr/bin/perl

#################################################################################
#                               word_cloud.pl									#
#################################################################################
#
# This script takes an article in plain text and creates a word cloud out of it
#

#================================================================================
# Copyright (C) 2014 - Sergio CASTILLO
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#================================================================================

use warnings;
use strict;
use Data::Dumper;
use App::WIoZ;


die "\nYou have to introduce 2 files as command line arguments:\n" .
"\t- Article.txt\n" .
"\t- Stopwords file\n\n"
unless (@ARGV == 2);

#================================================================================
# VARIABLES 
#================================================================================

my $in_file   = shift @ARGV;
my $stop_file = shift @ARGV;
my %stopwords = ();


#================================================================================
# MAIN LOOP 
#================================================================================

read_stopwords($stop_file, \%stopwords);

my ($out_name, $type)  = get_name($in_file);

print STDERR "# $out_name\n";

my %text_words   = read_file($in_file, \%stopwords);
my %common_words = filter_hash(\%text_words);

my $tmp_name = create_tmp($out_name, $type, \%common_words);
make_wc($tmp_name, $type);


#================================================================================
# FUNCTIONS 
#================================================================================
#--------------------------------------------------------------------------------
sub read_stopwords {

	my $stop_file = shift;
	my $stop_hash = shift;

	open my $stop_fh, '<', $stop_file
		or die "Can't open $stop_file : $!\n";

	while (<$stop_fh>) {
		chomp;
		next unless ($_ =~ m/\w/g);
		$_ =~ s/[^\w]//g;
		$stop_hash->{uc$_} = undef;
	} # while

	close($stop_fh);
	return;

} # sub read_stopwords


#--------------------------------------------------------------------------------
sub get_name {

	my $in_file = shift;
	my $type    = 0;

	$in_file =~ s/\.txt//g
		or die "Wrong file name!\nIt should be \"PMID_####_Author.txt\"\n";

	$in_file =~ s/.+\///g;
	
	$type = 1 if ($in_file =~ m/abstract/g);

	return($in_file, $type);

} # sub get_name

#--------------------------------------------------------------------------------
sub read_file {
	
	my $file       = shift;
	my $stopwords  = shift;
	my %text_words = ();

	open my $in_fh, '<', $file
		or die "Can't open $file : $!\n";

	while (<$in_fh>) {
		chomp;
		next unless ($_ =~ m/[^\w]/);
		my @words = split /\s+/, $_;

		foreach my $word (@words) {
			$word =~ s/[^\w]//g;
			next if ($word eq '' or exists $stopwords->{uc$word} or length($word) <= 1);
			$text_words{lc$word}++;
		} # foreach

	} # while

	die "Empty txt file!\n\n" unless (%text_words);
	return(%text_words);

} # sub read_file


#--------------------------------------------------------------------------------
sub filter_hash { # gets 15% of most common words 
	
	my $words_hash   = shift;
	my %smaller_hash = ();
	my $stop_num 	 = int(scalar(keys %{$words_hash}) * 0.15); 
	
	if ($stop_num < 5) {
		$stop_num = 10;
	} elsif ($stop_num > 100) {
		$stop_num = 100;
	}

	my $i = 0;

	foreach my $key (sort {$words_hash->{$b} <=> $words_hash->{$a} or $a cmp $b} (keys %{ $words_hash }) ) {
		last if ($i == $stop_num);
			# if words > 100, the program becomes too slow
		$smaller_hash{$key} = $words_hash->{$key};
		$i++;
	} # foreach

	return(%smaller_hash);

} # sub filter_hash


#--------------------------------------------------------------------------------
sub create_tmp {
	
	my $out_name   = shift;
	my $type 	   = shift;
	my $words_hash = shift;
	my $tmp_name   = "";

	$tmp_name = "${out_name}.tmp";	

	open my $tmp_fh, '>', $tmp_name
		or die "Can't create $tmp_name : $!\n";
	
	# If max-value and min-value are equal there is an error
	# this compares both values and, if they're equal, it changes
	# the maximum one to x+1

	my @key_array = sort {$words_hash->{$b} <=> $words_hash->{$a} or $a cmp $b} 
							keys %{$words_hash};

	my $first_elem = $key_array[0];
	my $last_elem  = $key_array[-1];

	if ($words_hash->{$first_elem} == $words_hash->{$last_elem}) {
		$words_hash->{$first_elem}++;
	}

	foreach my $word (@key_array) {
		print $tmp_fh "$word;$words_hash->{$word}\n";
	}

	close($tmp_fh);
	return($tmp_name);

} # sub create_tmp


#--------------------------------------------------------------------------------
sub make_wc {

	my $tmp_name = shift;
	my $type     = shift;
	my $name     = $tmp_name;
	$name        =~ s/\.tmp//g;

	my $color = '';

	if ($type == 0) { 
		$color = '144955'; # epub -> blue-ish
	} else {
		$color = '8F6048'; # abst -> brown
	}

	if (-d 'word_cloud') {
		$name = "word_cloud/$name";
		print STDERR "Saving $name file in word_cloud/\n\n";
	} else {
		print STDERR "word_cloud/ directory doesn't exist, saving $name file in current directory\n\n";
	}

	my $wioz = App::WIoZ->new(
		font_min => 14, font_max => 64,
		set_font => "DejaVuSans,normal,bold",
		svg => 0,
		filename => "$name",
		basecolor => "$color"
	);

	my @words = $wioz->read_words($tmp_name);
	$wioz->do_layout(@words);

} # sub make_wc

