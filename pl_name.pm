use strict;
use UNIVERSAL;

#
#			Interface Definition Language (OMG IDL CORBA v2.4)
#

package PerlNameVisitor;

# builds $node->{pl_name} and $node->{pl_package}

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self = {};
	bless($self, $class);
	my($parser) = @_;
	$self->{key} = 'pl_name';
	$self->{srcname} = $parser->YYData->{srcname};
	return $self;
}

#
#	3.5		OMG IDL Specification
#

sub visitNameSpecification {
	my $self = shift;
	my($node) = @_;
	$self->{pkg_curr} = 'main';
	foreach (@{$node->{list_decl}}) {
		$_->visitName($self);
	}
}

#
#	3.6		Module Declaration
#

sub visitNameModule {
	my $self = shift;
	my($node) = @_;
	my $pkg_save = $self->{pkg_curr};
	if ($self->{pkg_curr} eq 'main') {
		$node->{pl_package} = $node->{idf};
	} else {
		$node->{pl_package} = $self->{pkg_curr} . '::' . $node->{idf};
	}
	$self->{pkg_curr} = $node->{pl_package};
	foreach (@{$node->{list_decl}}) {
		$_->visitName($self);
	}
	$self->{pkg_curr} = $pkg_save;
}

#
#	3.7		Interface Declaration
#

sub visitNameInterface {
	my $self = shift;
	my($node) = @_;
	return if (exists $node->{pl_name});
	my $pkg_save = $self->{pkg_curr};
	if ($self->{pkg_curr} eq 'main') {
		$node->{pl_package} = $node->{idf};
	} else {
		$node->{pl_package} = $self->{pkg_curr} . '::' . $node->{idf};
	}
	$self->{pkg_curr} = $node->{pl_package};
	$node->{pl_name} = $node->{idf};
	foreach (@{$node->{list_decl}}) {
		if (	   $_->isa('Operation')
				or $_->isa('Attributes') ) {
			next;
		}
		$_->visitName($self);
	}
	if ($self->{srcname} eq $node->{filename}) {
		if (keys %{$node->{hash_attribute_operation}}) {
			foreach (values %{$node->{hash_attribute_operation}}) {
				$_->visitName($self);
			}
		}
	}
	$self->{pkg_curr} = $pkg_save;
}

sub visitNameForwardInterface {
	my $self = shift;
	my($node) = @_;
	if ($self->{pkg_curr} eq 'main') {
		$node->{pl_package} = $node->{idf};
	} else {
		$node->{pl_package} = $self->{pkg_curr} . '::' . $node->{idf};
	}
	$node->{pl_name} = $node->{idf};
}

#
#	3.8		Value Declaration
#

sub visitNameRegularValue {
	my $self = shift;
	my($node) = @_;
	if ($self->{pkg_curr} eq 'main') {
		$node->{pl_package} = $node->{idf};
	} else {
		$node->{pl_package} = $self->{pkg_curr} . '::' . $node->{idf};
	}
	$node->{pl_name} = $node->{idf};
}

sub visitNameBoxedValue {
	my $self = shift;
	my($node) = @_;
	if ($self->{pkg_curr} eq 'main') {
		$node->{pl_package} = $node->{idf};
	} else {
		$node->{pl_package} = $self->{pkg_curr} . '::' . $node->{idf};
	}
	$node->{pl_name} = $node->{idf};
}

sub visitNameAbstractValue {
	my $self = shift;
	my($node) = @_;
	if ($self->{pkg_curr} eq 'main') {
		$node->{pl_package} = $node->{idf};
	} else {
		$node->{pl_package} = $self->{pkg_curr} . '::' . $node->{idf};
	}
	$node->{pl_name} = $node->{idf};
}

sub visitNameForwardRegularValue {
	my $self = shift;
	my($node) = @_;
	if ($self->{pkg_curr} eq 'main') {
		$node->{pl_package} = $node->{idf};
	} else {
		$node->{pl_package} = $self->{pkg_curr} . '::' . $node->{idf};
	}
	$node->{pl_name} = $node->{idf};
}

sub visitNameForwardAbstractValue {
	my $self = shift;
	my($node) = @_;
	if ($self->{pkg_curr} eq 'main') {
		$node->{pl_package} = $node->{idf};
	} else {
		$node->{pl_package} = $self->{pkg_curr} . '::' . $node->{idf};
	}
	$node->{pl_name} = $node->{idf};
}

#
#	3.9		Constant Declaration
#

sub visitNameConstant {
	my $self = shift;
	my($node) = @_;
	$node->{pl_package} = $self->{pkg_curr};
	$node->{pl_name} = $node->{idf};
	$node->{value}->visitName($self);	# expression
}

sub _Eval {
	my $self = shift;
	my($list_expr,$type) = @_;
	my $elt = pop @{$list_expr};
	if (      $elt->isa('BinaryOp') ) {
		my $right = $self->_Eval($list_expr,$type);
		my $left = $self->_Eval($list_expr,$type);
		return "(" . $left . " " . $elt->{op} . " " . $right . ")";
	} elsif ( $elt->isa('UnaryOp') ) {
		my $right = $self->_Eval($list_expr,$type);
		return $elt->{op} . $right;
	} elsif ( $elt->isa('Constant') ) {
		return $elt->{pl_package} . '::' . $elt->{pl_name};
	} elsif ( $elt->isa('Enum') ) {
		return $elt->{pl_name};
	} elsif ( $elt->isa('Literal') ) {
		$elt->visitName($self,$type);
		return $elt->{$self->{key}};
	} else {
		warn __PACKAGE__," _Eval: INTERNAL ERROR ",ref $elt,".\n";
		return undef;
	}
}

sub visitNameExpression {
	my $self = shift;
	my($node) = @_;
	$node->{pl_package} = $self->{pkg_curr};
	my @list_expr = @{$node->{list_expr}};		# create a copy
	$node->{pl_name} = $self->_Eval(\@list_expr,$node->{type});
}

sub visitNameIntegerLiteral {
	my $self = shift;
	my($node,$type) = @_;
	my $str = $node->{value};
	$str =~ s/^\+//;
	$node->{pl_name} = $str;
}

sub visitNameStringLiteral {
	my $self = shift;
	my($node) = @_;
	my @list = unpack "C*",$node->{value};
	my $str = "\"";
	foreach (@list) {
		if ($_ < 32 or $_ >= 128) {
			$str .= sprintf "\\x%02x",$_;
		} else {
			$str .= chr $_;
		}
	}
	$str .= "\"";
	$node->{pl_name} = $str;
}

sub visitNameWideStringLiteral {
	my $self = shift;
	my($node) = @_;
	my @list = unpack "C*",$node->{value};
	my $str = "L\"";
	foreach (@list) {
		if ($_ < 32 or ($_ >= 128 and $_ < 256)) {
			$str .= sprintf "\\x%02x",$_;
		} elsif ($_ >= 256) {
			$str .= sprintf "\\x{%04x}",$_;
		} else {
			$str .= chr $_;
		}
	}
	$str .= "\"";
	$node->{pl_name} = $str;
}

sub visitNameCharacterLiteral {
	my $self = shift;
	my($node) = @_;
	my @list = unpack "C",$node->{value};
	my $c = $list[0];
	my $str = "\"";
	if ($c < 32 or $c >= 128) {
		$str .= sprintf "\\x%02x",$c;
	} else {
		$str .= chr $c;
	}
	$str .= "\"";
	$node->{pl_name} = $str;
}

sub visitNameWideCharacterLiteral {
	my $self = shift;
	my($node) = @_;
	my @list = unpack "C",$node->{value};
	my $c = $list[0];
	my $str = "L'";
	if ($c < 32 or ($c >= 128 and $c < 256)) {
		$str .= sprintf "\\x%02x",$c;
	} elsif ($c >= 256) {
		$str .= sprintf "\\x{%04x}",$c;
	} else {
		$str .= chr $c;
	}
	$str .= "'";
	$node->{pl_name} = $str;
}

sub visitNameFixedPtLiteral {
	my $self = shift;
	my($node) = @_;
	my $str = "'";
	$str .= $node->{value};
	$str .= "'";
	$node->{pl_name} = $str;
}

sub visitNameFloatingPtLiteral {
	my $self = shift;
	my($node) = @_;
	$node->{pl_name} = $node->{value};
}

sub visitNameBooleanLiteral {
	my $self = shift;
	my($node) = @_;
	if ($node->{value} eq 'TRUE') {
		$node->{pl_name} = "1";
	} else {
		$node->{pl_name} = "\"\"";
	}
}

#
#	3.10	Type Declaration
#

sub visitNameTypeDeclarators {
	my $self = shift;
	my($node) = @_;
	foreach (@{$node->{list_value}}) {
		$_->visitName($self);
	}
}

sub visitNameTypeDeclarator {
	my $self = shift;
	my($node) = @_;
	if (exists $node->{modifier}) {		# native IDL2.2
		$node->{pl_name} = $node->{idf};
	} else {
		return if (exists $node->{pl_package});
		$node->{pl_package} = $self->{pkg_curr};
		$node->{pl_name} = $node->{idf};
		$node->{type}->visitName($self);
		if (exists $node->{array_size}) {
			warn __PACKAGE__,"::visitNameTypeDecalarator $node->{idf} : empty array_size.\n"
					unless (@{$node->{array_size}});
			foreach (@{$node->{array_size}}) {
				$_->visitName($self);	# expression
			}
		}
	}
}

#
#	3.10.1	Basic Types
#
#	See	1.7		Mapping for Basic Data Types
#

sub visitNameBasicType {
	my $self = shift;
	my($node) = @_;
	my $name = $node->{value};
	$name =~ s/ /_/g;
	$node->{pl_package} = "CORBA";
	$node->{pl_name} = $name;
}

#
#	3.10.2	Constructed Types
#
#	3.10.2.1	Structures
#

sub visitNameStructType {
	my $self = shift;
	my($node) = @_;
	return if (exists $node->{pl_package});
	$node->{pl_package} = $self->{pkg_curr};
	$node->{pl_name} = $node->{idf};
	foreach (@{$node->{list_value}}) {
		$_->visitName($self);			# single or array
	}
}

sub visitNameArray {
	my $self = shift;
	my($node) = @_;
	$node->{pl_name} = $node->{idf};
	$node->{type}->visitName($self);
	warn __PACKAGE__,"::visitNameArray $node->{idf} : empty array_size.\n"
			unless (@{$node->{array_size}});
	foreach (@{$node->{array_size}}) {
		$_->visitName($self);			# expression
	}
}

sub visitNameSingle {
	my $self = shift;
	my($node) = @_;
	$node->{pl_name} = $node->{idf};
	$node->{type}->visitName($self);
}

#	3.10.2.2	Discriminated Unions
#

sub visitNameUnionType {
	my $self = shift;
	my($node) = @_;
	return if (exists $node->{pl_package});
	$node->{pl_package} = $self->{pkg_curr};
	$node->{pl_name} = $node->{idf};
	$node->{type}->visitName($self);
	foreach (@{$node->{list_expr}}) {
		$_->visitName($self);			# case
	}
}

sub visitNameCase {
	my $self = shift;
	my($node) = @_;
	foreach (@{$node->{list_label}}) {
		$_->visitName($self);			# default or expression
	}
	$node->{element}->visitName($self);
}

sub visitNameDefault {
	# empty
}

sub visitNameElement {
	my $self = shift;
	my($node) = @_;
	$node->{value}->visitName($self);		# array or single
}

#	3.10.2.3	Enumerations
#

sub visitNameEnumType {
	my $self = shift;
	my($node) = @_;
	$node->{pl_package} = $self->{pkg_curr};
	$node->{pl_name} = $node->{idf};
	foreach (@{$node->{list_expr}}) {
		$_->visitName($self);			# enum
	}
}

sub visitNameEnum {
	my $self = shift;
	my($node) = @_;
	$node->{pl_name} = $node->{idf};
}

#
#	3.10.3	Constructed Recursive Types and Forward Declarations
#

sub visitNameForwardStructType {
	my $self = shift;
	my($node) = @_;
	$node->{pl_package} = $self->{pkg_curr};
	$node->{pl_name} = $node->{idf};
}

sub visitNameForwardUnionType {
	my $self = shift;
	my($node) = @_;
	$node->{pl_package} = $self->{pkg_curr};
	$node->{pl_name} = $node->{idf};
}

#
#	3.10.4	Template Types
#
#	See	1.11	Mapping for Sequence Types
#

sub visitNameSequenceType {
	my $self = shift;
	my($node) = @_;
	return if (exists $node->{pl_package});
	my $type = $node->{type};
	while (		$type->isa('TypeDeclarator')
			and ! exists $type->{array_size} ) {
		$type = $type->{type};
	}
	$type->visitName($self);
	$node->{pl_package} = $self->{pkg_curr};
	my $name;
	if ($self->{pkg_curr} eq 'main') {
		$name = $type->{pl_name};
	} else {
		$name = $type->{pl_package} . '::' . $type->{pl_name};
	}
	$name =~ s/::/_/g;
	$node->{pl_name} = "sequence_" . $name;
}

#
#	See	1.12	Mapping for Strings
#

sub visitNameStringType {
	my $self = shift;
	my($node) = @_;
	$node->{pl_package} = "CORBA";
	$node->{pl_name} = "string";
}

#
#	See	1.13	Mapping for Wide Strings
#

sub visitNameWideStringType {
	my $self = shift;
	my($node) = @_;
	$node->{pl_package} = "CORBA";
	$node->{pl_name} = "wstring";
}

#
#	See	1.14	Mapping for Fixed
#

sub visitNameFixedPtType {
	my $self = shift;
	my($node) = @_;
	my $name = "fixed";
	$node->{pl_package} = "CORBA";
	$node->{pl_name} = $name;
}

#
#	3.11	Exception Declaration
#

sub visitNameException {
	my $self = shift;
	my($node) = @_;
	return if (exists $node->{pl_package});
	$node->{pl_package} = $self->{pkg_curr};
	$node->{pl_name} = $node->{idf};
	foreach (@{$node->{list_value}}) {
		$_->visitName($self);			# single or array
	}
}

#
#	3.12	Operation Declaration
#
#	See	1.4		Inheritance and Operation Names
#

sub visitNameOperation {
	my $self = shift;
	my($node) = @_;
	$node->{pl_package} = $self->{pkg_curr};
	$node->{pl_name} = $node->{idf};
	$node->{type}->visitName($self);
	foreach (@{$node->{list_param}}) {
		$_->visitName($self);			# parameter
	}
}

sub visitNameParameter {
	my $self = shift;
	my($node) = @_;
	$node->{pl_name} = $node->{idf};
	$node->{type}->visitName($self);
}

sub visitNameVoidType {
	my $self = shift;
	my($node) = @_;
	$node->{pl_name} = "";
}

#
#	3.13	Attribute Declaration
#

sub visitNameAttribute {
	my $self = shift;
	my($node) = @_;
	$node->{_get}->visitName($self);
	$node->{_set}->visitName($self) if (exists $node->{_set});
}

1;

