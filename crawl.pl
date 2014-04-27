#!/usr/bin/perl

#use strict;
#use warnings;
use File::Slurp;
use LWP::Simple;
use HTML::TreeBuilder::XPath;
use URI::Escape;
use DateTime::Format::Strptime;
use Email::Address;

# Custom pakage
use Database;

# Global variables
my $DOMAIN = 'http://www.make-it-in-germany.com/';
my $start_url = 'en/making-it/job-listings/?tx_rmmiigjobboerse_pi1%5Bcat1%5D=14#c11662';
my $translate_url = 'http://translate.google.com/translate_a/t?client=t&sl=de&tl=en&hl=en&sc=2&ie=UTF-8&oe=UTF-8&oc=1&otf=2&ssel=4&tsel=0&q=';
my $page_no = 1;
my @revelent_list = ('java', 'php');
my $LIST = join("|", @revelent_list);

# Correct the date format as per MySQL database
my $DATE_FORMAT = DateTime::Format::Strptime->new(
   pattern => '%d.%m.%Y',
   time_zone => 'local',
);

# Get the URls for all the pages on the website
sub get_link {
  my ($page_no, $url) = ($_[0], $_[1]);
  
  # Fetch the page
  my $page = get( get_absolute_url($url) ) or die $!;
  my $p = HTML::TreeBuilder::XPath->new_from_content( $page);
  my @trips= $p->findnodes( '//div[@class="paging"]');
  
  # Print & save all the job listings
  &get_jobs($url);
  
  my $x = HTML::TreeBuilder::XPath->new;
  $x->parse($trips[0]->as_HTML);

  foreach my $result ($x->findnodes(q{/html/body/div/a})) {
    if( $result->as_HTML() =~ /to next page/) {
      my $link = $result->attr_get_i('href');

      # Increase the page number
      $page_no++;
      
      # Print and parse the next page..
      print "Page no: $page_no\n";
      print "URL: ". get_absolute_url($link) ."\n";
      &get_link($page_no, $link);
    }
  }
  $x->delete;
  $p->delete;
}

# Get the URLs of all the jobs listed on each page and save them
sub get_jobs {
  my ($url) = ($_[0]);
  my $line = 1;
  my $count, $position, $date_of_pub, $employer, $location, $start_date, $email, $link = '';

  # Fetch the job page
  my $page = get( get_absolute_url($url) ) or die $!;
  my $p = HTML::TreeBuilder::XPath->new_from_content( $page);
  my @trips= $p->findnodes( '//table[@class="list"]');

  my $x = HTML::TreeBuilder::XPath->new;
  $x->parse($trips[0]->as_HTML);

  print "  List of revelent jobs ($LIST)\n";
  foreach my $results ($x->findnodes(q{/html/body/table/tr})) {
    my $y = HTML::TreeBuilder::XPath->new;
    $y->parse($results->as_HTML);

    $count = 1;
    foreach my $result ($y->findnodes(q{/html/body/table/tr/td})) {
      if($count == 1) { $position = $result->as_text(); $link = $result->find_by_tag_name('a')->attr_get_i('href'); }
      elsif($count == 2) { $date_of_pub = $result->as_text(); }
      elsif($count == 3) { $employer = $result->as_text(); }  
      elsif($count == 4) { $location = $result->as_text(); }    
      else { $start_date = $result->as_text(); }     
      $count++;
    }

    # Check & print if this link is revelent
    if($position ne "" && $link ne "" && &check_requirement($link)) {
      print "  $line. ". translate($position) ."\n";
	  $line++;

	  $email = get_employer_email($link);

	  # Insert relevent records in database
	  insert(translate($position), convert($date_of_pub), $employer, translate($location), convert($start_date), get_absolute_url($link), $email);
    }
  }
  $x->delete;
  $p->delete;
}

# Get complete URL
sub get_absolute_url {
  my $url = $_[0];
  return $DOMAIN . $url;
}

# Convert date format
sub convert {
  my $date = $_[0];
  return $DATE_FORMAT->parse_datetime($date)->ymd('-')
}

# Translate text from German to English 
sub translate {
  my $txt = $_[0];
  my $url = $translate_url . uri_escape_utf8($txt);
  #print $url."\n";
  
  use File::Fetch;
  my $ff = File::Fetch->new(uri => $url);
  my $file = $ff->fetch() or die $ff->error;

  my $text = read_file($file);
  my ($res) = $text =~ /\[\[\[\"(.*?)\"/g;
  $res =~ s/\s+/ /g;
  
  return $res;
}

# Check whether the requirement if relevent or not 
sub check_requirement {
	my $link = $_[0];
	my $page = get( get_absolute_url($link) ) or die $!;
    
	my $p = HTML::TreeBuilder::XPath->new_from_content($page);
    my $data = $p->findnodes( '//table[@class="details"]')->[0];
	my $text = $data->as_text();
	$p->delete;
	
	if($text =~ /$LIST/ig) { return 1; }
    else { return 0; }
}

#Get employer email address
sub get_employer_email {
	my $link = $_[0];
    my $page = get( get_absolute_url($link) ) or die $!;

    my $p = HTML::TreeBuilder::XPath->new_from_content($page);
    my $data = $p->findnodes( '//table[@class="details"]')->[3];
    my $text = $data->as_HTML();
	$text =~ s/'<td>'/' '/gi;
	$text =~ s/'<\/td>'/' '/gi;
    $p->delete;

	my @addrs = Email::Address->parse($text);
	return $addrs[0]->format;
}



# All starts here..
print "Page no: $page_no\n";
print "URL: ". get_absolute_url($start_url) ."\n";

&get_link($page_no, $start_url);
