use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'          => 'CORBA::XS',
    'VERSION_FROM'  => 'lib/CORBA/XS.pm',
    'ABSTRACT'      => 'IDL compiler to extension interface between Perl and C code',
    'PREREQ_PM'     => {
                        'CORBA::IDL'    => 2.60,
                        'CORBA::C'      => 2.60,
                        'CORBA::Perl'   => 0.40,
    },
    'INSTALLDIRS'   => 'site',
    'PM'            => {
                        'lib/CORBA/XS.pm'                   => '$(INST_LIBDIR)/XS.pm',
                        'lib/CORBA/XS/CVisitor.pm'          => '$(INST_LIBDIR)/XS/CVisitor.pm',
                        'lib/CORBA/XS/CdrCVisitor.pm'       => '$(INST_LIBDIR)/XS/CdrCVisitor.pm',
                        'lib/CORBA/XS/SkeletonCVisitor.pm'  => '$(INST_LIBDIR)/XS/SkeletonCVisitor.pm',
                        'lib/CORBA/XS/StubCVisitor.pm'      => '$(INST_LIBDIR)/XS/StubCVisitor.pm',
                        'lib/CORBA/XS/StubPerlVisitor.pm'   => '$(INST_LIBDIR)/XS/StubPerlVisitor.pm',
                        'C/corba.c'                         => '$(INST_LIBDIR)/XS/corba.c',
                        'C/corba.h'                         => '$(INSTALLARCHLIB)/CORE/corba.h',
                        'C/cdr.h'                           => '$(INSTALLARCHLIB)/CORE/cdr.h',
    },
    'EXE_FILES'     => [ 'bin/idl2xs_c' ],
    'AUTHOR'        => "Francois PERRAD (francois.perrad\@gadz.org)",
    'dist'          => {
                        'COMPRESS'      => 'gzip',
                        'SUFFIX'        => '.gz',
    },
);

