use strict;
use UNIVERSAL;

package CskeletonVisitor;

# needs $node->{c_name} (CnameVisitor) and $node->{c_arg} (CincludeVisitor)

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self = {};
	bless($self, $class);
	my($parser,$prefix) = @_;
	$prefix = 'skel_' if (!defined $prefix);
#	$self->{prefix} = $prefix;
	$self->{prefix} = '';
	$self->{srcname} = $parser->YYData->{srcname};
	$self->{inc} = {};
	my $filename = $self->{srcname};
	$filename =~ s/^([^\/]+\/)+//;
	$filename =~ s/\.idl$//i;
	$filename = $prefix . $filename . '.c0';
	$self->open_stream($filename);
	$self->{done_hash} = {};
	return $self;
}

sub open_stream {
	my $self = shift;
	my($filename) = @_;
	open(OUT, "> $filename")
			or die "can't open $filename ($!).\n";
	$self->{filename} = $filename;
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
	$filename = $self->{prefix} . $filename . '.h';
	print OUT "/* This file is partialy generated.*/\n";
	print OUT "/* START_EDIT */\n";
	print OUT "\n";
	print OUT "/* STOP_EDIT */\n";
	print OUT "\n";
	print OUT "#include \"",$filename,"\"\n";
	print OUT "\n";
	foreach (@{$node->{list_decl}}) {
		$_->visit($self);
	}
	print OUT "\n";
	print OUT "/* end of file : ",$self->{filename}," */\n";
	close OUT;
}

#
#	3.6		Module Declaration
#

sub visitModule {
	my $self = shift;
	my($node) = @_;
	if ($self->{srcname} eq $node->{filename}) {
		print OUT "/*\n";
		print OUT " * begin of module ",$node->{c_name},"\n";
		print OUT " */\n";
		foreach (@{$node->{list_decl}}) {
			$_->visit($self);
		}
		print OUT "/*\n";
		print OUT " * end of module ",$node->{c_name},"\n";
		print OUT " */\n";
	}
}

#
#	3.7		Interface Declaration
#

sub visitInterface {
	my $self = shift;
	my($node) = @_;
	if ($self->{srcname} eq $node->{filename}) {
		return if (exists $node->{modifier});	# abstract or local
		print OUT "/* START_EDIT (",$node->{c_name},") */\n";
		print OUT "\n";
		print OUT "/* STOP_EDIT (",$node->{c_name},") */\n";
		print OUT "\n";
		print OUT "/*\n";
		print OUT " * begin of interface ",$node->{c_name},"\n";
		print OUT " */\n";
		$self->{itf} = $node->{c_name};
		foreach (sort keys %{$node->{hash_attribute_operation}}) {
			my $elt = ${$node->{hash_attribute_operation}}{$_};
			$elt->visit($self);
		}
		print OUT "/*\n";
		print OUT " * end of interface ",$node->{c_name},"\n";
		print OUT " */\n";
	}
}

sub visitForwardInterface {
	# empty
}

#
#	3.8		Value Declaration
#

sub visitRegularValue {
	# C mapping is aligned with CORBA 2.1
}

sub visitBoxedValue {
	# C mapping is aligned with CORBA 2.1
}

sub visitAbstractValue {
	# C mapping is aligned with CORBA 2.1
}

sub visitForwardRegularValue {
	# C mapping is aligned with CORBA 2.1
}

sub visitForwardAbstractValue {
	# C mapping is aligned with CORBA 2.1
}

#
#	3.9		Constant Declaration
#

sub visitConstant {
	# empty
}

#
#	3.10	Type Declaration
#

sub visitTypeDeclarators {
	# empty
}

sub visitTypeDeclarator {
	# empty
}

sub visitStructType {
	# empty
}

sub visitUnionType {
	# empty
}

sub visitEnumType {
	# empty
}

sub visitForwardStructType {
	# empty
}

sub visitForwardUnionType {
	# empty
}

#
#	3.11	Exception Declaration
#

sub visitException {
	# empty
}

#
#	3.12	Operation Declaration
#

sub visitOperation {
	my $self = shift;
	my($node) = @_;
	print OUT "\n";
	print OUT "/*============================================================*/\n";
	print OUT "/* ARGSUSED */\n";
	print OUT $node->{c_arg},"\n" unless (exists $node->{modifier});
	print OUT $node->{c_arg}," // oneway\n" if (exists $node->{modifier});
	print OUT $self->{prefix},$node->{c_name},"(\n";
	print OUT "\t",$self->{itf}," _o,\n";
	foreach (@{$node->{list_param}}) {	# parameter
		print OUT "\t",$_->{c_arg},", // ",$_->{attr};
			print OUT " (variable length)\n" if (defined $_->{type}->{length});
			print OUT " (fixed length)\n" unless (defined $_->{type}->{length});
	}
	if (exists $node->{list_context}) {
		print OUT "\tCORBA_Context _ctx,\n";
	}
	print OUT "\tCORBA_Environment * _ev\n";
	print OUT ")\n";
	print OUT "{\n";
	if (exists $node->{list_raise}) {
		foreach (@{$node->{list_raise}}) {	# exception
			print OUT "\tstatic ",$_->{c_name}," _",$_->{c_name},";\n";
		}
	}
	print OUT "/* START_EDIT (",$self->{prefix},$node->{c_name},") */\n";
	print OUT "\n";
	print OUT "/* STOP_EDIT (",$self->{prefix},$node->{c_name},") */\n";
	print OUT "}\n";
	print OUT "\n";
}

#
#	3.13	Attribute Declaration
#

sub visitAttribute {
	my $self = shift;
	my($node) = @_;
	$node->{_get}->visit($self);
	$node->{_set}->visit($self) if (exists $node->{_set});
}

1;

