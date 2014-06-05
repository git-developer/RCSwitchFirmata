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

my %sets = (
  "tristateCode"     => $Device::Firmata::Protocol::RCOUTPUT_COMMANDS->{RCOUTPUT_CODE_PACKED_TRISTATE},
  "longCode"         => $Device::Firmata::Protocol::RCOUTPUT_COMMANDS->{RCOUTPUT_CODE_LONG},
  "charCode"         => $Device::Firmata::Protocol::RCOUTPUT_COMMANDS->{RCOUTPUT_CODE_CHAR},
);

my %attributes = (
  "protocol"         => $Device::Firmata::Protocol::RCOUTPUT_COMMANDS->{RCOUTPUT_PROTOCOL},
  "pulseLength"      => $Device::Firmata::Protocol::RCOUTPUT_COMMANDS->{RCOUTPUT_PULSE_LENGTH},
  "repeatTransmit"   => $Device::Firmata::Protocol::RCOUTPUT_COMMANDS->{RCOUTPUT_REPEAT_TRANSMIT},
  "defaultBitCount"  => 24,
);

my %tristateBits = (
  "0" => $Device::Firmata::Protocol::RC_TRISTATE_BITS->{TRISTATE_0},
  "F" => $Device::Firmata::Protocol::RC_TRISTATE_BITS->{TRISTATE_F},
  "1" => $Device::Firmata::Protocol::RC_TRISTATE_BITS->{TRISTATE_1},
);

sub
FRM_RCOUT_Initialize($)
{
  my ($hash) = @_;

  $hash->{GetFn}     = "FRM_RCOUT_Get";
  $hash->{SetFn}     = "FRM_RCOUT_Set";
  $hash->{DefFn}     = "FRM_Client_Define";
  $hash->{InitFn}    = "FRM_RCOUT_Init";
  $hash->{UndefFn}   = "FRM_Client_Undef";
  $hash->{AttrFn}    = "FRM_RCOUT_Attr";
  
  $hash->{AttrList}  = "IODev " . join(" ", keys %attributes) . " $main::readingFnAttributes";
  main::LoadModule("FRM_RC");
}

sub
FRM_RCOUT_Init($$)
{
  my ($hash, $args) = @_;
  FRM_RC_Init($hash, PIN_RCOUTPUT, \&FRM_RCOUT_observer, @attributes, %rcswitchParameters, %moduleParameters, $args);
  FRM_RCOUT_Attr("set", $hash->{NAME}, "defaultBitCount", $moduleParameters{"defaultBitCount"});
}

sub
FRM_RCOUT_Init_2($$)
{
  my ($hash, $args) = @_;
  my $ret = FRM_Init_Pin_Client($hash, $args, PIN_RCOUTPUT);
  return $ret if (defined $ret);
  my $pin = $hash->{PIN};
  eval {
    my $firmata = FRM_Client_FirmataDevice($hash);
    $firmata->observe_rc($pin, \&FRM_RCOUT_observer, $hash);
    my $name = $hash->{NAME};
    FRM_RCOUT_Attr("set", $name, "defaultBitCount", $attributes{"defaultBitCount"});
    foreach my $attribute (keys %attributes) { # send attribute values to the board
      if ($main::attr{$name}{$attribute}) {
        FRM_RCIN_apply_attribute($hash, $attribute);
      }
    }
  };
  return FRM_Catch($@) if $@;
  readingsSingleUpdate($hash, "state", "Initialized", 1);
  return undef;
}

sub
FRM_RCOUT_Attr($$$$) {
  my ($command, $name, $attribute, $value) = @_;
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
        
        defined($attributes{$attribute}) and do {
          $main::attr{$name}{$attribute} = $value;
          if ($main::init_done) {
            FRM_RCOUT_apply_attribute($hash,$attribute);
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

# The attribute is not applied within this module; instead, it is sent to the
# microcontroller. When the change was successful, a response message will
# arrive in the observer sub.
sub FRM_RCOUT_apply_attribute {
  my ($hash,$attribute) = @_;
  my $name = $hash->{NAME};

  return "Unknown attribute $attribute, choose one of " . join(" ", sort keys %attributes)
  	if(!defined($attributes{$attribute}));

  if ($attribute ne "defaultBitCount") {
    FRM_Client_FirmataDevice($hash)->rc_set_parameter($attributes{$attribute},
                                                      $hash->{PIN},
                                                      $main::attr{$name}{$attribute});
  }
}

sub FRM_RCOUT_observer
{
  my ( $key, $data, $hash ) = @_;
  my $name = $hash->{NAME};
  
  my %s = reverse(%sets);
  my %a = reverse(%attributes);
  my $subcommand = $s{$key};
  my $attrName = $a{$key};
  
COMMAND_HANDLER: {
    defined($subcommand) and do {
      if ("tristateCode" eq $subcommand) {
        my $tristateCode = shift @$data;
        Log3 $name, 4, "$subcommand: $tristateCode";
        readingsSingleUpdate($hash, $subcommand, $tristateCode, 1);
      } elsif ("longCode" eq $subcommand) {
        my $bitCount = shift @$data;
        my $longCode  = shift @$data;
        Log3 $name, 4, "$subcommand: $longCode/$bitCount";
        readingsBeginUpdate($hash);
        readingsBulkUpdate($hash, $subcommand, $longCode);
        readingsBulkUpdate($hash, "bitCount", $bitCount);
        readingsEndUpdate($hash, 1);
      } elsif ("charCode" eq $subcommand || "tristateString" eq $subcommand) {
        my $charCode = shift @$data; 
        Log3 $name, 4, "$subcommand: $charCode";
        readingsSingleUpdate($hash, $subcommand, $charCode, 1);
      } else {
        readingsSingleUpdate($hash, "state", "unknown subcommand $subcommand", 1);
      }
      last;
    };
    defined($attrName) and do {
      my $value = shift @$data;
      Log3 $name, 4, "$attrName: $value";

      $main::attr{$name}{$attrName}=$value;
      # TODO refresh web GUI somehow?
      last;
    };
};
}

sub
FRM_RCOUT_Set($@)
{
  my ($hash, @a) = @_;
  return "Need at least 2 parameters" if(@a < 2);
  my $command = $sets{$a[1]};
  return "Unknown argument $a[1], choose one of " . join(" ", sort keys %sets)
  	if(!defined($command));
  my @code;
  eval {
    if ($command eq $Device::Firmata::Protocol::RCOUTPUT_COMMANDS->{RCOUTPUT_CODE_PACKED_TRISTATE}) {
      @code = map {$tristateBits{$_}} split("", uc($a[2])); 
    } elsif ($command eq $Device::Firmata::Protocol::RCOUTPUT_COMMANDS->{RCOUTPUT_CODE_LONG}) {
      my $value = $a[2];
      my $bitCount = $a[3];
      $bitCount = $attr{$hash->{NAME}}{"defaultBitCount"} if not defined $bitCount;
      $bitCount = $attributes{"defaultBitCount"} if not defined $bitCount; # if defaultBitCount was deleted
      @code = ($bitCount, $value);
    } elsif ($command eq $Device::Firmata::Protocol::RCOUTPUT_COMMANDS->{RCOUTPUT_CODE_CHAR}) {
        @code = map {ord($_)} split("", $a[2]);
    }
    FRM_Client_FirmataDevice($hash)->rcoutput_send_code($command, $hash->{PIN}, @code);
  };
  return $@;
}

# FRM_RCOUT_Get behaves as CUL_Get so that 10_IT can use FRM_RCOUT as IODev
sub
FRM_RCOUT_Get($@)
{
  my ($self, $space, $get, $codeCommand) = @_;
  my ($code) = $codeCommand =~ /is([01fF]+)/;
  my $set = FRM_RCOUT_Set($self, $self->{NAME}, "tristateCode", $code);
  return "raw => $codeCommand";
}

1;

=pod
=begin html

<a name="FRM_RCOUT"></a>
<h3>FRM_RCOUT</h3>
  <p>
    Represents a pin of an <a href="http://www.arduino.cc">Arduino</a> running
    <a href="http://www.firmata.org">Firmata</a> configured to send data via the
    RCSwitch library.<br/>
    Requires a defined <a href="#FRM">FRM</a>-device to work.
  </p>
  <a name="FRM_RCOUTdefine" />
  <h4>Define</h4>
  <p>
    <code>define &lt;name&gt; FRM_RCOUT &lt;pin&gt;</code><br/>
    Defines the FRM_RCOUT device. &lt;pin&gt; is the arduino-pin to use.
  </p>
  <a name="FRM_RCOUTset" />
  <h4>Set</h4>
  <ul>
   <li>
     <code>set &lt;name&gt; tristateCode &lt;code&gt;</code><br/>
     Sends a tristate code, e.g. <code>00F0FF0FFF0F<code>
   </li>
   <li>
     <code>set &lt;name&gt; longCode &lt;code&gt; &lt;bitCount&gt;</code><br/>
     Sends a code as long decimal, e.g. <code>282961 24<code>.
     The first argument gives a bit pattern as long (32 bits),
     the second argument gives the number of bits that will actually be sent.
     For example, <code>5 8</code> will be sent as <code>0000 0101</code>
     whereas <code>5 4</code> will be sent as <code>0101</code>.<br/>
     The second argument may be omitted, in this case the attribute
     <code>defaultBitCount</code> is used. If this is not set, the default value
     of 24 is used.
   </li>
   <li>
     <code>set &lt;name&gt; charCode &lt;code&gt;</code><br/>
     sends a character code, e.g. <code>001011011101<code>
   </li>
  </ul>
  <a name="FRM_RCOUTget" />
  <h4>Get</h4>
    N/A
  <br/>
  <a name="FRM_RCOUTattr" />
  <h4>Attributes</h4>
  <ul>
    <li>
      <a href="#IODev">IODev</a><br/>
      Specify which <a href="#FRM">FRM</a> to use.
    </li>
    <li>
      <code>protocol</code>: RCSwitch parameter <code>protocol</code>
      (default: 1; see RCSwitch for details)
    </li>
    <li>
      <code>pulseLength: RCSwitch parameter <code>pulseLength</code>
      (default: 350; see RCSwitch for details)</code>
    </li>
    <li>
      <code>repeatTransmit: RCSwitch parameter <code>repeatTransmit</code>
      (default: 10; see RCSwitch for details)</code>
    </li>
    <li>
      <code>defaultBitCount: Default for the <code>bitCount</code> parameter
      of the <code>longCode</code> command (default: 24) 
    </li>
    <li><a href="#eventMap">eventMap</a><br></li>
    <li><a href="#readingFnAttributes">readingFnAttributes</a><br></li>
  </ul>

=end html
=cut
