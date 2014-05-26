#!/usr/bin/perl
# userdata 169.254.169.254/latest/user-data
use strict;
use warnings;

use Dancer;
use Config::Simple;

use AliEC2::SQLite;
use AliEC2::EC2;
use MIME::Base64;

use threads;
use Log::Log4perl qw< :easy >;

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


#set server => "192.168.32.1";
set port => 8080;

my $alienHome = $ENV{ALIEN_HOME};
print "Using " . $alienHome . " as config directory\n";
my $ec2config = new Config::Simple($alienHome . '/ec2.conf');
my $running = 1;

my $db = AliEC2::SQLite->new();
my $ec2 = AliEC2::EC2->new($ec2config);


sub setAlive {
    my $id = shift; 
    my $msg = $db->setStatus($id);
    error "$id is alive";
    return ("Setting " . $id . " as alive: " . $msg);
};

sub deleteVM {
    my $id = shift;
    my $msg = $db->delete($id);
    
    if($ec2->deleteVirtualMachine($id) == 0) {
        error "$id deleted";
    }
    else {
        error "couldn't delete $id";
    }
    
    return ("Deleting " . $id . ": " . $msg);
};

sub addVM {
    my $job = shift;
    my $script = shift;
    my $msg = "";
    
    if($db->existJobID($job) == 1) {
        #ignoring this for now.
		#error "Job id exist. ignoring";
        #return ("ERROR Job ID exist");
    }
    
    my $id = $ec2->spawnVirtualMachine($job, $script);
    $msg = $db->add($id, $job);
    
    if($id eq "error") {
        $msg = "Error starting instance";
    }
    return ("Adding " . $id . " with jobID " . $job . ": " . $msg);
};

get '/alive/:id' => sub {
	my $id = param('id');
    setAlive($id);
};

get '/done/:id' => sub {
	my $id = param('id');
	error "$id is done";
    deleteVM($id);
};

post '/spawn/:job' => sub {
	my $jid = param('job');
	
	my $script = param('script');
	
	print $script;
    addVM($jid, $script);
};

threads->create(sub {
	my $db = AliEC2::SQLite->new();
    while ( $running ) {
        sleep($ec2config->param('check_interval'));
        error "Looking for dead VMs";

        while((my $machine = $db->nextDeadMachine()) ne 0) {
        	error "$machine is dead. Killing it.";
        	deleteVM($machine);
        }
    }
});

dance;
$running = 0;
$db->end();
