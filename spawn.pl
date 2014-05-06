#!/usr/bin/perl

use utf8;


use Encode qw(encode);
use MIME::Base64;

use Net::Curl::Easy qw(:constants);
use Net::Curl::Form qw(:constants);

my $id = shift;

print "ID: $id\n";

print "\n\n\n";
open FILE, "<examplescript.sh";
my $unencdata = do { local $/; <FILE> };

my $encdata = encode('UTF-8', $unencdata, Encode::LEAVE_SRC | Encode::FB_CROAK);

print "ENCODED DATA:\n";
print $encdata;

my $data = $encdata;

my $url = "http://127.0.0.1:8080/spawn/$id";

print "CURL DRITT\n";

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

