use strict;

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
		print $FH "use ",$self->{path_use},$module,";\n";
		print $FH "\n";
		push @{$self->{parser}->YYData->{modules}}, $module;
	}
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
	if ($self->{srcname} eq $node->{filename}) {
		print $FH "#\n";
		print $FH "#   begin of module ",$node->{pl_package},"\n";
		print $FH "#\n";
		print $FH "\n";
		print $FH "package ",$node->{pl_package},";\n";
		print $FH "\n";
		print $FH "use Carp;\n";
		print $FH "\n";
		foreach (@{$node->{list_decl}}) {
			$_->visit($self);
		}
		print $FH "\n";
		print $FH "#\n";
		print $FH "#   end of module ",$node->{pl_package},"\n";
		print $FH "#\n";
		print $FH "\n";
	} else {
		$self->_insert_use($node->{filename});
	}
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
#	3.9		Constant Declaration
#

sub visitConstant {
	my $self = shift;
	my($node) = @_;
	if ($self->{srcname} eq $node->{filename}) {
		my $FH = $self->{out};
		print $FH "# ",$node->{pl_package},"::",$node->{pl_name},"\n";
		print $FH "sub ",$node->{pl_name}," () {\n";
		print $FH "\treturn ",$node->{value}->{pl_name},";\n";
		print $FH "}\n";
		print $FH "\n";
	}
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
	if ($self->{srcname} eq $node->{filename}) {
		my $FH = $self->{out};
		print $FH "# ",$node->{pl_package},"::",$node->{pl_name},"\n";
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
				print $FH "\t\t\tunless (scalar(\@{\$_}) == ",$_->{pl_name},");\n";
				print $FH "\tforeach (\@{\$_}) {\n";
			}
			print $FH "\t\t",$node->{type}->{pl_package},'::',$node->{type}->{pl_name};
				print $FH "__marshal(\$r_buffer,\$_);\n";
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
					print $FH "\$idx",$n," < ",$_->{pl_name},"; ";
					print $FH "\$idx",$n,"++) {\n";
			}
			print $FH "\t\tpush \@tab",$n,", ";
				print $FH $node->{type}->{pl_package},'::',$node->{type}->{pl_name},"__demarshal(\$r_buffer,\$r_offset,\$endian);\n";
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
			print $FH "\t",$node->{type}->{pl_package},"::",$node->{type}->{pl_name},"__marshal(\$r_buffer,\$value);\n";
			print $FH "}\n";
			print $FH "\n";
			print $FH "sub ",$node->{idf},"__demarshal {\n";
			print $FH "\tmy (\$r_buffer,\$r_offset,\$endian) = \@_;\n";
			print $FH "\treturn ",$node->{type}->{pl_package},"::",$node->{type}->{pl_name},"__demarshal(\$r_buffer,\$r_offset,\$endian);\n";
			print $FH "}\n";
			print $FH "\n";
		}
		print $FH "\n";
	}
}

#
#	3.10.2	Constructed Types
#
#	3.10.2.1	Structures
#

sub visitStructType {
	my $self = shift;
	my($node) = @_;
	my $name = $node->{pl_package} . "::" . $node->{pl_name};
	return if (exists $self->{done_hash}->{$name});
	$self->{done_hash}->{$name} = 1;
	foreach (@{$node->{list_expr}}) {
		if (	   $_->{type}->isa('StructType')
				or $_->{type}->isa('UnionType')
				or $_->{type}->isa('SequenceType')
				or $_->{type}->isa('FixedPtType') ) {
			$_->{type}->visit($self);
		}
	}
	if ($self->{srcname} eq $node->{filename}) {
		$self->{marshal} = '';
		$self->{demarshal} = '';
		foreach (@{$node->{list_value}}) {
			$self->{val} = "\$value->{" . $_->{idf} . "}";
			$_->visit($self);				# single or array
		}
		delete $self->{val};
		my $FH = $self->{out};
		print $FH "# ",$name,"\n";
		print $FH "sub ",$node->{pl_name},"__marshal {\n";
		print $FH "\t\tmy (\$r_buffer,\$value) = \@_;\n";
		print $FH "\t\tcroak \"undefined value for '",$node->{idf},"'.\\n\"\n";
		print $FH "\t\t\t\tunless (defined \$value);\n";
		print $FH "\t\tcroak \"invalid struct for '",$node->{idf},"' (not a HASH reference).\\n\"\n";
		print $FH "\t\t\t\tunless (ref \$value eq 'HASH');\n";
		foreach (@{$node->{list_value}}) {
			print $FH "\t\tcroak \"no member '",$_->{idf},"' in structure '",$node->{idf},"'.\\n\"\n";
			print $FH "\t\t\t\tunless (exists \$value->{",$_->{idf},"});\n";
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

	$self->{marshal} .= "\t\t\$_ = " . $self->{val} . ";\n";
	foreach (@{$node->{array_size}}) {
		$n ++;
		$self->{marshal} .= "\t\tcroak \"bad size of array '" . $node->{idf} . "'.\\n\"\n";
		$self->{marshal} .= "\t\t\t\tunless (scalar(\@{\$_}) == " . $_->{pl_name} . ");\n";
		$self->{marshal} .= "\t\tforeach (\@{\$_}) {\n";
	}
	if (exists $node->{type}->{max}) {
		$self->{marshal} .= "\t\t\t" . $node->{type}->{pl_package} . '::' . $node->{type}->{pl_name};
			$self->{marshal} .= "__marshal(\$r_buffer,\$_," . $node->{type}->{max}->{value} . ");\n";
	} else {
		$self->{marshal} .= "\t\t\t" . $node->{type}->{pl_package} . '::' . $node->{type}->{pl_name};
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
			$self->{demarshal} .= "\$idx" . $n . " < " . $_->{pl_name} . "; ";
			$self->{demarshal} .= "\$idx" . $n . "++) {\n";
	}
	$self->{demarshal} .= "\t\t\tpush \@" . $node->{idf} . "_tab" . $n . ", ";
		$self->{demarshal} .= $node->{type}->{pl_package} . '::' . $node->{type}->{pl_name} . "__demarshal(\$r_buffer,\$r_offset,\$endian);\n";
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
	if (exists $node->{type}->{max}) {
		$self->{marshal}  .= "\t\t" . $node->{type}->{pl_package} . '::' . $node->{type}->{pl_name} . "__marshal";
			$self->{marshal}  .= "(\$r_buffer," . $self->{val} . "," . $node->{type}->{max}->{value} . ");\n";
	} else {
		$self->{marshal}  .= "\t\t" . $node->{type}->{pl_package} . '::' . $node->{type}->{pl_name} . "__marshal";
			$self->{marshal}  .= "(\$r_buffer," . $self->{val} . ");\n";
	}
	$self->{demarshal}  .= "\t\t" . $self->{val} . " = ";
		$self->{demarshal}  .= $node->{type}->{pl_package} . '::' . $node->{type}->{pl_name} . "__demarshal(\$r_buffer,\$r_offset,\$endian);\n";
}

#	3.10.2.2	Discriminated Unions
#

sub visitUnionType {
	my $self = shift;
	my($node) = @_;
	my $name = $node->{pl_package} . "::" . $node->{pl_name};
	return if (exists $self->{done_hash}->{$name});
	$self->{done_hash}->{$name} = 1;
	foreach (@{$node->{list_expr}}) {
		if (	   $_->{element}->{type}->isa('StructType')
				or $_->{element}->{type}->isa('UnionType')
				or $_->{element}->{type}->isa('EnumType')
				or $_->{element}->{type}->isa('SequenceType')
				or $_->{element}->{type}->isa('FixedPtType') ) {
			$_->{element}->{type}->visit($self);
		}
	}
	if ($self->{srcname} eq $node->{filename}) {
		$self->{marshal} = '';
		$self->{demarshal} = '';
		my $type = $node->{type};
		while ($type->isa('TypeDeclarator')) {
			$type = $type->{type};
		}
		my $equal;
		if ($type->isa('IntegerType')) {
			$equal = "==";
		} else {
			$equal = "eq";
		}
		my $default = undef;
		foreach my $case (@{$node->{list_expr}}) {	# case
			foreach (@{$case->{list_label}}) {	# default or expression
				if ($_->isa('Default')) {
					$default = $case;
				} else {
					$self->{marshal} .= "\t} elsif (\$d " . $equal . " " . $_->{pl_name} . ") {\n";
					$self->{demarshal} .= "\t} elsif (\$d " . $equal . " " . $_->{pl_name} . ") {\n";
					$self->{val} = "\$value";
					$case->{element}->{value}->visit($self);	# array or single
				}
			}
		}
		if (defined $default) {
			$self->{marshal} .= "\t} else {\t# default\n";
			$self->{demarshal} .= "\t} else {\t# default\n";
			$self->{val} = "\$value";
			$default->{element}->{value}->visit($self);	# array or single
		} else {
			$self->{marshal} .= "\t} else {\n";
			$self->{marshal} .= "\t\tcroak \"invalid discriminator (\$d) for '" . $node->{idf} . "'.\\n\";\n";
			$self->{demarshal} .= "\t} else {\n";
			$self->{demarshal} .= "\t\tcroak \"invalid discriminator (\$d) for '" . $node->{idf} . "'.\\n\";\n";
		}
		delete $self->{val};
		my $FH = $self->{out};
		print $FH "# ",$name,"\n";
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
		print $FH "\t",$node->{type}->{pl_package},"::",$node->{type}->{pl_name},"__marshal(\$r_buffer,\$d);\n";
		print $FH "\tif (0) {\n";
		print $FH "\t\t# empty\n";
		print $FH $self->{marshal};
		print $FH "\t}\n";
		print $FH "}\n";
		print $FH "sub ",$node->{pl_name},"__demarshal {\n";
		print $FH "\tmy (\$r_buffer,\$r_offset,\$endian) = \@_;\n";
		print $FH "\tmy \$value = undef;\n";
		print $FH "\tmy \$d = ",$node->{type}->{pl_package},"::",$node->{type}->{pl_name},"__demarshal(\$r_buffer,\$r_offset,\$endian);\n";
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

#	3.10.2.3	Enumerations
#

sub visitEnumType {
	my $self = shift;
	my($node) = @_;
	my $name = $node->{pl_package} . "::" . $node->{pl_name};
	return if (exists $self->{done_hash}->{$name});
	$self->{done_hash}->{$name} = 1;
	if ($self->{srcname} eq $node->{filename}) {
		my $FH = $self->{out};
		print $FH "# ",$name,"\n";
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
	my $name = $node->{pl_package} . "::" . $node->{pl_name};
	return if (exists $self->{done_hash}->{$name});
	$self->{done_hash}->{$name} = 1;
	if ($self->{srcname} eq $node->{filename}) {
		my $type = $node->{type};
		while (		$type->isa('TypeDeclarator')
				and ! exists $type->{array_size} ) {
			$type = $type->{type};
		}
		if (	   $node->{type}->isa('SequenceType')
				or $node->{type}->isa('FixedPtType') ) {
			$type->visit($self);
		}
		my $FH = $self->{out};
		print $FH "# ",$name,"\n";
		print $FH "sub ",$node->{pl_name},"__marshal {\n";
		print $FH "\tmy (\$r_buffer,\$value,\$max) = \@_;\n";
		print $FH "\tcroak \"undefined value for '",$node->{pl_name},"'.\\n\"\n";
		print $FH "\t\t\tunless (defined \$value);\n";
		if        ( $type->{pl_name} eq 'char'
				 or $type->{pl_name} eq 'octet' ) {
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

#
#	3.11	Exception Declaration
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
			if (	   $_->{type}->isa('StructType')
					or $_->{type}->isa('UnionType')
					or $_->{type}->isa('SequenceType')
					or $_->{type}->isa('FixedPtType') ) {
				$_->{type}->visit($self);
			}
		}
	}
	if ($self->{srcname} eq $node->{filename}) {
		$self->{marshal} = '';
		$self->{demarshal} = '';
		foreach (@{$node->{list_value}}) {
			$self->{val} = "\$value->{" . $_->{idf} . "}";
			$_->visit($self);				# single or array
		}
		delete $self->{val};
		my $FH = $self->{out};
		print $FH "# ",$name,"\n";
		print $FH "sub ",$node->{pl_name},"__marshal {\n";
		print $FH "\t\tmy (\$r_buffer,\$value) = \@_;\n";
		print $FH "\t\tcroak \"undefined value for '",$node->{idf},"'.\\n\"\n";
		print $FH "\t\t\t\tunless (defined \$value);\n";
		foreach (@{$node->{list_value}}) {
			print $FH "\t\tcroak \"no member '",$_->{idf},"' in structure '",$node->{idf},"'.\\n\"\n";
			print $FH "\t\t\t\tunless (exists \$value->{",$_->{idf},"});\n";
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
				print $FH "\t\$str .= \"\\t",$_->{idf}," => \$self->{",$_->{idf},"}\\n\";\n";
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

