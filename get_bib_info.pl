#!/usr/bin/perl -w
use strict;
use File::Basename;
use HTTP::Request;
use LWP::UserAgent;


###################
#
# This script gets bibliography information using a PMID and outputs
# that information into directories that Textpresso can use.  It also outputs
# a file prepPDF.dat that is used for downloading PDFs 
# 
###################


#if (!($ARGV[1])) { die "
#
#USAGE: $0 <pmid_file> <download_directory> 
#
#e.g. $0 arabidopsis.pmid /home/textpresso/arabidopsis/data prepPDF.dat
#
#pmid_file can have one or two columns
#One column will assume that both the article_ID and the PMID are the same
#Two column will assume the first column is the article_ID and the second is the PMID
#
#\n
#";}

my ($database_name, $download_root, $pmid_file);

if (@ARGV == 2){
	$pmid_file = $ARGV[0];
	$download_root = $ARGV[1];
	my $p_name = basename($pmid_file);
	($database_name) = split(/\./, $p_name);
}
else {
	$database_name = &promptUser("Enter the database name ", "ecoli"); 
	$download_root = &promptUser("Enter the directory to save citations ", "/usr/local/textpresso/$database_name/Data/includes");
	$pmid_file = &promptUser("Enter the location of the PMID file ", "$download_root/$database_name.pmid");
}

my $path = $pmid_file;
my $p_name = basename($path);
my ($p_file) = split(/\./, $p_name);

# The directory where files will be downloaded to during processing.
# They will be moved to the directory for Textpresso annotation 


my @new_directories = ("abstract", "accession", "author", "body", "citation", "journal", "mesh", "title", "type", "year", "pdf", "body_pre-processing");

my %directories = ("abs" => "abstract/", "acc" => "accession/", "aut" => "author/", "bod" => "body/", "cit" => "citation/", "jou" => "journal/", "mes" => "mesh/", "tit" => "title/",  "typ" => "type/", "yea" => "year/", "pdf" => "pdf/");




##########################################
#
#  MAIN
#
##########################################


########
#
# Make directories required for corpus
#
########

print "Checking for required directories and creating them if they don't exist.\n";

makeDirectories(@new_directories);

print "______________\n";



 

########
#
# Read in the PMIDs and extract the PubMed citation info for each paper
#
########


# This is for pubmed files, so define this here
my $cmd = 'pubmed';

# Use the citation directory as the reference directory
# This way if there was no volume, page information previously
# it will be updated
 my $refdir = "year";
# my $refdir = "citation";

my @AI;
open (AI, "$download_root/prepPDF_$database_name.dat");
while (<AI>) {
	chomp;
	my ($pmid) = /(\d+)/;
	push @AI,$pmid;
}
my %ai;
map ($ai{$_}=1,@AI);
#my %ai = alreadyin($download_root, "$download_root/$refdir/");

####
# Read in the PMIDs from pmid_file
####


open (PMIDS, "<$pmid_file");

my %pmid_info = ();

while (my $pmid_line = <PMIDS>) {
    chomp $pmid_line;
    (my $article_id, my $pmid_num) = split(/\t/, $pmid_line);
    # Using Article ID as the key
    # If there's only one column the PMID and the article_ID are the same
    if (!$pmid_num) {
	$pmid_num = $article_id;
	$pmid_info{$article_id} = $pmid_num;
    }
    # If there's two columns, the first column is the article_ID and the
    # second is the PMID
    else {
	$pmid_info{$article_id} = $pmid_num;
    }
}


close(PMIDS);

# Get the bibliography information for each PMID

my @missing = grep(!defined($ai{$_}),keys %pmid_info);
my $num_pmids = scalar(@missing);#keys %pmid_info;

print "\nTotal PMIDs to download bibliography data for:".scalar(@missing)."\n";
print "\nGetting PubMed citation information from the PubMed web site\n";

foreach my $id (@missing) {#sort keys %pmid_info) {   
    # check to see if the PMID information has already been downloaded
#    if ($ai{$id}) {
#	print "Article ID $id - PMID $pmid_info{$id} has already been downloaded\n";
 #   }
 #   else {
	# comply with NCBI's requirement of doing more than 100 requests only 
	# between 9 pm and 5 am EST on weekdays.
	my @lc = localtime;
	if ($num_pmids > 100)
	{	if ($lc[2] > 2 && $lc[2] < 18 && $lc[6] > 0 && $lc[6] < 6) #while
		{	long_sleep();
		    }
	    }
    
	if (($cmd eq 'pubmed') || ($cmd eq 'all')) 
	{	my $url = "http\:\/\/eutils\.ncbi\.nlm\.nih\.gov\/entrez\/eutils\/efetch\.fcgi\?db\=pubmed\&id\=$pmid_info{$id}\&retmode\=xml";
		print $url, "\n";
		my $page = GetWebPage($url, 1);
		if (dumppubmedinfo($download_root, \%directories, $page, $id) > 0) {
		    print "There was an error and PMID $id could not be fetched!\n";
		}
	    }

	elsif (($cmd eq 'online'))
	{	my $url = "http\:\/\/eutils\.ncbi\.nlm\.nih\.gov\/entrez\/eutils\/elink\.fcgi\?dbfrom\=pubmed\&id\=$pmid_info{$id}\&retmode\=ref\&cmd\=prlinks";
		my $page = GetWebPage($url, 1);
		dumponlinetext($download_root, \%directories, $page, $id);
	    }
  #  }
}

print "______________\n";


########
#
# Preparing to download PDFs
# Reads in year, volume and page information to create a data file
#          needed for downloading pdfs
#
########

print "Preparing PDF download and printing to file $download_root/prepPDF_$p_file.dat\n";
prepPDFdownload();

print "______________\n";


########



########
#
# Subroutines
#
########


sub makeDirectories{
    my (@directories) = @_;
    my $nt = @directories;
#    my $outpath = $directories[$nt-1];
    my $outpath = $download_root;
    print "outpath: $outpath \n";

    if (-d $outpath){
	print "\n";
	foreach my $i (@directories){
	    if (-d "$outpath/$i"){
		print "Directory \'$i\' already exists.  Files will be added here.\n";
#		my @temp = <$outpath/$_/*>;
#		for (@temp){
#		    unlink
#			or warn "Couldn't unlink file: $!";
#		}
	    } else{mkdir "$outpath/$i"; print "Making $i\n"}
	}
    }else {print "$outpath does not exist!\n"; exit(0)}
} 


sub GetWebPage{
    my $u = shift;
    my $require_sleep = shift;
    my $page;
    my $ua = LWP::UserAgent->new(timeout => 30); #instantiates a new user agent
    my $request = HTTP::Request->new(GET => $u); #grabs url
    my $response = $ua->request($request);       #checks url, dies if not valid.
    die "Error while getting ", $response->request->uri," -- ", $response->status_line, "\nAborting" unless $response-> is_success;
    
    $page = $response->content;    #splits by line
    if ($require_sleep eq 1) {
	slp();
    }
    return $page;
}



sub slp {
    
    my $rand = int(rand 5) + 3;
    print "Sleeping for 3 seconds...";
    sleep 3;
    print "done.\n";

}

sub long_sleep {
    
    my $rand = int(rand 100);
    print "Slow time: Sleeping for $rand seconds...";
    sleep $rand;
    print "done.\n";

}

sub alreadyin {

    my $outdir = shift;
    my $fd = shift;

    my %ret = ();
    my @aux = glob("$fd/*");
    for (@aux) {
		my $f = basename($_, ''); 
		$ret{$f} = 1;
    }

#    my $acc_dir = $outdir . "/accession/";
#    my @files = <$acc_dir/*>;
#    foreach (@files)
#    {
#	open (IN, "<$_");
#	while (my $line = <IN>)
#	{
#	    chomp ($line);
#	    $ret{$line} = 1;
#	}
#	close (IN);
#    }
    return %ret;

}

sub dumponlinetext {
    my $outdir = shift;
    my $pDir = shift; 
    my $page = shift;
    my $pmid = shift;

    $page =~ s/\<script.*?\>.+\<\/script\>//sgi;
    $page =~ s/\<style.*?\>.+\<\/style\>//sgi;
    $page =~ s/\<\!\-\- .*? \-\-\>//sgi;
    $page =~ s/\<.*?\>//sgi;
    $page =~ s/\<\/.*?\>//sgi;
    $page =~ s/\&.+?\;//sgi;
    $page =~ s/\n\n+/\n/gi;
    $page =~ s/\t\t+/\t/gi;

    print "BODY:\n $page\n";
	my $file = $outdir . "/" . $$pDir{bod} . "/" . $pmid;
    open (BOD, ">$file") or die("could not open file.\n");
    print BOD $page;
    close (BOD);

}

sub dumppubmedinfo {

    my $outdir = shift;
    my $pDir = shift; 
    my $page = shift;
    my $pmid = shift;

    $page =~ s/\n//g;
    return $pmid if $page =~ /\<\!-- Error\>.+?\<\/Error --\>/i;
    
    print "Article ID: $pmid\n";
    print "PMID: $pmid_info{$pmid}\n";

    ### Get year
    if ($page =~ /\<PubDate\>(.+?)\<\/PubDate\>/i) {
	my ($PubDate) = $page =~ /\<PubDate\>(.+?)\<\/PubDate\>/i;
	my ($pubyear) = $PubDate =~ /\<Year\>(.+?)\<\/Year\>/i;
	print "YEAR:\n $pubyear\n";
	print "Printing to $outdir/$$pDir{yea}$pmid\n";
	if ($pubyear =~ /\d+/)
	{
	    unless (open (PUB, ">$outdir/$$pDir{yea}/$pmid")) {
		print "Sorry, cannot open directory $outdir/$$pDir{yea}/$pmid";}
	    open (PUB, ">$outdir/$$pDir{yea}/$pmid");
	    print PUB "$pubyear\n";
	    close (PUB);
	}
    }

    ## Get title
    if ($page =~ /\<ArticleTitle\>(.+?)\<\/ArticleTitle\>/i) {
	my ($title) = $page =~ /\<ArticleTitle\>(.+?)\<\/ArticleTitle\>/i;   
	if ($title =~ /\w+/)
	{
	    open (TITLE, ">$outdir/$$pDir{tit}/$pmid");
	    print TITLE "$title\n";
	    close (TITLE);
	}
    }


    
    ## Get volume
    my ($volume) = $page =~ /\<Volume\>(.+?)\<\/Volume\>/i;   
    
        
    ## Get issue
    my ($issue) = $page =~ /\<Issue\>(.+?)\<\/Issue\>/i;   
    
    
    ## Get page info
    my ($pagenum) = $page =~ /\<MedlinePgn\>(.+?)\<\/MedlinePgn\>/i;   

    if (($volume) || ($issue) || ($pagenum))
#	if (($volume =~ /.+/) || ($issue =~ /.+/) || ($pagenum =~ /.+/))
	{
	    open (CIT, ">$outdir/$$pDir{cit}/$pmid");
	    print CIT "V: $volume\nI: $issue\nP: $pagenum\n";
	    close (CIT);
	}
    
    
    ## Get Abstract 
    if ($page =~ /\<AbstractText\>(.+?)\<\/AbstractText\>/i) {
        my ($abstract) = $page =~ /\<AbstractText\>(.+?)\<\/AbstractText\>/i;

	if ($abstract =~ /\w+/)
	{
	    open (ABS, ">$outdir/$$pDir{abs}/$pmid");
	    print ABS "$abstract";
	    close (ABS);
	}
    }
    #else 
#	{ print "No abstract available at this time.\n"; }
	
    ## Get Authors
    if ($page =~ /\<Author.*?\>(.+?)\<\/Author\>/i) {
	my @authors = $page =~ /\<Author.*?\>(.+?)\<\/Author\>/ig;
	my $authors = "";
	foreach (@authors){
	    my ($lastname, $initials) = $_ =~ /\<LastName\>(.+?)\<\/LastName\>.+\<Initials\>(.+?)\<\/Initials\>/i;
	    $authors .= $lastname . " " . $initials . "\n";
	}
	if ($authors =~ /\w+/)
	{
	    open (AUT, ">$outdir/$$pDir{aut}/$pmid");
	    print AUT "$authors";
	    close (AUT);
	}
    }

    ## Get pub type
#    if ($page =~ /\<PublicationType\>(.+?)\<\/PublicationType\>/i) {
#	my ($type) = $page =~ /\<PublicationType\>(.+?)\<\/PublicationType\>/i;
#	
#	if ($type =~ /.+/)
#	{
#	    open (TYP, ">$outdir/$$pDir{typ}/$pmid");
#	    print TYP "$type";
#	    close (TYP);
#	}
#    }
        my (@type, @filter);
        if ($page =~ /\<PublicationType\>(.+?)\<\/PublicationType\>/i) {
		while ($page =~ /\<PublicationType\>(.+?)\<\/PublicationType\>/isg) {
			push @type, "$1\n";
		}	
		open (TYPE, ">/usr/local/textpresso/ecoli/Data/includes/type/$pmid") or die "$!";
		print TYPE @type;
		close (TYPE);
	}


### GET mesh
	my @mesh;
	if ($page =~ /\<MeshHeading\>(.+?)\<\/MeshHeading\>/i) {
		while ($page =~ /\<MeshHeading\>(.+?)\<\/MeshHeading\>/isg) {
			my $mesh_tags = $1;
			$1 =~ /\<DescriptorName .+?\>(.+?)\<\/DescriptorName\>/i;
			my $mesh_heading = $1;
			my $mesh .= "$mesh_heading : ";
			while ($mesh_tags =~ /\<QualifierName .+?\>(.+?)\<\/QualifierName\>/isg) {
				my $mesh_subheading = $1;
				$mesh .= "$mesh_subheading ";
			}
			push @mesh, "$mesh\n";
		}
	}

	if (@mesh > 0) {
		open (MES, ">$outdir/$$pDir{mes}/$pmid");
		print MES @mesh;	
	}

    if ($page =~ /<MedlineTA>(.+?)\<\/MedlineTA\>/i) {
	## Get Journal
	my ($journal) = $page =~ /<MedlineTA>(.+?)\<\/MedlineTA\>/i;
	
	if ($journal =~ /.+/)
	{
	    open (JOU, ">$outdir/$$pDir{jou}/$pmid");
	    print JOU "$journal";
	    close (JOU);
	}
    }

    ## Print accession number (this is the PMID number)
    open (ACC, ">$outdir/$$pDir{acc}/$pmid");
    print ACC "$pmid_info{$pmid}";
    close (ACC);

    return 0;
}

sub prepPDFdownload {
    my $yeardir = "$download_root/year";
    my $citationdir = "$download_root/citation";
    my $accdir = "$download_root/accession";
    my $journaldir = "$download_root/journal";
    my $output_file = "$download_root/prepPDF_$p_file.dat";
    print "PrepPDF OUTPUT FILE: $output_file \n";
    open (OUTFILE, ">$output_file");
    print OUTFILE "";
    close (OUTFILE);

    my @citationfiles = <$citationdir/*>;



    foreach my $file (@citationfiles) {
	(my $pmid = $file) =~ s/$citationdir\///;
	open (ACC, "<$accdir/$pmid");
	my $pmid_real = <ACC>;
	close (ACC);
	open (YEAR, "<$yeardir/$pmid");
	my $year = <YEAR>;
	chomp $year;
	close (YEAR);
	open (CIT, "<$citationdir/$pmid");
	my $volume = <CIT>;
	chomp $volume;
	$volume =~ s/V: //;
	my $issue = <CIT>;
	chomp $issue;
	$issue =~ s/I: //;
	my $page = <CIT>;
	chomp $page;    
	close (CIT);
	my @splits = split(/-/, $page);
	$splits[0] =~ s/P: (\w+)/$1/;
	open (JOU, "<$journaldir/$pmid");
	my $journal = <JOU>;
	chomp $journal;
	close (JOU);
	open (OUTFILE, ">>$output_file");
	print OUTFILE $journal, "\t", $pmid, "\t", $pmid_real, "\t", $year, "\t", $volume, "\t", $issue, "\t", $splits[0], "\n";
	close (OUTFILE);
#	print "$journal $pmid $year\n";
    }



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
