package AliEn::LQ::EC2;

use lib "/usr/local/share/perl5/";
use lib "/usr/local/lib64/perl5/";
use VM::EC2;
use MIME::Base64;
use AliEn::LQ;
use AliEn::Config;
use Config::Simple;

@ISA = qw( AliEn::LQ);
use strict;
use utf8;
use AliEn::Database::CE;
use Data::Dumper;

use Net::Curl::Easy qw(:constants);
use Net::Curl::Form qw(:constants);

sub initialize {
    my $self = shift;    
    $self->{LOCALJOBDB}=new AliEn::Database::CE or return;
    return 1;
}

sub submit {
    my $self        = shift;
    my $classad     = shift;
   	#my $executable  = shift;
    my $command   = join " ", @_;

	$self->info("reading config file ".$ENV{ALIEC2_HOME}. "/ec2.conf");
	my $ec2config = new Config::Simple($ENV{ALIEC2_HOME} . "/ec2.conf");
	
	my $error = 0;
	$command =~ s/"/\\"/gs;

	my $name=$ENV{ALIEN_LOG};
  	$name =~ s{\.JobAgent}{};
  	$name =~ s{^(.{14}).*$}{$1};

	$self->info("possible job agent ID: " . $1);
	my $execute=$command;
  	$execute =~ s{^.*/([^/]*)$}{$ENV{HOME}/$1}; #env HOME

  	system ("cp",$command, $execute);
    my $message.="$self->{SUBMIT_ARG}
    " . $self->excludeHosts() . " 
    $execute\n";

    $self->info("USING $self->{SUBMIT_CMD}\nWith  \n$message");

	open FH, ">$ENV{HOME}/userdata.txt";
	my $agentStartupScript = $execute;
	my $document = do {
	   	local $/ = undef;
		open my $fh, "<", $agentStartupScript
			or die "could not open $agentStartupScript: $!";
		<$fh>;
	};

	my $confCtxFileBefore = $ec2config->param('context_file_before');
	my $confCtxFileAfter = $ec2config->param('context_file_after');

	# A context file is containing user data for a cern-vm instance,
	# contextualization data and a script which is executed at startup
	$self->info("Loading contextalization file: $confCtxFileBefore");
	if(!open CONTEXTFILEBEFORE, "<$confCtxFileBefore") {
		$self->info("Can't find context file: $confCtxFileBefore");
		return 1;
	}

	$self->info("Loading ctx-file after: $confCtxFileAfter");
	if(!open CONTEXTFILEAFTER, "<$confCtxFileAfter") {
		$self->info("Can't fint context file(after): $confCtxFileAfter");
		return 1;
	}

	my $userdata = do { local $/; <CONTEXTFILEBEFORE> };
	$userdata .= $document . "\n";
	$userdata .= do { local $/; <CONTEXTFILEAFTER>};
	close CONTEXTFILEBEFORE;
	close CONTEXTFILEAFTER;	
	
	print FH $userdata;
	close FH;
	my $encdata = encode('UTF-8', $userdata, Encode::LEAVE_SRC | Encode::FB_CROAK);

	my $data = $encdata;

	my $url = "http://127.0.0.1:8080/spawn/$id";

	my $curl = new Net::Curl::Easy();

	$curl->setopt(CURLOPT_VERBOSE, 1);
	$curl->setopt(CURLOPT_NOSIGNAL, 1);
	$curl->setopt(CURLOPT_HEADER, 1);
	$curl->setopt(CURLOPT_TIMEOUT, 10);
	$curl->setopt(CURLOPT_URL, $url);

	my $curlf = new Net::Curl::Form();
	$curlf->add(CURLFORM_COPYNAME ,=> 'script', CURLFORM_COPYCONTENTS ,=> "$data");
	$curl->setopt(CURLOPT_HTTPPOST, $curlf);
		
	$curl->perform();
	
    return 0;
}

sub kill {
    my $self    = shift;
    my $queueid = shift;

    $self->info("test kill");	
    return "asd";
}

sub getBatchId {
   my $self=shift;
   return $self->{LAST_JOB_ID};
}

sub getStatus {
    return 'QUEUED';
}

sub getOutputFile {
    my $self = shift;
    my $queueId = shift;
    my $output = shift;
    
    open OUTPUT, "/tmp/tmpOutput";
    my @data = <OUTPUT>;
    close OUTPUT;

    return join("",@data);
}

sub getAllBatchIds {
    my @queuedJobs = (); 
    print "The queuedJobs are @queuedJobs\n";
    return @queuedJobs;
}

sub getNumberRunning() {
    my $self = shift;
    return $self->getAllBatchIds();
}

sub getContactByQueueID {
    my $self = shift;
    my $queueId = shift;
    my $info = $self->{LOCALJOBDB}->query("SELECT batchId FROM JOBAGENT where jobId=?", undef, {bind_values=>[$queueId]});
    my $batchId = (@$info)[0]->{batchId};
    $self->info("The job $queueId run in the job $batchId");
    return $batchId;
}
