use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'          => 'CORBA::XS',
    'VERSION_FROM'  => 'xs_c.pm',
    'ABSTRACT'      => 'IDL compiler to extension interface between Perl and C code',
    'PREREQ_PM'     => {
                        'CORBA::IDL::node'  => 2.40,
                        'CORBA::C::include' => 2.40,
                        'CORBA::Perl::cdr'  => 0,
    },
    'PM'            => {
                        'xs_c.pm'       => '$(INST_LIBDIR)/XS/xs_c.pm',
                        'c_cdr.pm'      => '$(INST_LIBDIR)/XS/c_cdr.pm',
                        'c_skel.pm'     => '$(INST_LIBDIR)/XS/c_skel.pm',
                        'c_stub.pm'     => '$(INST_LIBDIR)/XS/c_stub.pm',
                        'pl_stub.pm'    => '$(INST_LIBDIR)/XS/pl_stub.pm',
                        'C/corba.c'     => '$(INST_LIBDIR)/XS/corba.c',
                        'C/corba.h'     => '$(INSTALLARCHLIB)/CORE/corba.h',
                        'C/cdr.h'       => '$(INSTALLARCHLIB)/CORE/cdr.h'
    },
    'EXE_FILES'     => ['idl2xs_c.pl'],
    'AUTHOR'        => "Francois PERRAD (francois.perrad\@gadz.org)",
    'dist'          => {
                        'COMPRESS'      => 'gzip',
                        'SUFFIX'        => '.gz',
    },
);
