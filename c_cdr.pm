use strict;

package CcdrVisitor;

# needs $node->{c_name} (CnameVisitor), $node->{c_literal} (CliteralVisitor)

sub open_stream {
	my $self = shift;
	my($filename) = @_;
	open(OUT, "> $filename")
			or die "can't open $filename ($!).\n";
	$self->{out} = \*OUT;
	$self->{filename} = $filename;
}

#
#	3.5		OMG IDL Specification		(specialized)
#

#
#	3.6		Module Declaration
#

sub visitModule {
	my $self = shift;
	my($node) = @_;
	my $FH = $self->{out};
	print $FH "/*\n";
	print $FH " * begin of module ",$node->{c_name},"\n";
	print $FH " */\n";
	foreach (@{$node->{list_decl}}) {
		$_->visit($self);
	}
	print $FH "\n";
	print $FH "/*\n";
	print $FH " * end of module ",$node->{c_name},"\n";
	print $FH " */\n";
	print $FH "\n";
}

#
#	3.7		Interface Declaration		(specialized)
#

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
	my $self = shift;
	my($node) = @_;
	foreach (@{$node->{list_value}}) {
		$_->visit($self);
	}
}

sub visitTypeDeclarator {
	my $self = shift;
	my($node) = @_;
	return if (exists $node->{modifier});	# native IDL2.2
	if (	   $node->{type}->isa('StructType')
			or $node->{type}->isa('UnionType')
			or $node->{type}->isa('EnumType')
			or $node->{type}->isa('SequenceType')
			or $node->{type}->isa('FixedPtType') ) {
		$node->{type}->visit($self);
	}
	my $FH = $self->{out};
	if (exists $node->{array_size}) {
		warn __PACKAGE__,"::visitTypeDecalarator $node->{idf} : empty array_size.\n"
				unless (@{$node->{array_size}});

		my $deref = "";
		my $nb;
		my $first = 1;
		foreach (@{$node->{array_size}}) {
			$deref .= "*" unless ($first);
			$nb .= " * " unless ($first);
			$nb .= $_->{c_literal};
			$first = 0;
		}
		print $FH "#define ADD_SIZE_",$node->{c_name},"(size,v) {\\\n";
		print $FH "\t\t",$node->{type}->{c_name}," * ",$node->{c_name},"_ptr;\\\n";
		print $FH "\t\tfor (",$node->{c_name},"_ptr = ",$deref,"(v);\\\n";
		print $FH "\t\t     ",$node->{c_name},"_ptr < ",$deref,"(v) + (",$nb,");\\\n";
		print $FH "\t\t     ",$node->{c_name},"_ptr++) {\\\n";
		print $FH "\t\t\tADD_SIZE_",$node->{type}->{c_name},"(size,*",$node->{c_name},"_ptr);\\\n";
		print $FH "\t\t}\\\n";
		print $FH "\t}\n";
		print $FH "#define PUT_",$node->{c_name},"(ptr,v) {\\\n";
		print $FH "\t\t",$node->{type}->{c_name}," * ",$node->{c_name},"_ptr;\\\n";
		print $FH "\t\tfor (",$node->{c_name},"_ptr = ",$deref,"(v);\\\n";
		print $FH "\t\t     ",$node->{c_name},"_ptr < ",$deref,"(v) + (",$nb,");\\\n";
		print $FH "\t\t     ",$node->{c_name},"_ptr++) {\\\n";
		print $FH "\t\t\tPUT_",$node->{type}->{c_name},"(ptr,*",$node->{c_name},"_ptr);\\\n";
		print $FH "\t\t}\\\n";
		print $FH "\t}\n";
		if (defined $node->{length}) {
			if (exists $self->{client}) {
				print $FH "#define GET_inout_",$node->{c_name},"(ptr,v) {\\\n";
				print $FH "\t\t",$node->{type}->{c_name}," * ",$node->{c_name},"_ptr;\\\n";
				print $FH "\t\tfor (",$node->{c_name},"_ptr = ",$deref,"*(v);\\\n";
				print $FH "\t\t     ",$node->{c_name},"_ptr < ",$deref,"*(v) + (",$nb,");\\\n";
				print $FH "\t\t     ",$node->{c_name},"_ptr++) {\\\n";
				print $FH "\t\t\tGET_inout_",$node->{type}->{c_name},"(ptr,",$node->{c_name},"_ptr);\\\n";
				print $FH "\t\t}\\\n";
				print $FH "\t}\n";
				print $FH "#define GET_out_",$node->{c_name},"(ptr,v) {\\\n";
				print $FH "\t\t",$node->{type}->{c_name}," * ",$node->{c_name},"_ptr;\\\n";
				print $FH "\t\tfor (",$node->{c_name},"_ptr = ",$deref,"*(v);\\\n";
				print $FH "\t\t     ",$node->{c_name},"_ptr < ",$deref,"*(v) + (",$nb,");\\\n";
				print $FH "\t\t     ",$node->{c_name},"_ptr++) {\\\n";
				print $FH "\t\t\tGET_out_",$node->{type}->{c_name},"(ptr,",$node->{c_name},"_ptr);\\\n";
				print $FH "\t\t}\\\n";
				print $FH "\t}\n";
				print $FH "#define ALLOC_GET_out_",$node->{c_name},"(ptr,v) {\\\n";
				print $FH "\t\t",$node->{type}->{c_name}," * ",$node->{c_name},"_ptr;\\\n";
				print $FH "\t\tptr = ",$node->{type}->{c_name},"__alloc(",$nb,");\\\n";
				print $FH "\t\tif (NULL == ptr) goto err;\\\n";
				print $FH "\t\tfor (",$node->{c_name},"_ptr = ",$deref,"*(v);\\\n";
				print $FH "\t\t     ",$node->{c_name},"_ptr < ",$deref,"*(v) + (",$nb,");\\\n";
				print $FH "\t\t     ",$node->{c_name},"_ptr++) {\\\n";
				print $FH "\t\t\tGET_out_",$node->{type}->{c_name},"(ptr,",$node->{c_name},"_ptr);\\\n";
				print $FH "\t\t}\\\n";
				print $FH "\t}\n";
			} else {
				print $FH "#define GET_",$node->{c_name},"(ptr,v) {\\\n";
				print $FH "\t\t",$node->{type}->{c_name}," * ",$node->{c_name},"_ptr;\\\n";
				print $FH "\t\tfor (",$node->{c_name},"_ptr = ",$deref,"*(v);\\\n";
				print $FH "\t\t     ",$node->{c_name},"_ptr < ",$deref,"*(v) + (",$nb,");\\\n";
				print $FH "\t\t     ",$node->{c_name},"_ptr++) {\\\n";
				print $FH "\t\t\tGET_",$node->{type}->{c_name},"(ptr,",$node->{c_name},"_ptr);\\\n";
				print $FH "\t\t}\\\n";
				print $FH "\t}\n";
				print $FH "#define FREE_in_",$node->{c_name},"(v) {\\\n";
				print $FH "\t\t",$node->{type}->{c_name}," * ",$node->{c_name},"_ptr;\\\n";
				print $FH "\t\tfor (",$node->{c_name},"_ptr = ",$deref,"*(v);\\\n";
				print $FH "\t\t     ",$node->{c_name},"_ptr < ",$deref,"*(v) + (",$nb,");\\\n";
				print $FH "\t\t     ",$node->{c_name},"_ptr++) {\\\n";
				print $FH "\t\t\tFREE_in_",$node->{type}->{c_name},"(",$node->{c_name},"_ptr);\\\n";
				print $FH "\t\t}\\\n";
				print $FH "\t}\n";
				print $FH "#define FREE_inout_",$node->{c_name},"(v) {\\\n";
				print $FH "\t\t",$node->{type}->{c_name}," * ",$node->{c_name},"_ptr;\\\n";
				print $FH "\t\tfor (",$node->{c_name},"_ptr = ",$deref,"*(v);\\\n";
				print $FH "\t\t     ",$node->{c_name},"_ptr < ",$deref,"*(v) + (",$nb,");\\\n";
				print $FH "\t\t     ",$node->{c_name},"_ptr++) {\\\n";
				print $FH "\t\t\tFREE_inout_",$node->{type}->{c_name},"(",$node->{c_name},"_ptr);\\\n";
				print $FH "\t\t}\\\n";
				print $FH "\t}\n";
				print $FH "#define FREE_out_",$node->{c_name},"(v) {\\\n";
				print $FH "\t\t",$node->{type}->{c_name}," * ",$node->{c_name},"_ptr;\\\n";
				print $FH "\t\tfor (",$node->{c_name},"_ptr = ",$deref,"*(v);\\\n";
				print $FH "\t\t     ",$node->{c_name},"_ptr < ",$deref,"*(v) + (",$nb,");\\\n";
				print $FH "\t\t     ",$node->{c_name},"_ptr++) {\\\n";
				print $FH "\t\t\tFREE_out_",$node->{type}->{c_name},"(",$node->{c_name},"_ptr);\\\n";
				print $FH "\t\t}\\\n";
				print $FH "\t}\n";
			}
			print $FH "#define FREE_",$node->{c_name},"(v) {\\\n";
			print $FH "\t\t",$node->{type}->{c_name}," * ",$node->{c_name},"_ptr;\\\n";
			print $FH "\t\tfor (",$node->{c_name},"_ptr = ",$deref,"*(v);\\\n";
			print $FH "\t\t     ",$node->{c_name},"_ptr < ",$deref,"*(v) + (",$nb,");\\\n";
			print $FH "\t\t     ",$node->{c_name},"_ptr++) {\\\n";
			print $FH "\t\t\tFREE_",$node->{type}->{c_name},"(",$node->{c_name},"_ptr);\\\n";
			print $FH "\t\t}\\\n";
			print $FH "\t}\n";
		} else {
			print $FH "#define GET_",$node->{c_name},"(ptr,v) {\\\n";
			print $FH "\t\t",$node->{type}->{c_name}," * ",$node->{c_name},"_ptr;\\\n";
			print $FH "\t\tfor (",$node->{c_name},"_ptr = ",$deref,"*(v);\\\n";
			print $FH "\t\t     ",$node->{c_name},"_ptr < ",$deref,"*(v) + (",$nb,");\\\n";
			print $FH "\t\t     ",$node->{c_name},"_ptr++) {\\\n";
			print $FH "\t\t\tGET_",$node->{type}->{c_name},"(ptr,",$node->{c_name},"_ptr);\\\n";
			print $FH "\t\t}\\\n";
			print $FH "\t}\n";
			if (exists $self->{client}) {
				print $FH "#define GET_inout_",$node->{c_name}," GET_",$node->{c_name},"\n";
				print $FH "#define GET_out_",$node->{c_name}," GET_",$node->{c_name},"\n";
			}
		}
	} else {
		print $FH "#define ADD_SIZE_",$node->{c_name}," ADD_SIZE_",$node->{type}->{c_name},"\n";
		print $FH "#define PUT_",$node->{c_name}," PUT_",$node->{type}->{c_name},"\n";
		print $FH "#define GET_",$node->{c_name}," GET_",$node->{type}->{c_name},"\n";
		if (defined $node->{length}) {
			if (exists $self->{client}) {
				print $FH "#define GET_inout_",$node->{c_name}," GET_inout_",$node->{type}->{c_name},"\n";
				print $FH "#define GET_out_",$node->{c_name}," GET_out_",$node->{type}->{c_name},"\n";
				print $FH "#define ALLOC_GET_out_",$node->{c_name}," ALLOC_GET_out_",$node->{type}->{c_name},"\n";
			} else {
				print $FH "#define FREE_in_",$node->{c_name}," FREE_in_",$node->{type}->{c_name},"\n";
				print $FH "#define FREE_inout_",$node->{c_name}," FREE_inout_",$node->{type}->{c_name},"\n";
				print $FH "#define FREE_out_",$node->{c_name}," FREE_out_",$node->{type}->{c_name},"\n";
			}
			print $FH "#define FREE_",$node->{c_name}," FREE_",$node->{type}->{c_name},"\n";
		} else {
			if (exists $self->{client}) {
				print $FH "#define GET_inout_",$node->{c_name}," GET_",$node->{c_name},"\n";
				print $FH "#define GET_out_",$node->{c_name}," GET_",$node->{c_name},"\n";
			}
		}
	}
	print $FH "\n";
}

#
#	3.10.2	Constructed Types
#
#	3.10.2.1	Structures
#

sub visitStructType {
	my $self = shift;
	my($node) = @_;
	return if (exists $self->{done_hash}->{$node->{c_name}});
	$self->{done_hash}->{$node->{c_name}} = 1;
	foreach (@{$node->{list_expr}}) {
		if (	   $_->{type}->isa('StructType')
				or $_->{type}->isa('UnionType')
				or $_->{type}->isa('SequenceType')
				or $_->{type}->isa('FixedPtType') ) {
			$_->{type}->visit($self);
		}
	}
	$self->{add_size} = '';
	$self->{put} = '';
	$self->{get} = '';
	$self->{get_in} = '';
	$self->{get_inout} = '';
	$self->{get_out} = '';
	$self->{free} = '';
	$self->{union} = '';
	foreach (@{$node->{list_value}}) {
		$_->visit($self);				# single or array
	}
	my $FH = $self->{out};
	print $FH "#define ADD_SIZE_",$node->{c_name},"(size,v) {\\\n";
	print $FH $self->{add_size};
	print $FH "\t}\n";
	print $FH "#define PUT_",$node->{c_name},"(ptr,v) {\\\n";
	print $FH $self->{put};
	print $FH "\t}\n";
	if (defined $node->{length}) {
		if (exists $self->{client}) {
			print $FH "#define GET_inout_",$node->{c_name},"(ptr,v) {\\\n";
			print $FH $self->{get_inout};
			print $FH "\t}\n";
			print $FH "#define GET_out_",$node->{c_name},"(ptr,v) {\\\n";
			print $FH $self->{get_out};
			print $FH "\t}\n";
			print $FH "#define ALLOC_GET_out_",$node->{c_name},"(ptr,v) {\\\n";
			print $FH "\t\tv = ",$node->{c_name},"__alloc(1);\\\n";
			print $FH "\t\tif (NULL == (v)) goto err;\\\n";
			print $FH $self->{get_out};
			print $FH "\t}\n";
		} else {
			print $FH "#define GET_",$node->{c_name},"(ptr,v) {\\\n";
			print $FH $self->{get};
			print $FH "\t}\n";
			print $FH "#define FREE_in_",$node->{c_name}," FREE_",$node->{c_name},"\n";
			print $FH "#define FREE_inout_",$node->{c_name}," FREE_",$node->{c_name},"\n";
			print $FH "#define FREE_out_",$node->{c_name},"(v) {\\\n";
			print $FH "\t\tif (NULL != (v)) {\\\n";
			print $FH "\t\t\tFREE_",$node->{c_name},"(v);\\\n";
			print $FH "\t\t\tCORBA_free(v);\\\n";
			print $FH "\t}\\\n";
			print $FH "\t}\n";
		}
		print $FH "#define FREE_",$node->{c_name},"(v) {\\\n";
		print $FH $self->{free};
#		print $FH "\t\tCORBA_free(v);\\\n";
		print $FH "\t}\n";
	} else {
		print $FH "#define GET_",$node->{c_name},"(ptr,v) {\\\n";
		print $FH $self->{get};
		print $FH "\t}\n";
		if (exists $self->{client}) {
			print $FH "#define GET_inout_",$node->{c_name}," GET_",$node->{c_name},"\n";
			print $FH "#define GET_out_",$node->{c_name}," GET_",$node->{c_name},"\n";
		}
	}
	print $FH "\n";
	delete $self->{add_size};
	delete $self->{put};
	delete $self->{get};
	delete $self->{get_in};
	delete $self->{get_inout};
	delete $self->{get_out};
	delete $self->{free};
	delete $self->{union};
}

sub visitArray {
	my $self = shift;
	my($node) = @_;

	my $deref = "";
	my $nb;
	my $first = 1;
	foreach (@{$node->{array_size}}) {
		$deref .= "*" unless ($first);
		$nb .= " * " unless ($first);
		$nb .= $_->{c_literal};
		$first = 0;
	}

	$self->{add_size}  .= "\t\t{\\\n";
	$self->{add_size}  .= "\t\t\t" . $node->{type}->{c_name} . " * " . $node->{c_name} . "_ptr;\\\n";
	$self->{add_size}  .= "\t\t\tfor (" . $node->{c_name} . "_ptr = " . $deref . "((v)." . $self->{union} . $node->{c_name} . ");\\\n";
	$self->{add_size}  .= "\t\t\t     " . $node->{c_name} . "_ptr < " . $deref . "((v)." . $self->{union} . $node->{c_name} . ") + (" . $nb . ");\\\n";
	$self->{add_size}  .= "\t\t\t     " . $node->{c_name} . "_ptr++) {\\\n";
	$self->{add_size}  .= "\t\t\t\tADD_SIZE_" . $node->{type}->{c_name} . "(size,*" . $node->{c_name} . "_ptr);\\\n";
	$self->{add_size}  .= "\t\t\t}\\\n";
	$self->{add_size}  .= "\t\t}\\\n";
	$self->{put}       .= "\t\t{\\\n";
	$self->{put}       .= "\t\t\t" . $node->{type}->{c_name} . " * " . $node->{c_name} . "_ptr;\\\n";
	$self->{put}       .= "\t\t\tfor (" . $node->{c_name} . "_ptr = " . $deref . "((v)." . $self->{union} . $node->{c_name} . ");\\\n";
	$self->{put}       .= "\t\t\t     " . $node->{c_name} . "_ptr < " . $deref . "((v)." . $self->{union} . $node->{c_name} . ") + (" . $nb . ");\\\n";
	$self->{put}       .= "\t\t\t     " . $node->{c_name} . "_ptr++) {\\\n";
	$self->{put}       .= "\t\t\t\tPUT_" . $node->{type}->{c_name} . "(ptr,*" . $node->{c_name} . "_ptr);\\\n";
	$self->{put}       .= "\t\t\t}\\\n";
	$self->{put}       .= "\t\t}\\\n";
	$self->{get}       .= "\t\t{\\\n";
	$self->{get}       .= "\t\t\t" . $node->{type}->{c_name} . " * " . $node->{c_name} . "_ptr;\\\n";
	$self->{get}       .= "\t\t\tfor (" . $node->{c_name} . "_ptr = " . $deref . "((v)->" . $self->{union} . $node->{c_name} . ");\\\n";
	$self->{get}       .= "\t\t\t     " . $node->{c_name} . "_ptr < " . $deref . "((v)->" . $self->{union} . $node->{c_name} . ") + (" . $nb . ");\\\n";
	$self->{get}       .= "\t\t\t     " . $node->{c_name} . "_ptr++) {\\\n";
	$self->{get}       .= "\t\t\t\tGET_" . $node->{type}->{c_name} . "(ptr," . $node->{c_name} . "_ptr);\\\n";
	$self->{get}       .= "\t\t\t}\\\n";
	$self->{get}       .= "\t\t}\\\n";
	$self->{get_in}    .= "\t\t{\\\n";
	$self->{get_in}    .= "\t\t\t" . $node->{type}->{c_name} . " * " . $node->{c_name} . "_ptr;\\\n";
	$self->{get_in}    .= "\t\t\tfor (" . $node->{c_name} . "_ptr = " . $deref . "((v)->" . $self->{union} . $node->{c_name} . ");\\\n";
	$self->{get_in}    .= "\t\t\t     " . $node->{c_name} . "_ptr < " . $deref . "((v)->" . $self->{union} . $node->{c_name} . ") + (" . $nb . ");\\\n";
	$self->{get_in}    .= "\t\t\t     " . $node->{c_name} . "_ptr++) {\\\n";
	$self->{get_in}    .= "\t\t\t\tGET_in_" . $node->{type}->{c_name} . "(ptr," . $node->{c_name} . "_ptr);\\\n";
	$self->{get_in}    .= "\t\t\t}\\\n";
	$self->{get_in}    .= "\t\t}\\\n";
	$self->{get_inout} .= "\t\t{\\\n";
	$self->{get_inout} .= "\t\t\t" . $node->{type}->{c_name} . " * " . $node->{c_name} . "_ptr;\\\n";
	$self->{get_inout} .= "\t\t\tfor (" . $node->{c_name} . "_ptr = " . $deref . "((v)->" . $self->{union} . $node->{c_name} . ");\\\n";
	$self->{get_inout} .= "\t\t\t     " . $node->{c_name} . "_ptr < " . $deref . "((v)->" . $self->{union} . $node->{c_name} . ") + (" . $nb . ");\\\n";
	$self->{get_inout} .= "\t\t\t     " . $node->{c_name} . "_ptr++) {\\\n";
	$self->{get_inout} .= "\t\t\t\tGET_inout_" . $node->{type}->{c_name} . "(ptr," . $node->{c_name} . "_ptr);\\\n";
	$self->{get_inout} .= "\t\t\t}\\\n";
	$self->{get_inout} .= "\t\t}\\\n";
	$self->{get_out}   .= "\t\t{\\\n";
	$self->{get_out}   .= "\t\t\t" . $node->{type}->{c_name} . " * " . $node->{c_name} . "_ptr;\\\n";
	$self->{get_out}   .= "\t\t\tfor (" . $node->{c_name} . "_ptr = " . $deref . "((v)->" . $self->{union} . $node->{c_name} . ");\\\n";
	$self->{get_out}   .= "\t\t\t     " . $node->{c_name} . "_ptr < " . $deref . "((v)->" . $self->{union} . $node->{c_name} . ") + (" . $nb . ");\\\n";
	$self->{get_out}   .= "\t\t\t     " . $node->{c_name} . "_ptr++) {\\\n";
	$self->{get_out}   .= "\t\t\t\tGET_" . $node->{type}->{c_name} . "(ptr," . $node->{c_name} . "_ptr);\\\n";
	$self->{get_out}   .= "\t\t\t}\\\n";
	$self->{get_out}   .= "\t\t}\\\n";
	if (defined $node->{type}->{length}) {
		$self->{free}      .= "\t\t{\\\n";
		$self->{free}      .= "\t\t\t" . $node->{type}->{c_name} . " * " . $node->{c_name} . "_ptr;\\\n";
		$self->{free}      .= "\t\t\tfor (" . $node->{c_name} . "_ptr = " . $deref . "((v)->" . $self->{union} . $node->{c_name} . ");\\\n";
		$self->{free}      .= "\t\t\t     " . $node->{c_name} . "_ptr < " . $deref . "((v)->" . $self->{union} . $node->{c_name} . ") + (" . $nb . ");\\\n";
		$self->{free}      .= "\t\t\t     " . $node->{c_name} . "_ptr++) {\\\n";
		$self->{free}      .= "\t\t\t\tFREE_" . $node->{type}->{c_name} . "(" . $node->{c_name} . "_ptr);\\\n";
		$self->{free}      .= "\t\t\t}\\\n";
		$self->{free}      .= "\t\t}\\\n";
	}
}

sub visitSingle {
	my $self = shift;
	my($node) = @_;
	my $tab = '';
	$tab = "\t" if ($self->{union});
	$self->{add_size}  .= $tab . "\t\tADD_SIZE_" . $node->{type}->{c_name};
		$self->{add_size}  .= "(size,(v)." . $self->{union} . $node->{c_name} . ");\\\n";
	$self->{put}       .= $tab . "\t\tPUT_" . $node->{type}->{c_name};
		$self->{put}       .= "(ptr,(v)." . $self->{union} . $node->{c_name} . ");\\\n";
	$self->{get}       .= $tab . "\t\tGET_" . $node->{type}->{c_name};
		$self->{get}       .= "(ptr,&((v)->" . $self->{union} . $node->{c_name} . "));\\\n";
	$self->{get_in}    .= $tab . "\t\tGET_in_" . $node->{type}->{c_name};
		$self->{get_in}    .= "(ptr,&((v)->" . $self->{union} . $node->{c_name} . "));\\\n";
	$self->{get_inout} .= $tab . "\t\tGET_inout_" . $node->{type}->{c_name};
		$self->{get_inout} .= "(ptr,&((v)->" . $self->{union} . $node->{c_name} . "));\\\n";
	$self->{get_out}   .= $tab . "\t\tGET_out_" . $node->{type}->{c_name};
		$self->{get_out}   .= "(ptr,&((v)->" . $self->{union} . $node->{c_name} . "));\\\n";
	if (defined $node->{type}->{length}) {
		$self->{free}  .= $tab . "\t\tFREE_" . $node->{type}->{c_name};
			$self->{free}   .= "(&((v)->" . $self->{union} . $node->{c_name} . "));\\\n";
	}
}

#	3.10.2.2	Discriminated Unions
#

sub visitUnionType {
	my $self = shift;
	my($node) = @_;
	return if (exists $self->{done_hash}->{$node->{c_name}});
	$self->{done_hash}->{$node->{c_name}} = 1;
	foreach (@{$node->{list_expr}}) {
		if (	   $_->{element}->{type}->isa('StructType')
				or $_->{element}->{type}->isa('UnionType')
				or $_->{element}->{type}->isa('EnumType')
				or $_->{element}->{type}->isa('SequenceType')
				or $_->{element}->{type}->isa('FixedPtType') ) {
			$_->{element}->{type}->visit($self);
		}
	}
	my $FH = $self->{out};
	$self->{add_size} = '';
	$self->{put} = '';
	$self->{get} = '';
	$self->{get_in} = '';
	$self->{get_inout} = '';
	$self->{get_out} = '';
	$self->{free} = '';
	$self->{union} = '_u.';
	foreach (@{$node->{list_expr}}) {
		$_->visit($self);				# case
	}
	print $FH "#define ADD_SIZE_",$node->{c_name},"(size,v) {\\\n";
	print $FH "\t\tADD_SIZE_",$node->{type}->{c_name},"(size,(v)._d);\\\n";
	print $FH "\t\tswitch ((v)._d) {\\\n";
	print $FH $self->{add_size};
	print $FH "\t\t}\\\n";
	print $FH "\t}\n";
	print $FH "#define PUT_",$node->{c_name},"(ptr,v) {\\\n";
	print $FH "\t\tPUT_",$node->{type}->{c_name},"(ptr,(v)._d);\\\n";
	print $FH "\t\tswitch ((v)._d) {\\\n";
	print $FH $self->{put};
	print $FH "\t\t}\\\n";
	print $FH "\t}\n";
	if (defined $node->{length}) {
		if (exists $self->{client}) {
			print $FH "#define GET_inout_",$node->{c_name},"(ptr,v) {\\\n";
			print $FH "\t\tGET_inout_",$node->{type}->{c_name},"(ptr,&((v)->_d));\\\n";
			print $FH "\t\tswitch ((v)->_d) {\\\n";
			print $FH $self->{get_inout};
			print $FH "\t\t}\\\n";
			print $FH "\t}\n";
			print $FH "#define GET_out_",$node->{c_name},"(ptr,v) {\\\n";
			print $FH "\t\tGET_out_",$node->{type}->{c_name},"(ptr,&((v)->_d));\\\n";
			print $FH "\t\tswitch ((v)->_d) {\\\n";
			print $FH $self->{get_out};
			print $FH "\t\t}\\\n";
			print $FH "\t}\n";
			print $FH "#define ALLOC_GET_out_",$node->{c_name},"(ptr,v) {\\\n";
			print $FH "\t\tv = ",$node->{c_name},"__alloc(1);\\\n";
			print $FH "\t\tif (NULL == (v)) goto err;\\\n";
			print $FH "\t\tGET_out_",$node->{type}->{c_name},"(ptr,&((v)->_d));\\\n";
			print $FH "\t\tswitch ((v)->_d) {\\\n";
			print $FH $self->{get_out};
			print $FH "\t\t}\\\n";
			print $FH "\t}\n";
		} else {
			print $FH "#define GET_",$node->{c_name},"(ptr,v) {\\\n";
			print $FH "\t\tGET_",$node->{type}->{c_name},"(ptr,&((v)->_d));\\\n";
			print $FH "\t\tswitch ((v)->_d) {\\\n";
			print $FH $self->{get};
			print $FH "\t\t}\\\n";
			print $FH "\t}\n";
			print $FH "#define FREE_in_",$node->{c_name}," FREE_",$node->{c_name},"\n";
			print $FH "#define FREE_inout_",$node->{c_name}," FREE_",$node->{c_name},"\n";
			print $FH "#define FREE_out_",$node->{c_name},"(v) {\\\n";
			print $FH "\t\tif (NULL != (v)) {\\\n";
			print $FH "\t\t\tFREE_",$node->{c_name},"(v);\\\n";
			print $FH "\t\t\tCORBA_free(v);\\\n";
			print $FH "\t}\n";
		}
		print $FH "#define FREE_",$node->{c_name},"(v) {\\\n";
		print $FH "\t\tswitch ((v)->_d) {\\\n";
		print $FH $self->{free};
		print $FH "\t\t}\\\n";
#		print $FH "\t\tCORBA_free(v);\\\n";
		print $FH "\t}\n";
	} else {
		print $FH "#define GET_",$node->{c_name},"(ptr,v) {\\\n";
		print $FH "\t\tGET_",$node->{type}->{c_name},"(ptr,&((v)->_d));\\\n";
		print $FH "\t\tswitch ((v)->_d) {\\\n";
		print $FH $self->{get};
		print $FH "\t\t}\\\n";
		print $FH "\t}\n";
		if (exists $self->{client}) {
			print $FH "#define GET_inout_",$node->{c_name}," GET_",$node->{c_name},"\n";
			print $FH "#define GET_out_",$node->{c_name}," GET_",$node->{c_name},"\n";
		}
	}
	print $FH "\n";
	delete $self->{add_size};
	delete $self->{put};
	delete $self->{get};
	delete $self->{get_in};
	delete $self->{get_inout};
	delete $self->{get_out};
	delete $self->{free};
	delete $self->{union};
}

sub visitCase {
	my $self = shift;
	my($node) = @_;
	my $FH = $self->{out};
	foreach (@{$node->{list_label}}) {	# default or expression
		if ($_->isa('Default')) {
			$self->{add_size}  .= "\t\tdefault:\\\n";
			$self->{put}       .= "\t\tdefault:\\\n";
			$self->{get}       .= "\t\tdefault:\\\n";
			$self->{get_in}    .= "\t\tdefault:\\\n";
			$self->{get_inout} .= "\t\tdefault:\\\n";
			$self->{get_out}   .= "\t\tdefault:\\\n";
			$self->{free}      .= "\t\tdefault:\\\n";
		} else {
			$self->{add_size}  .= "\t\tcase " . $_->{c_literal} . ":\\\n";
			$self->{put}       .= "\t\tcase " . $_->{c_literal} . ":\\\n";
			$self->{get}       .= "\t\tcase " . $_->{c_literal} . ":\\\n";
			$self->{get_in}    .= "\t\tcase " . $_->{c_literal} . ":\\\n";
			$self->{get_inout} .= "\t\tcase " . $_->{c_literal} . ":\\\n";
			$self->{get_out}   .= "\t\tcase " . $_->{c_literal} . ":\\\n";
			$self->{free}      .= "\t\tcase " . $_->{c_literal} . ":\\\n";
		}
	}
	$node->{element}->{value}->visit($self);	# array or single
	$self->{add_size}  .= "\t\tbreak;\\\n";
	$self->{put}       .= "\t\tbreak;\\\n";
	$self->{get}       .= "\t\tbreak;\\\n";
	$self->{get_in}    .= "\t\tbreak;\\\n";
	$self->{get_inout} .= "\t\tbreak;\\\n";
	$self->{get_out}   .= "\t\tbreak;\\\n";
	$self->{free}      .= "\t\tbreak;\\\n";
}


#	3.10.2.3	Enumerations
#

sub visitEnumType {
	# empty
}

#
#	3.10.3	Constructed Recursive Types and Forward Declarations
#

sub visitForwardStructType {
	# empty
}

sub visitForwardUnionType {
	# empty
}

#
#	3.10.4	Template Types
#

sub visitSequenceType {
	my $self = shift;
	my($node) = @_;
	if (	   $node->{type}->isa('SequenceType')
			or $node->{type}->isa('FixedPtType') ) {
		$node->{type}->visit($self);
	}
	my $FH = $self->{out};
	print $FH "#ifndef _ALIGN_",$node->{c_name},"_defined\n";
	print $FH "#define _ALIGN_",$node->{c_name},"_defined\n";
	print $FH "#define ADD_SIZE_",$node->{c_name},"(size,v) {\\\n";
	print $FH "\t\t",$node->{type}->{c_name}," * ",$node->{c_name},"_ptr;\\\n";
	print $FH "\t\tADD_SIZE_CORBA_unsigned_long(size,(v)._length);\\\n";
	print $FH "\t\tfor (",$node->{c_name},"_ptr = (v)._buffer;\\\n";
	print $FH "\t\t     ",$node->{c_name},"_ptr < (v)._buffer + (v)._length;\\\n";
	print $FH "\t\t     ",$node->{c_name},"_ptr++) {\\\n";
	print $FH "\t\t\tADD_SIZE_",$node->{type}->{c_name},"(size,*",$node->{c_name},"_ptr);\\\n";
	print $FH "\t\t}\\\n";
	print $FH "\t}\n";
	print $FH "#define PUT_",$node->{c_name},"(ptr,v) {\\\n";
	print $FH "\t\t",$node->{type}->{c_name}," * ",$node->{c_name},"_ptr;\\\n";
	print $FH "\t\tPUT_CORBA_unsigned_long(ptr,(v)._length);\\\n";
	print $FH "\t\tfor (",$node->{c_name},"_ptr = (v)._buffer;\\\n";
	print $FH "\t\t     ",$node->{c_name},"_ptr < (v)._buffer + (v)._length;\\\n";
	print $FH "\t\t     ",$node->{c_name},"_ptr++) {\\\n";
	print $FH "\t\t\tPUT_",$node->{type}->{c_name},"(ptr,*",$node->{c_name},"_ptr);\\\n";
	print $FH "\t\t}\\\n";
	print $FH "\t}\n";
	my $nb = "(v)->_length";
	if (exists $self->{client}) {
		$nb = $node->{max}->{c_literal} if (exists $node->{max});
		print $FH "#define GET_inout_",$node->{c_name},"(ptr,v) {\\\n";
		print $FH "\t\t",$node->{type}->{c_name}," * ",$node->{c_name},"_ptr;\\\n";
		print $FH "\t\tGET_CORBA_unsigned_long(ptr,&((v)->_length));\\\n";
		print $FH "\t\tif (NULL != (v)->_buffer) CORBA_free((v)->_buffer);\\\n";
		print $FH "\t\tif (0 != ",$nb,") {\\\n";
		print $FH "\t\t\t(v)->_buffer = ",$node->{c_name},"__allocbuf(",$nb,");\\\n";
		print $FH "\t\t\tif (NULL == (v)->_buffer) goto err;\\\n";
		print $FH "\t\t\tfor (",$node->{c_name},"_ptr = (v)->_buffer;\\\n";
		print $FH "\t\t\t     ",$node->{c_name},"_ptr < (v)->_buffer + (v)->_length;\\\n";
		print $FH "\t\t\t     ",$node->{c_name},"_ptr++) {\\\n";
		print $FH "\t\t\t\tGET_inout_",$node->{type}->{c_name},"(ptr,",$node->{c_name},"_ptr);\\\n";
		print $FH "\t\t\t}\\\n";
		print $FH "\t\t} else {\\\n";
		print $FH "\t\t\t(v)->_buffer = NULL;\\\n";
		print $FH "\t\t}\\\n";
		print $FH "\t}\n";
		print $FH "#define GET_out_",$node->{c_name},"(ptr,v) {\\\n";
		print $FH "\t\t",$node->{type}->{c_name}," * ",$node->{c_name},"_ptr;\\\n";
		print $FH "\t\tGET_CORBA_unsigned_long(ptr,&((v)->_length));\\\n";
		print $FH "\t\tif (0 != ",$nb,") {\\\n";
		print $FH "\t\t\t(v)->_buffer = ",$node->{c_name},"__allocbuf(",$nb,");\\\n";
		print $FH "\t\t\tif (NULL == (v)->_buffer) goto err;\\\n";
		print $FH "\t\t\tfor (",$node->{c_name},"_ptr = (v)->_buffer;\\\n";
		print $FH "\t\t\t     ",$node->{c_name},"_ptr < (v)->_buffer + (v)->_length;\\\n";
		print $FH "\t\t\t     ",$node->{c_name},"_ptr++) {\\\n";
		print $FH "\t\t\t\tGET_out_",$node->{type}->{c_name},"(ptr,",$node->{c_name},"_ptr);\\\n";
		print $FH "\t\t\t}\\\n";
		print $FH "\t\t} else {\\\n";
		print $FH "\t\t\t(v)->_buffer = NULL;\\\n";
		print $FH "\t\t}\\\n";
		print $FH "\t}\n";
		print $FH "#define ALLOC_GET_out_",$node->{c_name}," GET_out_",$node->{c_name},"\n";
	} else {
		print $FH "#define GET_",$node->{c_name},"(ptr,v) {\\\n";
		print $FH "\t\t",$node->{type}->{c_name}," * ",$node->{c_name},"_ptr;\\\n";
		print $FH "\t\tGET_CORBA_unsigned_long(ptr,&((v)->_length));\\\n";
		print $FH "\t\tif (0 != (v)->_length) {\\\n";
		print $FH "\t\t\t(v)->_buffer = ",$node->{c_name},"__allocbuf(",$nb,");\\\n";
		print $FH "\t\t\tif (NULL == (v)->_buffer) goto err;\\\n";
		print $FH "\t\t\tfor (",$node->{c_name},"_ptr = (v)->_buffer;\\\n";
		print $FH "\t\t\t     ",$node->{c_name},"_ptr < (v)->_buffer + (v)->_length;\\\n";
		print $FH "\t\t\t     ",$node->{c_name},"_ptr++) {\\\n";
		print $FH "\t\t\t\tGET_",$node->{type}->{c_name},"(ptr,",$node->{c_name},"_ptr);\\\n";
		print $FH "\t\t\t}\\\n";
		print $FH "\t\t} else {\\\n";
		print $FH "\t\t\t(v)->_buffer = NULL;\\\n";
		print $FH "\t\t}\\\n";
		print $FH "\t}\n";
		print $FH "#define FREE_in_",$node->{c_name}," FREE_",$node->{c_name},"\n";
		print $FH "#define FREE_inout_",$node->{c_name}," FREE_",$node->{c_name},"\n";
		print $FH "#define FREE_out_",$node->{c_name},"(v) {\\\n";
		print $FH "\t\tif (NULL != (v)) {\\\n";
		print $FH "\t\t\tFREE_",$node->{c_name},"(v);\\\n";
		print $FH "\t\t\tCORBA_free(v);\\\n";
		print $FH "\t\t}\\\n";
		print $FH "\t}\n";
	}
	print $FH "#define FREE_",$node->{c_name},"(v) {\\\n";
	print $FH "\t\tif (NULL != (v)->_buffer) {\\\n";
	if (defined $node->{type}->{length}) {
		print $FH "\t\t\t",$node->{type}->{c_name}," * ",$node->{c_name},"_ptr;\\\n";
		print $FH "\t\t\tfor (",$node->{c_name},"_ptr = (v)->_buffer;\\\n";
		print $FH "\t\t\t     ",$node->{c_name},"_ptr < (v)->_buffer + (v)->_length;\\\n";
		print $FH "\t\t\t     ",$node->{c_name},"_ptr++) {\\\n";
#		print $FH "\t\t\t\tFREE_",$node->{type}->{c_name},"(*",$node->{c_name},"_ptr);\\\n";
		print $FH "\t\t\t\tFREE_",$node->{type}->{c_name},"(",$node->{c_name},"_ptr);\\\n";
		print $FH "\t\t\t}\\\n";
	}
	print $FH "\t\t\tCORBA_free((v)->_buffer);\\\n";
	print $FH "\t\t}\\\n";
	print $FH "\t}\n";
	print $FH "#endif\n";
	print $FH "\n";
}

sub visitFixedPtType {
	my $self = shift;
	my($node) = @_;
	warn __PACKAGE__,"::visitFixedPtType : TODO.\n";
}

#
#	3.11	Exception Declaration
#

sub visitException {
	my $self = shift;
	my($node) = @_;
	return unless (exists $node->{list_expr});
	foreach (@{$node->{list_expr}}) {
		if (	   $_->{type}->isa('StructType')
				or $_->{type}->isa('UnionType')
				or $_->{type}->isa('SequenceType')
				or $_->{type}->isa('FixedPtType') ) {
			$_->{type}->visit($self);
		}
	}
	$self->{add_size} = '';
	$self->{put} = '';
	$self->{get} = '';
	$self->{get_in} = '';
	$self->{get_inout} = '';
	$self->{get_out} = '';
	$self->{free} = '';
	$self->{union} = '';
	foreach (@{$node->{list_value}}) {
		$_->visit($self);			# single or array
	}
	my $FH = $self->{out};
	if (exists $self->{client}) {
		if (defined $node->{length}) {
			print $FH "#define GET_out_",$node->{c_name},"(ptr,v) {\\\n";
			print $FH $self->{get_out};
			print $FH "\t}\n";
			print $FH "#define FREE_",$node->{c_name},"(v) {\\\n";
			print $FH $self->{free};
			print $FH "\t\tCORBA_free(v);\\\n";
			print $FH "\t}\n";
		} else {
			print $FH "#define GET_",$node->{c_name},"(ptr,v) {\\\n";
			print $FH $self->{get};
			print $FH "\t}\n";
		}
	} else {
		print $FH "#define ADD_SIZE_",$node->{c_name},"(size,v) {\\\n";
		print $FH $self->{add_size};
		print $FH "\t}\n";
		print $FH "#define PUT_",$node->{c_name},"(ptr,v) {\\\n";
		print $FH $self->{put};
		print $FH "\t}\n";
	}
	print $FH "\n";
	delete $self->{add_size};
	delete $self->{put};
	delete $self->{get};
	delete $self->{get_in};
	delete $self->{get_inout};
	delete $self->{get_out};
	delete $self->{free};
	delete $self->{union};
}

#
#	3.12	Operation Declaration		(specialized)
#

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

