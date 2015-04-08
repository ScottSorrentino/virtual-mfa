#!/usr/bin/perl
#
# Sample TOTP implementation (http://tools.ietf.org/html/rfc6238) as an
# exercise in creating an MFA for AWS account access without requiring a
# phone/app.
#
# Scott Sorrentino <scott@sorrentino.net>
#
# !! If you store secrets out in the open, you're gonna have a bad time !!
#
# When used as an MFA device, the expectation is that the script will be 
# encrypted, possibly as a self-executing GPG script, hence the use of
# /dev/tty below.
#

use Digest::SHA qw(hmac_sha1);
use IO::Select

$last   = 0;
$secret = "DEPOSIT_SECRET_HERE";

# Open TTY instead of STDIN since we expect to run this in a pipeline from
# GPG
open(TTY,"</dev/tty");
$stdin  = IO::Select->new(\*TTY);

while (1){
    if (time - $last >= 30){
	print "OTP: ".getTotp($secret)."\n";
	print "[ Will generate another in 30s.  Hit Enter to quit ]\n";
	$last = time;
    }
    if ($stdin->can_read(.5)){
	chomp($a=<TTY>);
	exit;
    }
}

# Borrowed from http://search.cpan.org/~danpeder/MIME-Base32-1.01/ so we
# don't need to require/install the module everywhere for one function.
sub decode_base32{
    $_ = shift;
    my( $l );

    tr|A-Z2-7|\0-\37|;
    $_=unpack('B*', $_);
    s/000(.....)/$1/g;
    $l=length;
    
    # pouzije pouze platnou delku retezce
    $_=substr($_, 0, $l & ~7) if $l & 7;
    
    $_=pack('B*', $_);
}

sub getTotp {
    my ($key,$interval) = @_;
    
    # Turn the key into a standard string, no spaces, all upper case
    $key = uc($key);
    $key =~ s/\ //g;
    
    # decode the key from base32
    my $key_decoded = decode_base32($key);
    
    # Read the time, and produce the 30 second slice
    my $time = int(time / 30) + $interval;
    
    # Pack the time to binary
    $time = chr(0) . chr(0) . chr(0) . chr(0) . pack('N*',$time);
    
    # hash the time with the key
    my $hmac = hmac_sha1 ($time,$key_decoded);
    
    # get the offset
    my $offset = ord(substr($hmac,-1)) & 0x0F;
    
    # use the offset to get part of the hash
    my $hashpart = substr($hmac,$offset,4);
    
    # get the first number
    my @val = unpack("N",$hashpart);
    my $value = $val[0];
    
    # grab the first 32 bits
    $value = $value & 0x7FFFFFFF;
    $value = $value % 1000000;

    # Pad w/leading zeroes
    return sprintf("%0.6d",$value);
}
