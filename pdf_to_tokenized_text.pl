#!/usr/bin/perl -w
# PDF-to-text, dividing PDF files into italics and no_italics

####
# Need to fix
# Include pdftotext that works for permissions
####

#if (@ARGV < 2) { die "
#USAGE: $0 <dir containing pdf files> <dir to write html files with italics> <dir to write html files without italics> <dir to write text files when pdftohtml doesn't work>


#SAMPLE INPUT:  $0 ../import-data/dmelanogaster/data/pdf ../import-data/dmelanogaster/data/html_italics ../import-data/dmelanogaster/data/html_no_italics\n
#";}

use strict;
use File::Basename;

my ($pdf_dir, $tmp_root, $markedup_dir);

if (@ARGV == 3){
	$pdf_dir = $ARGV[0];
	$tmp_root = $ARGV[1];
	$markedup_dir = $ARGV[2];
}
else {
	$pdf_dir = &promptUser("Enter the directory of the downloaded pdfs ", "/usr/local/textpresso/ecoli/Data/includes/pdf"); 
	$tmp_root = &promptUser("Enter the tempory directory for processing pdfs  ", "/usr/local/textpresso/ecoli/Data/includes/body_pre-processing");
	$markedup_dir = &promptUser("Enter the directory to save tokenized pdfs", "/usr/local/textpresso/ecoli/Data/includes/body");
}

my $html_dir = "html_dir";
my $html_dir_full = "$tmp_root/$html_dir";
my $html_italics_dir = "html_italics";
my $html_italics_dir_full = "$tmp_root/$html_italics_dir";
my $html_no_italics_dir = "html_no_italics";
my $html_no_italics_dir_full = "$tmp_root/$html_no_italics_dir";
my $txt_dir = "html_text";
my $txt_dir_full = "$tmp_root/$txt_dir";
my $txt_process_dir = "text_process";
my $txt_process_dir_full = "$tmp_root/$txt_process_dir";


my $error_file = "error_log";



if (! -e $markedup_dir) { die "
The directory '$markedup_dir' does not exist.  Please create this directory.\n 
";}
if (! -e $tmp_root) { die "
The directory '$tmp_root' does not exist.  Please create this directory.\n 
";}



my $path = $0;
my $root = dirname($path);
my $pdftotext = "/usr/local/bin/pdftotext";
print "pdf path: $pdftotext\n";

# This path might need to be changed to get a version of pdftotext 
# that doesn't have the permission issues
$pdftotext = "/usr/local/bin/pdftotext";


# Make these directories

my @new_directories = ("$txt_dir", "$html_italics_dir", "$html_no_italics_dir", "$html_dir", "$txt_process_dir");

makeDirectories(@new_directories);



my @files = <$pdf_dir/*.pdf>;
my $t = 0;
my $success = 0;
my $failure = 0;
my $nopdf = 0;
my $pdftext = 0;


#################
#
# Turn PDFs into html or text
#
#################


#print "\n--------------------------\n\n";
print "\n";

my (@tokenized, %tokenized, %files, @missing);
@tokenized = <$markedup_dir/*>;
foreach (@tokenized) {
	$_ = basename($_);
	s/$/\.pdf/g;
	s/^/$pdf_dir\//g;
}
map ($tokenized{$_}=1,@tokenized);
map ($files{$_}=1,@files);
@missing = grep(!defined($tokenized{$_}),keys %files);
print scalar(@files)." total pdfs\n";
print scalar(@tokenized)." pdfs already tokenized\n";
print scalar(@missing)." pdfs to tokenize\n\n";
sleep 2;

foreach my $f (@missing)
{
	my @e = split /\//, $f;
	my $fn_suf = pop @e;
	$fn_suf =~ /(.*)\.pdf/;
	my $fn = $1;

	my $file1 = $html_italics_dir_full. "/" . $fn . "-1.html";
	my $file2 = $html_no_italics_dir_full. "/" . $fn . "-1.html";
	my $file3 = $txt_dir_full. "/" . $fn;


	# If the file hasn't already been processed, process it


    my $outfile1 = $markedup_dir . "/" . $fn;

    if (! -e $outfile1) # (1) #(! -e $outfile)
#	if ( (! -e $file1) && (! -e $file2) && (! -e $file3) )
	{
	    # total number of papers processed
	    $t++;
	    
	    ####
	    #
	    # Run pdftohtml on the pdfs
	    #
	    ####

		my @args = ($pdftotext, "-q", "-c", "-hidden", $f);

		my $x = system (@args); 

#		if ($x != 0)
#		{
#			print "pdftohtml on $f failed.\n";
#		}
	

		my @htmlfiles = <$pdf_dir/$fn\-*.html>;


	    # If pdftohtml worked, determine if the files have italics or
	    # not and sort them accordingly

		if (@htmlfiles) {
		    my @htmlfiles = <$pdf_dir/$fn\-*.html>;
		




		# See if the files have italics

		my $c = 0;

		foreach my $f (@htmlfiles)
		{
			open (IN, "<$f");
			while (<IN>)
			{	
				if (/\<i\>/)
				{
					$c = 1;
					last;
				}
			}
			close (IN);

			last if ($c == 1);
		}


		# If the pdf has italics, put it in the html_italics directory
		if ($c == 1)
		{
		    print "Italics: $fn\n";
		    
	
		foreach my $f (@htmlfiles)
			{
				@args = ("cp", $f, "$html_italics_dir_full");
				my $x = system (@args);
				@args = ("mv", $f, "$html_dir_full");
				$x = system(@args);
				die "copy of $_ failed\n" if ($x != 0);
			}
			
			$success++;
		}
		
		# If the pdf doesn't have italics, put it in the html_no_italics directory
		else
		{
			print "No italics: $fn\n";

#			if (!@htmlfiles) { 
#			    print "$fn didn't work\n";
#			    $nopdf++;
#			    die "copy of $_ failed\n";
#			}

			foreach my $f (@htmlfiles)
			{
				@args = ("cp", $f, "$html_no_italics_dir_full");
				my $x = system (@args);	
				@args = ("mv", $f, "$html_dir_full");
				$x = system(@args);
				die "copy of $_ failed\n" if ($x != 0);
			}
			$failure++;

		       
		}

		# Clean-up the pdftohtml conversion
		my @png = <$pdf_dir/$fn*.png>;
		foreach (@png)
		{
			@args = ("rm", "-f", $_);
			system (@args);
		}
		@png = <$pdf_dir/$fn*.html>;
		foreach (@png)
		{
			@args = ("rm", "-f", $_);
			system (@args);
		}
		print "$t files done.\n" if ($t % 100 == 0);
		@png = <$fn-outline.*>;
		foreach (@png)
		{
			@args = ("rm", "-f", $_);
			system (@args);
		}
		}

	    ###
	    #
	    # If pdftohtml doesn't work, try pdftotext
	    #
	    ###

	    
		elsif (!@htmlfiles) { 

		    open (ERRORFILE, ">>$tmp_root/$error_file");

		    my @args = ($pdftotext,  "-q", $f,  "$txt_dir_full/$fn");
		    my $x = system (@args);

		    if ($x) {
			print "*** PDF ERROR: $fn *** (pdftohtml and pdftotext failed)\n";
			print ERRORFILE "$fn\n";
			$nopdf++;
		    }
		    else {
			print "Text: $fn\n";
			my @htmlfiles = <$txt_dir_full/$fn>;
			@args = ("cp", "$txt_dir_full/$fn", "$txt_process_dir_full");
			my $y = system (@args);
			$pdftext++;
		    }
		    close ERRORFILE;
		}

	    }

}

print "\n--------------------------\n";
print "\nNumber of PDFs with italics = $success out of $t\n";
print "\nNumber of PDFs without italics = $failure out of $t\n";
print "\nNumber of PDFs that used pdftotext instead = $pdftext out of $t\n";
print "\nNumber of PDFs that didn't work at all = $nopdf out of $t\n*** Files with errors listed in the file: $tmp_root/$error_file ***\n\n";


print "--------------------------\n\n";


######
# 
#  The next step is to do gene markup with the italics if necessary
#  This is not included in this script and needs to be implemented if necessary.
#
######


######
#
# Then turn the html into text
#
######


# All html files are here as well as their respecitive italicized 
# and non-italicized directories
my @html_files = <$html_dir_full/*.html>;



my %filename_list;
foreach my $html_file (@html_files)
{
	my @e = split /\//, $html_file;
	my $f = pop @e;
	$f =~ /((FBrf)?\d+)-(\d+)\.html/;
	my $filename = $1;
	$filename_list{$filename} = 1 if (!defined($filename_list{$filename}));
}

foreach my $filename (keys %filename_list)
{
	my $txt_file = $txt_process_dir_full . "\/" . $filename;
	if (! -e $txt_file)
	{
		@html_files = <$html_dir_full/$filename-*.html>;
		my $n_pages = @html_files;
		my $combine = "";

		for (my $i=1; $i<=$n_pages; $i++)
		{
			my $html_file = $html_dir_full . "\/" . $filename . "-" . $i . "\.html";
			my $x = open (IN, "<$html_file");
			next if (!defined($x));
			
			# Find out whether left and right columns are merged
			my $n_lines = 0;
			my $pos1 = 0; my $pos2 = 0;
			my $c = 0;
			while (<IN>)
			{
				if (/^<DIV(\s+)style=\"position\:absolute\;top\:(\d+)\;left:(\d+)\"><nobr><span(\s+)class=\"ft(\d+)\">(.*)<\/span><\/nobr><\/DIV>$/)
					{
					$n_lines++;
					$pos1 = $3;
	
					if ($pos1 > $pos2)
					{	
						if ( ($pos1 > 439 && $pos2 < 440) || ($pos1-$pos2 > 300) ) # the number 440 is center for 2-column PDF
																				   # 300 is a heuristic
						{
							$c++;
						}
					}
					else
					{
						if ( ($pos2 > 439 && $pos1 < 440) || ($pos2-$pos1 > 300) )
						{
							$c++;
						}
					}
				}
	
				$pos2 = $pos1;
			}
			close (IN);
	
			open (IN, "<$html_file") or die ("No input file $html_file\n");
			if ($c > $n_lines/2 +1) # this page has merged columns
			{
				#print "merged: $filename $i\n";
				#print "c = $c, n = $n_lines\n";
				my $left = ""; my $right = "";
				while (<IN>)
				{
					if (/^<DIV(\s+)style=\"position\:absolute\;top\:(\d+)\;left:(\d+)\"><nobr><span(\s+)class=\"ft(\d+)\">(.*)<\/span><\/nobr><\/DIV>$/)
					{
						(my $left_pos, my $line) = ($3, $6);
						$line =~ s/<b>//g;   # assuming we do not need bold
						$line =~ s/<\/b>//g; # assuming we do not need bold
						$line =~ s/\&amp//g;
						$line =~ s/\&quot\;/"/g;
						$line =~ s/-<br>//g; # word split to next sentence
						$line =~ s/<br>/ /g; # new word on the next sentence
						$line =~ s/<A href=\"(.*)\">//g; # to prevent links
						$line =~ s/<\/a>//g;
						$line .= "\n";
	
						if ($left_pos < 440)
						{
							$left .= $line;
						}
						else
						{
							$right .= $line;
						}
					}
				}
				close (IN);
	
				$combine .= $left . $right;
			}
			else
			{
				#print "good: $filename $i\n";
				#print "c = $c, n = $n_lines\n";
				while (<IN>)
				{
					if (/^<DIV(\s+)style=\"position\:absolute\;top\:(\d+)\;left:(\d+)\"><nobr><span(\s+)class=\"ft(\d+)\">(.*)<\/span><\/nobr><\/DIV>$/)
					{
						(my $left_pos, my $line) = ($3, $6);
						$line =~ s/<b>//g;   # assuming we do not need bold
						$line =~ s/<\/b>//g; # assuming we do not need bold
						$line =~ s/\&amp//g;
						$line =~ s/\&quot\;/"/g;
						$line =~ s/-<br>//g; # word split to next sentence
						$line =~ s/<br>/ /g; # new word on the next sentence
						$line =~ s/<A href=\"(.*)\">//g; # to prevent links
						$line =~ s/<\/a>//g;
						$line .= "\n";
	
						$combine .= $line;
					}
				}
				close (IN);
			}
		}
		
		if ($combine ne "")
		{
			open (OUT, ">$txt_file") or die ("Cannot open out file $txt_file.\n");
			print OUT "$combine\n";
			close OUT;
		}
	}
}


######
#
#  Remove tags and tokenize the text
#
###### 



my @txt_files = <$txt_process_dir_full/*>;
my $tokenized_files = 0;
my $tf_files = 0;

foreach my $tf (@txt_files)
{
    $tf_files++;
    my @e = split /\//, $tf;
    my $filename = pop @e;

    my $outfile = $markedup_dir . "/" . $filename;

    if (! -e $outfile) # (1) #(! -e $outfile)
    {
	$tokenized_files++;
	open (IN, "<$tf");

	
	my $full_text = "";
	
	while (<IN>)
	{
	    $full_text .= $_;
	}
	
	# italicized word is split into next line
	$full_text =~ s/-<\/i>\n<i>//g;
	$full_text =~ s/<\/i>-\n<i>//g;
	$full_text =~ s/(<i>\S+)-\n(\S+<\/i>)/$1$2/g;
	
	# remove singular italics that occur in some papers.
	$full_text =~ s/<i>//g;
	$full_text =~ s/<\/i>//g;
	
	$full_text = &Tokenizer($full_text);
	open (OUT , ">$outfile");
	print OUT "$full_text\n";
	close OUT;
	close IN;
    }
}

my $processed = $tf_files - $tokenized_files;

print "$tokenized_files files processed.  $processed files previously processed.\n\n";

print "--------------------------\n\n";

print "*** If you got errors about libpaper.so.1 ***\nCopy that file from the alere distribution to /usr/lib/\n\n";

sub Tokenizer {
    
    my @incoming = @_;
    my $line = join ("", @incoming);

    # few things to begin with..
    
    # joins words hyphenated by the end of line
    $line =~ s/([a-z]+)- *\n+([a-z]+)/$1$2/g;
    # gets rid of hyphen in word, hypen, space, eg homo- and heterodimers
    $line =~ s/(\w+)- +/$1 /g;
    
    # deal with a period
    
    # gets rid of p.  after sing. capit. letters ( M. Young -> M Young)
    $line =~ s/(\b[A-Z])\./$1/g;
    # protect the "ca. <NUMBER>" notation!!!
    $line =~ s/( ca)\.( \d+)/$1$2/g;
    # gets rid of alot of extraneous periods within sentences ... 
    $line =~ s/e\.g\./eg/g;
    $line =~ s/i\.e\./ie/g;       
    $line =~ s/([Aa]l)\./$1/g;
    $line =~ s/([Ee]tc)\./$1/g;  
    $line =~ s/([Ee]x)\./$1/g;
    $line =~ s/([Vv]s)\./$1/g;
    $line =~ s/([Nn]o)\./$1/g;
    $line =~ s/([Vv]ol)\./$1/g;
    $line =~ s/([Ff]igs?)\./$1/g;
    $line =~ s/([Ss]t)\./$1/g;
    $line =~ s/([Cc]o)\./$1/g;
    $line =~ s/([Dd]r)\./$1/g;
    
    # now get rid of any newline characters, but protect already 
    # recognized end of sentence

    $line =~ s/ \. \n/_PERIOD_EOS__/g;
    $line =~ s/ \? \n/_QMARK_EOS__/g;
    $line =~ s/ \! \n/_EMARK_EOS__/g;
    
    # replaces new line character with a space
    $line =~ s/\n/ /g;
    
    # "protect" instances of periods that do not 
    # mark the end of a sentence by substituting 
    # an underscore for the following space i.e. 
    # ". " becomes "._"
    
    # general rule...
    # protect any period followed by a space then a small letter
    $line =~ s/\. ([a-z])/\._$1/g;
    
    # special instances not caught by general rules...
    # EXCEPTION; unprotect those sentences that begin 
    # with a small letter ie begin with a gene name!!!
    $line =~ s/\._([a-z]{3,4}-\d+)/\. $1/g;
    # EXCEPTION; unprotect those sentences that end with 
    # a capitalized abreviation, eg RNA!!!
    $line =~ s/ (\w+[A-Z]{2})\._/ $1\. /g;
    
    #rules for journal titles
    # protects abbreviated journal title names!
#    $line =~ s/([A-Z]\w+\.) ([A-Z]\w*\.) ?([A-Z]\w*\.)? ?([A-Z]\w*\.)? ?([A-Z]\w*\.)?/$1_$2_$3_$4_$5/g;           
    
    # reintroduce newline characters at ends
    # of sentences only where there
    # is a period followed by a space.
    $line =~ s/(\S\.|\S\?|\S\!) /$1\n/g;
    # modified by HMM previous line to match more cases 
    # for 'reintroduces newlines'
    
    # reverse recognized EOSes
    $line =~ s/_PERIOD_EOS__/ \. \n/g;
    $line =~ s/_QMARK_EOS__/ \? \n/g;
    $line =~ s/_EMARK_EOS__/ \! \n/g;
    

# commented out because too many false positives    
#    # places newline after section titles! 
#    $line =~ s/\b(ABSTRACT|RESEARCH COMMUNICATION|INTRODUCTION|MATERIALS AND METHODS|RESULTS|DISCUSSION|RESULTS AND DISCUSSION|REFERENCES)\b/$1\n/gi;  
    
    # reintroduce spaces following periods that 
    # do not mark the end of a sentence 
    # unprotects any period followed by a space and an small letter
    $line =~ s/\._([a-z])/\. $1/g;
    # unprotects any journal article names
    $line =~ s/([A-Z]\w+\.)_([A-Z]\w*\.)?_?([A-Z]\w*\.)?_?([A-Z]\w*\.)?_?([A-Z]\w*\.)?/$1 $2 $3 $4 $5/g;
    
    # rules for replacing perl metacharacters 
    # and other characters worth keeping
    # with literal descriptions in text ...
    
    # turns " into DQ
    $line =~ s/\"/_DQ__/g;
    # turns < into LT    
    $line =~ s/\</_LT__/g;
    # turns > into GT
    $line =~ s/\>/_GT__/g; 
    # turns + into EQ
    $line =~ s/\=/_EQ__/g;
    # turns & into AND
    $line =~ s/\&/_AND__/g;
    # turns @ into AT
    $line =~ s/\@/_AT__/g; 
    # turns / into SLASH
    $line =~ s/\//_SLASH__/g;
    # turns $ into DOLLAR
    $line =~ s/\$/_DOLLAR__/g;
    # turns % into PERCENT
    $line =~ s/\%/_PERCENT__/g;
    # turns ^ into CARET
    $line =~ s/\^/_CARET__/g;
    # turns * into STAR
    $line =~ s/\*/_STAR__/g;
    # turns + into PLUS
    $line =~ s/\+/_PLUS__/g;
    # turns | into VERTICAL
    $line =~ s/\|/_VERTICAL__/g;
    # turns \ into BACKSLASH
    $line =~ s/\\/_BACKSLASH__/g;

    # including turning all punctuation 
    # into literals .....
    $line =~ s/\./_PERIOD__/g;
    $line =~ s/\?/_QMARK__/g;
    $line =~ s/\!/_EMARK__/g;
    $line =~ s/,/_COMMA__/g;
    $line =~ s/;/_SEMICOLON__/g;
    $line =~ s/:/_COLON__/g;
    $line =~ s/\[/_OPENSB__/g;
    $line =~ s/\]/_CLOSESB__/g;
    $line =~ s/\(/_OPENRB__/g;
    $line =~ s/\)/_CLOSERB__/g;
    $line =~ s/\{/_OPENCB__/g;
    $line =~ s/\}/_CLOSECB__/g;
    $line =~ s/\-/_HYPHEN__/g;
    $line =~ s/\n/_NLC__/g;
    $line =~ s/ /_SPACE__/g;
    
    # now get fid of any non-literal characters...
    
    $line =~ s/\W//g;
    
    # now replace all back ...
    
    $line =~ s/_DQ__/\"/g;
    $line =~ s/_LT__/\</g;	
    $line =~ s/_GT__/\>/g;
    $line =~ s/_EQ__/\=/g;
    $line =~ s/_AND__/\&/g;
    $line =~ s/_AT__/\@/g;
    $line =~ s/_SLASH__/\//g;
    $line =~ s/_DOLLAR__/\$/g;
    $line =~ s/_PERCENT__/\%/g;
    $line =~ s/_CARET__/\^/g;
    $line =~ s/_STAR__/\*/g;
    $line =~ s/_PLUS__/\+/g;
    $line =~ s/_VERTICAL__/\|/g;
    $line =~ s/_BACKSLASH__/\\/g;
    $line =~ s/_PERIOD__/\./g;
    $line =~ s/_QMARK__/\?/g;
    $line =~ s/_EMARK__/\!/g;
    $line =~ s/_COMMA__/,/g;
    $line =~ s/_SEMICOLON__/;/g;
    $line =~ s/_COLON__/:/g;
    $line =~ s/_OPENSB__/\[/g;
    $line =~ s/_CLOSESB__/\]/g;
    $line =~ s/_OPENRB__/\(/g;
    $line =~ s/_CLOSERB__/\)/g;
    $line =~ s/_OPENCB__/\{/g;
    $line =~ s/_CLOSECB__/\}/g;
    $line =~ s/_HYPHEN__/\-/g;
    $line =~ s/_NLC__/\n/g;
    $line =~ s/_SPACE__/ /g;
    
    # rules for tokenizing punctuation marks in text
    # places space around ();:,.[]{}
    $line =~ s/([\)\:\;\,\.\(\[\{\}\]])/ $1 /g;
    
    # finally, clean up any extra spaces####
    # gets rid of tabs
    $line =~ s/\t/ /g;
    # gets rid of extra space              
    $line =~ s/ +/ /g;
    # gets rid of space after newline   
    $line =~ s/\n\s+/\n/g;   
    
    return $line;
    
}

sub makeDirectories{
    my (@directories) = @_;
    my $nt = @directories;
#    my $outpath = $directories[$nt-1];
    my $outpath = $tmp_root;
    print "OUTPATH: $outpath\n";

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
    }else {print "$outpath does not exist!  Please create this directory.\n"; exit(0)}
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
