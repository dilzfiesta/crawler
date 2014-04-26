#!/usr/bin/perl

#use strict;
#use warnings;

package Database;

use Exporter;
use DBI;
use XML::Simple;

our @ISA= qw( Exporter );

# these are exported by default.
our @EXPORT = qw( insert );

# Global variables
my $dbh = &init;

sub init {
	my $xml = XML::Simple->new;
	my $file = $xml->XMLin('db-config.xml') or die$!;

	my $dsn = "DBI:$file->{'vendor'}:database=$file->{'database'};host=$file->{'host'};port=$file->{'port'}";
  	my $dbh = DBI->connect($dsn, $file->{'username'}, $file->{'password'}) or die "Connection Error: $DBI::errstr\n";

	# Create tabe if not already exists
	$sql = $file->{'table'}->{'jobs'};
	$sth = $dbh->prepare($sql);
	$sth->execute or die "SQL Error: $DBI::errstr\n";

	print "Database initialized successfully\n";
	return $dbh;
}

sub get_connection {
  	return $dbh;
}

sub insert {
	my $dbh = &get_connection();
	my ($position, $published_date, $employer, $location, $start_date, $url) = ($_[0], $_[1], $_[2], $_[3], $_[4], $_[5]);
	$sql = "insert into crawler_jobs(position, published_date, employer, location, start_date, url) values(?, ?, ?, ?, ?, ?)";
	$sth = $dbh->prepare($sql);
	$sth->bind_param(1, $position);
	$sth->bind_param(2, $published_date);
 	$sth->bind_param(3, $employer);
  	$sth->bind_param(4, $location);
  	$sth->bind_param(5, $start_date);
  	$sth->bind_param(6, $url);
  	$sth->execute or die "SQL Error: $DBI::errstr\n";
}

1;
