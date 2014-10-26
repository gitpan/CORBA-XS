use strict;
use UNIVERSAL;

use Error;

package CORBA::Exception;

@CORBA::Exception::ISA = qw(Error);

sub new {
	my $self  = shift;
	local $Error::Depth = $Error::Depth + 1;
	$self->SUPER::new(@_);
}

sub stringify {
	my $self = shift;
	my $str = ref $self;
	$str .= " '$self->{_repos_id}'";
	return $str;
}

package CORBA::SystemException;

@CORBA::SystemException::ISA = qw(CORBA::Exception);

sub new {
	my $self  = shift;
	local $Error::Depth = $Error::Depth + 1;
	$self->SUPER::new(@_);
}

sub stringify {
	my $self = shift;
	my $str = $self->SUPER::stringify() . "\n";
	$str .= "\tminor => $self->{minor}\n";
	$str .= "\tcompleted => $self->{completed}\n";
	$str .= sprintf(" at %s line %d.\n", $self->file, $self->line);
	return $str;
}

package CORBA::UserException;

@CORBA::UserException::ISA = qw(CORBA::Exception);

sub new {
	my $self  = shift;
	local $Error::Depth = $Error::Depth + 1;
	$self->SUPER::new(@_);
}

package CORBA;

use Carp;

#
#	15.3	CDR Transfert Syntax
#

sub _align_marshal {
	my ($r_buffer,$n) = @_;
	while (length($$r_buffer) % $n) {
		$$r_buffer .= chr 0;
	}
}

sub _align_demarshal {
	my ($r_offset,$n) = @_;
	while ($$r_offset % $n) {
		$$r_offset ++;
	}
}

#
# char maps to a string of length 1.
#

sub char__marshal {
	my ($r_buffer,$value) = @_;
	croak "bad value for 'char'.\n"
			if (length($value) != 1);
	$$r_buffer .= $value;
}

sub char__demarshal {
	my ($r_buffer,$r_offset,$endian) = @_;
	my $str = substr $$r_buffer, $$r_offset, 1;
	croak "not enough data.\n"
			if (length($str) != 1);
	$$r_offset += 1;
	return $str;
}

#sub wchar__marshal {
#}
#
#sub wchar__demarshal {
#}

#
# short, long, float, double, and octet map to Perl scalar variables.
#

sub octet__marshal {
	my ($r_buffer,$value) = @_;
	croak "bad value for 'octet'.\n"
			if ($value < 0 or $value > 256);
	$$r_buffer .= chr $value;
}

sub octet__demarshal {
	my ($r_buffer,$r_offset,$endian) = @_;
	my $str = substr $$r_buffer, $$r_offset, 1;
	croak "not enough data.\n"
			if (length($str) != 1);
	$$r_offset += 1;
	return ord $str;
}

sub short__marshal {
	my ($r_buffer,$value) = @_;
	_align_marshal($r_buffer,2);
	$$r_buffer .= pack "s", $value;
}

sub short__demarshal {
	my ($r_buffer,$r_offset,$endian) = @_;
	_align_demarshal($r_offset,2);
	my $str = substr $$r_buffer, $$r_offset, 2;
	croak "not enough data.\n"
			if (length($str) != 2);
	$$r_offset += 2;
	if ($endian) {
		return unpack "s", $str;
	} else {
		return unpack "s", pack "v", unpack "n", $str;
	}
}

sub unsigned_short__marshal {
	my ($r_buffer,$value) = @_;
	_align_marshal($r_buffer,2);
	$$r_buffer .= pack "S", $value;
}

sub unsigned_short__demarshal {
	my ($r_buffer,$r_offset,$endian) = @_;
	_align_demarshal($r_offset,2);
	my $str = substr $$r_buffer, $$r_offset, 2;
	croak "not enough data.\n"
			if (length($str) != 2);
	$$r_offset += 2;
	if ($endian) {
		return unpack "v", $str;		# VAX : little
	} else {
		return unpack "n", $str;		# net : big
	}
}

sub long__marshal {
	my ($r_buffer,$value) = @_;
	_align_marshal($r_buffer,4);
	$$r_buffer .= pack "l", $value;
}

sub long__demarshal {
	my ($r_buffer,$r_offset,$endian) = @_;
	_align_demarshal($r_offset,4);
	my $str = substr $$r_buffer, $$r_offset, 4;
	croak "not enough data.\n"
			if (length($str) != 4);
	$$r_offset += 4;
	if ($endian) {
		return unpack "l", $str;
	} else {
		return unpack "l", pack "V", unpack "N", $str;
	}
}

sub unsigned_long__marshal {
	my ($r_buffer,$value) = @_;
	_align_marshal($r_buffer,4);
	$$r_buffer .= pack "L", $value;
}

sub unsigned_long__demarshal {
	my ($r_buffer,$r_offset,$endian) = @_;
	_align_demarshal($r_offset,4);
	my $str = substr $$r_buffer, $$r_offset, 4;
	croak "not enough data.\n"
			if (length($str) != 4);
	$$r_offset += 4;
	if ($endian) {
		return unpack "V", $str;		# VAX : little
	} else {
		return unpack "N", $str;		# net : big
	}
}

#sub long_long__marshal {
#	my ($r_buffer,$value) = @_;
#	_align_marshal($r_buffer,8);
#}
#
#sub long_long__demarshal {
#}

#sub unsigned_long_long__marshal {
#	my ($r_buffer,$value) = @_;
#	_align_marshal($r_buffer,8);
#}
#
#sub unsigned_long_long__demarshal {
#}

sub float__marshal {
	my ($r_buffer,$value) = @_;
	_align_marshal($r_buffer,4);
	$$r_buffer .= pack "f", $value;
}

sub float__demarshal {
	my ($r_buffer,$r_offset,$endian) = @_;
	_align_demarshal($r_offset,4);
	my $str = substr $$r_buffer, $$r_offset, 4;
	croak "not enough data.\n"
			if (length($str) != 4);
	$$r_offset += 4;
	return unpack "f", $str;
}

sub double__marshal {
	my ($r_buffer,$value) = @_;
	_align_marshal($r_buffer,8);
	$$r_buffer .= pack "d", $value;
}

sub double__demarshal {
	my ($r_buffer,$r_offset,$endian) = @_;
	_align_demarshal($r_offset,8);
	my $str = substr $$r_buffer, $$r_offset, 8;
	croak "not enough data.\n"
			if (length($str) != 8);
	$$r_offset += 8;
	return unpack "d", $str;
}

#sub long_double__marshal {
#	my ($r_buffer,$value) = @_;
#	_align_marshal($r_buffer,16);
#}
#
#sub long_double__demarshal {
#}

#
# boolean maps as excepted for Perl. That is, a CORBA boolean maps to "" if false
# and to 1 true.
#

sub boolean__marshal {
	my ($r_buffer,$value) = @_;
	if ($value) {
		$$r_buffer .= chr 1;
	} else {
		$$r_buffer .= chr 0;
	}
}

sub boolean__demarshal {
	my ($r_buffer,$r_offset,$endian) = @_;
	my $str = substr $$r_buffer, $$r_offset, 1;
	croak "not enough data.\n"
			if (length($str) != 1);
	$$r_offset += 1;
	if (0 == ord $str) {
		return "";
	} else {
		return 1;
	}
}

sub string__marshal {
	my ($r_buffer,$value,$max) = @_;
	my $len = length $value;
	croak "too long string (max:$max).\n"
			if (defined $max and $len > $max);
	unsigned_long__marshal($r_buffer,$len + 1);
	$$r_buffer .= $value;
	$$r_buffer .= chr 0;
}

sub string__demarshal {
	my ($r_buffer,$r_offset,$endian) = @_;
	my $len = unsigned_long__demarshal($r_buffer,$r_offset,$endian);
	my $str = substr $$r_buffer, $$r_offset, $len;
	croak "not enough data.\n"
			if (length($str) != $len);
	$$r_offset += $len;
	return substr $str, 0, $len - 1;
}

#sub wstring__marshal {
#	my ($r_buffer,$value) = @_;
#	unsigned_long__marshal($r_buffer,length($value) + 1);
#}
#
#sub wstring__demarshal {
#}

#sub fixed__marshal {
#	my ($r_buffer,$value) = @_;
#}
#
#sub fixed__demarshal {
#}

# CORBA::exception_type
sub exception_type__marshal {
	my ($r_buffer,$value) = @_;
	if      ($value eq 'NO_EXCEPTION') {
		CORBA::unsigned_long__marshal($r_buffer,0);
	} elsif ($value eq 'USER_EXCEPTION') {
		CORBA::unsigned_long__marshal($r_buffer,1);
	} elsif ($value eq 'SYSTEM_EXCEPTION') {
		CORBA::unsigned_long__marshal($r_buffer,2);
	} else {
		croak "bad value for 'CORBA::exception_type'.\n";
	}
}
sub exception_type__demarshal {
	my $value = CORBA::unsigned_long__demarshal(@_);
	if      ($value == 0) {
		return 'NO_EXCEPTION';
	} elsif ($value == 1) {
		return 'USER_EXCEPTION';
	} elsif ($value == 2) {
		return 'SYSTEM_EXCEPTION';
	} else {
		croak "bad value for 'CORBA::exception_type'.\n";
	}
}

sub NO_EXCEPTION {
	return 'NO_EXCEPTION';
}
sub USER_EXCEPTION {
	return 'USER_EXCEPTION';
}
sub SYSTEM_EXCEPTION {
	return 'SYSTEM_EXCEPTION';
}

# CORBA::completion_status
sub completion_status__marshal {
	my ($r_buffer,$value) = @_;
	if      ($value eq 'COMPLETED_YES') {
		CORBA::unsigned_long__marshal($r_buffer,0);
	} elsif ($value eq 'COMPLETED_NO') {
		CORBA::unsigned_long__marshal($r_buffer,1);
	} elsif ($value eq 'COMPLETED_MAYBE') {
		CORBA::unsigned_long__marshal($r_buffer,2);
	} else {
		croak "bad value for 'CORBA::completion_status'.\n";
	}
}
sub completion_status__demarshal {
	my $value = CORBA::unsigned_long__demarshal(@_);
	if      ($value == 0) {
		return 'COMPLETED_YES';
	} elsif ($value == 1) {
		return 'COMPLETED_NO';
	} elsif ($value == 2) {
		return 'COMPLETED_MAYBE';
	} else {
		croak "bad value for 'CORBA::completion_status'.\n";
	}
}

sub COMPLETED_YES {
	return 'COMPLETED_YES';
}
sub COMPLETED_NO {
	return 'COMPLETED_NO';
}
sub COMPLETED_MAYBE {
	return 'COMPLETED_MAYBE';
}

1;

