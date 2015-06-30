#!/usr/bin/perl
#vim: set shiftwidth=2 autoindent showmatch syntax=perl

# Perl Script to execute any ClearQuest query and generate
# a CSV file with the query results.
#
# Thanks to Sean Reynaud, whose original "query.cqpl"
# provided a starting point for this script.

# Author: David Bingham
# Date  : 3 July 2012

use CQPerlExt;

$main::debug = 0;        # Set to 1 for debugging (by -debug)

sub usage {
    print "ratlperl $0 -u Userid -p Password -q Query -c CSV [-s Set] [-d Database] [-l Logfile]\n";
    print "\tPerl Script to execute any ClearQuest query, and\n";
    print "\tgenerate a CSV file with the query results.\n";
    print "\n";
    print "Options:\n";
    print " -u Userid    ClearQuest User ID\n";
    print " -p Password  ClearQuest User Password\n";
    print " -q Query     ClearQuest Query path + name\n";
    print " -c CSV       CSV file name\n";
    print " -s Set       ClearQuest database set to use, default=MITEL\n";
    print " -d Database  ClearQuest database to use, default=MN\n";
    print " -l Logfile   Log File name, default=follow CSV\n";
    #       -debug       Turn on debugging - additional logs in log file
    print "\n";
    print "Example:\n";
    print " ratlperl $0 -u myid -p password -q \"Personal Queries/All Defects\" -c AllDefects.csv\n";
    print "\n";
}


# Simple logger
#
# Logs are printed on console unadorned.
#
# Each log in file is prepended by timestamp & file name. Example:
#     Thu 04/02/2015, 12:09:10.62, query.cqpl: This is a log message.
#
# If used before logfile name variable has been initialized, only
# console log will print, along with an error message.

sub logger {
    # print to console
    print "$_[0]\n";

    # Print to logfile, if it has been defined
    if ( $main::logfile ) {
        # Open log file
        open CQ,">>$main::logfile" or die "Cannot open file $main::logfile";

	# Generate timestamp
	use Time::HiRes qw(time);
        use POSIX qw(strftime);
    
        my $t = time;
        my $logtimestamp = strftime "%a %m/%d/%Y, %H:%M:%S", localtime $t;
        $logtimestamp .= sprintf ".%02d", ($t-int($t))*100; # without rounding

	# Print log
	print CQ "$logtimestamp, $0: $_[0]\n";

        # Close log file
        close CQ;
    } else {
	# drop a hint - because this log won't be in the file
	print "Log requested before logfile defined.\n";
    }
}


# fail (failure reason string)
sub fail {
    logger( $_[0] );
    exit 1;
}

# Input Validation
if (@ARGV <= 0) {
	usage();
	exit 1;
}

# Set defaults; these may be overridden by optional parameters
$main::dbset = "MITEL";
$main::database = "MN";

for (my $i = 0; $i < @ARGV; $i++) {
    if ($ARGV[$i] eq '-h') {
        usage();
        exit 0;
    } elsif ($ARGV[$i] eq '-u') {
        $main::user = $ARGV[++$i];
    } elsif ($ARGV[$i] eq '-p') {
        $main::password = $ARGV[++$i];
    } elsif ($ARGV[$i] eq '-q') {
        $main::query_name = $ARGV[++$i];
    } elsif ($ARGV[$i] eq '-c') {
        $main::csvfile = $ARGV[++$i];
    } elsif ($ARGV[$i] eq '-s') {
        $main::dbset = $ARGV[++$i];
    } elsif ($ARGV[$i] eq '-d') {
        $main::database = $ARGV[++$i];
    } elsif ($ARGV[$i] eq '-l') {
        $main::logfile = $ARGV[++$i];
    } elsif ($ARGV[$i] eq '-debug') {
	$main::debug = 1;
    } else {
        usage();
        exit 1;
    }
}


# Check that mandatory parameters were received.
if (!defined($main::user) || ($main::user eq "")) {
	usage();
	fail( "Missing required parameter: user" );
}
if (!defined($main::password) || ($main::password eq "")) {
	usage();
	fail( "Missing required parameter: password" );
}
if (!defined($main::query_name) || ($main::query_name eq "")) {
	usage();
	fail( "Missing required parameter: query_name" );
}
if (!defined($main::csvfile) || ($main::csvfile eq "")) {
	usage();
	fail( "Missing required parameter: csvfile" );
}
if (!defined($main::logfile) || ($main::logfile eq "")) {
	# Not an error, but use default log file, based on CSV file.
	$main::logfile = $main::csvfile;
	$main::logfile =~ s/\.csv$//i;
	$main::logfile =~ s/$/\.log/;
}

Main:{
    	my $session;
    	my $workspace;
	my $queryObj;
	my $results;

    	logger( "Running Query \"$main::query_name\"" );

    	logger( "\tBuilding session" ) if ($main::debug);
    	$session = CQPerlExt::CQSession_Build() or die "$!";

    	logger( "\tLogging in to ClearQuest - $main::database" ) if ($main::debug);
    	eval{ $session->UserLogon("$user","$password","$main::database","$main::dbset")};
	fail("Unable to log in as $user - check Userid and Password") if ( $@ );

    	logger( "\tGetting Workspace" ) if ($main::debug);
    	eval{ $workspace = $session->GetWorkSpace() };
	fail("Unable to obtain workspace") if ( $@ );

    	logger( "\tGetting Query Def" ) if ($main::debug);
    	eval{ $queryObj = $workspace->GetQueryDef("$main::query_name") };
	fail("Unable to obtain Query Object - check query name\n") if ( $@ );

    	logger( "\tExecuting Query" ) if ($main::debug);
    	$results = $session->BuildResultSet($queryObj);
    	$results->Execute();

    	# Open csv file
    	logger( "\tOpening CSV file ($main::csvfile)" ) if ($main::debug);
    	open CSV,">$main::csvfile" or die "Cannot open file $main::csvfile";

	# Print column headings first, skipping CQ internal ID (always col 1).
	# Tricky bit - when recordNumber is 0, we will print the column names,
	# otherwise column values from the relevant record.
    	logger( "\tGenerating CSV output" ) if ($main::debug);
	$recordNumber = 0;
	$numberOfColumns = $results->GetNumberOfColumns();
	do {
		for ($column = 2; $column <= $numberOfColumns; $column++) {
			if ($recordNumber == 0) {
				$columnValue = $results->GetColumnLabel($column);
			} else {
				$columnValue = $results->GetColumnValue($column);
			}
			# remove any Returns from the columnValue
			# it would be better to find a way to respect them,
			# but since they mess up the import to spreadsheets,
			# they just have to go.
			$columnValue =~ s/[\r\n]/ /g;
			# remove any commas from the columnValue
			$columnValue =~ s/,/ /g;
			# change double quotes to single quotes
			# consider dec 145-148 as well
			$columnValue =~ s/["‘’“”]/'/g;
			# change long-dash to regular hyphen (dec 151)
			$columnValue =~ s/–/-/g;
			# print value, followed by appropriate comma or newline
			($column < $numberOfColumns) ?
				print CSV "$columnValue," : 
				print CSV "$columnValue\n"
		}
		$recordNumber++;
	} while (($results->MoveNext()) ==1);
    	logger( "\tOutput ($recordNumber) Records" ) if ($main::debug);

	close (CSV);

    	logger( "\tUnbuilding ClearQuest Session" ) if ($main::debug);
    	CQPerlExt::CQSession_Unbuild($session);
    	logger( "Query complete" );

	exit( 0 );
}
