use strict;
use UNIVERSAL;

#
#			Interface Definition Language (OMG IDL CORBA v3.0)
#
#			C Language Mapping Specification, New Edition June 1999
#

package CORBA::XS::CskeletonVisitor;

use File::Basename;
use POSIX qw(ctime);

# needs $node->{c_name} (CnameVisitor) and $node->{c_arg} (CincludeVisitor)

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self = {};
	bless($self, $class);
	my ($parser, $prefix) = @_;
	$prefix = 'skel_' if (!defined $prefix);
#	$self->{prefix} = $prefix;
	$self->{prefix} = '';
	$self->{srcname} = $parser->YYData->{srcname};
	$self->{srcname_size} = $parser->YYData->{srcname_size};
	$self->{srcname_mtime} = $parser->YYData->{srcname_mtime};
	$self->{symbtab} = $parser->YYData->{symbtab};
	my $filename = $prefix . basename($self->{srcname}, ".idl") . ".c";
	$self->parse($filename);
	$self->open_stream($filename);
	$self->{done_hash} = {};
	$self->{num_key} = 'num_skel_c';
	return $self;
}

sub parse {
	my $self = shift;
	my ($filename) = @_;
	$self->{merge} = {};
	return unless ( -r $filename);
	open(IN, $filename)
			or die "can't open $filename ($!).\n";
	while (<IN>) {
		if (/\/\* START_EDIT (\(([^\)]+)\) )?\*\//) {
			my $key = $2 || $self->{srcname};
			my $code = "";
			while (<IN>) {
				last if (/\/\* STOP_EDIT/);
				$code .= $_;
			}
			$self->{merge}->{$key} = $code;
		}
	}
	close IN;
}

sub merge {
	my $self = shift;
	my ($key) = @_;
	$key = $self->{srcname} unless ($key);
	if (exists $self->{merge}->{$key}) {
		return $self->{merge}->{$key};
	} else {
		return "\n";
	}
}

sub open_stream {
	my $self = shift;
	my ($filename) = @_;
	open(OUT, "> $filename")
			or die "can't open $filename ($!).\n";
	$self->{filename} = $filename;
}

sub _get_defn {
	my $self = shift;
	my ($defn) = @_;
	if (ref $defn) {
		return $defn;
	} else {
		return $self->{symbtab}->Lookup($defn);
	}
}

#
#	3.5		OMG IDL Specification
#

sub visitSpecification {
	my $self = shift;
	my ($node) = @_;
	my $filename = $self->{prefix} . basename($self->{srcname}, ".idl") . ".h";
	print OUT "/* This file was partialy generated (by ",$0,").*/\n";
	print OUT "/* From file : ",$self->{srcname},", ",$self->{srcname_size}," octets, ",POSIX::ctime($self->{srcname_mtime});
	print OUT " */\n";
	print OUT "\n";
	print OUT "/* START_EDIT */\n";
	print OUT $self->merge();
	print OUT "/* STOP_EDIT */\n";
	print OUT "\n";
	print OUT "#include \"",$filename,"\"\n";
	print OUT "\n";
	foreach (@{$node->{list_decl}}) {
		$self->_get_defn($_)->visit($self);
	}
	print OUT "\n";
	print OUT "/* end of file : ",$self->{filename}," */\n";
	close OUT;
}

#
#	3.7		Module Declaration
#

sub visitModules {
	my $self = shift;
	my ($node) = @_;
	unless (exists $node->{$self->{num_key}}) {
		$node->{$self->{num_key}} = 0;
	}
	my $module = ${$node->{list_decl}}[$node->{$self->{num_key}}];
	$module->visit($self);
	$node->{$self->{num_key}} ++;
}

sub visitModule {
	my $self = shift;
	my ($node) = @_;
	if ($self->{srcname} eq $node->{filename}) {
		my $defn = $self->{symbtab}->Lookup($node->{full});
		print OUT "/*\n";
		print OUT " * begin of module ",$defn->{c_name},"\n";
		print OUT " */\n";
		foreach (@{$node->{list_decl}}) {
			$self->_get_defn($_)->visit($self);
		}
		print OUT "/*\n";
		print OUT " * end of module ",$defn->{c_name},"\n";
		print OUT " */\n";
	}
}

#
#	3.8		Interface Declaration
#

sub visitRegularInterface {
	my $self = shift;
	my ($node) = @_;
	if ($self->{srcname} eq $node->{filename}) {
		print OUT "/* START_EDIT (",$node->{c_name},") */\n";
		print OUT $self->merge($node->{c_name});
		print OUT "/* STOP_EDIT (",$node->{c_name},") */\n";
		print OUT "\n";
		print OUT "/*\n";
		print OUT " * begin of interface ",$node->{c_name},"\n";
		print OUT " */\n";
		$self->{itf} = $node->{c_name};
		foreach (sort keys %{$node->{hash_attribute_operation}}) {
			my $elt = ${$node->{hash_attribute_operation}}{$_};
			$self->_get_defn($elt)->visit($self);
		}
		print OUT "/*\n";
		print OUT " * end of interface ",$node->{c_name},"\n";
		print OUT " */\n";
	}
}

sub visitForwardRegularInterface {
	# empty
}

sub visitBaseInterface {
	# C mapping is aligned with CORBA 2.1
}

sub visitForwardBaseInterface {
	# C mapping is aligned with CORBA 2.1
}

#
#	3.10	Constant Declaration
#

sub visitConstant {
	# empty
}

#
#	3.11	Type Declaration
#

sub visitTypeDeclarators {
	# empty
}

sub visitTypeDeclarator {
	# empty
}

sub visitNativeType {
	# C mapping is aligned with CORBA 2.1
}

sub visitStructType {
	# empty
}

sub visitUnionType {
	# empty
}

sub visitForwardStructType {
	# empty
}

sub visitForwardUnionType {
	# empty
}

sub visitEnumType {
	# empty
}

#
#	3.12	Exception Declaration
#

sub visitException {
	# empty
}

#
#	3.13	Operation Declaration
#

sub visitOperation {
	my $self = shift;
	my ($node) = @_;
	my $name = $self->{prefix} . $self->{itf} . "_" . $node->{c_name};
	print OUT "\n";
	print OUT "/*============================================================*/\n";
	print OUT "/* ARGSUSED */\n";
	if (exists $node->{modifier}) {
		print OUT $node->{c_arg}," // oneway\n";
	} else {
		print OUT $node->{c_arg},"\n";
	}
	print OUT $name,"(\n";
	print OUT "\t",$self->{itf}," _o,\n";
	foreach (@{$node->{list_param}}) {	# parameter
		my $type = $self->_get_defn($_->{type});
		print OUT "\t",$_->{c_arg},", // ",$_->{attr};
			print OUT " (variable length)\n" if (defined $type->{length});
			print OUT " (fixed length)\n" unless (defined $type->{length});
	}
	if (exists $node->{list_context}) {
		print OUT "\tCORBA_Context _ctx,\n";
	}
	print OUT "\tCORBA_Environment * _ev\n";
	print OUT ")\n";
	print OUT "{\n";
	if (exists $node->{list_raise}) {
		foreach (@{$node->{list_raise}}) {	# exception
			my $defn = $self->_get_defn($_);
			print OUT "\tstatic ",$defn->{c_name}," _",$defn->{c_name},";\n";
		}
	}
	print OUT "/* START_EDIT (",$name,") */\n";
	print OUT $self->merge($name);
	print OUT "/* STOP_EDIT (",$name,") */\n";
	print OUT "}\n";
	print OUT "\n";
}

#
#	3.14	Attribute Declaration
#

sub visitAttribute {
	my $self = shift;
	my ($node) = @_;
	$node->{_get}->visit($self);
	$node->{_set}->visit($self) if (exists $node->{_set});
}

#
#	3.15	Repository Identity Related Declarations
#

sub visitTypeId {
	# empty
}

sub visitTypePrefix {
	# empty
}

1;

