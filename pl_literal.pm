use strict;
use UNIVERSAL;

#
#			Interface Definition Language (OMG IDL CORBA v3.0)
#

package PerlLiteralVisitor;

# builds $node->{pl_literal}

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self = {};
	bless($self, $class);
	my($parser) = @_;
	$self->{key} = 'pl_literal';
	$self->{symbtab} = $parser->YYData->{symbtab};
	return $self;
}

sub visitNameType {
	my $self = shift;
	my ($type) = @_;

	if (ref $type) {
		$type->visitName($self);
	} else {
		$self->{symbtab}->Lookup($type)->visitName($self);
	}
}

#
#	3.5		OMG IDL Specification
#

sub visitNameSpecification {
	my $self = shift;
	my($node) = @_;
	foreach (@{$node->{list_export}}) {
		$self->{symbtab}->Lookup($_)->visitName($self);
	}
}

#
#	3.7		Module Declaration
#

sub visitNameModules {
	my $self = shift;
	my($node) = @_;
	foreach (@{$node->{list_export}}) {
		$self->{symbtab}->Lookup($_)->visitName($self);
	}
}

#
#	3.8		Interface Declaration
#

sub visitNameBaseInterface {
	my $self = shift;
	my($node) = @_;
	return if (exists $node->{$self->{key}});
	$node->{$self->{key}} = 1;
	foreach (@{$node->{list_export}}) {
		$self->{symbtab}->Lookup($_)->visitName($self);
	}
}

#
#	3.9		Value Declaration
#

sub visitNameStateMember {
	my $self = shift;
	my($node) = @_;
	$self->visitNameType($node->{type});	# type_spec
	if (exists $node->{array_size}) {
		foreach (@{$node->{array_size}}) {
			$_->visitName($self);			# expression
		}
	}
}

sub visitNameInitializer {
	my $self = shift;
	my($node) = @_;
	foreach (@{$node->{list_param}}) {
		$_->visitName($self);				# parameter
	}
}

#
#	3.10	Constant Declaration
#

sub visitNameConstant {
	my $self = shift;
	my($node) = @_;
	$node->{value}->visitName($self);		# expression
}

sub _Eval {
	my $self = shift;
	my($list_expr, $type) = @_;
	my $elt = pop @{$list_expr};
	unless (ref $elt) {
		$elt = $self->{symbtab}->Lookup($elt);
	}
	if (      $elt->isa('BinaryOp') ) {
		my $right = $self->_Eval($list_expr, $type);
		my $left = $self->_Eval($list_expr, $type);
		return "(" . $left . " " . $elt->{op} . " " . $right . ")";
	} elsif ( $elt->isa('UnaryOp') ) {
		my $right = $self->_Eval($list_expr, $type);
		return $elt->{op} . $right;
	} elsif ( $elt->isa('Constant') ) {
		return $elt->{pl_package} . '::' . $elt->{pl_name};
	} elsif ( $elt->isa('Enum') ) {
		return $elt->{pl_name};
	} elsif ( $elt->isa('Literal') ) {
		$elt->visitName($self, $type);
		return $elt->{$self->{key}};
	} else {
		warn __PACKAGE__,"::_Eval: INTERNAL ERROR ",ref $elt,".\n";
		return undef;
	}
}

sub visitNameExpression {
	my $self = shift;
	my($node) = @_;
	my @list_expr = @{$node->{list_expr}};		# create a copy
	$node->{$self->{key}} = $self->_Eval(\@list_expr, $node->{type});
}

sub visitNameIntegerLiteral {
	my $self = shift;
	my($node,$type) = @_;
	my $str = $node->{value};
	$str =~ s/^\+//;
	$node->{$self->{key}} = $str;
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
	$node->{$self->{key}} = $str;
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
	$node->{$self->{key}} = $str;
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
	$node->{$self->{key}} = $str;
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
	$node->{$self->{key}} = $str;
}

sub visitNameFixedPtLiteral {
	my $self = shift;
	my($node) = @_;
	my $str = "'";
	$str .= $node->{value};
	$str .= "'";
	$node->{$self->{key}} = $str;
}

sub visitNameFloatingPtLiteral {
	my $self = shift;
	my($node) = @_;
	$node->{$self->{key}} = $node->{value};
}

sub visitNameBooleanLiteral {
	my $self = shift;
	my($node) = @_;
	if ($node->{value} eq 'TRUE') {
		$node->{$self->{key}} = "1";
	} else {
		$node->{$self->{key}} = "\"\"";
	}
}

#
#	3.11	Type Declaration
#

sub visitNameTypeDeclarator {
	my $self = shift;
	my($node) = @_;
	return if (exists $node->{modifier});	# native IDL2.2
	$self->visitNameType($node->{type});
	if (exists $node->{array_size}) {
		foreach (@{$node->{array_size}}) {
			$_->visitName($self);			# expression
		}
	}
}

#
#	3.11.1	Basic Types
#

sub visitNameBasicType {
	# empty
}

sub visitNameAnyType {
	# empty
}

#
#	3.11.2	Constructed Types
#
#	3.11.2.1	Structures
#

sub visitNameStructType {
	my $self = shift;
	my($node) = @_;
	return if (exists $node->{$self->{key}});
	$node->{$self->{key}} = 1;
	foreach (@{$node->{list_value}}) {
		$self->visitNameType($_);			# single or array
	}
}

sub visitNameArray {
	my $self = shift;
	my($node) = @_;
	$self->visitNameType($node->{type});
	foreach (@{$node->{array_size}}) {
		$_->visitName($self);				# expression
	}
}

sub visitNameSingle {
	my $self = shift;
	my($node) = @_;
	$self->visitNameType($node->{type});
}

#	3.11.2.2	Discriminated Unions
#

sub visitNameUnionType {
	my $self = shift;
	my($node) = @_;
	return if (exists $node->{$self->{key}});
	$node->{$self->{key}} = 1;
	$self->visitNameType($node->{type});
	foreach (@{$node->{list_expr}}) {
		$_->visitName($self);				# case
	}
}

sub visitNameCase {
	my $self = shift;
	my($node) = @_;
	foreach (@{$node->{list_label}}) {
		$_->visitName($self);				# default or expression
	}
	$node->{element}->visitName($self);		# array or single
}

sub visitNameDefault {
	# empty
}

sub visitNameElement {
	my $self = shift;
	my($node) = @_;
	$self->visitNameType($node->{value});	# single or array
}

#	3.11.2.4	Enumerations
#

sub visitNameEnumType {
	my $self = shift;
	my($node) = @_;
	foreach (@{$node->{list_expr}}) {
		$_->visitName($self);				# enum
	}
}

sub visitNameEnum {
	my $self = shift;
	my($node) = @_;
	$node->{$self->{key}} = $node->{idf};
}

#
#	3.11.3	Template Types
#

sub visitNameSequenceType {
	my $self = shift;
	my($node) = @_;
	$self->visitNameType($node->{type});
	$node->{max}->visitName($self) if (exists $node->{max});
}

sub visitNameStringType {
	my $self = shift;
	my($node) = @_;
	$node->{max}->visitName($self) if (exists $node->{max});
}

sub visitNameWideStringType {
	my $self = shift;
	my($node) = @_;
	$node->{max}->visitName($self) if (exists $node->{max});
}

sub visitNameFixedPtType {
	my $self = shift;
	my($node) = @_;
	$node->{d}->visitName($self);
	$node->{s}->visitName($self);
}

sub visitNameFixedPtConstType {
	# empty
}

#
#	3.12	Exception Declaration
#

sub visitNameException {
	my $self = shift;
	my($node) = @_;
	foreach (@{$node->{list_value}}) {
		$self->visitNameType($_);			# single or array
	}
}

#
#	3.13	Operation Declaration
#

sub visitNameOperation {
	my $self = shift;
	my($node) = @_;
	$self->visitNameType($node->{type});	# param_type_spec or void
	foreach (@{$node->{list_param}}) {
		$_->visitName($self);				# parameter
	}
}

sub visitNameParameter {
	my $self = shift;
	my($node) = @_;
	$self->visitNameType($node->{type});	# param_type_spec
}

sub visitNameVoidType {
	# empty
}

#
#	3.14	Attribute Declaration
#

sub visitNameAttribute {
	my $self = shift;
	my($node) = @_;
	$self->visitNameType($node->{type});	# param_type_spec
}

#
#	3.15	Repository Identity Related Declarations
#

sub visitNameTypeId {
	# empty
}

sub visitNameTypePrefix {
	# empty
}

#
#	3.16	Event Declaration
#

#
#	3.17	Component Declaration
#

sub visitNameProvides {
	# empty
}

sub visitNameUses {
	# empty
}

sub visitNamePublishes {
	# empty
}

sub visitNameEmits {
	# empty
}

sub visitNameConsumes {
	# empty
}

#
#	3.18	Home Declaration
#

sub visitNameFactory {
	my $self = shift;
	my($node) = @_;
	foreach (@{$node->{list_param}}) {
		$_->visitName($self);				# parameter
	}
}

sub visitNameFinder {
	my $self = shift;
	my($node) = @_;
	foreach (@{$node->{list_param}}) {
		$_->visitName($self);				# parameter
	}
}

1;

