#!/usr/bin/perl

# Perl Script to execute any ClearQuest chart query and generate
# a JPG file with the chart.
#
# Thanks to Sean Reynaud, whose original "query.cqpl"
# provided a starting point for this script.

# Author: David Bingham
# Date  : 25 November 2013

use CQPerlExt;

$main::debug = 0;        # Set to 1 for debugging (by -debug)

sub usage {
    print "ratlperl $0 -u Userid -p Password -q Query -o JPG [-s Set] [-d Database] [-l Logfile]\n";
    print "\tPerl Script to run any ClearQuest chart, and\n";
    print "\tgenerate a jpg file with the chart image.\n";
    print "\n";
    print "Options:\n";
    print " -u Userid    ClearQuest User ID\n";
    print " -p Password  ClearQuest User Password\n";
    print " -q Chart     ClearQuest Chart path + name\n";
    print " -o JPG       Output JPG file name\n";
    print " -s Set       ClearQuest database set to use, default=MITEL\n";
    print " -d Database  ClearQuest database to use, default=MN\n";
    print " -l Logfile   Log File name, default=follow output\n";
    #       -debug       Turn on debugging - additional logs in log file
    print "\n";
    print "Example:\n";
    print " ratlperl $0 -u myid -p password -q \"Personal Queries/All Defects\" -o AllDefects.jpg\n";
    print "\n";
}

# fail (failure reason string)
sub fail {
    print $_[0];
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
    } elsif ($ARGV[$i] eq '-o') {
        $main::outfile = $ARGV[++$i];
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
	print "Missing required parameter: user\n";
	exit 1;
}
if (!defined($main::password) || ($main::password eq "")) {
	usage();
	print "Missing required parameter: password\n";
	exit 1;
}
if (!defined($main::query_name) || ($main::query_name eq "")) {
	usage();
	print "Missing required parameter: query_name\n";
	exit 1;
}
if (!defined($main::outfile) || ($main::outfile eq "")) {
	usage();
	print "Missing required parameter: output file\n";
	exit 1;
}
if (!defined($main::logfile) || ($main::logfile eq "")) {
	# Not an error, but use default log file, based on CSV file.
	$main::logfile = $main::outfile;
	$main::logfile =~ s/\.csv$//i;
	$main::logfile =~ s/$/\.log/;
}

Main:{
    	my $session;
    	my $workspace;
	my $queryObj;
	my $results;

    	# Open log file
    	open CQ,">>$main::logfile" or die "Cannot open file $main::logfile";

    	$date = localtime();
    	print CQ "Running Query \"$main::query_name\" - $date\n";

    	print CQ "\tBuilding session\n" if ($main::debug);
    	$session = CQPerlExt::CQSession_Build() or die "$!";

    	print CQ "\tLogging in to ClearQuest - $main::database\n" if ($main::debug);
    	eval{ $session->UserLogon("$user","$password","$main::database","$main::dbset")};
	fail("Unable to log in as $user - check Userid and Password\n") if ( $@ );

    	print CQ "\tGetting Workspace\n" if ($main::debug);
    	eval{ $workspace = $session->GetWorkSpace() };
	fail("Unable to obtain workspace\n") if ( $@ );

    	print CQ "\tGetting Chart Def\n" if ($main::debug);
    	eval{ $queryObj = $workspace->GetChartDef("$main::query_name") };
	fail("Unable to obtain Query Object - check query name\n") if ( $@ );

    	print CQ "\tExecuting Query \n" if ($main::debug);
    	$results = $session->BuildResultSet($queryObj);
    	$results->Execute();

	# Generate Chart - this part is very different from queries
	$chartMgr = $workspace->GetChartMgr();
	$chartMgr->SetResultSet($results);
	$chartMgr->MakeJPEG($main::outfile);

    	print CQ "\tUnbuilding ClearQuest Session\n" if ($main::debug);
    	CQPerlExt::CQSession_Unbuild($session);
    	close (CQ);
}
