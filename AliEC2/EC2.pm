package AliEC2::EC2;

use VM::EC2;
use strict;
use warnings;

use Encode qw(decode);
use Dancer;
use Log::Log4perl qw< :easy >;
use Config::Simple;
use MIME::Base64;

setting log4perl => {
   tiny => 0,
   config => '
      log4perl.logger                      = DEBUG, OnFile, OnScreen
      log4perl.appender.OnFile             = Log::Log4perl::Appender::File
      log4perl.appender.OnFile.filename    = sample-debug.log
      log4perl.appender.OnFile.mode        = append
      log4perl.appender.OnFile.layout      = Log::Log4perl::Layout::PatternLayout
      log4perl.appender.OnFile.layout.ConversionPattern = [%d] [%5p] %m%n
      log4perl.appender.OnScreen           = Log::Log4perl::Appender::ScreenColoredLevels
      log4perl.appender.OnScreen.color.ERROR = bold red
      log4perl.appender.OnScreen.color.FATAL = bold red
      log4perl.appender.OnScreen.color.OFF   = bold green
      log4perl.appender.OnScreen.Threshold = ERROR
      log4perl.appender.OnScreen.layout    = Log::Log4perl::Layout::PatternLayout
      log4perl.appender.OnScreen.layout.ConversionPattern = [%d] >>> %m%n
   ',
};
setting logger => 'log4perl';

use Exporter qw(import);
our @EXPORT_OK = qw(new spawnVirtualMachine);

my $ec2config;

sub new {
	my ($class, $conf, %args) = @_;
	$ec2config = $conf;
	return bless { %args }, $class;
};

sub spawnVirtualMachine {
	my $self = shift;
	my $jobID = shift;
	my $script = shift;

	#error $ec2config->param('ec2_access_key');
	#error $ec2config->param('ec2_secret_key');
	#error $ec2config->param('ec2_url');
    
    my $id = "error";
    
    error "reading config file ".$ENV{ALIEN_HOME}."/ec2.conf";
	my $ec2config = new Config::Simple($ENV{ALIEN_HOME} . "/ec2.conf");
	
	error "Connecting to OpenStack";
	my $ec2 = VM::EC2->new(
		-access_key => $ec2config->param('ec2_access_key'), 
		-secret_key => $ec2config->param('ec2_secret_key'),
		-endpoint   => $ec2config->param('ec2_url'));

	if(!$ec2) {
		error "Can't connect to OS";
		return $id;
	}
	
	my $confImgType = $ec2config->param('image_type');
	
	my @images = $ec2->describe_images($confImgType);
	unless(@images) {
		error "EC2: " . $ec2->error;
		return $id;
	}

	my @runningInstances = $ec2->describe_instances({'tag:Role' => $ec2config->param('machine_role_tag')});
	my $numRunningInstances = @runningInstances;

	if($numRunningInstances >= $ec2config->param('limit_instances')) {
		# cleanup stopped instances?
		error "We're at max running instances";
		return $id;
	}
	
	my $userdata = decode('UTF-8', $script);
	
	error "USERDATA $userdata";
	
	# create and start a new instance
	# with the user data provided above.
	error "Starting instance of type: $confImgType";
	my @instances = $images[0]->run_instances(
			-instance_type => $ec2config->param('instance_type'),
			-min_count => 1,
			-max_count => 1,
			-security_group => $ec2config->param('security_group'),
			-key_name => $ec2config->param('key_name'),
			-user_data => $userdata);

    
    
	foreach(@instances) {
		$_->add_tag(Role=>$ec2config->param('machine_role_tag'));
		$id = $_->privateDnsName;
		error "Instance with id: $id started";
	}
	
	
	if(!@instances) {
		error "EC2 error $ec2->error_str";
		return $id;
	}
	
	return $id;
};

sub deleteVirtualMachine {
	my $self = shift;
	my $machineID = shift;
    
    error "reading config file ".$ENV{ALIEN_HOME}."/ec2.conf";
	my $ec2config = new Config::Simple($ENV{ALIEN_HOME} . "/ec2.conf");
	
	error "Connecting to OpenStack";
	my $ec2 = VM::EC2->new(
		-access_key => $ec2config->param('ec2_access_key'), 
		-secret_key => $ec2config->param('ec2_secret_key'),
		-endpoint   => $ec2config->param('ec2_url'));

	if(!$ec2) {
		error "Can't connect to OS";
		return 2;
	}

	my @runningInstances = $ec2->describe_instances({
	    'privateDnsName' => $machineID
	});
	
	my $num = @runningInstances;
	
	foreach(@runningInstances) {
	    if($_->privateDnsName eq $machineID) {
	        error "Found Instance ". $_->privateDnsName .". Deleting it.";
	        $ec2->terminate_instances($_);
	        return 0;
	    }
	}
	
	if( $num == 0 ) {
	    error "No such instance $machineID";
	    return 3;
	}
	
	error "An error occured while deleting $machineID";
	 
	return 1;
}

1;
























