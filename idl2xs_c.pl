#!/usr/bin/perl -w

use strict;
use CORBA::IDL::parser30;
use CORBA::IDL::symbtab;
# visitors
use CORBA::IDL::repos_id;
use CORBA::C::literal;
use CORBA::C::name;
use CORBA::C::include;
use CORBA::C::type;
use CORBA::XS::c_skel;
use CORBA::XS::c_stub;
use CORBA::XS::xs_c;
use CORBA::Perl::name;
use CORBA::Perl::literal;
use CORBA::XS::pl_stub;

my $parser = new Parser;
$parser->YYData->{verbose_error} = 1;		# 0, 1
$parser->YYData->{verbose_warning} = 1;		# 0, 1
$parser->YYData->{verbose_info} = 1;		# 0, 1
$parser->YYData->{verbose_deprecated} = 0;	# 0, 1 (concerns only version '2.4' and upper)
$parser->YYData->{symbtab} = new CORBA::IDL::Symbtab($parser);
my $cflags = '-D__idl2xs_c';
if ($Parser::IDL_version lt '3.0') {
	$cflags .= ' -D_PRE_3_0_COMPILER_';
}
if ($^O eq 'MSWin32') {
	$parser->YYData->{preprocessor} = 'cpp -C ' . $cflags;
#	$parser->YYData->{preprocessor} = 'CL /E /C /nologo ' . $cflags;	# Microsoft VC
} else {
	$parser->YYData->{preprocessor} = 'cpp -C ' . $cflags;
}
$parser->getopts("hi:J:vx");
if ($parser->YYData->{opt_v}) {
	print "CORBA::XS $CORBA::XS::xs_c::VERSION\n";
	print "CORBA::Perl $CORBA::Perl::cdr::VERSION\n";
	print "CORBA::C $CORBA::C::include::VERSION\n";
	print "CORBA::IDL $CORBA::IDL::node::VERSION\n";
	print "IDL $Parser::IDL_version\n";
	print "$0\n";
	print "Perl $] on $^O\n";
	exit;
}
if ($parser->YYData->{opt_h}) {
	use Pod::Usage;
	pod2usage(-verbose => 1);
}
$parser->Run(@ARGV);
$parser->YYData->{symbtab}->CheckForward();
$parser->YYData->{symbtab}->CheckRepositoryID();

if (exists $parser->YYData->{nb_error}) {
	my $nb = $parser->YYData->{nb_error};
	print "$nb error(s).\n"
}
if (        $parser->YYData->{verbose_warning}
		and exists $parser->YYData->{nb_warning} ) {
	my $nb = $parser->YYData->{nb_warning};
	print "$nb warning(s).\n"
}
if (        $parser->YYData->{verbose_info}
		and exists $parser->YYData->{nb_info} ) {
	my $nb = $parser->YYData->{nb_info};
	print "$nb info(s).\n"
}
if (        $parser->YYData->{verbose_deprecated}
		and exists $parser->YYData->{nb_deprecated} ) {
	my $nb = $parser->YYData->{nb_deprecated};
	print "$nb deprecated(s).\n"
}

if (        exists $parser->YYData->{root}
		and ! exists $parser->YYData->{nb_error} ) {
	$parser->YYData->{root}->visit(new CORBA::IDL::repositoryIdVisitor($parser));
	if (        $Parser::IDL_version ge '3.0'
			and $parser->YYData->{opt_x} ) {
		$parser->YYData->{symbtab}->Export();
	}
	$parser->YYData->{root}->visit(new CORBA::C::nameVisitor($parser));
	$parser->YYData->{root}->visit(new CORBA::C::literalVisitor($parser));
	$parser->YYData->{root}->visit(new CORBA::C::lengthVisitor($parser));
	$parser->YYData->{root}->visit(new CORBA::C::typeVisitor($parser));
	$parser->YYData->{root}->visit(new CORBA::C::incskelVisitor($parser, '', ''));
	$parser->YYData->{root}->visit(new CORBA::XS::CskeletonVisitor($parser));
	$parser->YYData->{root}->visit(new CORBA::XS::CstubVisitor($parser));
	$parser->YYData->{root}->visit(new CORBA::Perl::nameVisitor($parser));
	$parser->YYData->{root}->visit(new CORBA::Perl::literalVisitor($parser));
	$parser->YYData->{root}->visit(new CORBA::XS::PerlStubVisitor($parser));
	$parser->YYData->{root}->visit(new CORBA::XS::C_Visitor($parser));
}

__END__

=head1 NAME

idl2xs_c - IDL compiler to extension interface between Perl and C code

=head1 SYNOPSIS

idl2xs_c [options] I<spec>.idl

=head1 OPTIONS

All options are forwarded to C preprocessor, except -h -i -J -v -x.

With the GNU C Compatible Compiler Processor, useful options are :

=over 8

=item B<-D> I<name>

=item B<-D> I<name>=I<definition>

=item B<-I> I<directory>

=item B<-I->

=item B<-nostdinc>

=back

Specific options :

=over 8

=item B<-h>

Display help.

=item B<-i> I<directory>

Specify a path for import (only for version 3.0).

=item B<-J> I<directory>

Specify a path for Perl package importation (use I<package>;).

=item B<-v>

Display version.

=item B<-x>

Enable export (only for version 3.0).

=back

=head1 DESCRIPTION

B<idl2xs_c> is an alternative to B<h2xs> and B<XS> language when an B<IDL> interface is available.

B<idl2xs_c> parses the given input file (IDL) and generates :

=over 4

=item *
a Perl stub I<spec>.pm

(deals with CDR serialization, and autoload)

=item *
a C stub I<spec>.c

(deals with Perl API)

=item *
a C stub cdr_I<spec>.c

(deals with CDR serialization)

=item *
a include file I<spec>.h

(following the language C mapping rules)

=item *
a C skeleton skel_I<spec>.c0

=item *
Makefile.PL

=item *
Makefile

(from Makefile.PL)

=item *
test.pl

=item *
MANIFEST

=item *
Changes

=back

The files Makefile, Makefile.PL, Changes, MANIFEST, test.pl and I<spec>.c are
generated only if I<spec>.idl contains operation or attribute.

B<idl2xs_c> is a Perl OO application what uses the visitor design pattern.
The parser is generated by Parse::Yapp.

B<idl2xs_c> needs a B<cpp> executable.

B<idl2xs_c> needs CORBA::IDL and CORBA::C modules.

CORBA Specifications, including (IDL : Interface Language Definition and
CDR : Common Data Representation) and
C Language Mapping are available on E<lt>http://www.omg.org/E<gt>.

CORBA mapping for Perl [mapping.pod - Draft 1, 7 October 1999] comes with the package
CORBA::MICO or CORBA::ORBit.

Exceptions are implemented using the Error module.

=head1 TUTORIAL

=head2 EXAMPLE 1

The file Calc.idl describes the interface of a simple calculator.

First, run :

    idl2xs_c Calc.idl

Second, create skel_Calc.c from skel_Calc.c0 by completing each methode between tag
START_EDIT and STOP_EDIT :

    // IDL : long Add(in long val1, in long val2);

    CORBA_long
    Calc_Add(
        Calc _o,
        CORBA_long val1, // in (fixed length)
        CORBA_long val2, // in (fixed length)
        CORBA_Environment * _ev
    )
    {
    /* START_EDIT (Calc_Add) */
        return val1 + val2;
    /* STOP_EDIT (Calc_Add) */
    }

Third, build :

    make
    make test
    make install

Fourth, if you use Test::Unit, you can continue with :

    cd testunit
    testrunner suite_calc

Finally, using the extension module :

    use Calc;
    my $calc = new Calc();
    print $calc->Add(2, 3);

=head2 EXAMPLE 2

Now, a complex calculator with two IDL files.

Cplx.idl contains :

    module Cplx {
        struct Complex {
            float   re;
            float   im;
        };
    };

and CalcCplx.idl contains :

    #include "Cplx.idl"
    interface CalcCplx {
        Cplx::Complex Add(in Cplx::Complex val1, in Cplx::Complex val2);
        Cplx::Complex Sub(in Cplx::Complex val1, in Cplx::Complex val2);
    };

First, run :

    idl2xs_c Cplx.idl
    idl2xs_c CalcCplx.idl

Second, create skel_CplxCalc.c.

Third, build :

    make
    make test
    make install

=head2 EXAMPLE 3

Variante of a complex calculator with two IDL files.
This is another decomposition of IDL specification.

Cplx.idl is the same, CalcCplx.idl contains :

    #include "Cplx.idl"
    module Cplx {
        interface CalcCplx {
            Complex Add(in Complex val1, in Complex val2);
            Complex Sub(in Complex val1, in Complex val2);
        };
    };

The build process is the same.

=head1 SEE ALSO

cpp, perl, idl2html, idl2c

=head1 COPYRIGHT

(c) 2002-2004 Francois PERRAD, France. All rights reserved.

This program and all CORBA::XS modules are distributed
under the terms of the Artistic Licence.

=head1 AUTHOR

Francois PERRAD, francois.perrad@gadz.org

=cut

