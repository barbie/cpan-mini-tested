package CPAN::Mini::Tested;
use base 'CPAN::Mini';

use 5.006;
use strict;
use warnings;

use Cache::Simple::TimedExpiry 0.22;

use Config;
use DBI;

use File::Basename qw( basename );
use File::Spec::Functions qw( catfile );

use LWP::Simple qw(mirror RC_OK RC_NOT_MODIFIED);

our $VERSION = '0.14';

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
      $self->trace(" ... up to date\n");
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

sub _reset_cache {
  my $self = shift;
  $self->{test_db_cache} = undef, if ($self->{test_db_cache});
  $self->{test_db_cache} = new Cache::Simple::TimedExpiry;
  $self->{test_db_cache}->expire_after($self->{test_db_cache_expiry} || 300);
}

sub _passed {
  my ($self, $path) = @_;

  # CPAN::Mini 0.36 no longer calls the filter routine multiple times
  # per module, but it will for packages with multiple modules. So we
  # cache the results, but only for a limited time.

  unless (defined $self->{test_db_cache}) {
    $self->_reset_cache;
  }

  if ($self->{test_db_exceptions}) {
    if (ref($self->{test_db_exceptions}) eq "ARRAY") {
      foreach my $re (@{ $self->{test_db_exceptions} }) {
	die "Expected Regexp",
	  unless (ref($re) eq 'Regexp');
	return 1, if ($path =~ $re);
      }
    }
    else {
      die "Expected Regexp",
	unless (ref($self->{test_db_exceptions}) eq 'Regexp');
      return ($path =~ $self->{test_db_exceptions});
    }
  }

  if ($self->{test_db_cache}->has_key($path)) {
    return $self->{test_db_cache}->fetch($path);
  }

  my $count = 0;

  my $distver = basename($path);
  $distver =~ s/\.(tar\.gz|tar\.bz2|zip)$//;

  $self->{test_db_arch} ||= $Config{archname};

  if (ref($self->{test_db_arch}) eq 'ARRAY') {
    my @archs = @{ $self->{test_db_arch} };
    while ( (!$count) && (my $arch = shift @archs) ) {
      $count += $self->_check_db($distver, $arch);
    }
  }
  else {
    $count += $self->_check_db($distver, $self->{test_db_arch});
  }

  $self->{test_db_cache}->set($path, $count);

  return $count;
}

sub _filter_module {
  my ($self, $args) = @_;
  return CPAN::Mini::_filter_module($self, $args)
    || (!$self->_passed($args->{path}));
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

=item test_db_exceptions

A Regexp or array of Regexps of module paths that will be included in
the mirror even if there are no passed tests for them.

Note that if these modules are already in the exclusion list, then
they will not be included.

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

=item test_db_cache_expiry

The number of seconds it caches database queries. Defaults to C<300>.

CPAN::Mini will check the filters multiple times for distributions
that contain multiple modules. (Older versions of CPAN::Mini will
check the filters multiple times per module.)  Caching the results
improves performance, but we need to maintain the results for very
long, nor do we want all of the results to use memory.

=back

=head1 CAVEATS

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

