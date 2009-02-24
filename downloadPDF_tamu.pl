#!/usr/bin/perl -w
#
# Purpose: Download PDFs from specific journals. Needs as input a tab-delimited 
# file of the following format:
# <journal name> <pmid> <year> <volume> <issue> <firstpage>
# 
#
# Authors:  Hans-Michael Muller, Arun Rangarajan
# Date   :  February 2006,       Oct-Nov 2006


##############################################################################

use strict;
use WWW::Mechanize;
use File::Basename;
use Data::Dumper;

use vars qw($mech);

my ($database_name,$basedir,$infofile,$rescan_offline_files,$rescan_couldnt_download_files);

if (@ARGV == 2){
	$infofile = $ARGV[0];
	$basedir = $ARGV[1];
	my $p_name = basename($infofile);
	($database_name) = split(/\./, $p_name);
	$rescan_offline_files = "yes";
	$rescan_couldnt_download_files = "yes";
}
else {
	$database_name = &promptUser("Enter the database name ", "ecoli"); 
	$basedir = &promptUser("Enter the directory to save pdfs ", "/usr/local/textpresso/$database_name/Data/includes");
	$infofile = &promptUser("Enter the full location of the PMID file ", "$basedir/$database_name.pmid");
	$rescan_offline_files = &promptUser("Do you want to rescan for files previously logged as 'offline'? ", "yes");
	$rescan_couldnt_download_files = &promptUser("Do you want to rescan for files previously logged as 'couldn't download'? ", "yes");
}

my $pdfdir   = "$basedir/pdf";

# Make pdf directory if it's not there

if (-d $basedir){
	print "\n";

	if (-d "$pdfdir"){
		print "********* PDFs will be added to $pdfdir *********\n";
	} 
	else{mkdir "$pdfdir"; print "Making $pdfdir\n"}
}
else {print "$basedir does not exist.  Please create this directory.\n"; exit(0)}


print "______________\n";

#Create the output files if they do not exist.
if (! -e "$basedir/couldnt_download.out") {
	open (COULDNT_DOWNLOAD, ">>$basedir/couldnt_download.out");
	print COULDNT_DOWNLOAD "These pdfs could not be downloaded because a pdf link could not be found. We may not have institutional access.\n\n"; 
	close (COULDNT_DOWNLOAD);
}
if (! -e "$basedir/not_online.out") {
	open (NOTONLINE, ">>$basedir/not_online.out");
	print NOTONLINE "These pdfs could not be downloaded because the article isn't currently available online.\n\n"; 
	close (NOTONLINE);
}


															#Check if a PMID has already been logged.
my %offlinejo;														#Hash file for journals logged as 'not online'.
getofflinejo(\%offlinejo, "$basedir/not_online.out");
my %couldntdljo;													#Hash file for journals logged as 'couldn't download'.
getcouldntdljo(\%couldntdljo, "$basedir/couldnt_download.out");
my %prepPDFfile;													#Hash file for bibliography information.
my $prepPDF = dirname($infofile);
if (getprepPDFfile(\%prepPDFfile, "$prepPDF/prepPDF_$database_name.dat") =~ /false/) {					#Check to see if prepPDF bibliography file exists  
	print "Could not find prepPDF bibliography file. You may need to run ./get_bib_info.pl first. Proceeding without it...\n";
}
my %pmidfile;								#Hash file for PMIDs.
getpmidfile(\%pmidfile, "$infofile");

my (%downloaded, %a1, %a2, %missing);      
my @missing;
my @downloaded = <$pdfdir/*.pdf>;         #Takes a list of all downloaded files and imports them into an array
foreach (@downloaded) {
	s/$pdfdir\///g;
	s/\.pdf//g;
}

map ($downloaded{$_}=1,@downloaded); #Convert the downloaded array into a hash
@missing = grep(!defined($downloaded{$_}),keys %pmidfile); #Create an array of all files listed in the PMID hash but not the downloaded hash (Skips already downloaded files)
map ($a1{$_}=1,@missing); 

my %loggedjo = %offlinejo;

foreach my $key2 ( keys %couldntdljo ) {									#Create a combined hash of all the PMIDs in not_online.out
	if( exists $loggedjo{$key2} ) {										#and couldnt_download.out
		warn "Key [$key2] is in both hashes!";
		next;
		}
	else {
		$loggedjo{$key2} = $couldntdljo{$key2};
	}
}

my @check = grep(defined($downloaded{$_}),keys %loggedjo); 							#Creates array of PMIDs that have already been successfully 
my @files = ("couldnt_download.out","not_online.out");								#downloaded but are still listed in the *.out files, then
if (scalar(@check) > 0) {											#updates the *.out files by removing the successful PMIDs
	for my $file (@files) {
		open (OUTFILE, "+<$basedir/$file");						
		my @list = <OUTFILE>;
		for my $check (@check) {
			@list = grep { !/^$check$/i } @list;
		}
		seek(OUTFILE,0,0);
		print OUTFILE @list;
		truncate(OUTFILE,tell (OUTFILE));
		close (OUTFILE);
	}
}

my $downloaded = 0;
my $total = 0;
my $couldntdownload = 0;
my $notonline = 0;

if ($rescan_couldnt_download_files =~ /n+/i) { 									#Skips files already logged as 'couldn't download'
	@missing = grep(!defined($couldntdljo{$_}),keys %a1);
}

if ($rescan_offline_files =~ /n+/i) { 										#Skips files already logged as 'not online'
	@missing = grep(!defined($offlinejo{$_}),keys %a1);
}

if (($rescan_offline_files =~ /n+/i) && ($rescan_couldnt_download_files =~ /n+/i)) { 				#Skips 'couldn't download' and 'not online' files
	@missing = grep(!defined($offlinejo{$_}),keys %a1);
	map ($a2{$_}=1,@missing); 										#create %a2 with elements from @a1
	@missing = grep(!defined($couldntdljo{$_}),keys %a2);
}

print "\nTotal pdfs to download: ".scalar(@missing)."\n\n";

foreach ( @missing ) {
	chomp;
	my $articleid = $_;
	my $citation = prepPDFfile($articleid, \%prepPDFfile);
	print "#" . (scalar(@missing) - $total) . ": $citation\n";
	$total++;
	my $auxurl = "http://metalib.tamu.edu:9003/tamu?id=pmid:$articleid";
	my $auxcont = getwebpage($auxurl);
	if ($auxcont !~ /full text available online from/i) {							#Check both TAMU Libraries and Pubmed for journal links.  
		$auxurl = "http://www.ncbi.nlm.nih.gov/pubmed?term=$articleid";					#If nothing is found, article is assumed to be not yet 
		getwebpage($auxurl);										#available online.
		if ($mech->content !~ / id=\"linkout-icon/)
		{
			my $test = prepPDFfile($articleid, \%prepPDFfile);
			print "This article isn't currently available online. Article logged to $basedir/not_online.out\n";
			if (! offlinejo($test, \%offlinejo)) {
				open (NOTONLINE, ">>$basedir/not_online.out");
				print NOTONLINE "$articleid\n";
				close (NOTONLINE);
			}
			$notonline++;
			goto done;
		}
	}
	print "Checking TAMU Libraries...\n";
	metalib($articleid);
	print "Article couldn't be downloaded via TAMU Libraries. Checking Pubmed...\n";
	$auxurl = "http://www.ncbi.nlm.nih.gov/pubmed?term=$articleid";
	getwebpage($auxurl);
														
	if ($mech->content =~ / id=\"linkout-icon/)								#Check the Pubmed webpage for article link.
	{  	
		$auxurl = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/elink.fcgi?dbfrom=pubmed&retmode=ref&cmd=prlinks&id=$articleid";
		getwebpage($auxurl);
		pdf($articleid);
	}
	else{
		print "Article not found via Pubmed.\n";
	}
	if ( ! -e "$pdfdir/$articleid.pdf") {
		my $test = prepPDFfile($articleid, \%prepPDFfile);
		print "Couldn't download this article. Article logged to $basedir/couldnt_download.out\n";
		if (! couldntdljo($test, \%couldntdljo)) {
			open (COULDNT_DOWNLOAD, ">>$basedir/couldnt_download.out");
			print COULDNT_DOWNLOAD "$articleid\n";
			close (COULDNT_DOWNLOAD);
		}
		$couldntdownload++;
	}

done:
print "__________________________________________________________________\n";
skip:
}

print "\nPDFs requested: $total\n
PDFs downloaded: $downloaded\n
PDFs that couldn't download: $couldntdownload\n
PDFs not online: $notonline\n\n";

if (getprepPDFfile(\%prepPDFfile, "$prepPDF/prepPDF_$database_name.dat") =~ /true/) {
	print "Writing full citation data for log files\n";
	open (NOTONLINE, "<$basedir/not_online.out");
	open (NODAT, ">$basedir/not_online.dat");
	my (@NODAT, @CDDAT);
	foreach ( <NOTONLINE> ) {
		chomp;
		print ".";
		my $articleid = $_;
		my $citation = prepPDFfile($articleid, \%prepPDFfile);
		push @NODAT,"$citation\n";
	}
	@NODAT = sort(@NODAT);
	print NODAT @NODAT;
	close (NODAT);
	close (NOTONLINE);
	print "\nCitation data for offline files written to $basedir/not_online.dat\n";
	open (COULDNT_DOWNLOAD, "<$basedir/couldnt_download.out");
	open (CDDAT, ">$basedir/couldnt_download.dat");
	foreach ( <COULDNT_DOWNLOAD> ) {
		chomp;
		print ".";
		my $citation = prepPDFfile($_, \%prepPDFfile);
		push @CDDAT,"$citation\n";
	}
	@CDDAT = sort(@CDDAT);
	print CDDAT @CDDAT;
	close (CDDAT);
	close (COULDNT_DOWNLOAD);
	print "\nCitation data for files that couldn't download written to $basedir/couldnt_download.dat\n";
}

#General subroutine for downloading journal pdf links.
sub pdf {	
	my $articleid = shift;
	my @pdf_links;
	return if $mech->response->status_line =~ /^400/; 							#Skip link if webpage gives bad request error (400)
	if ($mech->uri =~ /web\.ebscohost\.com/) {		 						 
		my $url = $mech->uri;									        #EBSCOHost uses javascript to hide the pdf link
		$url =~ s/detail/pdf/g;										#This edits the url to find the link 
		$url =~ s/\&bdata.*//g;
		print "$url\n";
		getwebpage($url);
	}
#	print $mech->content; 											#Uncomment to view downloaded webpage source code.
	if ($mech->base =~ /pubmedcentral/) {
		my @lc = localtime;										#Comply with NCBI's requirement of doing more than 100
		if (scalar(@missing) > 100) {									#requests only between 9 pm and 5 am EST on weekdays.
			if ($lc[2] > 2 && $lc[2] < 18 && $lc[6] > 0 && $lc[6] < 6) {   
				long_sleep();
			}
		}
	}

	$mech->follow_link( text_regex => qr/full text/i, url_regex => qr/nature\.com/i ); 			#Redirects certain Nature links to pdf page.

	if ($mech->content =~ / content=\"(http\S+?pdf)\"/)	 						#Follows unorthodox pdf <meta content> links.
	{
		getwebpage($1);
	}

	if ($mech->ct =~ /pdf/) {										#Download the page if the contents are pdf.
		print "URL = " . $mech->uri . "\n";
		$mech->save_content( "$pdfdir/$articleid.pdf");
		print "$articleid\.pdf added to $pdfdir directory.\n";
		$downloaded++;
		goto done;
	}

	for my $link ( $mech->links ) {										#Filter the links to find the likely pdf match.
#		printf "CANDIDATE link = %s\n",$link->url_abs;							#Uncomment to print all 'visible' webpage links.
		next if $link->url_abs =~ /^https/;   								#Toss secure links.
		next if $link->url !~ /pdf|content\.ebscohost\.com|gatewayurl\&\_origin=inwardhub/i;		#Tosses links not containing the following regex words.
		next if $link->url !~ /\d/;									#Toss any links without digits. (Assumes only candidate links have date information)
		next if $link->url =~ /recommend|buttons|frame/i;						#Tosses links containing the following words. (Blocks false positives) 
		if ($link->url =~ /javascript:.+\(\'(http\S+?)\'\)/) {						#Finds the real url in certain javascript links
			push @pdf_links,$1
		}
#		printf "CANDIDATE link = %s\n",$link->url_abs;							#Uncomment to print all filtered links.
		push @pdf_links,$link->url_abs;
	}
	print "Number of possible pdf links found: " . scalar(@pdf_links) . "\n";
#	if ( ($mech->base =~ /acs\.org|scielo\.cl/i) && (scalar(@pdf_links)>10) ) {				#If too many links are detected, skip the page	
	if ( scalar(@pdf_links)>10 ) {				#If too many links are detected, skip the page	
		print "Too many links to find a correct match. Skipping link...\n";				#(Likely b/c link directs to table of contents page)	
		return;													
	}
	for my $link ( @pdf_links ) { 										#Follow each link and check for pdf content.
		print "$link\n";	
		getwebpage($link);
		pdf($articleid);
	}
	if($mech->content =~ /<meta http-equiv=\"refresh\" content=\"\d;.*url=(\S+?)\"/i) {  #Follows meta refresh link tags.
		getwebpage($1);
		pdf($articleid);
	}

}

#Check TAMU Libraries
sub metalib
{
	my $articleid = shift;
#	my $auxurl = "http://metalib.tamu.edu:9003/tamu?id=pmid:$articleid";
	my $auxurl = "http://linkresolver.tamu.edu:9003/tamu?url_ver=Z39.88-2004&url_ctx_fmt=infofi/fmt:kev:mtx:ctx;ctx_ver=Z39.88-2004;ctx_enc=info:ofi/enc:UTF-8;rfr_id=info:sid/TAMU:textpresso&sfx.ignore_date_threshold=1&sfx.response_type=sfx_api_0_1_xml&rft_id=info:pmid/$articleid";
	my $auxcont = getwebpage($auxurl);
#	my ($i, $x, $var1, $var2, $var3, $var4, @tmp_ctx_svc_id, @tmp_ctx_obj_id, @service_id, @request_id, @journal_sites);
#Finds all possible full text links and pushes them to arrays.
#	while ($auxcont =~ /name=\'tmp_ctx_svc_id\' value=\'(\d+?)\'.*?name=\'tmp_ctx_obj_id\' value=\'(\d+)\'.*?name=\'service_id\' value=\'(\d+)\'.*?name=\'request_id\' value=\'(\d+)\'.*?Full text available online from.*?<span class=\"TargetName\">(.*?)<\/span><\/A>/isg)
	my ($i, $x, @journal_name, @journal_url);
	while ($auxcont =~ /<target_name>(.+?)<\/target_name>.*?<service>getFullTxt<\/service>.*?<url>(.+?)<\/url>/isg)
	{
#		push @tmp_ctx_svc_id,$1;
#		push @tmp_ctx_obj_id,$2;
#		push @service_id,$3;
#		push @request_id,$4;
#		push @journal_sites,$5;
		push @journal_name,$1;
		push @journal_url,$2;
	}
															#Check each link to find the pdf downloads.
#	for ($i=0,$x=scalar(@journal_sites);$i<$x;$i++){
#		$var1 = $tmp_ctx_svc_id[$i];	
#		$var2 = $tmp_ctx_obj_id[$i];
#		$var3 = $service_id[$i];
#		$var4 = $request_id[$i];
#		print "Article is available via: $journal_sites[$i]\n";
#		$auxurl = "http://p9003-metalib.tamu.edu.ezproxy.tamu.edu:2048/tamu/cgi/core/sfxresolver.cgi?tmp_ctx_svc_id=$var1&tmp_ctx_obj_id=$var2&service_id=$var3&request_id=$var4";
	for ($i=0,$x=scalar(@journal_name);$i<$x;$i++){
		print "Article is available via: $journal_name[$i]\n";
		print "Attempting to download...\n";
		getwebpage($journal_url[$i]);
		pdf($articleid);
	}
}

### GENERAL SUBROUTINES

sub getwebpage
{  
	my $u = shift;
	return if ($u eq "");
	my $page = "";
	our $mech = WWW::Mechanize->new(agent => 'Mozilla/5.0', timeout => 30, cookie_jar=> {}, requests_redirectable => [], quiet => [1],); # instantiates a new user agent
		my $request = $mech->get($u); # grabs url
		for my $url ($u)
		{
			my $r = $mech->get($u);
			if ($r->status_line =~ m/^30[12]/ and $r->header('Location')) 
			{
				$url = $r->header('Location');
				redo;
			}
		}	
	$mech->success or print  "Error while getting " . $u . "--" . $mech->response->status_line . "\n";
	$page = $mech->content;    #splits by line 
	slp();
	return $page;
}

sub slp 
{   #my $rand = int(rand 5) + 5;
	my $rand = 2;
#    print "Sleeping for $rand seconds...";
	sleep $rand;
#    print "done.\n";
}

sub long_sleep {

	my $rand = int(rand 100);
	print "Slow time: Sleeping for $rand seconds...";
	sleep $rand;
	print "done.\n";

}

### SUBROUTINES FOR HASH FILES

sub getofflinejo {
	my $pHash_Table = shift;
	my $infile = shift;
	open (IN, "<$infile") || die ("Cannot find input file not_online.out\n");
	while (<IN>) {
		next unless my ($articleid) = /(.+)/;
		$$pHash_Table{$articleid} = 1;
	}
	close IN;
	return;
}

sub offlinejo {
	my $articleid = shift;
	my $pofflinejo = shift;
	my $test = 0;
	foreach (keys %$pofflinejo) {
		$test = 1 if ($_ eq $articleid);
	}
	return $test;
}

sub getcouldntdljo {
	my $pHash_Table = shift;
	my $infile = shift;
	open (IN, "<$infile") || die ("Cannot find input file couldnt_download.out\n");
	while (<IN>) {
		next unless my ($articleid) = /(.+)/;
		$$pHash_Table{$articleid} = 1;
	}
	close IN;
	return;
}

sub couldntdljo {
	my $articleid = shift;
	my $pcouldntdljo = shift;
	my $test = 0;
	foreach (keys %$pcouldntdljo) {
		$test = 1 if ($_ eq $articleid);
		if ($_ =~ /$articleid/) {
			$test = 1;
		}
	}
	return $test;
}

sub getprepPDFfile {
	my $pHash_Table = shift;
	my $infile = shift;
	if (-e $infile) {
		open (IN, "<$infile");
		while (<IN>) {
			chomp;
			my ($articleid) = $_;
			$$pHash_Table{$articleid} = 1;
		}
		close IN;
		return "true";
	}
	else {
		return "false";
	}
}

sub prepPDFfile {
	my $articleid = shift;
	my $pprepPDFfile = shift;
	my $test;
	foreach (keys %$pprepPDFfile) {
		if ($_ =~ /$articleid/) {
			$test = $_;
			return $test;
		}
		else { $test = $articleid; }
	}
	return $test;
}

sub getpmidfile {
	my $pHash_Table = shift;
	my $infile = shift;
	open (IN, "<$infile") || die ("Cannot find $infile\n");
	while (<IN>) {
		chomp;
		my ($articleid) = $_;
		$$pHash_Table{$articleid} = 1;
	}
	close IN;
	return;
}

sub promptUser {
   my ($promptString,$defaultValue) = @_;
   if ($defaultValue) {
      print $promptString, "[", $defaultValue, "]: ";
   } else {
      print $promptString, ": ";
   }
   $| = 1;               # force a flush after our print
   $_ = <STDIN>;         # get the input from STDIN (presumably the keyboard)
   chomp;
   if ("$defaultValue") {
      return $_ ? $_ : $defaultValue;    # return $_ if it has a value
   } else {
      return $_;
   }
}
