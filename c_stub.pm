use strict;
use POSIX qw(ctime);

use CORBA::XS::c_cdr;

package XS_CstubVisitor;

@XS_CstubVisitor::ISA = qw(CcdrVisitor);

# needs $node->{c_name} (CnameVisitor), $node->{c_literal} (CliteralVisitor)

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self = {};
	bless($self, $class);
	my($parser,$incpath,$prefix) = @_;
	$self->{incpath} = $incpath || '';
#	$prefix = 'skel_' unless (defined $prefix);
#	$self->{prefix} = $prefix;
	$self->{prefix} = '';
	$self->{srcname} = $parser->YYData->{srcname};
	$self->{srcname_size} = $parser->YYData->{srcname_size};
	$self->{srcname_mtime} = $parser->YYData->{srcname_mtime};
	$self->{server} = 1;
	my $filename = $self->{srcname};
	$filename =~ s/^([^\/]+\/)+//;
	$filename =~ s/\.idl$//i;
	$filename = 'cdr_' . $filename . '.c';
	$self->open_stream($filename);
	$self->{done_hash} = {};
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
	$filename = $self->{prefix} . $filename . '.h';
	my $FH = $self->{out};
	print $FH "/* This file is generated. DO NOT modify it */\n";
	print $FH "/* From file : ",$self->{srcname},", ",$self->{srcname_size}," octets, ",POSIX::ctime($self->{srcname_mtime});
	print $FH " * Generation date : ",POSIX::ctime(time());
	print $FH " */\n";
	print $FH "\n";
	print $FH "#include <string.h>\n";
	print $FH "#include <",$self->{incpath},"cdr.h>\n";
	print $FH "#include \"",$filename,"\"\n";
	print $FH "\n";
	print $FH "\n";
	foreach (@{$node->{list_decl}}) {
		$_->visit($self);
	}
	print $FH "/* end of file : ",$self->{filename}," */\n";
	close $FH;
}

#
#	3.6		Module Declaration			(inherited)
#

#
#	3.7		Interface Declaration
#

sub visitInterface {
	my $self = shift;
	my($node) = @_;
	my $FH = $self->{out};
	print $FH "/*\n";
	print $FH " * begin of interface ",$node->{c_name},"\n";
	print $FH " */\n";
	$self->{itf} = $node->{c_name};
	foreach (@{$node->{list_decl}}) {
		if (	   $_->isa('Operation')
				or $_->isa('Attributes') ) {
			next;
		}
		$_->visit($self);
	}
	print $FH "\n";
	if (		$self->{srcname} eq $node->{filename}
			and keys %{$node->{hash_attribute_operation}}
			and ! exists $node->{modifier} ) {		# abstract or native
		print $FH "\t\t/*-- functions --*/\n";
		print $FH "\n";
		foreach (values %{$node->{hash_attribute_operation}}) {
			$_->visit($self);
		}
		print $FH "\n";
	}
	print $FH "/*\n";
	print $FH " * end of interface ",$node->{c_name},"\n";
	print $FH " */\n";
	print $FH "\n";
}

#
#	3.8		Value Declaration			(inherited)
#

#
#	3.9		Constant Declaration		(inherited)
#

#
#	3.10	Type Declaration			(inherited)
#

#
#	3.11	Exception Declaration		(inherited)
#

#
#	3.12	Operation Declaration
#

sub visitOperation {
	my $self = shift;
	my($node) = @_;
	my $FH = $self->{out};
	my $label_err = undef;
	my $nb_param_out = 0;
	my $nb_param_in = 0;
	unless ($node->{type}->isa("VoidType")) {		# return
		$label_err = $node->{type}->{length};
		$nb_param_out ++;
		$node->{c_put_name} = Cname_put2->NameAttr($node->{type},'return') . "_ret";
	}
	foreach (@{$node->{list_in}}) {					# paramater
		$_->{c_get_ptr_name} = Cptrname_get2->NameAttr($_->{type},$_->{attr}) . $_->{c_name};
		$label_err ||= $_->{type}->{length};
		$nb_param_in ++;
	}
	foreach (@{$node->{list_inout}}) {				# paramater
		$_->{c_get_ptr_name} = Cptrname_get2->NameAttr($_->{type},$_->{attr}) . $_->{c_name};
		$_->{c_put_name} = Cname_put2->NameAttr($_->{type},$_->{attr}) . $_->{c_name};
		$label_err ||= $_->{type}->{length};
		$nb_param_in ++;
		$nb_param_out ++;
	}
	foreach (@{$node->{list_out}}) {				# paramater
		$_->{c_get_ptr_name} = Cptrname_get2->NameAttr($_->{type},$_->{attr}) . $_->{c_name};
		$_->{c_put_name} = Cname_put2->NameAttr($_->{type},$_->{attr}) . $_->{c_name};
		$nb_param_out ++;
	}
	my $nb_user_except = 0;
	$nb_user_except = @{$node->{list_raise}} if (exists $node->{list_raise});
	print $FH "\n";
	if (exists $node->{modifier}) {		# oneway
		print $FH "void cdr_",$_->{c_name},"(void * _ref, char *_is)\n";
	} else {
		print $FH "int cdr_",$_->{c_name},"(void * _ref, char *_is, char **_os)\n";
	}
	print $FH "{\n";
	print $FH "\tCORBA_Environment _Ev;\n";
	unless ($node->{type}->isa("VoidType")) {
		print $FH "\t",Cdecl_var->NameAttr($_->{type},'return','_ret'),";\n";
	}
	foreach (@{$node->{list_param}}) {	# parameter
		print $FH "\t",Cdecl_var->NameAttr($_->{type},$_->{attr},$_->{c_name}),";\n";
	}
	if ($nb_param_in or $nb_param_out or $nb_user_except) {
		print $FH "\tCORBA_char *_p;\n";
		print $FH "\tunsigned _align = 4;\n";
	}
	unless (exists $node->{modifier}) {		# oneway
		print $FH "\tint _size = 0;\n";
	}
	print $FH "\n";
	unless ($node->{type}->isa("VoidType")) {
		my @init = Cinit_var->NameAttr($_->{type},'return','_ret');
		foreach (@init) {
			print $FH "\t",$_,";\n";
		}
	}
	foreach (@{$node->{list_param}}) {	# parameter
		my @init = Cinit_var->NameAttr($_->{type},$_->{attr},$_->{c_name});
		foreach (@init) {
			print $FH "\t",$_,";\n";
		}
	}
	print $FH "\tmemset(&_Ev, 0, sizeof _Ev);\n";
	if ($nb_param_in) {
		print $FH "\t_p = _is;\n";
		foreach (@{$node->{list_param}}) {	# parameter
			if (	   $_->{attr} eq 'in'
					or $_->{attr} eq 'inout' ) {
				print $FH "\tGET_",$_->{type}->{c_name},"(_p,",$_->{c_get_ptr_name},");\n";
			}
		}
		print $FH "\n";
	}
	if ($node->{type}->isa("VoidType")) {
		print $FH "\t",$self->{prefix},$node->{c_name},"(\n";
	} else {
		print $FH "\t",Cname_call->NameAttr($_->{type},'return'),"_ret = ";
			print $FH $self->{prefix},$node->{c_name},"(\n";
	}
	print $FH "\t\t_ref,\n";
	foreach (@{$node->{list_param}}) {
		print $FH "\t\t",Cname_call->NameAttr($_->{type},$_->{attr}),$_->{c_name},",";
			print $FH " /* ",$_->{attr}," (variable length) */\n" if (defined $_->{type}->{length});
			print $FH " /* ",$_->{attr}," (fixed length) */\n" unless (defined $_->{type}->{length});
	}
	print $FH "\t\t&_Ev\n";
	print $FH "\t);\n";
	unless (exists $node->{modifier}) {		# oneway
		print $FH "\n";
		print $FH "\tif (CORBA_NO_EXCEPTION == _Ev._major)\n";
		print $FH "\t{\n";
		print $FH "\t\t_align = 4;\n";
		print $FH "\t\tADD_SIZE_CORBA_long(_size,CORBA_NO_EXCEPTION);\n";
		if ($nb_param_out) {
			unless ($node->{type}->isa("VoidType")) {
				print $FH "\t\tADD_SIZE_",$node->{type}->{c_name},"(_size,",$node->{c_put_name},");\n";
			}
			foreach (@{$node->{list_param}}) {	# parameter
				if (	   $_->{attr} eq 'inout'
						or $_->{attr} eq 'out' ) {
					print $FH "\t\tADD_SIZE_",$_->{type}->{c_name},"(_size,",$_->{c_put_name},");\n";
				}
			}
		}
		print $FH "\n";
		print $FH "\t\tif (NULL == (*_os = CORBA_alloc(_size)))\n";
		print $FH "\t\t{\n";
		print $FH "\t\t\treturn -1;\n";
		print $FH "\t\t}\n";
		print $FH "\t\telse\n";
		print $FH "\t\t{\n";
		print $FH "\t\t\t_align = 4;\n";
		print $FH "\t\t\t_p = *_os;\n";
		print $FH "\t\t\tPUT_CORBA_long(_p,CORBA_NO_EXCEPTION);\n";
		if ($nb_param_out) {
			unless ($node->{type}->isa("VoidType")) {
				print $FH "\t\t\tPUT_",$node->{type}->{c_name},"(_p,",$node->{c_put_name},");\n";
			}
			foreach (@{$node->{list_param}}) {	# parameter
				if (	   $_->{attr} eq 'inout'
						or $_->{attr} eq 'out' ) {
					print $FH "\t\t\tPUT_",$_->{type}->{c_name},"(_p,",$_->{c_put_name},");\n";
				}
			}
			print $FH "\t\t}\n";
		}
		print $FH "\t}\n";
		if (exists $node->{list_raise}) {
			print $FH "\telse if (CORBA_USER_EXCEPTION == _Ev._major)\n";
			print $FH "\t{\n";
			my $condition = "if ";
			foreach (@{$node->{list_raise}}) {
				if ($nb_user_except > 1) {
					print $FH "\t\t",$condition,"(0 == strcmp(ex_",$_->{c_name},",CORBA_exception_id(&_Ev)))\n";
					print $FH "\t\t{\n";
				}
				print $FH "\t\t\t",$_->{c_name}," * _",$_->{c_name}," = CORBA_exception_value(&_Ev);\n"
						if (exists $_->{list_expr});
				print $FH "\t\t\t_align = 4;\n";
				print $FH "\t\t\tADD_SIZE_CORBA_long(_size,CORBA_USER_EXCEPTION);\n";
				print $FH "\t\t\tADD_SIZE_CORBA_string(_size,ex_",$_->{c_name},");\n";
				print $FH "\t\t\tADD_SIZE_",$_->{c_name},"(_size,*_",$_->{c_name},");\n"
						if (exists $_->{list_expr});
				print $FH "\n";
				print $FH "\t\t\tif (NULL == (*_os = CORBA_alloc(_size)))\n";
				print $FH "\t\t\t{\n";
				print $FH "\t\t\t\treturn -1;\n";
				print $FH "\t\t\t}\n";
				print $FH "\t\t\telse\n";
				print $FH "\t\t\t{\n";
				print $FH "\t\t\t\t_align = 4;\n";
				print $FH "\t\t\t\t_p = *_os;\n";
				print $FH "\t\t\t\tPUT_CORBA_long(_p,CORBA_USER_EXCEPTION);\n";
				print $FH "\t\t\t\tPUT_CORBA_string(_p,ex_",$_->{c_name},");\n";
				print $FH "\t\t\t\tPUT_",$_->{c_name},"(_p,*_",$_->{c_name},");\n"
						if (exists $_->{list_expr});
				print $FH "\t\t\t}\n";
				$condition = "else if ";
				if ($nb_user_except > 1) {
					print $FH "\t\t}\n";
				}
			}
			print $FH "\t}\n";
		}
		print $FH "\telse if (CORBA_SYSTEM_EXCEPTION == _Ev._major)\n";
		print $FH "\t{\n";
		print $FH "\t\tCORBA_SystemException *_pSE;\n";
		print $FH "\t\t_pSE = CORBA_exception_value(&_Ev);\n";
		print $FH "\t\t_align = 4;\n";
		print $FH "\t\tADD_SIZE_CORBA_long(_size,CORBA_SYSTEM_EXCEPTION);\n";
		print $FH "\t\tADD_SIZE_CORBA_string(_size,CORBA_exception_id(&_Ev));\n";
		print $FH "\t\tADD_SIZE_CORBA_long(_size,_pSE->minor);\n";
		print $FH "\t\tADD_SIZE_CORBA_long(_size,_pSE->completed);\n";
		print $FH "\t\tif (NULL == (*_os = CORBA_alloc(4)))\n";
		print $FH "\t\t{\n";
		print $FH "\t\t\treturn -1;\n";
		print $FH "\t\t}\n";
		print $FH "\t\telse\n";
		print $FH "\t\t{\n";
		print $FH "\t\t\t_align = 4;\n";
		print $FH "\t\t\t_p = *_os;\n";
		print $FH "\t\t\tPUT_CORBA_long(_p,CORBA_SYSTEM_EXCEPTION);\n";
		print $FH "\t\t\tPUT_CORBA_string(_p,CORBA_exception_id(&_Ev));\n";
		print $FH "\t\t\tPUT_CORBA_long(_p,_pSE->minor);\n";
		print $FH "\t\t\tPUT_CORBA_long(_p,_pSE->completed);\n";
		print $FH "\t\t}\n";
		print $FH "\t}\n";
		print $FH "\treturn _size;\n";
	}
	if ($label_err) {
		print $FH "\n";
		print $FH "err:\n";
		foreach (@{$node->{list_param}}) {	# parameter
			print $FH "\tFREE_",$_->{attr},"_",$_->{type}->{c_name},"(",$_->{c_get_ptr_name},");\n"
					if (defined $_->{type}->{length});
		}
		unless (exists $node->{modifier}) {		# oneway
			print $FH "\treturn -1;\n";
		}
	}
	print $FH "}\n";
}

#
#	3.13	Attribute Declaration		(inherited)
#

##############################################################################

package Cdecl_var;

#
#	See	1.21	Summary of Argument/Result Passing
#

# needs $type->{length}

sub NameAttr {
	my $proto = shift;
	my($type, $attr, $name) = @_;
	my $class = ref $type;
	$class = "BasicType" if ($type->isa("BasicType"));
	$class = "AnyType" if ($type->isa("AnyType"));
	my $func = 'NameAttr' . $class;
	return $proto->$func($type,$attr,$name);
}

sub NameAttrInterface {
	warn __PACKAGE__,"::NameAttrInterface : not supplied \n";
}

sub NameAttrTypeDeclarator {
	my $proto = shift;
	my($type, $attr, $name) = @_;
	if (exists $type->{array_size}) {
		warn __PACKAGE__,"::NameAttrTypeDeclarator $type->{idf} : empty array_size.\n"
				unless (@{$type->{array_size}});
		if (      $attr eq 'in' ) {
			return $type->{c_name} . " " . $name;
		} elsif ( $attr eq 'inout' ) {
			return $type->{c_name} . " " . $name;
		} elsif ( $attr eq 'out' ) {
			if (defined $type->{length}) {		# variable
				return $type->{c_name} . "_slice * " . $name;
			} else {
				return $type->{c_name} . " " . $name;
			}
		} elsif ( $attr eq 'return' ) {
			return $type->{c_name} . "_slice " . $name;
		} else {
			warn __PACKAGE__,"::NameTypeDeclarator : ERROR_INTERNAL $attr \n";
		}
	 } else {
		return $proto->NameAttr($type->{type},$attr,$name);
	}
}

sub NameAttrBasicType {
	my $proto = shift;
	my($type, $attr, $name) = @_;
	if (      $attr eq 'in' ) {
		return $type->{c_name} . " " . $name;
	} elsif ( $attr eq 'inout' ) {
		return $type->{c_name} . " " . $name;
	} elsif ( $attr eq 'out' ) {
		return $type->{c_name} . " " . $name;
	} elsif ( $attr eq 'return' ) {
		return $type->{c_name} . " " . $name;
	} else {
		warn __PACKAGE__,"::NameBasicType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrAnyType {
	warn __PACKAGE__,"::NameAttrAnyType : not supplied \n";
}

sub NameAttrStructType {
	my $proto = shift;
	my($type, $attr, $name) = @_;
	if (      $attr eq 'in' ) {
		return $type->{c_name} . " " . $name;
	} elsif ( $attr eq 'inout' ) {
		return $type->{c_name} . " " . $name;
	} elsif ( $attr eq 'out' ) {
		if (defined $type->{length}) {		# variable
			return $type->{c_name} . " * " . $name;
		} else {
			return $type->{c_name} . " " . $name;
		}
	} elsif ( $attr eq 'return' ) {
		if (defined $type->{length}) {		# variable
			return $type->{c_name} . " * " . $name;
		} else {
			return $type->{c_name} . " " . $name;
		}
	} else {
		warn __PACKAGE__,"::NameStructType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrUnionType {
	my $proto = shift;
	my($type, $attr, $name) = @_;
	if (      $attr eq 'in' ) {
		return $type->{c_name} . " " . $name;
	} elsif ( $attr eq 'inout' ) {
		return $type->{c_name} . " " . $name;
	} elsif ( $attr eq 'out' ) {
		if (defined $type->{length}) {		# variable
			return $type->{c_name} . " * " . $name;
		} else {
			return $type->{c_name} . " " . $name;
		}
	} elsif ( $attr eq 'return' ) {
		if (defined $type->{length}) {		# variable
			return $type->{c_name} . " * " . $name;
		} else {
			return $type->{c_name} . " " . $name;
		}
	} else {
		warn __PACKAGE__,"::NameUnionType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrEnumType {
	my $proto = shift;
	my($type, $attr, $name) = @_;
	if (      $attr eq 'in' ) {
		return $type->{c_name} . " " . $name;
	} elsif ( $attr eq 'inout' ) {
		return $type->{c_name} . " " . $name;
	} elsif ( $attr eq 'out' ) {
		return $type->{c_name} . " " . $name;
	} elsif ( $attr eq 'return' ) {
		return $type->{c_name} . " " . $name;
	} else {
		warn __PACKAGE__,"::NameEnumType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrSequenceType {
	my $proto = shift;
	my($type, $attr, $name) = @_;
	my $max = 0;
	$max = $type->{max}->{c_literal} if (exists $type->{max});
	if (      $attr eq 'in' ) {
		return $type->{c_name} . " " . $name;
	} elsif ( $attr eq 'inout' ) {
		return $type->{c_name} . " " . $name;
	} elsif ( $attr eq 'out' ) {
		return $type->{c_name} . " * " . $name;
	} elsif ( $attr eq 'return' ) {
		return $type->{c_name} . " * " . $name;
	} else {
		warn __PACKAGE__,"::NameSequenceType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrStringType {
	my $proto = shift;
	my($type, $attr, $name) = @_;
	if (      $attr eq 'in' ) {
		return $type->{c_name} . " " . $name;
	} elsif ( $attr eq 'inout' ) {
		return $type->{c_name} . " " . $name;
	} elsif ( $attr eq 'out' ) {
		return $type->{c_name} . " " . $name;
	} elsif ( $attr eq 'return' ) {
		return $type->{c_name} . "* " . $name;
	} else {
		warn __PACKAGE__,"::NameStringType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrWideStringType {
	my $proto = shift;
	my($type, $attr, $name) = @_;
	if (      $attr eq 'in' ) {
		return $type->{c_name} . " " . $name;
	} elsif ( $attr eq 'inout' ) {
		return $type->{c_name} . " " . $name;
	} elsif ( $attr eq 'out' ) {
		return $type->{c_name} . " " . $name;
	} elsif ( $attr eq 'return' ) {
		return $type->{c_name} . "* " . $name;
	} else {
		warn __PACKAGE__,"::NameWideStringType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrFixedPtType {
	my $proto = shift;
	my($type, $attr, $name) = @_;
	my $d = 0;
	$d = $type->{d}->{c_literal} if (exists $type->{d});
	my $s = 0;
	$s = $type->{s}->{c_literal} if (exists $type->{s});
	if (      $attr eq 'in' ) {
		return $type->{c_name} . " " . $name;
	} elsif ( $attr eq 'inout' ) {
		return $type->{c_name} . " " . $name;
	} elsif ( $attr eq 'out' ) {
		return $type->{c_name} . " " . $name;
	} elsif ( $attr eq 'return' ) {
		return $type->{c_name} . " " . $name;
	} else {
		warn __PACKAGE__,"::NameFixedPtType : ERROR_INTERNAL $attr \n";
	}
}

##############################################################################

package Cinit_var;

#
#	See	1.21	Summary of Argument/Result Passing
#

# needs $type->{length}

sub NameAttr {
	my $proto = shift;
	my($type, $attr, $name) = @_;
	my $class = ref $type;
	$class = "BasicType" if ($type->isa("BasicType"));
	$class = "AnyType" if ($type->isa("AnyType"));
	my $func = 'NameAttr' . $class;
	return $proto->$func($type,$attr,$name);
}

sub NameAttrInterface {
	warn __PACKAGE__,"::NameAttrInterface : not supplied \n";
}

sub NameAttrTypeDeclarator {
	my $proto = shift;
	my($type, $attr, $name) = @_;
	if (exists $type->{array_size}) {
		warn __PACKAGE__,"::NameAttrTypeDeclarator $type->{idf} : empty array_size.\n"
				unless (@{$type->{array_size}});
		if (      $attr eq 'in' ) {
			return ();
		} elsif ( $attr eq 'inout' ) {
			return ();
		} elsif ( $attr eq 'out' ) {
			if (defined $type->{length}) {		# variable
				return ($name . " = NULL");
			} else {
				return ();
			}
		} elsif ( $attr eq 'return' ) {
			return ();
		} else {
			warn __PACKAGE__,"::NameTypeDeclarator : ERROR_INTERNAL $attr \n";
		}
	 } else {
		return $proto->NameAttr($type->{type},$attr,$name);
	}
}

sub NameAttrBasicType {
	my $proto = shift;
	my($type, $attr, $name) = @_;
	if (      $attr eq 'in' ) {
		return ();
	} elsif ( $attr eq 'inout' ) {
		return ();
	} elsif ( $attr eq 'out' ) {
		return ();
	} elsif ( $attr eq 'return' ) {
		return ();
	} else {
		warn __PACKAGE__,"::NameBasicType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrAnyType {
	warn __PACKAGE__,"::NameAttrAnyType : not supplied \n";
}

sub NameAttrStructType {
	my $proto = shift;
	my($type, $attr, $name) = @_;
	if (      $attr eq 'in' ) {
		return ();
	} elsif ( $attr eq 'inout' ) {
		return ();
	} elsif ( $attr eq 'out' ) {
		if (defined $type->{length}) {		# variable
			return ($name . " = NULL");
		} else {
			return ();
		}
	} elsif ( $attr eq 'return' ) {
		if (defined $type->{length}) {		# variable
			return ($name . " = NULL");
		} else {
			return ();
		}
	} else {
		warn __PACKAGE__,"::NameStructType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrUnionType {
	my $proto = shift;
	my($type, $attr, $name) = @_;
	if (      $attr eq 'in' ) {
		return ();
	} elsif ( $attr eq 'inout' ) {
		return ();
	} elsif ( $attr eq 'out' ) {
		if (defined $type->{length}) {		# variable
			return ($name . " = NULL");
		} else {
			return ();
		}
	} elsif ( $attr eq 'return' ) {
		if (defined $type->{length}) {		# variable
			return ($name . " = NULL");
		} else {
			return ();
		}
	} else {
		warn __PACKAGE__,"::NameUnionType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrEnumType {
	my $proto = shift;
	my($type, $attr, $name) = @_;
	if (      $attr eq 'in' ) {
		return ();
	} elsif ( $attr eq 'inout' ) {
		return ();
	} elsif ( $attr eq 'out' ) {
		return ();
	} elsif ( $attr eq 'return' ) {
		return ();
	} else {
		warn __PACKAGE__,"::NameEnumType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrSequenceType {
	my $proto = shift;
	my($type, $attr, $name) = @_;
	my $max = 0;
	$max = $type->{max}->{c_literal} if (exists $type->{max});
	if (      $attr eq 'in' ) {
		return (
			$name . "._maximum = " . $max,
			$name . "._length = 0",
			$name . "._buffer = NULL"
		);
	} elsif ( $attr eq 'inout' ) {
		return (
			$name . "._maximum = " . $max,
			$name . "._length = 0",
			$name . "._buffer = NULL"
		);
	} elsif ( $attr eq 'out' ) {
		return ($name . " = NULL");
	} elsif ( $attr eq 'return' ) {
		return ($name . " = NULL");
	} else {
		warn __PACKAGE__,"::NameSequenceType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrStringType {
	my $proto = shift;
	my($type, $attr, $name) = @_;
	if (      $attr eq 'in' ) {
		return ($name . " = NULL");
	} elsif ( $attr eq 'inout' ) {
		return ($name . " = NULL");
	} elsif ( $attr eq 'out' ) {
		return ($name . " = NULL");
	} elsif ( $attr eq 'return' ) {
		return ($name . " = NULL");
	} else {
		warn __PACKAGE__,"::NameStringType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrWideStringType {
	my $proto = shift;
	my($type, $attr, $name) = @_;
	if (      $attr eq 'in' ) {
		return ($name . " = NULL");
	} elsif ( $attr eq 'inout' ) {
		return ($name . " = NULL");
	} elsif ( $attr eq 'out' ) {
		return ($name . " = NULL");
	} elsif ( $attr eq 'return' ) {
		return ($name . " = NULL");
	} else {
		warn __PACKAGE__,"::NameWideStringType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrFixedPtType {
	my $proto = shift;
	my($type, $attr, $name) = @_;
	my $d = 0;
	$d = $type->{d}->{c_literal} if (exists $type->{d});
	my $s = 0;
	$s = $type->{s}->{c_literal} if (exists $type->{s});
	if (      $attr eq 'in' ) {
		return (
			$name . "._digits = " . $d,
			$name . "._scale = " . $s,
		);
	} elsif ( $attr eq 'inout' ) {
		return (
			$name . "._digits = " . $d,
			$name . "._scale = " . $s,
		);
	} elsif ( $attr eq 'out' ) {
		return (
			$name . "._digits = " . $d,
			$name . "._scale = " . $s,
		);
	} elsif ( $attr eq 'return' ) {
		return (
			$name . "._digits = " . $d,
			$name . "._scale = " . $s,
		);
	} else {
		warn __PACKAGE__,"::NameFixedPtType : ERROR_INTERNAL $attr \n";
	}
}

##############################################################################

package Cname_call;

#
#	See	1.21	Summary of Argument/Result Passing
#

# needs $type->{length}

sub NameAttr {
	my $proto = shift;
	my($type, $attr) = @_;
	my $class = ref $type;
	$class = "BasicType" if ($type->isa("BasicType"));
	$class = "AnyType" if ($type->isa("AnyType"));
	my $func = 'NameAttr' . $class;
	return $proto->$func($type,$attr);
}

sub NameAttrInterface {
	warn __PACKAGE__,"::NameAttrInterface : not supplied \n";
}

sub NameAttrTypeDeclarator {
	my $proto = shift;
	my($type, $attr) = @_;
	if (exists $type->{array_size}) {
		warn __PACKAGE__,"::NameAttrTypeDeclarator $type->{idf} : empty array_size.\n"
				unless (@{$type->{array_size}});
		if (      $attr eq 'in' ) {
			return "";
		} elsif ( $attr eq 'inout' ) {
			return "";
		} elsif ( $attr eq 'out' ) {
			if (defined $type->{length}) {		# variable
				return "";
			} else {
				return "";
			}
		} elsif ( $attr eq 'return' ) {
			return "";
		} else {
			warn __PACKAGE__,"::NameTypeDeclarator : ERROR_INTERNAL $attr \n";
		}
	 } else {
		return $proto->NameAttr($type->{type},$attr);
	}
}

sub NameAttrBasicType {
	my $proto = shift;
	my($type, $attr) = @_;
	if (      $attr eq 'in' ) {
		return "";
	} elsif ( $attr eq 'inout' ) {
		return "&";
	} elsif ( $attr eq 'out' ) {
		return "&";
	} elsif ( $attr eq 'return' ) {
		return "";
	} else {
		warn __PACKAGE__,"::NameBasicType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrAnyType {
	warn __PACKAGE__,"::NameAttrAnyType : not supplied \n";
}

sub NameAttrStructType {
	my $proto = shift;
	my($type, $attr) = @_;
	if (      $attr eq 'in' ) {
		return "&";
	} elsif ( $attr eq 'inout' ) {
		return "&";
	} elsif ( $attr eq 'out' ) {
		return "&";
	} elsif ( $attr eq 'return' ) {
		return "";
	} else {
		warn __PACKAGE__,"::NameStructType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrUnionType {
	my $proto = shift;
	my($type, $attr) = @_;
	if (      $attr eq 'in' ) {
		return "&";
	} elsif ( $attr eq 'inout' ) {
		return "&";
	} elsif ( $attr eq 'out' ) {
		return "&";
	} elsif ( $attr eq 'return' ) {
		return "";
	} else {
		warn __PACKAGE__,"::NameUnionType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrEnumType {
	my $proto = shift;
	my($type, $attr) = @_;
	if (      $attr eq 'in' ) {
		return "";
	} elsif ( $attr eq 'inout' ) {
		return "&";
	} elsif ( $attr eq 'out' ) {
		return "&";
	} elsif ( $attr eq 'return' ) {
		return "";
	} else {
		warn __PACKAGE__,"::NameEnumType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrSequenceType {
	my $proto = shift;
	my($type, $attr) = @_;
	if (      $attr eq 'in' ) {
		return "&";
	} elsif ( $attr eq 'inout' ) {
		return "&";
	} elsif ( $attr eq 'out' ) {
		return "&";
	} elsif ( $attr eq 'return' ) {
		return "";
	} else {
		warn __PACKAGE__,"::NameSequenceType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrStringType {
	my $proto = shift;
	my($type, $attr) = @_;
	if (      $attr eq 'in' ) {
		return "";
	} elsif ( $attr eq 'inout' ) {
		return "&";
	} elsif ( $attr eq 'out' ) {
		return "&";
	} elsif ( $attr eq 'return' ) {
		return "";
	} else {
		warn __PACKAGE__,"::NameStringType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrWideStringType {
	my $proto = shift;
	my($type, $attr) = @_;
	if (      $attr eq 'in' ) {
		return "";
	} elsif ( $attr eq 'inout' ) {
		return "&";
	} elsif ( $attr eq 'out' ) {
		return "&";
	} elsif ( $attr eq 'return' ) {
		return "";
	} else {
		warn __PACKAGE__,"::NameWideStringType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrFixedPtType {
	my $proto = shift;
	my($type, $attr) = @_;
	if (      $attr eq 'in' ) {
		return "&";
	} elsif ( $attr eq 'inout' ) {
		return "&";
	} elsif ( $attr eq 'out' ) {
		return "&";
	} elsif ( $attr eq 'return' ) {
		return "";
	} else {
		warn __PACKAGE__,"::NameFixedPtType : ERROR_INTERNAL $attr \n";
	}
}

##############################################################################

package Cname_put2;

#
#	See	1.21	Summary of Argument/Result Passing
#

# needs $type->{length}

sub NameAttr {
	my $proto = shift;
	my($type, $attr) = @_;
	my $class = ref $type;
	$class = "BasicType" if ($type->isa("BasicType"));
	$class = "AnyType" if ($type->isa("AnyType"));
	my $func = 'NameAttr' . $class;
	return $proto->$func($type,$attr);
}

sub NameAttrInterface {
	warn __PACKAGE__,"::NameAttrInterface : not supplied \n";
}

sub NameAttrTypeDeclarator {
	my $proto = shift;
	my($type, $attr) = @_;
	if (exists $type->{array_size}) {
		warn __PACKAGE__,"::NameAttrTypeDeclarator $type->{idf} : empty array_size.\n"
				unless (@{$type->{array_size}});
		if (      $attr eq 'inout' ) {
			return "";
		} elsif ( $attr eq 'out' ) {
			return "";
		} elsif ( $attr eq 'return' ) {
			return "";
		} else {
			warn __PACKAGE__,"::NameTypeDeclarator : ERROR_INTERNAL $attr \n";
		}
	 } else {
		return $proto->NameAttr($type->{type},$attr);
	}
}

sub NameAttrBasicType {
	my $proto = shift;
	my($type, $attr) = @_;
	if (      $attr eq 'inout' ) {
		return "";
	} elsif ( $attr eq 'out' ) {
		return "";
	} elsif ( $attr eq 'return' ) {
		return "";
	} else {
		warn __PACKAGE__,"::NameBasicType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrAnyType {
	warn __PACKAGE__,"::NameAttrAnyType : not supplied \n";
}

sub NameAttrStructType {
	my $proto = shift;
	my($type, $attr) = @_;
	if (      $attr eq 'inout' ) {
		return "";
	} elsif ( $attr eq 'out' ) {
		if (defined $type->{length}) {		# variable
			return "*";
		} else {
			return "";
		}
	} elsif ( $attr eq 'return' ) {
		if (defined $type->{length}) {		# variable
			return "*";
		} else {
			return "";
		}
	} else {
		warn __PACKAGE__,"::NameStructType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrUnionType {
	my $proto = shift;
	my($type, $attr) = @_;
	if (      $attr eq 'inout' ) {
		return "";
	} elsif ( $attr eq 'out' ) {
		if (defined $type->{length}) {		# variable
			return "*";
		} else {
			return "";
		}
	} elsif ( $attr eq 'return' ) {
		if (defined $type->{length}) {		# variable
			return "*";
		} else {
			return "";
		}
	} else {
		warn __PACKAGE__,"::NameUnionType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrEnumType {
	my $proto = shift;
	my($type, $attr) = @_;
	if (      $attr eq 'inout' ) {
		return "";
	} elsif ( $attr eq 'out' ) {
		return "";
	} elsif ( $attr eq 'return' ) {
		return "";
	} else {
		warn __PACKAGE__,"::NameEnumType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrSequenceType {
	my $proto = shift;
	my($type, $attr) = @_;
	if (      $attr eq 'inout' ) {
		return "";
	} elsif ( $attr eq 'out' ) {
		return "*";
	} elsif ( $attr eq 'return' ) {
		return "*";
	} else {
		warn __PACKAGE__,"::NameSequenceType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrStringType {
	my $proto = shift;
	my($type, $attr) = @_;
	if (      $attr eq 'inout' ) {
		return "";
	} elsif ( $attr eq 'out' ) {
		return "";
	} elsif ( $attr eq 'return' ) {
		return "*";
	} else {
		warn __PACKAGE__,"::NameStringType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrWideStringType {
	my $proto = shift;
	my($type, $attr) = @_;
	if (      $attr eq 'inout' ) {
		return "";
	} elsif ( $attr eq 'out' ) {
		return "";
	} elsif ( $attr eq 'return' ) {
		return "*";
	} else {
		warn __PACKAGE__,"::NameWideStringType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrFixedPtType {
	my $proto = shift;
	my($type, $attr) = @_;
	if (      $attr eq 'inout' ) {
		return "";
	} elsif ( $attr eq 'out' ) {
		return "";
	} elsif ( $attr eq 'return' ) {
		return "";
	} else {
		warn __PACKAGE__,"::NameFixedPtType : ERROR_INTERNAL $attr \n";
	}
}

##############################################################################

package Cptrname_get2;

#
#	See	1.21	Summary of Argument/Result Passing
#

# needs $type->{length}

sub NameAttr {
	my $proto = shift;
	my($type, $attr) = @_;
	my $class = ref $type;
	$class = "BasicType" if ($type->isa("BasicType"));
	$class = "AnyType" if ($type->isa("AnyType"));
	my $func = 'NameAttr' . $class;
	return $proto->$func($type,$attr);
}

sub NameAttrInterface {
	warn __PACKAGE__,"::NameAttrInterface : not supplied \n";
}

sub NameAttrTypeDeclarator {
	my $proto = shift;
	my($type, $attr) = @_;
	if (exists $type->{array_size}) {
		warn __PACKAGE__,"::NameAttrTypeDeclarator $type->{idf} : empty array_size.\n"
				unless (@{$type->{array_size}});
		if (      $attr eq 'in' ) {
			return "&";
		} elsif ( $attr eq 'inout' ) {
			return "&";
		} elsif ( $attr eq 'out' ) {
			if (defined $type->{length}) {		# variable
				return "&";
			} else {
				return "&";
			}
		} elsif ( $attr eq 'return' ) {
			return "&";
		} else {
			warn __PACKAGE__,"::NameTypeDeclarator : ERROR_INTERNAL $attr \n";
		}
	 } else {
		return $proto->NameAttr($type->{type},$attr);
	}
}

sub NameAttrBasicType {
	my $proto = shift;
	my($type, $attr) = @_;
	if (      $attr eq 'in' ) {
		return "&";
	} elsif ( $attr eq 'inout' ) {
		return "&";
	} elsif ( $attr eq 'out' ) {
		return "&";
	} elsif ( $attr eq 'return' ) {
		return "&";
	} else {
		warn __PACKAGE__,"::NameBasicType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrAnyType {
	warn __PACKAGE__,"::NameAttrAnyType : not supplied \n";
}

sub NameAttrStructType {
	my $proto = shift;
	my($type, $attr) = @_;
	if (      $attr eq 'in' ) {
		return "&";
	} elsif ( $attr eq 'inout' ) {
		return "&";
	} elsif ( $attr eq 'out' ) {
		if (defined $type->{length}) {		# variable
			return "";
		} else {
			return "&";
		}
	} elsif ( $attr eq 'return' ) {
		if (defined $type->{length}) {		# variable
			return "";
		} else {
			return "&";
		}
	} else {
		warn __PACKAGE__,"::NameStructType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrUnionType {
	my $proto = shift;
	my($type, $attr) = @_;
	if (      $attr eq 'in' ) {
		return "&";
	} elsif ( $attr eq 'inout' ) {
		return "&";
	} elsif ( $attr eq 'out' ) {
		if (defined $type->{length}) {		# variable
			return "";
		} else {
			return "&";
		}
	} elsif ( $attr eq 'return' ) {
		if (defined $type->{length}) {		# variable
			return "";
		} else {
			return "&";
		}
	} else {
		warn __PACKAGE__,"::NameUnionType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrEnumType {
	my $proto = shift;
	my($type, $attr) = @_;
	if (      $attr eq 'in' ) {
		return "&";
	} elsif ( $attr eq 'inout' ) {
		return "&";
	} elsif ( $attr eq 'out' ) {
		return "&";
	} elsif ( $attr eq 'return' ) {
		return "&";
	} else {
		warn __PACKAGE__,"::NameEnumType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrSequenceType {
	my $proto = shift;
	my($type, $attr) = @_;
	my $max = 0;
	$max = $type->{max}->{c_literal} if (exists $type->{max});
	if (      $attr eq 'in' ) {
		return "&";
	} elsif ( $attr eq 'inout' ) {
		return "&";
	} elsif ( $attr eq 'out' ) {
		return "";
	} elsif ( $attr eq 'return' ) {
		return "";
	} else {
		warn __PACKAGE__,"::NameSequenceType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrStringType {
	my $proto = shift;
	my($type, $attr) = @_;
	if (      $attr eq 'in' ) {
		return "&";
	} elsif ( $attr eq 'inout' ) {
		return "&";
	} elsif ( $attr eq 'out' ) {
		return "&";
	} elsif ( $attr eq 'return' ) {
		return "";
	} else {
		warn __PACKAGE__,"::NameStringType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrWideStringType {
	my $proto = shift;
	my($type, $attr) = @_;
	if (      $attr eq 'in' ) {
		return "&";
	} elsif ( $attr eq 'inout' ) {
		return "&";
	} elsif ( $attr eq 'out' ) {
		return "&";
	} elsif ( $attr eq 'return' ) {
		return "";
	} else {
		warn __PACKAGE__,"::NameWideStringType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrFixedPtType {
	my $proto = shift;
	my($type, $attr) = @_;
	if (      $attr eq 'in' ) {
		return "&";
	} elsif ( $attr eq 'inout' ) {
		return "&";
	} elsif ( $attr eq 'out' ) {
		return "&";
	} elsif ( $attr eq 'return' ) {
		return "&";
	} else {
		warn __PACKAGE__,"::NameFixedPtType : ERROR_INTERNAL $attr \n";
	}
}

1;

