use strict;

#
#			Interface Definition Language (OMG IDL CORBA v3.0)
#

package PerlCdrVisitor;

# needs $node->{pl_name} $node->{pl_package} (PerlNameVisitor)

sub open_stream {
	my $self = shift;
	my($filename) = @_;
	open(OUT, "> $filename")
			or die "can't open $filename ($!).\n";
	$self->{out} = \*OUT;
	$self->{filename} = $filename;
}

sub _insert_use {
	my $self = shift;
	my($module) = @_;
	my $FH = $self->{out};
	$module =~ s/^([^\/]+\/)+//;
	$module =~ s/\.idl$//i;
	unless (exists $self->{use}->{$module}) {
		$self->{use}->{$module} = 1;
		push @{$self->{parser}->YYData->{modules}}, $module;
		print $FH "use ",$self->{path_use},$module,";\n";
		print $FH "\n";
	}
}

sub _get_defn {
	my $self = shift;
	my($defn) = @_;
	if (ref $defn) {
		return $defn;
	} else {
		return $self->{symbtab}->Lookup($defn);
	}
}

#
#	3.5		OMG IDL Specification		(specialized)
#

#
#	3.7		Module Declaration
#

sub visitModules {
	my $self = shift;
	my($node) = @_;
	unless (exists $node->{$self->{num_key}}) {
		$node->{$self->{num_key}} = 0;
	}
	my $module = ${$node->{list_decl}}[$node->{$self->{num_key}}];
	$module->visit($self);
	$node->{$self->{num_key}} ++;
}

sub visitModule {
	my $self = shift;
	my($node) = @_;
	my $FH = $self->{out};
	if ($self->{srcname} eq $node->{filename}) {
		my $defn = $self->{symbtab}->Lookup($node->{full});
		print $FH "#\n";
		print $FH "#   begin of module ",$defn->{pl_package},"\n";
		print $FH "#\n";
		print $FH "\n";
		print $FH "package ",$defn->{pl_package},";\n";
		print $FH "\n";
		print $FH "use Carp;\n";
		print $FH "\n";
		foreach (@{$node->{list_decl}}) {
			$self->_get_defn($_)->visit($self);
		}
		print $FH "\n";
		print $FH "#\n";
		print $FH "#   end of module ",$defn->{pl_package},"\n";
		print $FH "#\n";
		print $FH "\n";
	} else {
		$self->_insert_use($node->{filename});
	}
}

#
#	3.8		Interface Declaration		(specialized)
#

sub visitLocalInterface {
	# empty
}

sub visitForwardRegularInterface {
	# empty
}

sub visitForwardAbstractInterface {
	# empty
}

sub visitForwardLocalInterface {
	# empty
}

#
#	3.9		Value Declaration
#

sub visitRegularValue {
	# empty
}

sub visitBoxedValue {
	# empty
}

sub visitAbstractValue {
	# empty
}

sub visitForwardRegularValue {
	# empty
}

sub visitForwardAbstractValue {
	# empty
}

#
#	3.10	Constant Declaration
#

sub visitConstant {
	my $self = shift;
	my($node) = @_;
	if ($self->{srcname} eq $node->{filename}) {
		my $FH = $self->{out};
		print $FH "# ",$node->{pl_package},"::",$node->{pl_name},"\n";
		print $FH "sub ",$node->{pl_name}," () {\n";
		print $FH "\treturn ",$node->{value}->{pl_literal},";\n";
		print $FH "}\n";
		print $FH "\n";
	}
}

#
#	3.11	Type Declaration
#

sub visitTypeDeclarators {
	my $self = shift;
	my($node) = @_;
	foreach (@{$node->{list_decl}}) {
		$self->_get_defn($_)->visit($self);
	}
}

sub visitTypeDeclarator {
	my $self = shift;
	my($node) = @_;
	return if (exists $node->{modifier});	# native IDL2.2
	my $type = $self->_get_defn($node->{type});
	if (	   $type->isa('StructType')
			or $type->isa('UnionType')
			or $type->isa('EnumType')
			or $type->isa('SequenceType')
			or $type->isa('FixedPtType') ) {
		$type->visit($self);
	}
	if ($self->{srcname} eq $node->{filename}) {
		my $FH = $self->{out};
		print $FH "# ",$node->{pl_package},"::",$node->{pl_name}," (typedef)\n";
		if (exists $node->{array_size}) {
			warn __PACKAGE__,"::visitTypeDecalarator $node->{idf} : empty array_size.\n"
					unless (@{$node->{array_size}});
			my $n;

			print $FH "sub ",$node->{idf},"__marshal {\n";
			print $FH "\tmy (\$r_buffer,\$value) = \@_;\n";
			print $FH "\tcroak \"undefined value for '",$node->{idf},"'.\\n\"\n";
			print $FH "\t\t\tunless (defined \$value);\n";
			$n = 0;
			print $FH "\t\$_ = \$value;\n";
			foreach (@{$node->{array_size}}) {
				$n ++;
				print $FH "\tcroak \"bad size of array '",$node->{idf},"'.\\n\"\n";
				print $FH "\t\t\tunless (scalar(\@{\$_}) == ",$_->{pl_literal},");\n";
				print $FH "\tforeach (\@{\$_}) {\n";
			}
			if (exists $type->{max}) {
				print $FH "\t\t",$type->{pl_package},'::',$type->{pl_name},"__marshal(\$r_buffer,\$_,",$type->{max}->{value},");\n";
			} else {
				print $FH "\t\t",$type->{pl_package},'::',$type->{pl_name},"__marshal(\$r_buffer,\$_);\n";
			}
			while ($n--) {
				print $FH "\t}\n";
			}
			print $FH "}\n";
			print $FH "\n";

			print $FH "sub ",$node->{idf},"__demarshal {\n";
			print $FH "\tmy (\$r_buffer,\$r_offset,\$endian) = \@_;\n";
			$n = 0;
			foreach (@{$node->{array_size}}) {
				$n ++;
				print $FH "\tmy \@tab",$n," = ();\n";
				print $FH "\tfor (my \$idx",$n," = 0; ";
					print $FH "\$idx",$n," < ",$_->{pl_literal},"; ";
					print $FH "\$idx",$n,"++) {\n";
			}
			print $FH "\t\tpush \@tab",$n,", ";
				print $FH $type->{pl_package},'::',$type->{pl_name},"__demarshal(\$r_buffer,\$r_offset,\$endian);\n";
			print $FH "\t}\n";
			while ($n > 1) {
				print $FH "\t\tpush \@tab",($n - 1),", ";
					print $FH "\\\@tab",$n,";\n";
				print $FH "\t}\n";
				$n --;
			}
			print $FH "\treturn \\\@tab1;\n";
			print $FH "}\n";
			print $FH "\n";
		} else {
			print $FH "sub ",$node->{idf},"__marshal {\n";
			print $FH "\tmy (\$r_buffer,\$value) = \@_;\n";
			print $FH "\tcroak \"undefined value for '",$node->{idf},"'.\\n\"\n";
			print $FH "\t\t\tunless (defined \$value);\n";
			if (exists $type->{max}) {
				print $FH "\t",$type->{pl_package},"::",$type->{pl_name},"__marshal(\$r_buffer,\$value,",$type->{max}->{value},");\n";
			} else {
				print $FH "\t",$type->{pl_package},"::",$type->{pl_name},"__marshal(\$r_buffer,\$value);\n";
			}
			print $FH "}\n";
			print $FH "\n";
			print $FH "sub ",$node->{idf},"__demarshal {\n";
			print $FH "\tmy (\$r_buffer,\$r_offset,\$endian) = \@_;\n";
			print $FH "\treturn ",$type->{pl_package},"::",$type->{pl_name},"__demarshal(\$r_buffer,\$r_offset,\$endian);\n";
			print $FH "}\n";
			print $FH "\n";
		}
		print $FH "\n";
	}
}

#
#	3.11.2	Constructed Types
#
#	3.11.2.1	Structures
#

sub visitStructType {
	my $self = shift;
	my($node) = @_;
	my $name = $node->{pl_package} . "::" . $node->{pl_name};
	return if (exists $self->{done_hash}->{$name});
	$self->{done_hash}->{$name} = 1;
	foreach (@{$node->{list_expr}}) {
		my $type = $self->_get_defn($_->{type});
		if (	   $type->isa('StructType')
				or $type->isa('UnionType')
				or $type->isa('SequenceType')
				or $type->isa('FixedPtType') ) {
			$type->visit($self);
		}
	}
	if ($self->{srcname} eq $node->{filename}) {
		$self->{marshal} = '';
		$self->{demarshal} = '';
		foreach (@{$node->{list_value}}) {
			my $member = $self->_get_defn($_);			# single or array
			$self->{val} = "\$value->{" . $member->{idf} . "}";
			$member->visit($self);
		}
		delete $self->{val};
		my $FH = $self->{out};
		print $FH "# ",$name," (struct)\n";
		print $FH "sub ",$node->{pl_name},"__marshal {\n";
		print $FH "\t\tmy (\$r_buffer,\$value) = \@_;\n";
		print $FH "\t\tcroak \"undefined value for '",$node->{idf},"'.\\n\"\n";
		print $FH "\t\t\t\tunless (defined \$value);\n";
		print $FH "\t\tcroak \"invalid struct for '",$node->{idf},"' (not a HASH reference).\\n\"\n";
		print $FH "\t\t\t\tunless (ref \$value eq 'HASH');\n";
		foreach (@{$node->{list_value}}) {
			my $member = $self->_get_defn($_);			# single or array
			print $FH "\t\tcroak \"no member '",$member->{idf},"' in structure '",$node->{idf},"'.\\n\"\n";
			print $FH "\t\t\t\tunless (exists \$value->{",$member->{idf},"});\n";
		}
		print $FH $self->{marshal};
		print $FH "}\n";
		print $FH "sub ",$node->{pl_name},"__demarshal {\n";
		print $FH "\t\tmy (\$r_buffer,\$r_offset,\$endian) = \@_;\n";
		print $FH "\t\tmy \$value = {};\n";
		print $FH $self->{demarshal};
		print $FH "\t\treturn \$value;\n";
		print $FH "}\n";
		print $FH "\n";
		delete $self->{marshal};
		delete $self->{demarshal};
	}
}

sub visitArray {
	my $self = shift;
	my($node) = @_;
	my $n = 0;
	my $type = $self->_get_defn($node->{type});
	$self->{marshal} .= "\t\t\$_ = " . $self->{val} . ";\n";
	foreach (@{$node->{array_size}}) {
		$n ++;
		$self->{marshal} .= "\t\tcroak \"bad size of array '" . $node->{idf} . "'.\\n\"\n";
		$self->{marshal} .= "\t\t\t\tunless (scalar(\@{\$_}) == " . $_->{pl_literal} . ");\n";
		$self->{marshal} .= "\t\tforeach (\@{\$_}) {\n";
	}
	if (exists $type->{max}) {
		$self->{marshal} .= "\t\t\t" . $type->{pl_package} . '::' . $type->{pl_name};
			$self->{marshal} .= "__marshal(\$r_buffer,\$_," . $type->{max}->{value} . ");\n";
	} else {
		$self->{marshal} .= "\t\t\t" . $type->{pl_package} . '::' . $type->{pl_name};
			$self->{marshal} .= "__marshal(\$r_buffer,\$_);\n";
	}
	while ($n--) {
		$self->{marshal} .= "\t\t}\n";
	}

	$n = 0;
	foreach (@{$node->{array_size}}) {
		$n ++;
		$self->{demarshal} .= "\t\tmy \@" . $node->{idf} . "_tab" . $n . " = ();\n";
		$self->{demarshal} .= "\t\tfor (my \$idx" . $n . " = 0; ";
			$self->{demarshal} .= "\$idx" . $n . " < " . $_->{pl_literal} . "; ";
			$self->{demarshal} .= "\$idx" . $n . "++) {\n";
	}
	$self->{demarshal} .= "\t\t\tpush \@" . $node->{idf} . "_tab" . $n . ", ";
		$self->{demarshal} .= $type->{pl_package} . '::' . $type->{pl_name} . "__demarshal(\$r_buffer,\$r_offset,\$endian);\n";
	$self->{demarshal} .= "\t\t}\n";
	while ($n > 1) {
		$self->{demarshal} .= "\t\t\tpush \@" . $node->{idf} . "_tab" . ($n - 1) . ", ";
			$self->{demarshal} .= "\\\@" . $node->{idf} . "_tab" . $n . ";\n";
		$self->{demarshal} .= "\t\t}\n";
		$n --;
	}
	$self->{demarshal} .= "\t\t" . $self->{val} . " = \\\@" . $node->{idf} . "_tab1;\n";
}

sub visitSingle {
	my $self = shift;
	my($node) = @_;
	my $type = $self->_get_defn($node->{type});
	if (exists $type->{max}) {
		$self->{marshal}  .= "\t\t" . $type->{pl_package} . '::' . $type->{pl_name} . "__marshal";
			$self->{marshal}  .= "(\$r_buffer," . $self->{val} . "," . $type->{max}->{value} . ");\n";
	} else {
		$self->{marshal}  .= "\t\t" . $type->{pl_package} . '::' . $type->{pl_name} . "__marshal";
			$self->{marshal}  .= "(\$r_buffer," . $self->{val} . ");\n";
	}
	$self->{demarshal}  .= "\t\t" . $self->{val} . " = ";
		$self->{demarshal}  .= $type->{pl_package} . '::' . $type->{pl_name} . "__demarshal(\$r_buffer,\$r_offset,\$endian);\n";
}

#	3.11.2.2	Discriminated Unions
#

sub visitUnionType {
	my $self = shift;
	my($node) = @_;
	my $name = $node->{pl_package} . "::" . $node->{pl_name};
	return if (exists $self->{done_hash}->{$name});
	$self->{done_hash}->{$name} = 1;
	foreach (@{$node->{list_expr}}) {
		my $type = $self->_get_defn($_->{element}->{type});
		if (	   $type->isa('StructType')
				or $type->isa('UnionType')
				or $type->isa('EnumType')
				or $type->isa('SequenceType')
				or $type->isa('FixedPtType') ) {
			$type->visit($self);
		}
	}
	if ($self->{srcname} eq $node->{filename}) {
		$self->{marshal} = '';
		$self->{demarshal} = '';
		my $type = $self->_get_defn($node->{type});
		while ($type->isa('TypeDeclarator')) {
			$type = $self->_get_defn($type->{type});
		}
		my $equal;
		if ($type->isa('IntegerType')) {
			$equal = "==";
		} else {
			$equal = "eq";
		}
		$type = $self->_get_defn($node->{type});
		my $default = undef;
		foreach my $case (@{$node->{list_expr}}) {	# case
			foreach (@{$case->{list_label}}) {	# default or expression
				if ($_->isa('Default')) {
					$default = $case;
				} else {
					$self->{marshal} .= "\t} elsif (\$d " . $equal . " " . $_->{pl_literal} . ") {\n";
					$self->{demarshal} .= "\t} elsif (\$d " . $equal . " " . $_->{pl_literal} . ") {\n";
					$self->{val} = "\$value";
					$self->_get_defn($case->{element}->{value})->visit($self);	# array or single
				}
			}
		}
		if (defined $default) {
			$self->{marshal} .= "\t} else {\t# default\n";
			$self->{demarshal} .= "\t} else {\t# default\n";
			$self->{val} = "\$value";
			$self->_get_defn($default->{element}->{value})->visit($self);	# array or single
		} else {
			$self->{marshal} .= "\t} else {\n";
			$self->{marshal} .= "\t\tcroak \"invalid discriminator (\$d) for '" . $node->{idf} . "'.\\n\";\n";
			$self->{demarshal} .= "\t} else {\n";
			$self->{demarshal} .= "\t\tcroak \"invalid discriminator (\$d) for '" . $node->{idf} . "'.\\n\";\n";
		}
		delete $self->{val};
		my $FH = $self->{out};
		print $FH "# ",$name," (union)\n";
		print $FH "sub ",$node->{pl_name},"__marshal {\n";
		print $FH "\tmy (\$r_buffer,\$union) = \@_;\n";
		print $FH "\tcroak \"undefined value for '",$node->{idf},"'.\\n\"\n";
		print $FH "\t\t\tunless (defined \$union);\n";
		print $FH "\tcroak \"invalid union for '",$node->{idf},"' (not a ARRAY reference).\\n\"\n";
		print $FH "\t\t\tunless (ref \$union eq 'ARRAY');\n";
		print $FH "\tcroak \"invalid union '",$node->{idf},"'.\\n\"\n";
		print $FH "\t\t\tunless (scalar(\@{\$union}) == 2);\n";
		print $FH "\tmy \$d = \${\$union}[0];\n";
		print $FH "\tmy \$value = \${\$union}[1];\n";
		print $FH "\t",$type->{pl_package},"::",$type->{pl_name},"__marshal(\$r_buffer,\$d);\n";
		print $FH "\tif (0) {\n";
		print $FH "\t\t# empty\n";
		print $FH $self->{marshal};
		print $FH "\t}\n";
		print $FH "}\n";
		print $FH "sub ",$node->{pl_name},"__demarshal {\n";
		print $FH "\tmy (\$r_buffer,\$r_offset,\$endian) = \@_;\n";
		print $FH "\tmy \$value = undef;\n";
		print $FH "\tmy \$d = ",$type->{pl_package},"::",$type->{pl_name},"__demarshal(\$r_buffer,\$r_offset,\$endian);\n";
		print $FH "\tif (0) {\n";
		print $FH "\t\t# empty\n";
		print $FH $self->{demarshal};
		print $FH "\t}\n";
		print $FH "\treturn [\$d,\$value];\n";
		print $FH "}\n";
		print $FH "\n";
		delete $self->{marshal};
		delete $self->{demarshal};
	}
}

#	3.11.2.3	Constructed Recursive Types and Forward Declarations
#

sub visitForwardStructType {
	# empty
}

sub visitForwardUnionType {
	# empty
}

#	3.11.2.4	Enumerations
#

sub visitEnumType {
	my $self = shift;
	my($node) = @_;
	my $name = $node->{pl_package} . "::" . $node->{pl_name};
	return if (exists $self->{done_hash}->{$name});
	$self->{done_hash}->{$name} = 1;
	if ($self->{srcname} eq $node->{filename}) {
		my $FH = $self->{out};
		print $FH "# ",$name," (enum)\n";
		print $FH "sub ",$node->{pl_name},"__marshal {\n";
		print $FH "\tmy (\$r_buffer,\$value) = \@_;\n";
		print $FH "\tif (0) {\n";
		my $idx = 0;
		foreach (@{$node->{list_expr}}) {
			print $FH "\t} elsif (\$value eq '",$_->{pl_name},"') {\n";
			print $FH "\t\tCORBA::unsigned_long__marshal(\$r_buffer,",$idx++,");\n";
		}
		print $FH "\t} else {\n";
		print $FH "\t\tcroak \"bad value for '",$name,"'.\\n\";\n";
		print $FH "\t}\n";
		print $FH "}\n";
		print $FH "sub ",$node->{pl_name},"__demarshal {\n";
		print $FH "\tmy \$value = CORBA::unsigned_long__demarshal(\@_);\n";
		print $FH "\tif (0) {\n";
		$idx = 0;
		foreach (@{$node->{list_expr}}) {
			print $FH "\t} elsif (\$value == ",$idx++,") {\n";
			print $FH "\t\treturn '",$_->{pl_name},"';\n";
		}
		print $FH "\t} else {\n";
		print $FH "\t\tcroak \"bad value for '",$name,"'.\\n\";\n";
		print $FH "\t}\n";
		print $FH "}\n";
		print $FH "\n";
		foreach (@{$node->{list_expr}}) {
			$_->visit($self);			# enum
		}
		print $FH "\n";
	}
}

sub visitEnum {
	my $self = shift;
	my($node) = @_;
	my $FH = $self->{out};
	print $FH "sub ",$node->{pl_name}," () {\n";
	print $FH "\treturn '",$node->{pl_name},"';\n";
	print $FH "}\n";
}

#
#	3.11.3	Template Types
#

sub visitSequenceType {
	my $self = shift;
	my($node) = @_;
	my $name = $node->{pl_package} . "::" . $node->{pl_name};
	return if (exists $self->{done_hash}->{$name});
	$self->{done_hash}->{$name} = 1;
	if ($self->{srcname} eq $node->{filename}) {
		my $type = $self->_get_defn($node->{type});
		if (	   $type->isa('SequenceType')
				or $type->isa('FixedPtType') ) {
			$type->visit($self);
		}
		my $FH = $self->{out};
		print $FH "# ",$name," (sequence)\n";
		print $FH "sub ",$node->{pl_name},"__marshal {\n";
		print $FH "\tmy (\$r_buffer,\$value,\$max) = \@_;\n";
		print $FH "\tcroak \"undefined value for '",$node->{pl_name},"'.\\n\"\n";
		print $FH "\t\t\tunless (defined \$value);\n";
		if        ( $type->{pl_name} eq 'char'
				 or $type->{pl_name} eq 'octet' ) {
			print $FH "\tcroak \"value '\$value' is not a string.\\n\"\n";
			print $FH "\t\t\tif (ref \$value);\n";
			print $FH "\tmy \$len = length(\$value);\n";
			print $FH "\tcroak \"too long sequence for '",$node->{pl_name},"' (max:\$max).\\n\"\n";
			print $FH "\t\t\tif (defined \$max and \$len > \$max);\n";
			print $FH "\tCORBA::unsigned_long__marshal(\$r_buffer,\$len);\n";
			print $FH "\t\$\$r_buffer .= \$value;\n";
		} else {
			print $FH "\tmy \$len = scalar(\@{\$value});\n";
			print $FH "\tcroak \"too long sequence for '",$node->{pl_name},"' (max:\$max).\\n\"\n";
			print $FH "\t\t\tif (defined \$max and \$len > \$max);\n";
			print $FH "\tCORBA::unsigned_long__marshal(\$r_buffer,\$len);\n";
			print $FH "\tforeach (\@{\$value}) {\n";
			print $FH "\t\t",$type->{pl_package},"::",$type->{pl_name},"__marshal(\$r_buffer,\$_);\n";
			print $FH "\t}\n";
		}
		print $FH "}\n";
		print $FH "\n";
		print $FH "sub ",$node->{pl_name},"__demarshal {\n";
		print $FH "\tmy (\$r_buffer,\$r_offset,\$endian) = \@_;\n";
		print $FH "\tmy \$len = CORBA::unsigned_long__demarshal(\$r_buffer,\$r_offset,\$endian);\n";
		print $FH "\tmy \@seq = ();\n";
		if        ( $type->{pl_name} eq 'char'
				 or $type->{pl_name} eq 'octet' ) {
			print $FH "\tmy \$str = substr \$\$r_buffer, \$\$r_offset, \$len;\n";
			print $FH "\t\$\$r_offset += \$len;\n";
			print $FH "\treturn \$str;\n";
		} else {
			print $FH "\twhile (\$len--) {\n";
			print $FH "\t\tpush \@seq,",$type->{pl_package},"::",$type->{pl_name},"__demarshal(\$r_buffer,\$r_offset,\$endian);\n";
			print $FH "\t}\n";
			print $FH "\treturn \\\@seq;\n";
		}
		print $FH "}\n";
		print $FH "\n";
	}
}

sub visitFixedPtType {
	# empty
}

sub visitFixedPtConstType {
	# empty
}

#
#	3.12	Exception Declaration
#

sub visitException {
	my $self = shift;
	my($node) = @_;
	my $name = $node->{pl_package} . "::" . $node->{pl_name};
	return if (exists $self->{done_hash}->{$name});
	$self->{done_hash}->{$name} = 1;
	if (exists $node->{list_expr}) {
		warn __PACKAGE__,"::visitException $node->{idf} : empty list_expr.\n"
				unless (@{$node->{list_expr}});

		foreach (@{$node->{list_expr}}) {
			my $type = $self->_get_defn($_->{type});
			if (	   $type->isa('StructType')
					or $type->isa('UnionType')
					or $type->isa('SequenceType')
					or $type->isa('FixedPtType') ) {
				$type->visit($self);
			}
		}
	}
	if ($self->{srcname} eq $node->{filename}) {
		$self->{marshal} = '';
		$self->{demarshal} = '';
		foreach (@{$node->{list_value}}) {
			my $member = $self->_get_defn($_);			# single or array
			$self->{val} = "\$value->{" . $member->{idf} . "}";
			$member->visit($self);				# single or array
		}
		delete $self->{val};
		my $FH = $self->{out};
		print $FH "# ",$name," (exception)\n";
		print $FH "sub ",$node->{pl_name},"__marshal {\n";
		print $FH "\t\tmy (\$r_buffer,\$value) = \@_;\n";
		print $FH "\t\tcroak \"undefined value for '",$node->{idf},"'.\\n\"\n";
		print $FH "\t\t\t\tunless (defined \$value);\n";
		foreach (@{$node->{list_value}}) {
			my $member = $self->_get_defn($_);			# single or array
			print $FH "\t\tcroak \"no member '",$member->{idf},"' in structure '",$node->{idf},"'.\\n\"\n";
			print $FH "\t\t\t\tunless (exists \$value->{",$member->{idf},"});\n";
		}
		print $FH $self->{marshal};
		print $FH "}\n";
		print $FH "sub ",$node->{pl_name},"__demarshal {\n";
		print $FH "\t\tmy (\$r_buffer,\$r_offset,\$endian) = \@_;\n";
		print $FH "\t\tmy \$value = {};\n";
		print $FH $self->{demarshal};
		print $FH "\t\treturn \$value;\n";
		print $FH "}\n";
		print $FH "\n";
		delete $self->{marshal};
		delete $self->{demarshal};
		print $FH "package ",$node->{pl_package},"::",$node->{pl_name},";\n";
		print $FH "\n";
		print $FH "\@",$node->{pl_package},"::",$node->{pl_name},"::ISA = qw(CORBA::UserException);\n";
		print $FH "\n";
		print $FH "sub new {\n";
		print $FH "\tmy \$self = shift;\n";
		print $FH "\tlocal \$Error::Depth = \$Error::Depth + 1;\n";
		print $FH "\t\$self->SUPER::new(\@_);\n";
		print $FH "}\n";
		print $FH "\n";
		print $FH "sub stringify {\n";
		print $FH "\tmy \$self = shift;\n";
		print $FH "\tmy \$str = \$self->SUPER::stringify() . \"\\n\";\n";
		if (scalar(@{$node->{list_value}})) {
			foreach (@{$node->{list_value}}) {
				my $member = $self->_get_defn($_);			# single or array
				print $FH "\t\$str .= \"\\t",$member->{idf}," => \$self->{",$member->{idf},"}\\n\";\n";
			}
		} else {
			print $FH "\t\$str .= \"\\t(no data)\";\n";
		}
		print $FH "\t\$str .= sprintf(\" at \%s line \%d.\\n\", \$self->file, \$self->line);\n";
		print $FH "\treturn \$str;\n";
		print $FH "}\n";
		print $FH "\n";
		print $FH "package ",$node->{pl_package},";\n";
		print $FH "\n";
	}
}

#
#	3.13	Operation Declaration		(specialized)
#

#
#	3.14	Attribute Declaration
#

sub visitAttribute {
	my $self = shift;
	my($node) = @_;
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

#
#	3.16	Event Declaration
#

sub visitRegularEvent {
	# empty
}

sub visitAbstractEvent {
	# empty
}

sub visitForwardRegularEvent {
	# empty
}

sub visitForwardAbstractEvent {
	# empty
}

#
#	3.17	Component Declaration
#

sub visitComponent {
	# empty
}

sub visitForwardComponent {
	# empty
}

#
#	3.18	Home Declaration
#

sub visitHome {
	# empty
}

1;

