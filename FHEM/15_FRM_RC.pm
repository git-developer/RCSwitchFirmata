#############################################
package main;

use strict;
use warnings;

#add FHEM/lib to @INC if it's not allready included. Should rather be in fhem.pl than here though...
BEGIN {
	if (!grep(/FHEM\/lib$/,@INC)) {
		foreach my $inc (grep(/FHEM$/,@INC)) {
			push @INC,$inc."/lib";
		};
	};
};

use Device::Firmata::Constants  qw/ :all /;

#####################################

my %rcParameters = (
  "vccPin"           => PIN_HIGH,
  "gndPin"           => PIN_LOW,
);

sub
FRM_RC_Initialize($)
{
  my ($hash) = @_;
  LoadModule("FRM");
}

sub
FRM_RC_Init($$$$$)
{
  my ($hash, $command, $observer, @attributes, %rcswitchParameters, %moduleParameters, $args) = @_;
  my $ret = FRM_Init_Pin_Client($hash, $args, $command);
  return $ret if (defined $ret);
  my $pin = $hash->{PIN};
  eval {
    my $firmata = FRM_Client_FirmataDevice($hash);
    $firmata->observe_rc($pin, $observer, $hash);
    my $name = $hash->{NAME};
    foreach my $attribute (@attributes) { # apply attributes after initialization
      if ($main::attr{$name}{$attribute}) {
        FRM_RC_apply_attribute($hash, $attribute, %rcswitchParameters, %moduleParameters);
      }
    }
  };
  return FRM_Catch($@) if $@;
  return undef;
}

sub
FRM_RC_Attr($$$$) {
  my ($command, $name, $attribute, $value, @attributes) = @_;
  my $hash = $main::defs{$name};
  eval {
    if ($command eq "set") {
      ARGUMENT_HANDLER: {
        $attribute eq "IODev" and do {
          if ($main::init_done and (!defined ($hash->{IODev}) or $hash->{IODev}->{NAME} ne $value)) {
            FRM_Client_AssignIOPort($hash, $value);
            FRM_Init_Client($hash) if (defined ($hash->{IODev}));
          }
          last;
        };
        
        (grep {$_ eq $attribute} @attributes) and do {
          $main::attr{$name}{$attribute} = $value;
          if ($main::init_done) {
            FRM_RC_apply_attribute($hash, $attribute);
          }
          last;
        };
      }
    }
  };
  my $ret = FRM_Catch($@) if $@;
  if ($ret) {
    $hash->{STATE} = "error setting $attribute to $value: ".$ret;
    return "cannot $command attribute $attribute to $value for $name: ".$ret;
  }
  return undef;
}

sub FRM_RC_apply_attribute {
  my ($hash, $attribute, $rcswitchParameters, $moduleParameters) = @_;
  my $value = $main::attr{$hash->{NAME}}{$attribute};
  my $device = FRM_Client_FirmataDevice($hash);
  Log3 $hash, 5, "FRM_RC_apply_attribute(" . join(", ", @_) . ")";
  
  if (defined($rcswitchParameters{$attribute})) {
    my $parameterName = $rcswitchParameters{$attribute};
    $device->rc_set_parameter($parameterName, $hash->{PIN}, $value);
  } elsif (defined($rcParameters{$attribute})) {
    my $pin = $value;
    my $pinValue = $rcParameters{$attribute};
    Log3 $hash, 5, "$hash->{NAME}: $attribute := $pin";
    $device->pin_mode($pin, PIN_OUTPUT);
    $device->digital_write($pin, $pinValue);
  } elsif (defined($moduleParameters{$attribute})) {
   # TODO what to do?
  } else {
    return "Unknown attribute $attribute, choose one of "
             . join(" ", sort (@rcParameters, @rcswitchParameters, @moduleParameters));
  }
}

sub FRM_RC_observer
{
  my ( $key, $data, $hash, $rcswitchParameters ) = @_;
  my $name = $hash->{NAME};
  
  my %a = reverse(%rcswitchParameters);
  my $attrName = $a{$key};
  
COMMAND_HANDLER: {
    defined($attrName) and do {
      my $value = shift @$data;
      Log3 $name, 4, "$name: $attrName = $value";

      $main::attr{$name}{$attrName}=$value;
      # TODO refresh web GUI somehow?
      last;
    };
};
}

1;
