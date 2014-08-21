=head1 NAME

CPAN::Mini::Tested - create a CPAN mirror using modules that have passed tests

=head1 SYNOPSYS

  use CPAN::Mini::Tested;

  CPAN::Mini::Tested->update_mirror(
   remote => "http://cpan.mirrors.comintern.su",
   local  => "/usr/share/mirrors/cpan",
   trace  => 1
  );

=head1 DESCRIPTION

This module is a subclass of L<CPAN::Mini> which checks the CPAN
Testers database for passing tests of that distribution on your
platform.  Distributions will only be downloaded if there are passing
tests.

The major differences are that it will download the F<testers.db> file
from the CPAN Testers web site when updating indices.

=head1 CAVEATS

This is a prototype module, which will need further work before using
in a production environment.

This module is only of use if there are active testers for your
platform.

Note that the lack of passing tests in the testers database does not
mean that a module will not run on your platform, only that it will
not be downloded. Likewise, passing tests do not mean that a module
will run on your platform.

=head1 AUTHOR

Robert Rothenberg <rrwo at cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005 by Robert Rothenberg.  All Rights Reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.3 or,
at your option, any later version of Perl 5 you may have available.

=head1 SEE ALSO

L<CPAN::Mini>

CPAN Testers L<http://testers.cpan.org>

=cut

package CPAN::Mini::Tested;
use base 'CPAN::Mini';

use 5.006;
use strict;
use warnings;

use Config;
use DBI;

use File::Basename qw( basename );
use File::Spec::Functions qw( catfile );

use LWP::Simple qw(mirror RC_OK RC_NOT_MODIFIED);

our $VERSION = '0.02';

sub _connect {
  my ($self, $database)  = @_;
  $self->{test_database} = DBI->connect(
    "DBI:SQLite:dbname=".$database, "", ""
  );

  $self->{test_handle} = $self->{test_database}->prepare( qq{
    SELECT COUNT(id) FROM reports
    WHERE action='PASS' AND distversion=? AND platform=?
  });

 # TODO: diagnostics 
}

sub _disconnect {
  my $self = shift;
  if ($self->{test_database}) {
    $self->{test_database}->disconnect;
    $self->{test_database} = undef;
  }
}

sub file_allowed {
  my ($self, $file) = @_;
  return (basename($file) eq 'testers.db') ? 1 :
    CPAN::Mini::file_allowed($self, $file);
}

sub mirror_indices {
  my $self = shift;

  my $local_file = catfile($self->{local}, 'testers.db');

  if ((-e $local_file) && ((-M $local_file) > 1)) {
    $self->trace('testers.db');
    my $status   = mirror('http://testers.cpan.org/testers.db', $local_file);
  }
  $self->_connect($local_file); # TODO: test connection created

  return CPAN::Mini::mirror_indices($self);
}

sub clean_unmirrored {
  my $self = shift;
  $self->_disconnect();
  return CPAN::Mini::clean_unmirrored($self);
}

sub _passed {
  my ($self, $path) = @_;
  if (exists $self->{passed}->{$path}) {
    return $self->{passed}->{$path};
  }

  $self->{passed}->{$path} = 0;

  my $distver = basename($path);
  $distver =~ s/.tar.gz$//;

  $self->{test_handle}->execute($distver,$Config{archname});

  my $row = $self->{test_handle}->fetch;
  $self->{passed}->{$path} = $row->[0], if ($row);

  return $self->{passed}->{$path};
}

sub _filter_module {
  my ($self, $args) = @_;
  return 1 unless $self->_passed($args->{path});
  return CPAN::Mini::_filter_module($self, $args);
}

1;
__END__
