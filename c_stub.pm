use strict;
use POSIX qw(ctime);

#
#			Interface Definition Language (OMG IDL CORBA v3.0)
#

use CORBA::XS::c_cdr;

package CORBA::XS::CstubVisitor;

use base qw(CORBA::XS::CcdrVisitor);
use File::Basename;

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
	$self->{symbtab} = $parser->YYData->{symbtab};
	$self->{server} = 1;
	my $filename = "cdr_" . basename($self->{srcname}, ".idl") . ".c";
	$self->open_stream($filename);
	$self->{done_hash} = {};
	$self->{num_key} = 'num_c_stub';
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
	print $FH "/* This file was generated (by ",$0,"). DO NOT modify it */\n";
	print $FH "/* From file : ",$self->{srcname},", ",$self->{srcname_size}," octets, ",POSIX::ctime($self->{srcname_mtime});
	print $FH " */\n";
	print $FH "\n";
	print $FH "#include <string.h>\n";
	print $FH "#include <",$self->{incpath},"cdr.h>\n";
	print $FH "#include \"",$filename,"\"\n";
	print $FH "\n";
	print $FH "\n";
	foreach (@{$node->{list_decl}}) {
		$self->_get_defn($_)->visit($self);
	}
	print $FH "/* end of file : ",$self->{filename}," */\n";
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
	my $FH = $self->{out};
	print $FH "/*\n";
	print $FH " * begin of interface ",$node->{c_name},"\n";
	print $FH " */\n";
	foreach (@{$node->{list_decl}}) {
		my $defn = $self->_get_defn($_);
		if (	   $defn->isa('Operation')
				or $defn->isa('Attributes') ) {
			next;
		}
		$defn->visit($self);
	}
	print $FH "\n";
	if (	    $self->{srcname} eq $node->{filename}
			and keys %{$node->{hash_attribute_operation}} ) {
		$self->{itf} = $node->{c_name};
		print $FH "\t\t/*-- functions --*/\n";
		print $FH "\n";
		foreach (values %{$node->{hash_attribute_operation}}) {
			$self->_get_defn($_)->visit($self);
		}
		print $FH "\n";
	}
	print $FH "/*\n";
	print $FH " * end of interface ",$node->{c_name},"\n";
	print $FH " */\n";
	print $FH "\n";
}

sub visitAbstractInterface {
	# C mapping is aligned with CORBA 2.1
	my $self = shift;
	my($node) = @_;
	my $FH = $self->{out};
	print $FH "/*\n";
	print $FH " * begin of interface ",$node->{c_name},"\n";
	print $FH " */\n";
	foreach (@{$node->{list_decl}}) {
		my $defn = $self->_get_defn($_);
		if (	   $defn->isa('Operation')
				or $defn->isa('Attributes') ) {
			next;
		}
		$defn->visit($self);
	}
	print $FH "\n";
	print $FH "/*\n";
	print $FH " * end of interface ",$node->{c_name},"\n";
	print $FH " */\n";
	print $FH "\n";
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
	my $FH = $self->{out};
	my $label_err = undef;
	my $nb_param_out = 0;
	my $nb_param_in = 0;
	my $type = $self->_get_defn($node->{type});
	unless ($type->isa("VoidType")) {				# return
		$label_err = $type->{length};
		$nb_param_out ++;
		$node->{c_put_name} = CORBA::XS::Cname_put2->NameAttr($self->{symbtab}, $type, 'return') . "_ret";
	}
	foreach (@{$node->{list_in}}) {					# parameter
		$type = $self->_get_defn($_->{type});
		$_->{c_get_ptr_name} = CORBA::XS::Cptrname_get2->NameAttr($self->{symbtab}, $type, $_->{attr}) . $_->{c_name};
		$label_err ||= $type->{length};
		$nb_param_in ++;
	}
	foreach (@{$node->{list_inout}}) {				# parameter
		$type = $self->_get_defn($_->{type});
		$_->{c_get_ptr_name} = CORBA::XS::Cptrname_get2->NameAttr($self->{symbtab}, $type, $_->{attr}) . $_->{c_name};
		$_->{c_put_name} = CORBA::XS::Cname_put2->NameAttr($self->{symbtab}, $type, $_->{attr}) . $_->{c_name};
		$label_err ||= $type->{length};
		$nb_param_in ++;
		$nb_param_out ++;
	}
	foreach (@{$node->{list_out}}) {				# parameter
		$type = $self->_get_defn($_->{type});
		$_->{c_get_ptr_name} = CORBA::XS::Cptrname_get2->NameAttr($self->{symbtab}, $type, $_->{attr}) . $_->{c_name};
		$_->{c_put_name} = CORBA::XS::Cname_put2->NameAttr($self->{symbtab}, $type, $_->{attr}) . $_->{c_name};
		$nb_param_out ++;
	}
	my $nb_user_except = 0;
	$nb_user_except = @{$node->{list_raise}} if (exists $node->{list_raise});
	print $FH "\n";
	if (exists $node->{modifier}) {		# oneway
		print $FH "void cdr_",$self->{itf},"_",$node->{c_name},"(void * _ref, char *_is)\n";
	} else {
		print $FH "int cdr_",$self->{itf},"_",$node->{c_name},"(void * _ref, char *_is, char **_os)\n";
	}
	print $FH "{\n";
	print $FH "\tCORBA_Environment _Ev;\n";
	$type = $self->_get_defn($node->{type});
	unless ($type->isa("VoidType")) {
		print $FH "\t",CORBA::XS::Cdecl_var->NameAttr($self->{symbtab}, $type, 'return', '_ret'),";\n";
	}
	foreach (@{$node->{list_param}}) {	# parameter
		$type = $self->_get_defn($_->{type});
		print $FH "\t",CORBA::XS::Cdecl_var->NameAttr($self->{symbtab}, $type, $_->{attr}, $_->{c_name}),";\n";
	}
	if ($nb_param_in or $nb_param_out or $nb_user_except) {
		print $FH "\tCORBA_char *_p;\n";
		print $FH "\tunsigned _align = 4;\n";
	}
	unless (exists $node->{modifier}) {		# oneway
		print $FH "\tint _size = 0;\n";
	}
	print $FH "\n";
	$type = $self->_get_defn($node->{type});
	unless ($type->isa("VoidType")) {
		my @init = CORBA::XS::Cinit_var->NameAttr($self->{symbtab}, $type, 'return', '_ret');
		foreach (@init) {
			print $FH "\t",$_,";\n";
		}
	}
	foreach (@{$node->{list_param}}) {	# parameter
		$type = $self->_get_defn($_->{type});
		my @init = CORBA::XS::Cinit_var->NameAttr($self->{symbtab}, $type, $_->{attr}, $_->{c_name});
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
				$type = $self->_get_defn($_->{type});
				print $FH "\tGET_",$type->{c_name},"(_p,",$_->{c_get_ptr_name},");\n";
			}
		}
		print $FH "\n";
	}
	$type = $self->_get_defn($node->{type});
	if ($type->isa("VoidType")) {
		print $FH "\t",$self->{prefix},$self->{itf},"_",$node->{c_name},"(\n";
	} else {
		print $FH "\t",CORBA::XS::Cname_call->NameAttr($self->{symbtab}, $type, 'return'),"_ret = ";
			print $FH $self->{prefix},$self->{itf},"_",$node->{c_name},"(\n";
	}
	print $FH "\t\t_ref,\n";
	foreach (@{$node->{list_param}}) {
		$type = $self->_get_defn($_->{type});
		print $FH "\t\t",CORBA::XS::Cname_call->NameAttr($self->{symbtab}, $type, $_->{attr}),$_->{c_name},",";
			print $FH " /* ",$_->{attr}," (variable length) */\n" if (defined $type->{length});
			print $FH " /* ",$_->{attr}," (fixed length) */\n" unless (defined $type->{length});
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
			$type = $self->_get_defn($node->{type});
			unless ($type->isa("VoidType")) {
				print $FH "\t\tADD_SIZE_",$type->{c_name},"(_size,",$node->{c_put_name},");\n";
			}
			foreach (@{$node->{list_param}}) {	# parameter
				if (	   $_->{attr} eq 'inout'
						or $_->{attr} eq 'out' ) {
					$type = $self->_get_defn($_->{type});
					print $FH "\t\tADD_SIZE_",$type->{c_name},"(_size,",$_->{c_put_name},");\n";
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
			$type = $self->_get_defn($node->{type});
			unless ($type->isa("VoidType")) {
				print $FH "\t\t\tPUT_",$type->{c_name},"(_p,",$node->{c_put_name},");\n";
			}
			foreach (@{$node->{list_param}}) {	# parameter
				if (	   $_->{attr} eq 'inout'
						or $_->{attr} eq 'out' ) {
					$type = $self->_get_defn($_->{type});
					print $FH "\t\t\tPUT_",$type->{c_name},"(_p,",$_->{c_put_name},");\n";
				}
			}
		}
		print $FH "\t\t}\n";
		print $FH "\t}\n";
		if (exists $node->{list_raise}) {
			print $FH "\telse if (CORBA_USER_EXCEPTION == _Ev._major)\n";
			print $FH "\t{\n";
			my $condition = "if ";
			foreach (@{$node->{list_raise}}) {
				my $defn = $self->_get_defn($_);
				if ($nb_user_except > 1) {
					print $FH "\t\t",$condition,"(0 == strcmp(ex_",$defn->{c_name},",CORBA_exception_id(&_Ev)))\n";
					print $FH "\t\t{\n";
				}
				print $FH "\t\t\t",$defn->{c_name}," * _",$defn->{c_name}," = CORBA_exception_value(&_Ev);\n"
						if (exists $defn->{list_expr});
				print $FH "\t\t\t_align = 4;\n";
				print $FH "\t\t\tADD_SIZE_CORBA_long(_size,CORBA_USER_EXCEPTION);\n";
				print $FH "\t\t\tADD_SIZE_CORBA_string(_size,ex_",$defn->{c_name},");\n";
				print $FH "\t\t\tADD_SIZE_",$defn->{c_name},"(_size,*_",$defn->{c_name},");\n"
						if (exists $defn->{list_expr});
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
				print $FH "\t\t\t\tPUT_CORBA_string(_p,ex_",$defn->{c_name},");\n";
				print $FH "\t\t\t\tPUT_",$defn->{c_name},"(_p,*_",$defn->{c_name},");\n"
						if (exists $defn->{list_expr});
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
			$type = $self->_get_defn($_->{type});
			print $FH "\tFREE_",$_->{attr},"_",$type->{c_name},"(",$_->{c_get_ptr_name},");\n"
					if (defined $type->{length});
		}
		unless (exists $node->{modifier}) {		# oneway
			print $FH "\treturn -1;\n";
		}
	}
	print $FH "}\n";
}

#
#	3.14	Attribute Declaration		(inherited)
#

##############################################################################

package CORBA::XS::Cdecl_var;

#
#	See	1.21	Summary of Argument/Result Passing
#

# needs $type->{length}

sub NameAttr {
	my $proto = shift;
	my($symbtab, $type, $attr, $name) = @_;
	my $class = ref $type;
	$class = "BasicType" if ($type->isa("BasicType"));
	$class = "AnyType" if ($type->isa("AnyType"));
	$class = "BaseInterface" if ($type->isa("BaseInterface"));
	$class = "ForwardBaseInterface" if ($type->isa("ForwardBaseInterface"));
	my $func = 'NameAttr' . $class;
	if($proto->can($func)) {
		return $proto->$func($symbtab, $type, $attr, $name);
	} else {
		warn "Please implement a function '$func' in '",__PACKAGE__,"'.\n";
	}
}

sub NameAttrBaseInterface {
	warn __PACKAGE__,"::NameAttrBaseInterface : not supplied \n";
}

sub NameAttrForwardBaseInterface {
	warn __PACKAGE__,"::NameAttrForwardInterface : not supplied \n";
}

sub NameAttrTypeDeclarator {
	my $proto = shift;
	my($symbtab, $type, $attr, $name) = @_;
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
			warn __PACKAGE__,"::NameAttrTypeDeclarator : ERROR_INTERNAL $attr \n";
		}
	} else {
		my $type = $type->{type};
		unless (ref $type) {
			$type = $symbtab->Lookup($type);
		}
		return $proto->NameAttr($symbtab, $type, $attr, $name);
	}
}

sub NameAttrNativeType {
	my $proto = shift;
	my($symbtab, $type, $attr, $name) = @_;
	warn __PACKAGE__,"::NameAttrNativeType native : not supplied \n";
}

sub NameAttrBasicType {
	my $proto = shift;
	my($symbtab, $type, $attr, $name) = @_;
	if (      $attr eq 'in' ) {
		return $type->{c_name} . " " . $name;
	} elsif ( $attr eq 'inout' ) {
		return $type->{c_name} . " " . $name;
	} elsif ( $attr eq 'out' ) {
		return $type->{c_name} . " " . $name;
	} elsif ( $attr eq 'return' ) {
		return $type->{c_name} . " " . $name;
	} else {
		warn __PACKAGE__,"::NameAttrBasicType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrAnyType {
	warn __PACKAGE__,"::NameAttrAnyType : not supplied \n";
}

sub NameAttrStructType {
	my $proto = shift;
	my($symbtab, $type, $attr, $name) = @_;
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
		warn __PACKAGE__,"::NameAttrStructType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrUnionType {
	my $proto = shift;
	my($symbtab, $type, $attr, $name) = @_;
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
		warn __PACKAGE__,"::NameAttrUnionType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrEnumType {
	my $proto = shift;
	my($symbtab, $type, $attr, $name) = @_;
	if (      $attr eq 'in' ) {
		return $type->{c_name} . " " . $name;
	} elsif ( $attr eq 'inout' ) {
		return $type->{c_name} . " " . $name;
	} elsif ( $attr eq 'out' ) {
		return $type->{c_name} . " " . $name;
	} elsif ( $attr eq 'return' ) {
		return $type->{c_name} . " " . $name;
	} else {
		warn __PACKAGE__,"::NameAttrEnumType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrSequenceType {
	my $proto = shift;
	my($symbtab, $type, $attr, $name) = @_;
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
		warn __PACKAGE__,"::NameAttrSequenceType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrStringType {
	my $proto = shift;
	my($symbtab, $type, $attr, $name) = @_;
	if (      $attr eq 'in' ) {
		return $type->{c_name} . " " . $name;
	} elsif ( $attr eq 'inout' ) {
		return $type->{c_name} . " " . $name;
	} elsif ( $attr eq 'out' ) {
		return $type->{c_name} . " " . $name;
	} elsif ( $attr eq 'return' ) {
		return $type->{c_name} . "* " . $name;
	} else {
		warn __PACKAGE__,"::NameAttrStringType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrWideStringType {
	my $proto = shift;
	my($symbtab, $type, $attr, $name) = @_;
	if (      $attr eq 'in' ) {
		return $type->{c_name} . " " . $name;
	} elsif ( $attr eq 'inout' ) {
		return $type->{c_name} . " " . $name;
	} elsif ( $attr eq 'out' ) {
		return $type->{c_name} . " " . $name;
	} elsif ( $attr eq 'return' ) {
		return $type->{c_name} . "* " . $name;
	} else {
		warn __PACKAGE__,"::NameAttrWideStringType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrFixedPtType {
	my $proto = shift;
	my($symbtab, $type, $attr, $name) = @_;
	if (      $attr eq 'in' ) {
		return $type->{c_name} . " " . $name;
	} elsif ( $attr eq 'inout' ) {
		return $type->{c_name} . " " . $name;
	} elsif ( $attr eq 'out' ) {
		return $type->{c_name} . " " . $name;
	} elsif ( $attr eq 'return' ) {
		return $type->{c_name} . " " . $name;
	} else {
		warn __PACKAGE__,"::NameAttrFixedPtType : ERROR_INTERNAL $attr \n";
	}
}

##############################################################################

package CORBA::XS::Cinit_var;

#
#	See	1.21	Summary of Argument/Result Passing
#

# needs $type->{length}

sub NameAttr {
	my $proto = shift;
	my($symbtab, $type, $attr, $name) = @_;
	my $class = ref $type;
	$class = "BasicType" if ($type->isa("BasicType"));
	$class = "AnyType" if ($type->isa("AnyType"));
	$class = "BaseInterface" if ($type->isa("BaseInterface"));
	$class = "ForwardBaseInterface" if ($type->isa("ForwardBaseInterface"));
	my $func = 'NameAttr' . $class;
	if($proto->can($func)) {
		return $proto->$func($symbtab, $type, $attr, $name);
	} else {
		warn "Please implement a function '$func' in '",__PACKAGE__,"'.\n";
	}
}

sub NameAttrBaseInterface {
	warn __PACKAGE__,"::NameAttrBaseInterface : not supplied \n";
}

sub NameAttrForwardBaseInterface {
	warn __PACKAGE__,"::NameAttrForwardBaseInterface : not supplied \n";
}

sub NameAttrTypeDeclarator {
	my $proto = shift;
	my($symbtab, $type, $attr, $name) = @_;
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
			warn __PACKAGE__,"::NameAttrTypeDeclarator : ERROR_INTERNAL $attr \n";
		}
	} else {
		my $type = $type->{type};
		unless (ref $type) {
			$type = $symbtab->Lookup($type);
		}
		return $proto->NameAttr($symbtab, $type, $attr, $name);
	}
}

sub NameAttrNativeType {
	my $proto = shift;
	my($symbtab, $type, $attr, $name) = @_;
	warn __PACKAGE__,"::NameAttrNativeType native : not supplied \n";
}

sub NameAttrBasicType {
	my $proto = shift;
	my($symbtab, $type, $attr, $name) = @_;
	if (      $attr eq 'in' ) {
		return ();
	} elsif ( $attr eq 'inout' ) {
		return ();
	} elsif ( $attr eq 'out' ) {
		return ();
	} elsif ( $attr eq 'return' ) {
		return ();
	} else {
		warn __PACKAGE__,"::NameAttrBasicType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrAnyType {
	warn __PACKAGE__,"::NameAttrAnyType : not supplied \n";
}

sub NameAttrStructType {
	my $proto = shift;
	my($symbtab, $type, $attr, $name) = @_;
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
		warn __PACKAGE__,"::NameAttrStructType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrUnionType {
	my $proto = shift;
	my($symbtab, $type, $attr, $name) = @_;
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
		warn __PACKAGE__,"::NameAttrUnionType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrEnumType {
	my $proto = shift;
	my($symbtab, $type, $attr, $name) = @_;
	if (      $attr eq 'in' ) {
		return ();
	} elsif ( $attr eq 'inout' ) {
		return ();
	} elsif ( $attr eq 'out' ) {
		return ();
	} elsif ( $attr eq 'return' ) {
		return ();
	} else {
		warn __PACKAGE__,"::NameAttrEnumType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrSequenceType {
	my $proto = shift;
	my($symbtab, $type, $attr, $name) = @_;
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
		warn __PACKAGE__,"::NameAttrSequenceType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrStringType {
	my $proto = shift;
	my($symbtab, $type, $attr, $name) = @_;
	if (      $attr eq 'in' ) {
		return ($name . " = NULL");
	} elsif ( $attr eq 'inout' ) {
		return ($name . " = NULL");
	} elsif ( $attr eq 'out' ) {
		return ($name . " = NULL");
	} elsif ( $attr eq 'return' ) {
		return ($name . " = NULL");
	} else {
		warn __PACKAGE__,"::NameAttrStringType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrWideStringType {
	my $proto = shift;
	my($symbtab, $type, $attr, $name) = @_;
	if (      $attr eq 'in' ) {
		return ($name . " = NULL");
	} elsif ( $attr eq 'inout' ) {
		return ($name . " = NULL");
	} elsif ( $attr eq 'out' ) {
		return ($name . " = NULL");
	} elsif ( $attr eq 'return' ) {
		return ($name . " = NULL");
	} else {
		warn __PACKAGE__,"::NameAttrWideStringType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrFixedPtType {
	my $proto = shift;
	my($symbtab, $type, $attr, $name) = @_;
	my $d = $type->{d}->{c_literal};
	my $s = $type->{s}->{c_literal};
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
		warn __PACKAGE__,"::NameAttrFixedPtType : ERROR_INTERNAL $attr \n";
	}
}

##############################################################################

package CORBA::XS::Cname_call;

#
#	See	1.21	Summary of Argument/Result Passing
#

# needs $type->{length}

sub NameAttr {
	my $proto = shift;
	my($symbtab, $type, $attr) = @_;
	my $class = ref $type;
	$class = "BasicType" if ($type->isa("BasicType"));
	$class = "AnyType" if ($type->isa("AnyType"));
	$class = "BaseInterface" if ($type->isa("BaseInterface"));
	$class = "ForwardBaseInterface" if ($type->isa("ForwardBaseInterface"));
	my $func = 'NameAttr' . $class;
	if($proto->can($func)) {
		return $proto->$func($symbtab, $type, $attr);
	} else {
		warn "Please implement a function '$func' in '",__PACKAGE__,"'.\n";
	}
}

sub NameAttrBaseInterface {
	warn __PACKAGE__,"::NameAttrBaseInterface : not supplied \n";
}

sub NameAttrAbstractInterface {
	warn __PACKAGE__,"::NameAttrForwardBaseInterface : not supplied \n";
}

sub NameAttrTypeDeclarator {
	my $proto = shift;
	my($symbtab, $type, $attr) = @_;
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
			warn __PACKAGE__,"::NameAttrTypeDeclarator : ERROR_INTERNAL $attr \n";
		}
	} else {
		my $type = $type->{type};
		unless (ref $type) {
			$type = $symbtab->Lookup($type);
		}
		return $proto->NameAttr($symbtab, $type, $attr);
	}
}

sub NameAttrNativeType {
	my $proto = shift;
	my($symbtab, $type, $attr) = @_;
	warn __PACKAGE__,"::NameAttrNativeType native : not supplied \n";
}

sub NameAttrBasicType {
	my $proto = shift;
	my($symbtab, $type, $attr) = @_;
	if (      $attr eq 'in' ) {
		return "";
	} elsif ( $attr eq 'inout' ) {
		return "&";
	} elsif ( $attr eq 'out' ) {
		return "&";
	} elsif ( $attr eq 'return' ) {
		return "";
	} else {
		warn __PACKAGE__,"::NameAttrBasicType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrAnyType {
	warn __PACKAGE__,"::NameAttrAnyType : not supplied \n";
}

sub NameAttrStructType {
	my $proto = shift;
	my($symbtab, $type, $attr) = @_;
	if (      $attr eq 'in' ) {
		return "&";
	} elsif ( $attr eq 'inout' ) {
		return "&";
	} elsif ( $attr eq 'out' ) {
		return "&";
	} elsif ( $attr eq 'return' ) {
		return "";
	} else {
		warn __PACKAGE__,"::NameAttrStructType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrUnionType {
	my $proto = shift;
	my($symbtab, $type, $attr) = @_;
	if (      $attr eq 'in' ) {
		return "&";
	} elsif ( $attr eq 'inout' ) {
		return "&";
	} elsif ( $attr eq 'out' ) {
		return "&";
	} elsif ( $attr eq 'return' ) {
		return "";
	} else {
		warn __PACKAGE__,"::NameAttrUnionType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrEnumType {
	my $proto = shift;
	my($symbtab, $type, $attr) = @_;
	if (      $attr eq 'in' ) {
		return "";
	} elsif ( $attr eq 'inout' ) {
		return "&";
	} elsif ( $attr eq 'out' ) {
		return "&";
	} elsif ( $attr eq 'return' ) {
		return "";
	} else {
		warn __PACKAGE__,"::NameAttrEnumType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrSequenceType {
	my $proto = shift;
	my($symbtab, $type, $attr) = @_;
	if (      $attr eq 'in' ) {
		return "&";
	} elsif ( $attr eq 'inout' ) {
		return "&";
	} elsif ( $attr eq 'out' ) {
		return "&";
	} elsif ( $attr eq 'return' ) {
		return "";
	} else {
		warn __PACKAGE__,"::NameAttrSequenceType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrStringType {
	my $proto = shift;
	my($symbtab, $type, $attr) = @_;
	if (      $attr eq 'in' ) {
		return "";
	} elsif ( $attr eq 'inout' ) {
		return "&";
	} elsif ( $attr eq 'out' ) {
		return "&";
	} elsif ( $attr eq 'return' ) {
		return "";
	} else {
		warn __PACKAGE__,"::NameAttrStringType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrWideStringType {
	my $proto = shift;
	my($symbtab, $type, $attr) = @_;
	if (      $attr eq 'in' ) {
		return "";
	} elsif ( $attr eq 'inout' ) {
		return "&";
	} elsif ( $attr eq 'out' ) {
		return "&";
	} elsif ( $attr eq 'return' ) {
		return "";
	} else {
		warn __PACKAGE__,"::NameAttrWideStringType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrFixedPtType {
	my $proto = shift;
	my($symbtab, $type, $attr) = @_;
	if (      $attr eq 'in' ) {
		return "&";
	} elsif ( $attr eq 'inout' ) {
		return "&";
	} elsif ( $attr eq 'out' ) {
		return "&";
	} elsif ( $attr eq 'return' ) {
		return "";
	} else {
		warn __PACKAGE__,"::NameAttrFixedPtType : ERROR_INTERNAL $attr \n";
	}
}

##############################################################################

package CORBA::XS::Cname_put2;

#
#	See	1.21	Summary of Argument/Result Passing
#

# needs $type->{length}

sub NameAttr {
	my $proto = shift;
	my($symbtab, $type, $attr) = @_;
	my $class = ref $type;
	$class = "BasicType" if ($type->isa("BasicType"));
	$class = "AnyType" if ($type->isa("AnyType"));
	$class = "BaseInterface" if ($type->isa("BaseInterface"));
	$class = "ForwardBaseInterface" if ($type->isa("ForwardBaseInterface"));
	my $func = 'NameAttr' . $class;
	if($proto->can($func)) {
		return $proto->$func($symbtab, $type, $attr);
	} else {
		warn "Please implement a function '$func' in '",__PACKAGE__,"'.\n";
	}
}

sub NameAttrBaseInterface {
	warn __PACKAGE__,"::NameAttrBaseInterface : not supplied \n";
}

sub NameAttrForwardBaseInterface {
	warn __PACKAGE__,"::NameAttrForwardBaseInterface : not supplied \n";
}

sub NameAttrTypeDeclarator {
	my $proto = shift;
	my($symbtab, $type, $attr) = @_;
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
		my $type = $type->{type};
		unless (ref $type) {
			$type = $symbtab->Lookup($type);
		}
		return $proto->NameAttr($symbtab, $type, $attr);
	}
}

sub NameAttrNativeType {
	my $proto = shift;
	my($symbtab, $type, $attr) = @_;
	warn __PACKAGE__,"::NameAttrNativeType native : not supplied \n";
}

sub NameAttrBasicType {
	my $proto = shift;
	my($symbtab, $type, $attr) = @_;
	if (      $attr eq 'inout' ) {
		return "";
	} elsif ( $attr eq 'out' ) {
		return "";
	} elsif ( $attr eq 'return' ) {
		return "";
	} else {
		warn __PACKAGE__,"::NameAttrBasicType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrAnyType {
	warn __PACKAGE__,"::NameAttrAnyType : not supplied \n";
}

sub NameAttrStructType {
	my $proto = shift;
	my($symbtab, $type, $attr) = @_;
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
		warn __PACKAGE__,"::NameAttrStructType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrUnionType {
	my $proto = shift;
	my($symbtab, $type, $attr) = @_;
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
		warn __PACKAGE__,"::NameAttrUnionType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrEnumType {
	my $proto = shift;
	my($symbtab, $type, $attr) = @_;
	if (      $attr eq 'inout' ) {
		return "";
	} elsif ( $attr eq 'out' ) {
		return "";
	} elsif ( $attr eq 'return' ) {
		return "";
	} else {
		warn __PACKAGE__,"::NameAttrEnumType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrSequenceType {
	my $proto = shift;
	my($symbtab, $type, $attr) = @_;
	if (      $attr eq 'inout' ) {
		return "";
	} elsif ( $attr eq 'out' ) {
		return "*";
	} elsif ( $attr eq 'return' ) {
		return "*";
	} else {
		warn __PACKAGE__,"::NameAttrSequenceType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrStringType {
	my $proto = shift;
	my($symbtab, $type, $attr) = @_;
	if (      $attr eq 'inout' ) {
		return "";
	} elsif ( $attr eq 'out' ) {
		return "";
	} elsif ( $attr eq 'return' ) {
		return "*";
	} else {
		warn __PACKAGE__,"::NameAttrStringType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrWideStringType {
	my $proto = shift;
	my($symbtab, $type, $attr) = @_;
	if (      $attr eq 'inout' ) {
		return "";
	} elsif ( $attr eq 'out' ) {
		return "";
	} elsif ( $attr eq 'return' ) {
		return "*";
	} else {
		warn __PACKAGE__,"::NameAttrWideStringType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrFixedPtType {
	my $proto = shift;
	my($symbtab, $type, $attr) = @_;
	if (      $attr eq 'inout' ) {
		return "";
	} elsif ( $attr eq 'out' ) {
		return "";
	} elsif ( $attr eq 'return' ) {
		return "";
	} else {
		warn __PACKAGE__,"::NameAttrFixedPtType : ERROR_INTERNAL $attr \n";
	}
}

##############################################################################

package CORBA::XS::Cptrname_get2;

#
#	See	1.21	Summary of Argument/Result Passing
#

# needs $type->{length}

sub NameAttr {
	my $proto = shift;
	my($symbtab, $type, $attr) = @_;
	my $class = ref $type;
	$class = "BasicType" if ($type->isa("BasicType"));
	$class = "AnyType" if ($type->isa("AnyType"));
	$class = "BaseInterface" if ($type->isa("BaseInterface"));
	$class = "ForwardBaseInterface" if ($type->isa("ForwardBaseInterface"));
	my $func = 'NameAttr' . $class;
	if($proto->can($func)) {
		return $proto->$func($symbtab, $type, $attr);
	} else {
		warn "Please implement a function '$func' in '",__PACKAGE__,"'.\n";
	}
}

sub NameAttrBaseInterface {
	warn __PACKAGE__,"::NameAttrBaseInterface : not supplied \n";
}

sub NameAttrForwardBaseInterface {
	warn __PACKAGE__,"::NameAttrForwardBaseInterface : not supplied \n";
}

sub NameAttrTypeDeclarator {
	my $proto = shift;
	my($symbtab, $type, $attr) = @_;
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
			warn __PACKAGE__,"::NameAttrTypeDeclarator : ERROR_INTERNAL $attr \n";
		}
	} else {
		my $type = $type->{type};
		unless (ref $type) {
			$type = $symbtab->Lookup($type);
		}
		return $proto->NameAttr($symbtab, $type, $attr);
	}
}

sub NameAttrNativeType {
	my $proto = shift;
	my($symbtab, $type, $attr) = @_;
	warn __PACKAGE__,"::NameAttrNativeType native : not supplied \n";
}

sub NameAttrBasicType {
	my $proto = shift;
	my($symbtab, $type, $attr) = @_;
	if (      $attr eq 'in' ) {
		return "&";
	} elsif ( $attr eq 'inout' ) {
		return "&";
	} elsif ( $attr eq 'out' ) {
		return "&";
	} elsif ( $attr eq 'return' ) {
		return "&";
	} else {
		warn __PACKAGE__,"::NameAttrBasicType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrAnyType {
	warn __PACKAGE__,"::NameAttrAnyType : not supplied \n";
}

sub NameAttrStructType {
	my $proto = shift;
	my($symbtab, $type, $attr) = @_;
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
		warn __PACKAGE__,"::NameAttrStructType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrUnionType {
	my $proto = shift;
	my($symbtab, $type, $attr) = @_;
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
		warn __PACKAGE__,"::NameAttrUnionType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrEnumType {
	my $proto = shift;
	my($symbtab, $type, $attr) = @_;
	if (      $attr eq 'in' ) {
		return "&";
	} elsif ( $attr eq 'inout' ) {
		return "&";
	} elsif ( $attr eq 'out' ) {
		return "&";
	} elsif ( $attr eq 'return' ) {
		return "&";
	} else {
		warn __PACKAGE__,"::NameAttrEnumType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrSequenceType {
	my $proto = shift;
	my($symbtab, $type, $attr) = @_;
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
		warn __PACKAGE__,"::NameAttrSequenceType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrStringType {
	my $proto = shift;
	my($symbtab, $type, $attr) = @_;
	if (      $attr eq 'in' ) {
		return "&";
	} elsif ( $attr eq 'inout' ) {
		return "&";
	} elsif ( $attr eq 'out' ) {
		return "&";
	} elsif ( $attr eq 'return' ) {
		return "";
	} else {
		warn __PACKAGE__,"::NameAttrStringType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrWideStringType {
	my $proto = shift;
	my($symbtab, $type, $attr) = @_;
	if (      $attr eq 'in' ) {
		return "&";
	} elsif ( $attr eq 'inout' ) {
		return "&";
	} elsif ( $attr eq 'out' ) {
		return "&";
	} elsif ( $attr eq 'return' ) {
		return "";
	} else {
		warn __PACKAGE__,"::NameAttrWideStringType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrFixedPtType {
	my $proto = shift;
	my($symbtab, $type, $attr) = @_;
	if (      $attr eq 'in' ) {
		return "&";
	} elsif ( $attr eq 'inout' ) {
		return "&";
	} elsif ( $attr eq 'out' ) {
		return "&";
	} elsif ( $attr eq 'return' ) {
		return "&";
	} else {
		warn __PACKAGE__,"::NameAttrFixedPtType : ERROR_INTERNAL $attr \n";
	}
}

1;

