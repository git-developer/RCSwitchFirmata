#############################################
package main;

use strict;
use warnings;

#add FHEM/lib to @INC if it's not already included. Should rather be in fhem.pl than here though...
BEGIN {
	if (!grep(/FHEM\/lib$/,@INC)) {
		foreach my $inc (grep(/FHEM$/,@INC)) {
			push @INC,$inc."/lib";
		};
	};
};

use Device::Firmata::Constants  qw/ :all /;

#####################################

our %rcAttributes = (
  "vccPin"           => PIN_HIGH,
  "gndPin"           => PIN_LOW,
);

my $RC_TRISTATE_BIT_VALUES = {
  TRISTATE_0        => 0,
  TRISTATE_F        => 1,
  TRISTATE_RESERVED => 2,
  TRISTATE_1        => 3,
};

my $RC_TRISTATE_CHARS = {
  $RC_TRISTATE_BIT_VALUES->{TRISTATE_0} => "0",
  $RC_TRISTATE_BIT_VALUES->{TRISTATE_F} => "F",
  $RC_TRISTATE_BIT_VALUES->{TRISTATE_1} => "1",
};

my %RC_TRISTATE_BITS = reverse %$RC_TRISTATE_CHARS;

my @rc_observer = []; # TODO empty on reset, unload etc.


sub
FRM_RC_Initialize($)
{
  my ($hash) = @_;
  LoadModule("FRM");
}

sub
FRM_RC_Init($$$$$$)
{
  my ($hash, $pinmode, $observer, $r, $m, $args) = @_;
  my %rcswitchAttributes = %$r;
  my %moduleAttributes = %$m;
  my $ret = FRM_Init_Pin_Client($hash, $args, $pinmode);
  return $ret if (defined $ret);
  my $pin = $hash->{PIN};
  eval {
    FRM_RC_register_observer($pin, $observer, $hash);
    my $name = $hash->{NAME};
    foreach my $attribute (keys %moduleAttributes) {
      FRM_RCOUT_Attr("set", $name, $attribute, $moduleAttributes{$attribute});
    }
    my @a = (keys %rcswitchAttributes, keys %rcAttributes);
    foreach my $attribute (@a) { # send attribute values to the board
      if ($main::attr{$name}{$attribute}) {
        Log3($hash, 4, "$attribute := $main::attr{$name}{$attribute}");
        FRM_RC_apply_attribute($hash, $attribute, %rcswitchAttributes);
      } else {
        Log3($hash, 4, "$attribute is undefined");
      }
    }
  };
  return FRM_Catch($@) if $@;
  readingsSingleUpdate($hash, "state", "Initialized", 1);
  return undef;
}

sub
FRM_RC_Attr($$$$$) {
  my ($command, $name, $attribute, $value, $r) = @_;
  my %rcswitchAttributes = %$r;
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
        defined($rcswitchAttributes{$attribute}) and do {
          $main::attr{$name}{$attribute} = $value; # store value, but don't send it to the the board until everything is up
          if ($main::init_done) {
            FRM_RC_apply_attribute($hash, $attribute, %rcswitchAttributes);
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

sub FRM_RC_register_observer {
  my ( $pin, $observer, $context ) = @_;
  $rc_observer[$pin] =  {
      method  => $observer,
      context => $context,
  };
  my $firmata = FRM_Client_FirmataDevice($context);
  my $currentObserver = $firmata->{sysex_observer};
  if (defined $currentObserver and $currentObserver->{method} eq \&FRM_RC_sysex_observer) {
      main::Log3($context, 3, "Reusing existing sysex observer");
  } else {
    if (defined $currentObserver) {
      main::Log3($context, 2, "Overwriting existing observer");
    } else {
      main::Log3($context, 3, "Registering new sysex observer");
    }
    $firmata->observe_sysex(\&FRM_RC_observe_sysex, undef);
  }

  return 1;
}

# The attribute is not applied within this module; instead, it is sent to the
# microcontroller. When the change was successful, a response message will
# arrive in the observer sub.
sub FRM_RC_apply_attribute {
  my ($hash, $attribute, %moduleAttributes) = @_;
  my $name = $hash->{NAME};
  
  my %attributes = (%rcAttributes, %moduleAttributes);

  return "Unknown attribute $attribute, choose one of " . join(" ", sort keys %attributes)
    if(!defined($attributes{$attribute}));

  if (defined($rcAttributes{$attribute})) {
    my $pin = $main::attr{$hash->{NAME}}{$attribute};
    Log3($hash, 5, "$hash->{NAME}: $attribute := $pin");
    my $pinValue = $attributes{$attribute};
    my $device = FRM_Client_FirmataDevice($hash);
    $device->pin_mode($pin, PIN_OUTPUT);
    $device->digital_write($pin, $pinValue);
  } else {
    FRM_RC_set_parameter(FRM_Client_FirmataDevice($hash),
                         $moduleAttributes{$attribute},
                         $hash->{PIN},
                         $main::attr{$name}{$attribute});
  }
}

sub FRM_RC_set_parameter {
  my ( $firmata, $subcommand, $pin, $value ) = @_;

  my @data = ($value & 0xFF, ($value>>8) & 0xFF);

  return FRM_RC_send_message($firmata, $subcommand, $pin, @data);
}


sub FRM_RC_observe_sysex {
  my ( $sysex_message, undef ) = @_;
  
  my $command            = $sysex_message->{command};
  my $sysex_message_data = $sysex_message->{data};
  my $subcommand         = shift @$sysex_message_data;
  my $pin                = shift @$sysex_message_data;
  my @data               = Device::Firmata::Protocol::unpack_from_7bit(@$sysex_message_data);
  my $observer           = $rc_observer[$pin];

  if (defined $observer) {
    $observer->{method}( $observer->{context}, $subcommand, @data );
  }
}

sub FRM_RC_get_tristate_code {
  return join("", map { my $v = $RC_TRISTATE_CHARS->{$_};
                        defined $v ? $v : "X";
                      }
                  @_);
}	

sub FRM_RC_get_tristate_bits {
  my ($v) = @_;
  return map {$RC_TRISTATE_BITS{$_}} split("", uc($v));
}

sub FRM_RC_align {
  my @transferSymbols = @_;
  while ((@transferSymbols & 0x03) != 0) {
    push @transferSymbols, $RC_TRISTATE_BIT_VALUES->{TRISTATE_RESERVED};
  }
  return @transferSymbols;
}

sub FRM_RC_send_message {
  my ($firmata, $subcommand, $pin, @data) = @_;
  my $protocol = $firmata->{protocol};
  my $protocol_version  = $protocol->{protocol_version};
  my $protocol_commands = $COMMANDS->{$protocol_version};

  my $message = $protocol->packet_sysex($protocol_commands->{RESERVED_COMMAND},
                                        $subcommand,
                                        $pin,
                                        Device::Firmata::Protocol::pack_as_7bit(@data) );
  return $firmata->{io}->data_write($message);
}

1;
