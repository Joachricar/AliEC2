#!/usr/bin/perl

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

my $alienHome = $ENV{ALIEN_HOME};
print "Using " . $alienHome . " as config directory\n";
my $ec2config = new Config::Simple($alienHome . '/ec2.conf');
my $running = 1;

my $db = AliEC2::SQLite->new();
my $ec2 = AliEC2::EC2->new($ec2config);


sub setAlive {
    my $id = shift; 
    my $msg = $db->setStatus($id);
    return ("Setting " . $id . " as alive: " . $msg);
};

sub deleteVM {
    my $id = shift;
    my $msg = $db->delete($id);
    return ("Deleting " . $id . ": " . $msg);
};

sub addVM {
    my $id = shift;
    my $job = shift;
    my $script = shift;
    my $msg = $db->add($id, $job);
    $ec2->spawnVirtualMachine($id, $job, $script);
    return ("Adding " . $id . " with jobID " . $job . ": " . $msg);
};

get '/alive/:id' => sub {
	my $id = param('id');
    setAlive($id);
};

get '/done/:id' => sub {
	my $id = param('id');
    deleteVM($id);
};

get '/spawn/:id/:job/:script' => sub {
	my $id = param('id');
	my $jid = param('job');
    addVM($id, $jid);
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