#!/usr/bin/perl
# sdscc-pec-email.cqpl
# Sends a multipart test email to self, via Net::SMTP
# Adds an attachment, ala http://www.perlmonks.org/?node_id=675595

use CQPerlExt;
use Net::SMTP;
use Mail::Send;  ## Just pointing out... there is another way to mail things.
use Digest::MD5 qw(md5_hex);
use MIME::Base64 qw( encode_base64 );

$main::debug = 0;        # Set to 1 for debugging (by -debug)

# Set defaults; these may be overridden by optional parameters
$main::dbset = "MITEL";
$main::database = "MN";

$main::smtpServer = "smtp.mitel.com";

sub usage {
	print "You're doing it wrong...\n\n";
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
if (!defined($main::csvfile) || ($main::csvfile eq "")) {
	usage();
	fail( "Missing required parameter: csvfile" );
}


Main: {
    # Session and logon needed if GetUserEmail is used.
    my $session = CQSession::Build();
    eval{ $session->UserLogon("$user","$password","$main::database","$main::dbset")};
    	fail("Unable to log in as $user - check Userid and Password") if ( $@ );

    logger( "Generating email." );
    
    # You must log in to a database session if GetUserEmail is used.
    $me = $session->GetUserEmail();
    $from = $me;
    $to = $me;
    $msg_subject = "SDSCC Daily PEC Report";
    $msg_body = "\nToday\'s PEC list is attached:\n\nHave a nice day! :)\n";
    
    # section boundary for multipart email
    $boundary = md5_hex(rand);
    
    # Get CSV attachment
    logger("csvfile is $csvfile");
    my $attachTextFile = $csvfile; 
    open(DAT, $attachTextFile) || die("Could not open text file!");
    my @textFile = <DAT>;
    ## Count lines, ala http://www.perlmonks.org/?node_id=28301
    while (<DAT>) {}
    my $dparCount = $. - 1;
    close(DAT);
    $msg_body .= "\nNumber of DPARs in report: $dparCount\n";
    if ($dparCount == 0) {
	logger("No DPARs. Exit without sending email.");
        exit 0;
    }
    ## Add HTML table
    $table = `ratlperl csv2html.pl headers < $csvfile`;
    ## Modify style attributes
    $table =~ s/<table>/<table border="1" cellpadding="5" cellspacing="0" style="background-color:#eefdfd;border:1px solid black;font-family:arial,helvetica,sans-serif;">/ ;
    ## Turn defect numbers into links to CqWeb interface
    $table =~ s/(MN[0-9]+)/<a href='https:\/\/mitelcqw.mitel.com\/cqweb\/restapi\/MITEL\/MN\/RECORD\/\1?format=HTML&noframes=true&recordType=Defect'>\1<\/a>/g;
    $msg_body .= $table;

    
    # Send email message via SMTP
    $smtp = Net::SMTP->new($main::smtpServer) or die "Cannot connect to SMTP server";
    
    $smtp->mail( $from )
      or die "SMTP failure ", $smtp->code(), " ", $smtp->message();
    $smtp->to( $to )
       or die "SMTP error adding 'TO': ", $smtp->code(), " ", $smtp->message();
    
    $smtp->data();
    $smtp->datasend("MIME-Version: 1.0\n");
    $smtp->datasend("Reply-To: $me\n");
    $smtp->datasend("Sender: $0\n");
    $smtp->datasend("Auto-Submitted: auto-generated\n");
    $smtp->datasend("Subject: $msg_subject\n");
    $smtp->datasend("From: $me\n");
    $smtp->datasend("To: $me\n");
    $smtp->datasend("Content-Type: multipart/alternative;\n\tboundary=\"$boundary\"\n\n");
    
    # Plaintext part
    $smtp->datasend("\n--$boundary\n");
    $smtp->datasend("Content-Type: text/plain; charset-ISO-8859-1\n\n");
    $smtp->datasend("Content-Disposition: quoted-printable\n");
    $smtp->datasend($msg_body);
    $smtp->datasend("\n");
    
    # Text Attachment
    $smtp->datasend("--$boundary\n");
    $smtp->datasend("Content-Type: application/text; name=\"$attachTextFile\"\n");
    $smtp->datasend("Content-Disposition: attachment; filename=\"$attachTextFile\"\n");
    $smtp->datasend("\n");
    $smtp->datasend("@textFile\n");
    
    # HTML part
    $smtp->datasend("\n--$boundary\n");
    $smtp->datasend("Content-Type: text/html; charset=utf-8\n\n");
    $smtp->datasend("<!doctype html public \"-//w3c//dtd html 4.0 transitional//en\">\n");
    $smtp->datasend("<html>\n");
    $smtp->datasend("<body>\n");
    $smtp->datasend("<table width=\"100%\" cellspacing=\"0\" cellpadding=\"1\" border=\"0\">\n");
    $smtp->datasend("<tr><td>\n");
    $smtp->datasend("<font face=\"sans-serif\" size=\"-1\">\n");
    $smtp->datasend("<p>\n");
    $smtp->datasend("<p>\n");
    $smtp->datasend($msg_body."\n");
    $smtp->datasend("</font></td></tr></table>\n");
    $smtp->datasend("</body>\n");
    $smtp->datasend("</html>\n");
    
    # End of message
    $smtp->datasend("\n--$boundary--\n");
    $smtp->dataend()
      or die "SMTP failure ", $smtp->code(), " ", $smtp->message();
    $smtp->quit;
    
    # Release CQ Session
    CQSession::Unbuild($session); 
    
    exit 0;
}
