
use Test;
BEGIN { plan tests => 1 };
use CPAN::Mini::Tested;
ok(1); # If we made it this far, we're ok.

__END__

# CPAN::Mini::Tested->update_mirror(
#   remote => "http://www.cpan.org",
#   local  => "/temp/cpan",
#   trace  => 1
#  );


