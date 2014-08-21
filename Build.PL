use Module::Build;

my $build = Module::Build->new
    (
     module_name => 'CPAN::Mini::Tested',
     license => 'perl',
     requires => {
       'perl'                       => '5.6.1',
       'base'                       => 0,
       'File::Basename'             => 0,
       'File::Spec::Functions'      => 0,
       'CPAN::Mini'                 => 0.321,
       'DBI'                        => 0,
       'DBD::SQLite'                => '< 1.00',
       'LWP::Simple'                => 0,
     },
     recommends => {
     },
     build_requires => {
     },
     create_makefile_pl => 'traditional',
     create_readme      => 1,
     dist_author        => 'Robert Rothenberg <rrwo at cpan.org>',
     sign               => 1,
);

$build->create_build_script;
