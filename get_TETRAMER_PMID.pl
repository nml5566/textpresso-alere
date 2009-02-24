#!/usr/bin/perl -w
use strict;
use WWW::Mechanize;
my $basedir = "/usr/local/textpresso/ecoli/Data/includes/";
my $mech = WWW::Mechanize->new(agent => 'Mozilla/5.0', timeout => 30, cookie_jar=> {}, requests_redirectable => [], quiet => [1],); # instantiates a new user agent
my $uri = "http://ecoliwiki.net/pagelist.php?like=PMID:%&style=short&output=file";
$mech->get( $uri );
my @PMIDLIST = split(/\n/, $mech->content);
open (FH, ">$basedir/ecoli.pmid");
foreach (@PMIDLIST) { 
	s/PMID://g;
	print FH "$_\n";
}
close (FH);
