use strict;
use POSIX qw(ctime);

#
#			Interface Definition Language (OMG IDL CORBA v3.0)
#

use CORBA::Perl::cdr;

package CORBA::XS::PerlStubVisitor;

use base qw(CORBA::Perl::cdrVisitor);
use File::Basename;

# needs $node->{pl_name} $node->{pl_package} (PerlNameVisitor)

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self = {};
	bless($self, $class);
	my($parser) = @_;
	$self->{parser} = $parser;
	$self->{parser}->YYData->{modules} = [];
	$self->{srcname} = $parser->YYData->{srcname};
	$self->{srcname_size} = $parser->YYData->{srcname_size};
	$self->{srcname_mtime} = $parser->YYData->{srcname_mtime};
	$self->{symbtab} = $parser->YYData->{symbtab};
	$self->{client} = 1;
	$self->{use} = {};
	if (exists $parser->YYData->{opt_J}) {
		$self->{path_use} = $parser->YYData->{opt_J};
		$self->{path_use} =~ s/\//::/g;
		$self->{path_use} .= "::";
	} else {
		$self->{path_use} = "";
	}
	my $filename = basename($self->{srcname}, ".idl") . ".pm";
	$self->open_stream($filename);
	$self->{done_hash} = {};
	$self->{has_methods} = 0;
	$self->{pkg_modif} = 0;
	$self->{stringify} = 1;
	$self->{id} = 0;
	$self->{num_key} = 'num_pl_stub';
	return $self;
}

#
#	3.5		OMG IDL Specification
#

sub visitSpecification {
	my $self = shift;
	my($node) = @_;
	my $filename = $self->{srcname};
	$filename =~ s/^([^\/]+\/)+//;
	$filename =~ s/\.idl$//i;
	my $FH = $self->{out};
	$self->{pkg_modif} = 0;
	print $FH "#   This file was generated (by ",$0,"). DO NOT modify it.\n";
	print $FH "# From file : ",$self->{srcname},", ",$self->{srcname_size}," octets, ",POSIX::ctime($self->{srcname_mtime});
	print $FH "\n";
	print $FH "use strict;\n";
	print $FH "\n";
	print $FH "# Preloaded methods go here.\n";
	print $FH "\n";
	print $FH "package main;\n";
	print $FH "\n";
	print $FH "use CORBA::Perl::CORBA;\n";
	print $FH "use Carp;\n";
	print $FH "\n";
	foreach (@{$node->{list_decl}}) {
		$self->_get_defn($_)->visit($self);
		if ($self->{pkg_modif}) {
			$self->{pkg_modif} = 0;
			print $FH "package main;\n";
			print $FH "\n";
		}
	}
	if ($self->{has_methods}) {
		print $FH "package ",$filename,";\n";
		print $FH "\n";
		print $FH "use strict;\n";
		print $FH "use warnings;\n";
		print $FH "\n";
		print $FH "require DynaLoader;\n";
		print $FH "\n";
		print $FH "our \@ISA = qw(DynaLoader);\n";
		print $FH "\n";
		print $FH "our \$VERSION = '0.01';\n";
		print $FH "\n";
		print $FH "bootstrap ",$filename," \$VERSION;\n";
		print $FH "\n";
	}
	print $FH "1;\n";
	print $FH "\n";
	print $FH "#   end of file : ",$self->{filename},"\n";
	close $FH;
}

#
#	3.7		Module Declaration			(inherited)
#

#
#	3.8		Interface Declaration
#

sub visitRegularInterface {
	my $self = shift;
	my($node) = @_;
	if ($self->{srcname} eq $node->{filename}) {
		my $version;
		my $FH = $self->{out};
		$self->{pkg_modif} = 0;
		print $FH "#\n";
		print $FH "#   begin of interface ",$node->{pl_package},"\n";
		print $FH "#\n";
		print $FH "\n";
		print $FH "package ",$node->{pl_package},";\n";
		print $FH "\n";
		print $FH "use CORBA::Perl::CORBA;\n";
		print $FH "use Carp;\n";
		print $FH "\n";
		foreach (@{$node->{list_decl}}) {
			my $defn = $self->_get_defn($_);
			if (	   $defn->isa('Operation')
					or $defn->isa('Attributes') ) {
				next;
			}
			$defn->visit($self);
			if ($self->{pkg_modif}) {
				$self->{pkg_modif} = 0;
				print $FH "package ",$defn->{pl_package},";\n";
				print $FH "\n";
			}
		}
		print $FH "\n";
		if (keys %{$node->{hash_attribute_operation}}) {
			$self->{itf} = $node->{pl_name};
			$self->{repos_id} = $node->{repos_id};
			print $FH "######  methodes\n";
			print $FH "\n";
			print $FH "# constructor\n";
			print $FH "sub new {\n";
			print $FH "\tmy \$proto = shift;\n";
			print $FH "\tmy \$class = ref(\$proto) || \$proto;\n";
			print $FH "\tmy \$self = {};\n";
			print $FH "\tbless(\$self, \$class);\n";
			print $FH "\tmy \$this = shift;\n";
			print $FH "\t\$self->{_this} = \$this || 0;\n";
			print $FH "\treturn \$self;\n";
			print $FH "}\n";
			print $FH "\n";
			foreach (values %{$node->{hash_attribute_operation}}) {
				$self->_get_defn($_)->visit($self);
			}
			print $FH "\n";
		}
		print $FH "#\n";
		print $FH "#   end of interface ",$node->{pl_package},"\n";
		print $FH "#\n";
		print $FH "\n";
		$self->{pkg_modif} = 1;
	} else {
		$self->_insert_use($node->{filename});
	}
}

sub visitAbstractInterface {
	my $self = shift;
	my($node) = @_;
	if ($self->{srcname} eq $node->{filename}) {
		my $version;
		my $FH = $self->{out};
		print $FH "#\n";
		print $FH "#   begin of abstract interface ",$node->{pl_package},"\n";
		print $FH "#\n";
		print $FH "\n";
		print $FH "package ",$node->{pl_package},";\n";
		print $FH "\n";
		print $FH "use CORBA::Perl::CORBA;\n";
		print $FH "use Carp;\n";
		print $FH "\n";
		foreach (@{$node->{list_decl}}) {
			my $defn = $self->_get_defn($_);
			if (	   $defn->isa('Operation')
					or $defn->isa('Attributes') ) {
				next;
			}
			$defn->visit($self);
		}
		print $FH "\n";
		print $FH "#\n";
		print $FH "#   end of abstract interface ",$node->{pl_package},"\n";
		print $FH "#\n";
		print $FH "\n";
		$self->{pkg_modif} = 1;
	} else {
		$self->_insert_use($node->{filename});
	}
}

#
#	3.9		Value Declaration			(inherited)
#

#
#	3.10	Constant Declaration		(inherited)
#

#
#	3.11	Type Declaration			(inherited)
#

#
#	3.12	Exception Declaration		(inherited)
#

#
#	3.13	Operation Declaration
#

sub visitOperation {
	my $self = shift;
	my($node) = @_;
	$self->{has_methods} = 1;
	my $FH = $self->{out};
	print $FH "# ",$self->{itf},"::",$node->{pl_name},"\n";
	print $FH "sub ",$node->{pl_name}," {\n";
	print $FH "\tmy \$self = shift;\n";
	print $FH "\tmy \$_this = 0;\n";
	print $FH "\t\$_this = \$self->{_this} if (ref \$self and \$self->isa('",$node->{pl_package},"'));\n";
	foreach (@{$node->{list_param}}) {		# paramater
		if ($_->{attr} eq 'in') {
			print $FH "\tmy \$",$_->{pl_name}," = shift;\n";
			print $FH "\tcroak \"undefined parameter '",$_->{pl_name},"' in '",$node->{pl_name},"'.\\n\"\n";
			print $FH "\t\t\tunless (defined \$",$_->{pl_name},");\n";
		}
		if ($_->{attr} eq 'inout') {
			print $FH "\tmy \$r_",$_->{pl_name}," = shift;\n";
			print $FH "\tcroak \"undefined parameter '",$_->{pl_name},"' in '",$node->{pl_name},"'.\\n\"\n";
			print $FH "\t\t\tunless (defined \$r_",$_->{pl_name},");\n";
		}
	}
	print $FH "\n";
	print $FH "\tmy \$_is = '';\n";
	foreach (@{$node->{list_param}}) {		# paramater
		my $type = $self->_get_defn($_->{type});
		if      ($_->{attr} eq 'in') {
			print $FH "\t",$type->{pl_package},"::",$type->{pl_name},"__marshal";
				print $FH "(\\\$_is,\$",$_->{pl_name},");\n";
		} elsif ($_->{attr} eq 'inout') {
			print $FH "\t",$type->{pl_package},"::",$type->{pl_name},"__marshal";
				print $FH "(\\\$_is,\${\$r_",$_->{pl_name},"});\n";
		}
	}
	print $FH "\tmy \$_os = '';\n"
			unless (exists $node->{modifier});
	print $FH "\n";
	if (exists $node->{modifier}) {		# oneway
		print $FH "\t",$node->{pl_package},"::cdr_",$node->{pl_name},"(\$_this,\$_is);\n";
	} else {
		print $FH "\tmy \$_ret = ",$node->{pl_package},"::cdr_",$node->{pl_name},"(\$_this,\$_is,\$_os);\n";
		print $FH "\tif (\$_ret <= 0) {\n";
		print $FH "\t\tthrow CORBA::SystemException(\n";
		print $FH "\t\t\t\t_repos_id => 'IDL:CORBA/NO_MEMORY:1.0',\n";
		print $FH "\t\t\t\tminor     => 3,\n";
		print $FH "\t\t\t\tcompleted => CORBA::COMPLETED_MAYBE\n";
		print $FH "\t\t);\n";
		print $FH "\t}\n";
		print $FH "\tmy \$_offset = 0;\n";
		print $FH "\tmy \$_endian = 1;\n";
		print $FH "\tmy \$_status = CORBA::exception_type__demarshal(\\\$_os,\\\$_offset,\$_endian);\n";
		print $FH "\tif      (\$_status eq CORBA::NO_EXCEPTION) {\n";
		my $nb = 0;
		my $type = $self->_get_defn($node->{type});
		unless ($type->isa("VoidType")) {
			print $FH "\t\tmy \$_return = ";
				print $FH $type->{pl_package},"::",$type->{pl_name};
				print $FH "__demarshal(\\\$_os,\\\$_offset,\$_endian);\n";
			$nb ++;
		}
		foreach (@{$node->{list_param}}) {		# paramater
			$type = $self->_get_defn($_->{type});
			if (	   $_->{attr} eq 'inout'
					or $_->{attr} eq 'out' ) {
				print $FH "\t\tmy \$",$_->{pl_name}," = ";
					print $FH $type->{pl_package},"::",$type->{pl_name};
					print $FH "__demarshal(\\\$_os,\\\$_offset,\$_endian);\n";
				$nb ++ if ($_->{attr} eq 'out');
			}
		}
		foreach (@{$node->{list_param}}) {		# paramater
			if ($_->{attr} eq 'inout') {
				print $FH "\t\t\${\$r_",$_->{pl_name},"} = \$",$_->{pl_name},";\n";
			}
		}
		print $FH "\t\treturn";
		print $FH " " if ($nb > 0);
		print $FH "(" if ($nb > 1);
		my $first = 1;
		$type = $self->_get_defn($node->{type});
		unless ($type->isa("VoidType")) {
			print $FH "\$_return";
			$first = 0;
		}
		foreach (@{$node->{list_param}}) {		# paramater
			if ($_->{attr} eq 'out') {
				print $FH ", " unless ($first);
				print $FH "\$",$_->{pl_name};
				$first = 0;
			}
		}
		print $FH ")" if ($nb > 1);
		print $FH ";\n";
		print $FH "\t} elsif (\$_status eq CORBA::USER_EXCEPTION) {\n";
		print $FH "\t\tmy \$_exception_id = CORBA::string__demarshal(\\\$_os,\\\$_offset,\$_endian);\n";
		print $FH "\t\tif (0) {\n";
		foreach (@{$node->{list_raise}}) {
			my $defn = $self->_get_defn($_);
			print $FH "\t\t} elsif (\$_exception_id eq \"",$defn->{repos_id},"\") {\n";
			print  $FH "\t\t\tmy \$_value = ";
				print $FH $defn->{pl_package},"::",$defn->{pl_name};
				print $FH "__demarshal(\\\$_os,\\\$_offset,\$_endian);\n";
			print $FH "\t\t\tthrow ",$defn->{pl_package},"::",$defn->{pl_name},"(\n";
			print $FH "\t\t\t\t\t_repos_id => \$_exception_id,\n";
			print $FH "\t\t\t\t\t\%{\$_value}\n";
			print $FH "\t\t\t);\n";
		}
		print $FH "\t\t} else {\n";
		print $FH "\t\t\twarn \"unknown user exception \$_exception_id.\\n\";\n";
		print $FH "\t\t}\n";
		print $FH "\t} elsif (\$_status eq CORBA::SYSTEM_EXCEPTION) {\n";
		print $FH "\t\tmy \$_exception_id = CORBA::string__demarshal(\\\$_os,\\\$_offset,\$_endian);\n";
		print $FH "\t\tmy \$_minor_code_value = CORBA::unsigned_long__demarshal(\\\$_os,\\\$_offset,\$_endian);\n";
		print $FH "\t\tmy \$_completion_status = CORBA::completion_status__demarshal(\\\$_os,\\\$_offset,\$_endian);\n";
		print $FH "\t\tthrow CORBA::SystemException(\n";
		print $FH "\t\t\t\t_repos_id => \$_exception_id,\n";
		print $FH "\t\t\t\tminor     => \$_minor_code_value,\n";
		print $FH "\t\t\t\tcompleted => \$_completion_status\n";
		print $FH "\t\t);\n";
		print $FH "\t} else {\n";
		print $FH "\t\twarn \"reply status \$_status.\\n\";\n";
		print $FH "\t}\n";
	}
	print $FH "}\n";
	print $FH "\n";
}

#
#	3.14	Attribute Declaration		(inherited)
#

1;

