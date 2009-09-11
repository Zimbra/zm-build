package Zimbra::Util::Timezone;
use strict;
our %TIMEZONES;
our $_PARSED=0;

sub new {
  my $class = shift;
  my $tzname = shift;
  my $self = { tzname => $tzname, tzid=>undef, primary=>undef };
  bless $self, $class;
  $TIMEZONES{$self} = $self;
}
 
sub tzname {
  my $self = shift;
  if (@_) {
    $self->{tzname} = shift;
  } else {
    $self->{tzname};
  }
}
sub tzid {
  my $self = shift;
  if (@_) {
    $self->{tzid} = shift;
  } else {
    $self->{tzid};
  }
}
sub tzalias {
  my $self = shift;
  if (@_) {
    $self->{tzalias} = shift if ($self->{tzalias} eq "");
  } else {
    $self->{tzalias};
  }
}

sub primary {
  my $self = shift;
  if (@_) {
    $self->{primary} = shift;
  } else {
    $self->{primary};
  }
}

sub parse {
  my $self = shift;
  my $file = shift;
  return if ($_PARSED == 1);
  $file="/opt/zimbra/conf/timezones.ics" if ($file eq "");
  open(FILE, "$file") or return undef;
  my $tz;
  while (<FILE>) {
    $tz = $self->new if (/BEGIN:VTIMEZONE/);
    $tz->tzid($1) if (/TZID:(.+)/);
    $tz->tzname($1) if (/TZNAME:(.+)/);
    $tz->primary(1) if (/X-ZIMBRA-TZ-PRIMARY:TRUE/);
    next if (/END:VTIMEZONE/);
  }
  close(FILE);
  $_PARSED=1;
  return $tz;
}

sub gettzbyname {
  my $self = shift;
  my $name = shift;
  foreach (sort values %TIMEZONES) {
    return $_ if ($_->tzname eq $name && $_->primary == 1);
  }
  return undef;
}
sub gettzbyid {
  my $self = shift;
  my $name = shift;
  foreach (sort values %TIMEZONES) {
    return $_ if ($_->tzid eq $name && $_->primary == 1);
  }
  return undef;
}

sub dump {
  my $self = shift;
  my @tzs;
  foreach (values %TIMEZONES) {
    #next if ($_->tzname eq "");
    push(@tzs, $_->tzid) if ($_->primary == 1);
  }
  return @tzs;
}

1;
