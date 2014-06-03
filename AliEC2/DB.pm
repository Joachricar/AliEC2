package AliEC2::DB;

use strict;
use warnings;

use Dancer;
use DBI;
use Log::Log4perl qw< :easy >;

use DateTime;
use DateTime::Duration;
use DateTime::Format::DBI;
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

=comment

Database
 + InstanceName Text
 + JobID Integer So we dont start multiple instances for one job
 + LastUpdate Timestamp
 + Status Text

=cut

use Exporter qw(import);
our @EXPORT_OK = qw(add delete exist setStatus getStatus);

my $dbh;
my $ec2config;

sub new {
    my ($class, $conf, %args) = @_;
	$ec2config = $conf;	    
	my $db_type = $ec2config->param('db_type');
	my $db_host = $ec2config->param('db_host') or '';
	my $db_name = $ec2config->param('db_name');
	my $db_user = $ec2config->param('db_user') or '';
	my $db_pass = $ec2config->param('db_pass') or '';

    $dbh = DBI->connect("dbi:$db_type:dbname=$db_name;host=$db_host","$db_user","$db_pass");
    $dbh->do("create table if not exists instances (
        InstanceName Text PRIMARY KEY,
        JobID Integer,
        Status Text,
        LastUpdate DATETIME DEFAULT CURRENT_TIMESTAMP
    );");
    
    return bless { %args }, $class;
};

sub add {
    my ($self, $id, $jobid) = @_;
    
    if($self->existVM($id)) {
        return "Instance exist";
    }
    
    if($self->existJobID($jobid)) {
        return "JobID exist";
    }
    
    if($dbh->do("insert into instances ('InstanceName', 'JobID', 'Status') values ('$id','$jobid','Spawned');")) {
        return "OK";
    }
    else {
        return "Error";
    }
};

sub delete {
    my ($self, $id) = @_;
    
    if($self->existVM($id)) {
        my $stmt = qq(delete from instances where InstanceName='$id');
        my $query = $dbh->prepare($stmt);
        my $rv = $query->execute();
        
        if($rv < 1) {
            return "An error occured: no rows deleted";
        }
        return "OK. Deleted";
    }
    return "No such instance";
};

sub existVM {
    my ($self, $id) = @_;
    
    my $stmt = qq(SELECT count(*) from instances where InstanceName='$id');
    my $query = $dbh->prepare($stmt);
    my $rv = $query->execute();
    my $rowcount = $query->fetchrow_array;
    
    if($rowcount == 0) {
        return 0;
    }
    
    return 1;
};

sub existJobID {
    my ($self, $id) = @_;
    
    my $stmt = qq(SELECT count(*) from instances where JobID='$id');
    my $query = $dbh->prepare($stmt);
    my $rv = $query->execute();
    my $rowcount = $query->fetchrow_array;
    
    if($rowcount == 0) {
        return 0;
    }
    
    return 1;
};

sub setStatusTo {
 
    my ($self, $id, $status) = @_;
    
    if($self->existVM($id)) {
        my $stmt = qq(update instances set Status='$status', LastUpdate=CURRENT_TIMESTAMP where InstanceName='$id');
        my $query = $dbh->prepare($stmt);
        my $rv = $query->execute();
        
        if($rv < 1) {
            return "An error occured: no rows updated";
        }
        return "OK. Updated";
    }
    return "No such instance";
}
sub setStatus {
    my ($self, $id) = @_;
    $self->setStatusTo($id, "Updating");
    return $self->setStatusTo($id, "Alive");
};

sub getStatus {
    my $id = @_;
};

sub end {
    $dbh->disconnect();
};

sub nextDeadMachine {
    my $self = shift;

    my $stmt = qq(select * from instances);
    my $query = $dbh->prepare($stmt);
    my $rv = $query->execute();

    while (my @data = $query->fetchrow_array()) {
        my $id = $data[0];
        my $interval = -1;
        my $time = DateTime->now();

        if($data[2] eq "Alive") {
            $interval = 120;
        }
        if($data[2] eq "Spawned") {
            $interval = 180;
        }

        if($interval == -1) {
            error "Something wrong with VM state of $id";
            return 0;
        }

        my $duration = DateTime::Duration->new(
            seconds => $interval
        );

        # my $dtf = DateTime::Format::DBI->new( $self->dbh );
        my $minUpdate = $time->subtract_duration($duration);
        my $dtf = DateTime::Format::DBI->new($dbh);
        my $dt2 = $dtf->parse_datetime($data[3]);

        my $cmp = DateTime->compare($minUpdate, $dt2);

        if($cmp > 0) {
            return $id;
        }
    }
    return 0;
}

1;
