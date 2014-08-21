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

our $VERSION = '0.11';

sub _dbh {
  my $self = shift;
  return $self->{test_db};
}

sub _sth {
  my $self = shift;
  return $self->{test_db_sth};
}

sub _connect {
  my ($self, $database)  = @_;

  $database ||= $self->{test_db_file};

  $self->{test_db} = DBI->connect(
    "DBI:SQLite:dbname=".$database, "", "", {
      RaiseError => 1,
      %{$self->{test_db_conn} || { }},
    },
  ) or die "Unable to connect: ", $DBI::errstr;

  $self->{test_db_sth} =
    $self->_dbh->prepare( qq{
      SELECT COUNT(id) FROM reports
      WHERE action='PASS' AND distversion=? AND platform=?
  }) or die "Unable to create prepare statement: ", $self->_dbh->errstr;

  return 1;
}


sub _disconnect {
  my $self = shift;
  if ($self->_dbh) {
    $self->_sth->finish if ($self->_sth);
    $self->_dbh->disconnect;
  }
  return 1;
}

sub file_allowed {
  my ($self, $file) = @_;
  return (basename($file) eq 'testers.db') ? 1 :
    CPAN::Mini::file_allowed($self, $file);
}

sub mirror_indices {
  my $self = shift;

  $self->{test_db_file} ||= catfile($self->{local}, 'testers.db');
  my $local_file = $self->{test_db_file};

  # test_db_age < 0, do not update it

  my $test_db_age = $self->{test_db_age};
     $test_db_age = 1, unless (defined $test_db_age);

  if ( ($self->{force}) || (($test_db_age >= 0) &&
       (-e $local_file) && ((-M $local_file) > $test_db_age)) ){
    $self->trace('testers.db');
    my $db_src = $self->{test_db_src} ||
      'http://testers.cpan.org/testers.db';
    my $status = mirror($db_src, $local_file);

    if ($status == RC_OK) {
      $self->trace(" ... updated\n");
    } elsif ($status == RC_NOT_MODIFIED) {
      $self->trace(' ... up to date\n');
    } else {
      warn "\n$db_src: $status\n";
      return;
    }

  }
  $self->_connect() if (-r $local_file);

  return CPAN::Mini::mirror_indices($self);
}

sub clean_unmirrored {
  my $self = shift;
  $self->_disconnect();
  return CPAN::Mini::clean_unmirrored($self);
}

sub _check_db {
  my ($self, $distver, $arch) = @_;

  $self->_sth->execute($distver, $arch);
  my $row = $self->_sth->fetch;

  if ($row) { return $row->[0]; } else { return 0; }
}


sub _passed {
  my ($self, $path) = @_;

  # Test results are cached because the filter routine is called
  # several times for each module, at least in CPAN::Mini 0.32

  if (exists $self->{test_db_passed}->{$path}) {
    return $self->{test_db_passed}->{$path};
  }

  $self->{test_db_passed}->{$path} = 0;

  my $distver = basename($path);
  $distver =~ s/\.(tar\.gz|tar\.bz2|zip)$//;

  $self->{test_db_arch} ||= $Config{archname};

  if (ref($self->{test_db_arch}) eq 'ARRAY') {
    my @archs = @{ $self->{test_db_arch} };
    while ( (!$self->{test_db_passed}->{$path}) &&
	    (my $arch = shift @archs) ) {
      $self->{test_db_passed}->{$path} +=
	$self->_check_db($distver, $arch);
    }
  }
  else {
    $self->{test_db_passed}->{$path} +=
      $self->_check_db($distver, $self->{test_db_arch});
  }

  return $self->{test_db_passed}->{$path};
}

sub _filter_module {
  my ($self, $args) = @_;
  return 1 unless $self->_passed($args->{path});
  return CPAN::Mini::_filter_module($self, $args);
}

1;
__END__


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
from the CPAN Testers web site when updating indices, and it will
check if a distribution has passed tests in the specified platform
before applying other filtering rules to it.

The following additional options are supported:

=over

=item test_db_age

The maximum age of the local copy of the testers database, in
days. The default is C<1>.

When set to C<0>, or when the C<force> option is set, the latest copy
of the database will be downloaded no matter how old it is.

When set to C<-1>, a new copy will never be downloaded.

Note that the testers database can be quite large (over 15MB).

=item test_db_src

When to download the latest copy of the testers database. Defaults to
L<http://testers.cpan.org/testers.db>.

=item test_db_file

The location of the local copy of the testers database. Defaults to
the root directory of C<local>.

=item test_db_arch

The platform that tests are expected to pass.  Defaults to the current
platform C<$Config{archname}>.

If this is set to a list of platforms (an array reference), then it
expects tests on any one of those platforms to pass.  This is useful
for maintaining a mirror that supports multiple platforms, or in cases
where there tests are similar platforms are acceptable.

=item test_db_conn

Connection parameters for L<DBI>. In most cases these can be ignored.

=back

=head1 CAVEATS

This is a prototype module, which will need further work before using
in a production environment.

This module is only of use if there are active testers for your
platform.

Note that the lack of passing tests in the testers database does not
mean that a module will not run on your platform, only that it will
not be downloded. (There may be a lag of several days before test
results of the newest modules appear in the database.)  Likewise,
passing tests do not mean that a module will run on your platform.

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

