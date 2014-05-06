package AliEn::LQ::OpenStack;

use lib "/usr/local/share/perl5/";
use lib "/usr/local/lib64/perl5/";
use VM::EC2;
use MIME::Base64;
use AliEn::LQ;
use AliEn::Config;
use Config::Simple;

@ISA = qw( AliEn::LQ);
use strict;
use AliEn::Database::CE;
use Data::Dumper;

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

	$self->info("reading config file ".$ENV{ALIEN_HOME}."/ec2.conf");
	my $ec2config = new Config::Simple($ENV{ALIEN_HOME} . "/ec2.conf");
	
	my $error = 0;
	$command =~ s/"/\\"/gs;

	my $name=$ENV{ALIEN_LOG};
  	$name =~ s{\.JobAgent}{};
  	$name =~ s{^(.{14}).*$}{$1};

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

	$self->info("Connecting to OpenStack");
	my $ec2 = VM::EC2->new(
		-access_key => $ec2config->param('ec2_access_key'), 
		-secret_key => $ec2config->param('ec2_secret_key'),
		-endpoint   => $ec2config->param('ec2_url'));

	if(!$ec2) {
		$self->info("Can't connect to OS");
		return 4;
	}

	$self->info("Submitting to openstack");
	my $confImgType = $ec2config->param('image_type');
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

	my @images = $ec2->describe_images($confImgType);
	unless(@images) {
		$self->info("EC2: " . $ec2->error);
		return 2;
	}

	close FH;

	my @runningInstances = $ec2->describe_instances({'tag:Role' => $ec2config->param('machine_role_tag')});
	my $numRunningInstances = @runningInstances;

	if($numRunningInstances >= $ec2config->param('limit_instances')) {
		# cleanup stopped instances?
		$self->info("We're at max running instances");
		return 5;
	}

	# create and start a new instance
	# with the user data provided above.
	$self->info("Starting instance of type: $confImgType");
	my @instances = $images[0]->run_instances(
			-instance_type => $ec2config->param('instance_type'),
			-min_count => 1,
			-max_count => 1,
			-security_group => $ec2config->param('security_group'),
			-key_name => $ec2config->param('key_name'),
			-user_data => $userdata);

	foreach(@instances) {
		$_->add_tag(Role=>$ec2config->param('machine_role_tag'));
	}
	
	
	if(!@instances) {
		$self->info($ec2->error_str);
		return 3;
	}

	$ec2->wait_for_instances(@instances);

	my $inst = $instances[0];
	$self->info("Instance started with IP: " . $inst->ipAddress);
    return 0;
}

sub kill {
    my $self    = shift;
    my $queueid = shift;

    $self->info("test kill");	
    return "DERP";
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
