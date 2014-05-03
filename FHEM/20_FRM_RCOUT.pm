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
  "code"             => $Device::Firmata::Protocol::RCOUTPUT_COMMANDS->{RCOUTPUT_SEND_TRISTATE_CODE},
);

my %attributes = (
  "protocol"         => $Device::Firmata::Protocol::RCOUTPUT_COMMANDS->{RCOUTPUT_SET_PROTOCOL},
  "pulseLength"      => $Device::Firmata::Protocol::RCOUTPUT_COMMANDS->{RCOUTPUT_SET_PULSE_LENGTH},
  "repeatTransmit"   => $Device::Firmata::Protocol::RCOUTPUT_COMMANDS->{RCOUTPUT_SET_REPEAT_TRANSMIT},
);

my %tristateBits = (
  "0" => $Device::Firmata::Protocol::RCOUTPUT_TRISTATE_BITS->{TRISTATE_0},
  "F" => $Device::Firmata::Protocol::RCOUTPUT_TRISTATE_BITS->{TRISTATE_F},
  "1" => $Device::Firmata::Protocol::RCOUTPUT_TRISTATE_BITS->{TRISTATE_1},
);

sub
FRM_RCOUT_Initialize($)
{
  my ($hash) = @_;

  $hash->{SetFn}     = "FRM_RCOUT_Set";
  $hash->{DefFn}     = "FRM_Client_Define";
  $hash->{InitFn}    = "FRM_RCOUT_Init";
  $hash->{UndefFn}   = "FRM_Client_Undef";
  $hash->{AttrFn}    = "FRM_RCOUT_Attr";
  
  $hash->{AttrList}  = "IODev " . join(" ", %attributes) . " $main::readingFnAttributes";
  main::LoadModule("FRM");
}

sub
FRM_RCOUT_Init($$)
{
  my ($hash,$args) = @_;
  my $ret = FRM_Init_Pin_Client($hash,$args,PIN_RCOUTPUT);
  return $ret if (defined $ret);
  my $pin = $hash->{PIN};
  eval {
    my $firmata = FRM_Client_FirmataDevice($hash);
    $firmata->observe_rc($pin,\&FRM_RCOUT_observer,$hash);
  };
  return FRM_Catch($@) if $@;
  main::readingsSingleUpdate($hash,"state","Initialized",1);
  return undef;
}

sub
FRM_RCOUT_Attr($$$$) {
  my ($command,$name,$attribute,$value) = @_;
  my $hash = $main::defs{$name};
  eval {
    if ($command eq "set") {
      ARGUMENT_HANDLER: {
        $attribute eq "IODev" and do {
          if ($main::init_done and (!defined ($hash->{IODev}) or $hash->{IODev}->{NAME} ne $value)) {
            FRM_Client_AssignIOPort($hash,$value);
            FRM_Init_Client($hash) if (defined ($hash->{IODev}));
          }
          last;
        };
        
        defined($attributes{$attribute}) and do {
          if ($main::init_done) {
          	$main::attr{$name}{$attribute}=$value;
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

sub FRM_RCOUT_apply_attribute {
  my ($hash,$attribute) = @_;
  my $name = $hash->{NAME};

  return "Unknown attribute $attribute, choose one of " . join(" ", sort keys %attributes)
  	if(!defined($attributes{$attribute}));

  FRM_Client_FirmataDevice($hash)->rcoutput_set_parameter($hash->{PIN}, $attributes{$attribute}, $main::attr{$name}{$attribute});
}

sub FRM_RCOUT_observer
{
  my ( $key, $value, $hash ) = @_;
  my $name = $hash->{NAME};
  
  my %s = reverse(%sets);
  my %a = reverse(%attributes);
  
COMMAND_HANDLER: {
    defined($s{$key}) and do {
      my %tristateChars = reverse(%tristateBits);
      my $tristateCode = join("", map { my $v = $tristateChars{$_}; defined $v ? $v : "X";} @$value); 
      Log3 $name, 4, "$s{$key}: $tristateCode";
      main::readingsSingleUpdate($hash, $s{$key}, $tristateCode, 1);
      last;
    };
    defined($a{$key}) and do {
      $value = @$value[0] + (@$value[1] << 8);
      Log3 $name, 4, "$a{$key}: $value";

      $main::attr{$name}{$a{$key}}=$value;
      last;
    };
};
}

sub
FRM_RCOUT_Set($@)
{
  my ($hash, @a) = @_;
  return "Need at least 2 parameters" if(@a < 2);
  return "Unknown argument $a[1], choose one of " . join(" ", sort keys %sets)
  	if(!defined($sets{$a[1]}));
  my $command = $a[1];
  my $value = uc($a[2]);
  
  my @v = map {$tristateBits{$_}} split("", $value); 

  eval {
    if ($command eq "code") {
      FRM_Client_FirmataDevice($hash)->rcoutput_send_code($hash->{PIN}, @v);
    }
  };
  return $@;
}

1;

=pod
=begin html

<a name="FRM_RCOUT"></a>
<h3>FRM_RCOUT</h3>
<ul>
  represents a pin of an <a href="http://www.arduino.cc">Arduino</a> running <a href="http://www.firmata.org">Firmata</a>
  configured to send data via the RCSwitch library.<br>
  Requires a defined <a href="#FRM">FRM</a>-device to work.<br><br> 
  
  <a name="FRM_RCOUTdefine"></a>
  <b>Define</b>
  <ul>
  <code>define &lt;name&gt; FRM_RCOUT &lt;pin&gt;</code> <br>
  Defines the FRM_RCOUT device. &lt;pin&gt> is the arduino-pin to use.
  </ul>
  
  <br>
  <a name="FRM_RCOUTset"></a>
  <b>Set</b><br>
  <ul>
  <code>set &lt;name&gt; code &lt;code&gt;</code><br>sends a tristate coded message, e.g. <code>00FFF FF0FF F0<code> <br/> 
  </ul>
  <a name="FRM_RCOUTget"></a>
  <b>Get</b><br>
  <ul>
  N/A
  </ul><br>
  <a name="FRM_RCOUTattr"></a>
  <b>Attributes</b><br>
  <ul>
      <li><a href="#IODev">IODev</a><br>
      Specify which <a href="#FRM">FRM</a> to use. (Optional, only required if there is more
      than one FRM-device defined.)
      </li>
      <li><a href="#eventMap">eventMap</a><br></li>
      <li><a href="#readingFnAttributes">readingFnAttributes</a><br></li>
    </ul>
  </ul>
<br>

=end html
=cut
