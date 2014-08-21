use Module::Build;

my $build = Module::Build->new
    (
     module_name => 'CPAN::Mini::Tested',
     license => 'perl',
     requires => {
       'perl'                       => '5.6.1',
       'base'                       => 0,
       'Cache::Simple::TimedExpiry' => 0.22,
       'CPAN::Mini'                 => 0.32,
       'DBI'                        => 0,
       'DBD::SQLite2'               => 0,
       'File::Basename'             => 0,
       'File::Spec::Functions'      => 0,
       'LWP::Simple'                => 0,
       'Regexp::Assemble'           => 0.06,
     },
     recommends => {
     },
     build_requires => {
       'Test::More'                 => 0,
     },
     conflicts      => {
     },
     create_makefile_pl => 'traditional',
     create_readme      => 0,
     dist_author        => 'Robert Rothenberg <rrwo at cpan.org>',
     sign               => 1,
);

$build->create_build_script;
