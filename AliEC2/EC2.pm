package AliEC2::EC2;

use VM::EC2;
use strict;
use warnings;

use Dancer;
use Log::Log4perl qw< :easy >;
use Config::Simple;

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
	my $machineID = shift;
	my $jobID = shift;
	my $script = shift;

	#error $ec2config->param('ec2_access_key');
	#error $ec2config->param('ec2_secret_key');
	#error $ec2config->param('ec2_url');
    
    $self->info("reading config file ".$ENV{HOME}."/.alien/ec2config.conf");
	my $ec2config = new Config::Simple($ENV{HOME} . "/.alien/ec2config.conf");
	
	error "spawned $machineID for job $jobID";
};

sub deleteVirtualMachine {
	my $self = shift;
	my $machineID = shift;
	
	
}

1;
