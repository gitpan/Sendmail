# Net::DNS::Sendmail.pm
#
# Copyright (c) 2005 Srikanth Penumetcha <srikanth@coreunix.com>. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

package Net::DNS::Sendmail;

require 5.001;

use strict;
use vars qw($VERSION @ISA);
use IO::Socket;
use Net::DNS;

$VERSION = "0.1";

@ISA = qw(Net::DNS);

sub new {
	my $self = shift;
	my $type = ref($self) || $self;
	$self = {};
	$self->{'emails'} = undef;
	$self->{'from'} = undef;
	$self->{'subject'} = undef;
	$self->{'data'} = undef;
	$self->{'verbose'} = undef;
	$self->{'domain'} = undef;
	bless $self, $type;
	return $self;
}

sub data {
	my $self = shift;
	$self->{'data'} .= shift;
	1;
}

sub from {
	my $self = shift;
	my $domain;
	$self->{'from'} = shift;
	if ( $self->{'from'} =~
		 m/\s*\<?\s*([0-9a-zA-Z_\-\.]*)\@([0-9a-zA-Z_\-\.]*)\s*\>?\s*/ ) {
	  $domain = $2;
	  if( ! $self->{'domain'} ) {
		$self->{'domain'} = $domain;
	  }
	}
	1;
}

sub senderdomain {
	my $self = shift;
	$self->{'domain'} = shift;
	1;
}

sub subject {
	my $self = shift;
	$self->{'subject'} = shift;
	1;
}

sub to {
	my $self = shift;
	my $emails = shift;
	my @emails = split/[\,\;]/, $emails; 
	my $nos;
	foreach ( @emails ) {
		if ( m/\s*\<?\s*([0-9a-zA-Z_\-\.]*)\@([0-9a-zA-Z_\-\.]*)\s*\>?\s*/ ) {
			push @{ $self->{'emails'}}, "$1\@$2";
			$nos++;
			print "user:--" . $1 . "--\t\tdomain:--" . $2 . "--\n" if $self->{'verbose'};
		}
	}
	return $nos;
}

sub verbose {
	my $self = shift;
	$self->{'verbose'} = 1;
	1;
}

sub sendmail {
	my $self = shift;
	my @mxhosts;
	my $line;
	my $HELLO;
	for my $email ( @{$self->{'emails'}} ) {
		$_ = $email;
		my ($user, $domain) = ($1, $2) if s/(.*)\@(.*)//o ;
		@mxhosts = $self->getmxhost($domain);
		for my $mxtry ( @mxhosts ) {
			print "email, $mxtry is doing this\n";
			if( ($HELLO = $self->__testhello($mxtry)) eq "HELO" ) {
				if($self->__sendmailSMTP($email, $mxtry)) {last;}
			} 
			elsif( $HELLO eq "EHLO" ) {
				if($self->__sendmailESMTP($email, $mxtry)) {last;}
			}
		}
  	}
}

sub __sendmailSMTP {
	my $self = shift;
	my $email = shift;
	my $mxtry = shift;
	my $line;
	my %mp;
	my $sock = new IO::Socket::INET(
		PeerAddr => $mxtry,
		PeerPort => 25,
		Proto => 'tcp') || print "Error creating socket: $!";
	select($line); $|=1;select(STDOUT);
	#$/ = "\r\n";
	$|++; 
	while($line = <$sock>) {
		if ( ($line !~ /^250 /) || ($line !~ /^354 /) ) {
			print $line if $self->{'verbose'};
		}
		if ( ($line =~ /250 .*$/) && $mp{mail} && $mp{rcpt} && $mp{data} &&
					$mp{mesg} ) {
		print $sock "QUIT\n";
		print "QUIT DONE\n" if $self->{'verbose'};
		return 1;
		}
		elsif ( ($line =~ /354 .*$/) && $mp{mail} && $mp{rcpt} && $mp{data} ) {
		print $sock "From: $self->{'from'}\r\n";
		print $sock "To: $email\r\n";
		print $sock "Subject: $self->{'subject'}\r\n\r\n";
		print $sock " $self->{'data'}\r\n";
		print $sock ".\r\n";
		print "MESSAGE DONE\n" if $self->{'verbose'};
		$mp{mesg} = 1;
		}
		elsif ( ($line =~ /250 .*$/) && $mp{mail} && $mp{rcpt}  ) {
		print $sock "DATA\r\n";
		print "DATA DONE\n" if $self->{'verbose'};
		$mp{data} = 1;
		}
		elsif ( ($line =~ /250 .*$/i) && $mp{mail} ) {
		print $sock "RCPT TO: <$email>\r\n";
		print "RCPT DONE\n" if $self->{'verbose'};
		$mp{rcpt} = 1;
		}
		elsif ( $line =~ /250 .*$/ ) {
		print $sock "MAIL FROM:<$self->{'from'}>\r\n";
		print "MAIL DONE\n" if $self->{'verbose'};
		$mp{mail} = 1;
		}
		elsif ( $line =~ /220 .*$/ ) {
		print $sock "HELO $self->{'domain'}\r\n";
		undef %mp;
		}
		else {
			#do nothing
		}
		undef $line;
	}
	return undef;
}

sub __sendmailESMTP {
	my $self = shift;
	my $email = shift;
	my $mxtry = shift;
	my $line;
	my %mp;
	my $sock = new IO::Socket::INET(
		PeerAddr => $mxtry,
		PeerPort => 25,
		Proto => 'tcp') || print "Error creating socket: $!";
	select($line); $|=1;select(STDOUT);
	#$/ = "\r\n";
	$|++; 
	while($line = <$sock>) {
		if ( ($line !~ /^250 /) || ($line !~ /^354 /) ) {
			print $line if $self->{'verbose'};
		}
		if ( ($line =~ /250 .*$/) && $mp{mail} && $mp{rcpt} && $mp{data} &&
					$mp{mesg} ) {
		print $sock "QUIT\n";
		print "QUIT DONE\n" if $self->{'verbose'};
		return 1;
		}
		elsif ( ($line =~ /354 .*$/) && $mp{mail} && $mp{rcpt} && $mp{data} ) {
		print $sock "From: $self->{'from'}\r\n";
		print $sock "To: $email\r\n";
		print $sock "Subject: $self->{'subject'}\r\n\r\n";
		print $sock " $self->{'data'}\r\n";
		print $sock ".\r\n";
		print "MESSAGE DONE\n" if $self->{'verbose'};
		$mp{mesg} = 1;
		}
		elsif ( ($line =~ /250 .*$/) && $mp{mail} && $mp{rcpt}  ) {
		print $sock "DATA\r\n";
		print "DATA DONE\n" if $self->{'verbose'};
		$mp{data} = 1;
		}
		elsif ( ($line =~ /250 .*$/i) && $mp{mail} ) {
		print $sock "RCPT TO: <$email>\r\n";
		print "RCPT DONE\n" if $self->{'verbose'};
		$mp{rcpt} = 1;
		}
		elsif ( $line =~ /250 .*$/ ) {
		print $sock "MAIL FROM:<$self->{'from'}>\r\n";
		print "MAIL DONE\n" if $self->{'verbose'};
		$mp{mail} = 1;
		}
		elsif ( $line =~ /220 .*$/ ) {
		print $sock "HELO $self->{'domain'}\r\n";
		undef %mp;
		}
		else {
			#do nothing
		}
		undef $line;
	}
	return undef;
}

# Find which EHLO or HELO works.
sub __testhello {
   my $self = shift;
   my $mxtry = shift;
   my $line;
   my $HELLO;
   my %mp;
	my $sock = new IO::Socket::INET(
		PeerAddr => $mxtry,
		PeerPort => 25,
		Proto => 'tcp') || print "Error creating socket: $!";
	select($line); $|=1;select(STDOUT);
	#$/ = "\r\n";
	$|++; 
   while ( $line = <$sock> ) {
	if ( ($line !~ /^220 /) || ($line !~ /^250 /) ) {
		print $line;
	}
	if ( ($line =~ /^250 /) && $mp{EHLO}  ) {
		$HELLO = "EHLO";
		last;
	}
	elsif ( ($line =~ /^250 /) && $mp{HELO}  ) {
		$HELLO = "HELO";
		last;
	}

	if( print $sock "EHLO $self->{'domain'}\r\n" ) {
		$mp{EHLO} = 1;
		undef $mp{HELO};
	}
	elsif( print $sock "HELO $self->{'domain'}\r\n" ) {
		$mp{HELO} = 1;
		undef $mp{EHLO};
	}
	undef $line;
   }
   return $HELLO;
}

sub getmxhost {
  my $self = shift;
  my $name = shift;
  my $res  = Net::DNS::Resolver->new;
  my @mx   = mx($res, $name);
  my @tmx;
  if (@mx) {
      foreach my $rr (@mx) {
          print $rr->preference, "-- --", $rr->exchange, "\n" if $self->{'verbose'};
			push @tmx, $rr->exchange;
      }
  } else {
      warn "Can't find MX records for $name: ", $res->errorstring, "\n";
  }
	return @tmx;
}

1;

__END__

=head1 NAME

Net::DNS::Sendmail - Simple Mail Transfer Mail Client with MX lookup.
		Which will basically act as a primitive sendmail MTA.

=head1 SYNOPSIS

	use Net::DNS::Sendmail;

	#  Constructors
	$smtp = Net::DNS::Sendmail->new();
	$smtp->to("john\@gmail.com, mary\@yahoo.com, goliath\@hotmail.com");
	$smtp->from("srikanth\@cpan.org");
	$smtp->subject("This is the subject line.");
	$smtp->data("This allows for sending single or multiple emails\n " .
		directly to sendmail servers.");
	$smtp->data(" This program runs directly on the public domain just like"); 
	$smtp->data(" sendmail.");	
	$smtp->sendmail();

=head1 DESCRIPTION

This module implements a client interface to the SMTP and EMSMTP ( as mentioned in
RFC821 and RFC2821) servers which allow you to use it as a SMTP/ESMTP client.
This module connects directly to Yahoo/Hotmail/Gmail servers and 
delivers the mail without the need for intermediate Mail Transfer Agents(MTA) like
sendmail(L<sendmail.org>).

A new Net::DNS::Sendmail object must be created with the I<new> method. Once
this has been done then the to, from, subject and data sections of an
email are created with the following methods using the object:


=head1 Examples:

This example sends and email to krishna@bharat.com

	#!/usr/local/bin/perl  -w
	
	use Net::DNS::Sendmail;

	$smtp = Net::DNS::Sendmail->new();
	$smtp->to( 'krishna@bharat.com' );
	$smtp->from( 'rama@ramayana.com' );
	$smtp->subject( "This is the great treaty\n");
	$smtp->data("This the story of the great Krishna in Maha Bharat and, ");
	$smtp->data("Rama in The Ramayana.\n");
	$smtp->sendmail();

This example sends emails to both krishna@bharat.com and rama@ramayana.com.

	#!/usr/local/bin/perl  -w
	
	use Net::DNS::Sendmail;

	$smtp = Net::DNS::Sendmail->new();
	$smtp->to('krishna@bharat.com,rama@ramayana.com' );
	$smtp->from( 'bhrama@mydomain.com' );
	$smtp->senderdomain( 'bhrama@mydomain.com' );
	$smtp->subject( "This is the great treaty\n");
	$smtp->data("This the story of the great Krishna in Maha Bharat and, ");
	$smtp->data("Rama in The Ramayana.\n");
	$smtp->sendmail();


=head1 METHODS

Unless otherwise stated all methods return either a I<true> or I<false>
value, with I<true> meaning that the operation was a success. When a method
states that it returns a value, failure will be returned as I<undef> or an
empty list.


=item to( <email-address> )

This sets the remote email to whom to deliver the message to and the 
<email-address> is replaced with the destination email address or addresses.
If more than one email address needs to be given, please seperate them with a comma.

=item B<Note:>
When using single quote do not escape the @ symbol.  

=item from( <email-address> )

This sets the from whom the message is being sent from. Only one email address
should be specified here.

=item subject( <email-subject> )

This sets the subject of the email message that is being sent.

=item data( <message-content> )

This sets the email message content that is being sent to the receiver.

=item sendmail()

This finally sends the email to the mentioned email address or addresses
after all the above to(), from(), subject() and data() methods have been called.

=item senderdomain( <domain-name> )

This sets the domain for EHLO commands for some of the SMPT/ESMPT servers which
check whether the from address domain is the same as the domain the email is being
is sent from for SPAM protection reasons. Replace <domain-name> with the domain
name from where this program is being run from. eg.
$smtp->senderdomain('yahoo.com') 

=item verbose();

If this method is called before the all of the above methods, the verbose 
information is printed to STDOUT.

=head1 INSTALLATION

To install this module type the following:

   perl Makefile.PL
   make
   make test
   make install

=head1 DEPENDENCIES

This module requires these other modules and libraries:

  IO::Socket
  Net::DNS


=head1 MAILINGLIST:

http://www.coreunix.com/corebb/index.php

http://www.coreunix.com/opensource/sendmail

=head1 AUTHOR

Srikanth Penumetcha, E<lt>srikanth@coreunix.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005 by Srikanth Penumetcha

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
