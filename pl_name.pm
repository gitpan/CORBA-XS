use strict;
use UNIVERSAL;

#
#			Interface Definition Language (OMG IDL CORBA v3.0)
#

package CORBA::XS::PerlNameVisitor;

# builds $node->{pl_name} and $node->{pl_package}

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self = {};
	bless($self, $class);
	my ($parser) = @_;
	$self->{symbtab} = $parser->YYData->{symbtab};
	return $self;
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

sub _get_name {
	my $self = shift;
	my ($node) = @_;
	my $name = $node->{idf};
	return $name;
}

sub _get_pkg {
	my $self = shift;
	my ($node) = @_;
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

sub visitSpecification {
	my $self = shift;
	my ($node) = @_;
	foreach (@{$node->{list_export}}) {
		$self->{symbtab}->Lookup($_)->visit($self);
	}
}

#
#	3.7		Module Declaration
#

sub visitModules {
	my $self = shift;
	my ($node) = @_;
	$node->{pl_package} = $self->_get_pkg($node);
	foreach (@{$node->{list_export}}) {
		$self->{symbtab}->Lookup($_)->visit($self);
	}
}

#
#	3.8		Interface Declaration
#

sub visitBaseInterface {
	my $self = shift;
	my ($node) = @_;
	return if (exists $node->{pl_name});
	$node->{pl_package} = $self->_get_pkg($node);
	$node->{pl_name} = $self->_get_name($node);
	foreach (@{$node->{list_export}}) {
		$self->{symbtab}->Lookup($_)->visit($self);
	}
}

sub visitForwardBaseInterface {
	my $self = shift;
	my ($node) = @_;
	return if (exists $node->{pl_name});
	$node->{pl_package} = $self->_get_pkg($node);
	$node->{pl_name} = $self->_get_name($node);
}

#
#	3.9		Value Declaration
#

sub visitStateMember {
	my $self = shift;
	my ($node) = @_;
	$node->{pl_package} = $self->_get_pkg($node);
	$node->{pl_name} = $self->_get_name($node);
	$self->_get_defn($node->{type})->visit($self);
}

sub visitInitializer {
	my $self = shift;
	my ($node) = @_;
	$node->{pl_package} = $self->_get_pkg($node);
	$node->{pl_name} = $self->_get_name($node);
	foreach (@{$node->{list_param}}) {
		$_->visit($self);			# parameter
	}
}

#
#	3.10	Constant Declaration
#

sub visitConstant {
	my $self = shift;
	my ($node) = @_;
	$node->{pl_package} = $self->_get_pkg($node);
	$node->{pl_name} = $self->_get_name($node);
}

sub visitExpression {
	# empty
}

#
#	3.11	Type Declaration
#

sub visitTypeDeclarator {
	my $self = shift;
	my ($node) = @_;
	$node->{pl_package} = $self->_get_pkg($node);
	$node->{pl_name} = $self->_get_name($node);
	unless (exists $node->{modifier}) {		# native
		$self->_get_defn($node->{type})->visit($self);
	}
}

#
#	3.11.1	Basic Types
#

sub visitBasicType {
	my $self = shift;
	my ($node) = @_;
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

sub visitStructType {
	my $self = shift;
	my ($node) = @_;
	return if (exists $node->{pl_package});
	$node->{pl_package} = $self->_get_pkg($node);
	$node->{pl_name} = $self->_get_name($node);
	foreach (@{$node->{list_member}}) {
		$self->_get_defn($_)->visit($self);		# member
	}
}

sub visitMember {
	my $self = shift;
	my ($node) = @_;
	$node->{pl_name} = $self->_get_name($node);
	$self->_get_defn($node->{type})->visit($self);
}

#	3.11.2.2	Discriminated Unions
#

sub visitUnionType {
	my $self = shift;
	my ($node) = @_;
	return if (exists $node->{pl_package});
	$node->{pl_package} = $self->_get_pkg($node);
	$node->{pl_name} = $self->_get_name($node);
	$self->_get_defn($node->{type})->visit($self);
	foreach (@{$node->{list_expr}}) {
		$_->visit($self);			# case
	}
}

sub visitCase {
	my $self = shift;
	my ($node) = @_;
	foreach (@{$node->{list_label}}) {
		$_->visit($self);			# default or expression
	}
	$node->{element}->visit($self);
}

sub visitDefault {
	# empty
}

sub visitElement {
	my $self = shift;
	my ($node) = @_;
	$self->_get_defn($node->{value})->visit($self);		# member
}

#	3.11.2.4	Enumerations
#

sub visitEnumType {
	my $self = shift;
	my ($node) = @_;
	$node->{pl_package} = $self->_get_pkg($node);
	$node->{pl_name} = $self->_get_name($node);
	foreach (@{$node->{list_expr}}) {
		$_->visit($self);			# enum
	}
}

sub visitEnum {
	my $self = shift;
	my ($node) = @_;
	$node->{pl_name} = $self->_get_name($node);
}

#
#	3.11.3	Template Types
#

sub visitSequenceType {
	my $self = shift;
	my ($node) = @_;
	my $type = $self->_get_defn($node->{type});
	$type->visit($self);
	$node->{pl_package} = $self->_get_pkg($node);
	my $name = ($type->{pl_package} eq 'main') ? $type->{pl_name} : $type->{pl_package} . '::' . $type->{pl_name};
	$name =~ s/::/_/g;
	$node->{pl_name} = "sequence_" . $name;
}

sub visitStringType {
	my $self = shift;
	my ($node) = @_;
	$node->{pl_package} = "CORBA";
	$node->{pl_name} = "string";
}

sub visitWideStringType {
	my $self = shift;
	my ($node) = @_;
	$node->{pl_package} = "CORBA";
	$node->{pl_name} = "wstring";
}

sub visitFixedPtType {
	my $self = shift;
	my ($node) = @_;
	my $name = "fixed";
	$node->{pl_package} = "CORBA";
	$node->{pl_name} = $name;
}

sub visitFixedPtConstType {
	my $self = shift;
	my ($node) = @_;
	my $name = "fixed";
	$node->{pl_package} = "CORBA";
	$node->{pl_name} = $name;
}

#
#	3.12	Exception Declaration
#

sub visitException {
	my $self = shift;
	my ($node) = @_;
	$node->{pl_package} = $self->_get_pkg($node);
	$node->{pl_name} = $self->_get_name($node);
	foreach (@{$node->{list_member}}) {
		$self->_get_defn($_)->visit($self);		# member
	}
}

#
#	3.13	Operation Declaration
#

sub visitOperation {
	my $self = shift;
	my ($node) = @_;
	$node->{pl_package} = $self->_get_pkg($node);
	$node->{pl_name} = $self->_get_name($node);
	$self->_get_defn($node->{type})->visit($self);
	foreach (@{$node->{list_param}}) {
		$_->visit($self);			# parameter
	}
}

sub visitParameter {
	my $self = shift;
	my($node) = @_;
	$node->{pl_name} = $self->_get_name($node);
	$self->_get_defn($node->{type})->visit($self);
}

sub visitVoidType {
	my $self = shift;
	my ($node) = @_;
	$node->{pl_name} = "";
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

#
#	3.17	Component Declaration
#

sub visitProvides {
	my $self = shift;
	my ($node) = @_;
	$node->{pl_package} = $self->_get_pkg($node);
	$node->{pl_name} = $self->_get_name($node);
}

sub visitUses {
	my $self = shift;
	my ($node) = @_;
	$node->{pl_package} = $self->_get_pkg($node);
	$node->{pl_name} = $self->_get_name($node);
}

sub visitPublishes {
	my $self = shift;
	my ($node) = @_;
	$node->{pl_package} = $self->_get_pkg($node);
	$node->{pl_name} = $self->_get_name($node);
}

sub visitEmits {
	my $self = shift;
	my ($node) = @_;
	$node->{pl_package} = $self->_get_pkg($node);
	$node->{pl_name} = $self->_get_name($node);
}

sub visitConsumes {
	my $self = shift;
	my ($node) = @_;
	$node->{pl_package} = $self->_get_pkg($node);
	$node->{pl_name} = $self->_get_name($node);
}

#
#	3.18	Home Declaration
#

sub visitFactory {
	my $self = shift;
	my ($node) = @_;
	$node->{pl_package} = $self->_get_pkg($node);
	$node->{pl_name} = $self->_get_name($node);
	foreach (@{$node->{list_param}}) {
		$_->visit($self);			# parameter
	}
}

sub visitFinder {
	my $self = shift;
	my ($node) = @_;
	$node->{pl_package} = $self->_get_pkg($node);
	$node->{pl_name} = $self->_get_name($node);
	foreach (@{$node->{list_param}}) {
		$_->visit($self);			# parameter
	}
}

1;

