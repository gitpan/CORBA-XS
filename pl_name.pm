use strict;
use UNIVERSAL;

#
#			Interface Definition Language (OMG IDL CORBA v3.0)
#

package PerlNameVisitor;

# builds $node->{pl_name} and $node->{pl_package}

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self = {};
	bless($self, $class);
	my($parser) = @_;
	$self->{symbtab} = $parser->YYData->{symbtab};
	return $self;
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

sub _get_name {
	my $self = shift;
	my($node) = @_;
	my $name = $node->{idf};
	return $name;
}

sub _get_pkg {
	my $self = shift;
	my($node) = @_;
	my $pkg = $node->{full};
	unless (   $node->isa('Modules')
			or $node->isa('BaseInterface') ) {
		$pkg =~ s/::[0-9A-Z_a-z]+$//;
		if ($pkg) {
			my $defn = $self->{symbtab}->Lookup($pkg);
			if (	   $defn->isa('StructType')
					or $defn->isa('UnionType')
					or $defn->isa('ExceptionType') ) {
				$pkg =~ s/::[0-9A-Z_a-z]+$//;
			}
		}
	}
	$pkg =~ s/^:://;
	return ($pkg eq '') ? 'main' : $pkg;
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
	$node->{pl_package} = $self->_get_pkg($node);
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
	return if (exists $node->{pl_name});
	$node->{pl_package} = $self->_get_pkg($node);
	$node->{pl_name} = $self->_get_name($node);
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
	$node->{pl_package} = $self->_get_pkg($node);
	$node->{pl_name} = $self->_get_name($node);
	$self->_get_defn($node->{type})->visitName($self);
}

sub visitNameInitializer {
	my $self = shift;
	my($node) = @_;
	$node->{pl_package} = $self->_get_pkg($node);
	$node->{pl_name} = $self->_get_name($node);
	foreach (@{$node->{list_param}}) {
		$_->visitName($self);			# parameter
	}
}

#
#	3.10	Constant Declaration
#

sub visitNameConstant {
	my $self = shift;
	my($node) = @_;
	$node->{pl_package} = $self->_get_pkg($node);
	$node->{pl_name} = $self->_get_name($node);
}

sub visitNameExpression {
	# empty
}

#
#	3.11	Type Declaration
#

sub visitNameTypeDeclarator {
	my $self = shift;
	my($node) = @_;
	$node->{pl_package} = $self->_get_pkg($node);
	$node->{pl_name} = $self->_get_name($node);
	unless (exists $node->{modifier}) {		# native
		$self->_get_defn($node->{type})->visitName($self);
	}
}

#
#	3.11.1	Basic Types
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
#	3.11.2	Constructed Types
#
#	3.11.2.1	Structures
#

sub visitNameStructType {
	my $self = shift;
	my($node) = @_;
	return if (exists $node->{pl_package});
	$node->{pl_package} = $self->_get_pkg($node);
	$node->{pl_name} = $self->_get_name($node);
	foreach (@{$node->{list_value}}) {
		$self->_get_defn($_)->visitName($self);		# single or array
	}
}

sub visitNameArray {
	my $self = shift;
	my($node) = @_;
	$node->{pl_name} = $self->_get_name($node);
	$self->_get_defn($node->{type})->visitName($self);
}

sub visitNameSingle {
	my $self = shift;
	my($node) = @_;
	$node->{pl_name} = $self->_get_name($node);
	$self->_get_defn($node->{type})->visitName($self);
}

#	3.11.2.2	Discriminated Unions
#

sub visitNameUnionType {
	my $self = shift;
	my($node) = @_;
	return if (exists $node->{pl_package});
	$node->{pl_package} = $self->_get_pkg($node);
	$node->{pl_name} = $self->_get_name($node);
	$self->_get_defn($node->{type})->visitName($self);
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
	$self->_get_defn($node->{value})->visitName($self);		# single or array
}

#	3.11.2.4	Enumerations
#

sub visitNameEnumType {
	my $self = shift;
	my($node) = @_;
	$node->{pl_package} = $self->_get_pkg($node);
	$node->{pl_name} = $self->_get_name($node);
	foreach (@{$node->{list_expr}}) {
		$_->visitName($self);			# enum
	}
}

sub visitNameEnum {
	my $self = shift;
	my($node) = @_;
	$node->{pl_name} = $self->_get_name($node);
}

#
#	3.11.3	Template Types
#

sub visitNameSequenceType {
	my $self = shift;
	my($node) = @_;
	my $type = $self->_get_defn($node->{type});
	$type->visitName($self);
	$node->{pl_package} = $self->_get_pkg($node);
	my $name = ($type->{pl_package} eq 'main') ? $type->{pl_name} : $type->{pl_package} . '::' . $type->{pl_name};
	$name =~ s/::/_/g;
	$node->{pl_name} = "sequence_" . $name;
}

sub visitNameStringType {
	my $self = shift;
	my($node) = @_;
	$node->{pl_package} = "CORBA";
	$node->{pl_name} = "string";
}

sub visitNameWideStringType {
	my $self = shift;
	my($node) = @_;
	$node->{pl_package} = "CORBA";
	$node->{pl_name} = "wstring";
}

sub visitNameFixedPtType {
	my $self = shift;
	my($node) = @_;
	my $name = "fixed";
	$node->{pl_package} = "CORBA";
	$node->{pl_name} = $name;
}

sub visitNameFixedPtConstType {
	my $self = shift;
	my($node) = @_;
	my $name = "fixed";
	$node->{pl_package} = "CORBA";
	$node->{pl_name} = $name;
}

#
#	3.12	Exception Declaration
#

sub visitNameException {
	my $self = shift;
	my($node) = @_;
	$node->{pl_package} = $self->_get_pkg($node);
	$node->{pl_name} = $self->_get_name($node);
	foreach (@{$node->{list_value}}) {
		$self->_get_defn($_)->visitName($self);		# single or array
	}
}

#
#	3.13	Operation Declaration
#

sub visitNameOperation {
	my $self = shift;
	my($node) = @_;
	$node->{pl_package} = $self->_get_pkg($node);
	$node->{pl_name} = $self->_get_name($node);
	$self->_get_defn($node->{type})->visitName($self);
	foreach (@{$node->{list_param}}) {
		$_->visitName($self);			# parameter
	}
}

sub visitNameParameter {
	my $self = shift;
	my($node) = @_;
	$node->{pl_name} = $self->_get_name($node);
	$self->_get_defn($node->{type})->visitName($self);
}

sub visitNameVoidType {
	my $self = shift;
	my($node) = @_;
	$node->{pl_name} = "";
}

#
#	3.14	Attribute Declaration
#

sub visitNameAttribute {
	my $self = shift;
	my($node) = @_;
	$node->{_get}->visitName($self);
	$node->{_set}->visitName($self) if (exists $node->{_set});
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
	my $self = shift;
	my($node) = @_;
	$node->{pl_package} = $self->_get_pkg($node);
	$node->{pl_name} = $self->_get_name($node);
}

sub visitNameUses {
	my $self = shift;
	my($node) = @_;
	$node->{pl_package} = $self->_get_pkg($node);
	$node->{pl_name} = $self->_get_name($node);
}

sub visitNamePublishes {
	my $self = shift;
	my($node) = @_;
	$node->{pl_package} = $self->_get_pkg($node);
	$node->{pl_name} = $self->_get_name($node);
}

sub visitNameEmits {
	my $self = shift;
	my($node) = @_;
	$node->{pl_package} = $self->_get_pkg($node);
	$node->{pl_name} = $self->_get_name($node);
}

sub visitNameConsumes {
	my $self = shift;
	my($node) = @_;
	$node->{pl_package} = $self->_get_pkg($node);
	$node->{pl_name} = $self->_get_name($node);
}

#
#	3.18	Home Declaration
#

sub visitNameFactory {
	my $self = shift;
	my($node) = @_;
	$node->{pl_package} = $self->_get_pkg($node);
	$node->{pl_name} = $self->_get_name($node);
	foreach (@{$node->{list_param}}) {
		$_->visitName($self);			# parameter
	}
}

sub visitNameFinder {
	my $self = shift;
	my($node) = @_;
	$node->{pl_package} = $self->_get_pkg($node);
	$node->{pl_name} = $self->_get_name($node);
	foreach (@{$node->{list_param}}) {
		$_->visitName($self);			# parameter
	}
}

1;

