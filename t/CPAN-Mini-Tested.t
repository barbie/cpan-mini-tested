#!/usr/bin/perl

use strict;
use Test::More tests => 27;

use_ok('CPAN::Mini::Tested', 0.12);

my $self = {
  test_db_file => './t/mock.db',
  test_db_arch => 'PA-RISC1.1',
  test_db_conn => { RaiseError => 1, PrintError => 1, },
  trace        => 0,
};

bless $self, "CPAN::Mini::Tested";

ok($self->_connect);

ok($self->_filter_module({
  module  => 'FCGI',
  version => '0.48',
  path    => 'FCGI-0.48',
}), "module_filters skip not-pass");

ok(!$self->_passed('FCGI-0.48'));

ok(!$self->_filter_module({
  module  => 'HTML-EP-Explorer',
  version => '0.1004',
  path    => 'HTML-EP-Explorer-0.1004',
}), "module_filters skip not-pass");

ok($self->_passed('HTML-EP-Explorer-0.1004'));

$self->{test_db_arch}   = 'sun4-solaris';
$self->_reset_cache;

ok($self->_filter_module({
  module  => 'FCGI',
  version => '0.48',
  path    => 'FCGI-0.48',
}), "module_filters skip not-pass");

ok(!$self->_passed('FCGI-0.48'));

ok($self->_filter_module({
  module  => 'HTML-EP-Explorer',
  version => '0.1004',
  path    => 'HTML-EP-Explorer-0.1004',
}), "module_filters skip not-pass");

ok(!$self->_passed('HTML-EP-Explorer-0.1004'));

$self->{test_db_arch}   = [qw( sun4-solaris )];
$self->_reset_cache;

ok($self->_filter_module({
  module  => 'FCGI',
  version => '0.48',
  path    => 'FCGI-0.48',
}), "module_filters skip not-pass");

ok(!$self->_passed('FCGI-0.48'));

ok($self->_filter_module({
  module  => 'HTML-EP-Explorer',
  version => '0.1004',
  path    => 'HTML-EP-Explorer-0.1004',
}), "module_filters skip not-pass");

ok(!$self->_passed('HTML-EP-Explorer-0.1004'));

$self->{test_db_arch}   = [qw( sun4-solaris PA-RISC1.1 )];
$self->_reset_cache;

ok($self->_filter_module({
  module  => 'FCGI',
  version => '0.48',
  path    => 'FCGI-0.48',
}), "module_filters skip not-pass");

ok(!$self->_passed('FCGI-0.48'));

ok(!$self->_filter_module({
  module  => 'HTML-EP-Explorer',
  version => '0.1004',
  path    => 'HTML-EP-Explorer-0.1004',
}), "module_filters skip not-pass");

ok($self->_passed('HTML-EP-Explorer-0.1004'));

$self->{test_db_arch}   = 'NonExistentArch';
$self->_reset_cache;

ok($self->_filter_module({
  module  => 'FCGI',
  version => '0.48',
  path    => 'FCGI-0.48',
}), "module_filters skip not-pass");

ok(!$self->_passed('FCGI-0.48'));

ok($self->_filter_module({
  module  => 'HTML-EP-Explorer',
  version => '0.1004',
  path    => 'HTML-EP-Explorer-0.1004',
}), "module_filters skip not-pass");

ok(!$self->_passed('HTML-EP-Explorer-0.1004'));

$self->{test_db_arch}   = [qw( NonExistentArch PA-RISC1.1 )];
$self->_reset_cache;

ok($self->_filter_module({
  module  => 'FCGI',
  version => '0.48',
  path    => 'FCGI-0.48',
}), "module_filters skip not-pass");

ok(!$self->_passed('FCGI-0.48'));

ok(!$self->_filter_module({
  module  => 'HTML-EP-Explorer',
  version => '0.1004',
  path    => 'HTML-EP-Explorer-0.1004',
}), "module_filters skip not-pass");

ok($self->_passed('HTML-EP-Explorer-0.1004'));


ok($self->_disconnect);

1;

__END__

  CPAN::Mini::Tested->update_mirror(
    remote => "http://www.cpan.org",
    local  => "/temp/cpan",
    trace  => 1,
    module_filters => [
      qr/Acme/i,
    ],
    test_db_age => -1,
   );


