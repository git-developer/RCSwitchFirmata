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

my %attributes = (
  "tolerance"        => $Device::Firmata::Protocol::RCINPUT_COMMANDS->{RCINPUT_TOLERANCE},
  "rawDataEnabled"   => $Device::Firmata::Protocol::RCINPUT_COMMANDS->{RCINPUT_RAW_DATA},
);

sub
FRM_RCIN_Initialize($)
{
  my ($hash) = @_;

  $hash->{DefFn}     = "FRM_Client_Define";
  $hash->{InitFn}    = "FRM_RCIN_Init";
  $hash->{UndefFn}   = "FRM_Client_Undef";
  $hash->{AttrFn}    = "FRM_RCIN_Attr";
  
  $hash->{AttrList}  = "IODev " . join(" ", keys %attributes) . " " . $readingFnAttributes;
  LoadModule("FRM");
}

sub
FRM_RCIN_Init($$)
{
  my ($hash, $args) = @_;
  my $ret = FRM_Init_Pin_Client($hash, $args, PIN_RCINPUT);
  return $ret if (defined $ret);
  my $pin = $hash->{PIN};
  eval {
    my $firmata = FRM_Client_FirmataDevice($hash);
    $firmata->observe_rc($pin, \&FRM_RCIN_observer, $hash);
    foreach my $a (keys %attributes) { # send attribute values to the board
      FRM_RCIN_apply_attribute($hash, $a) if $attr{$hash->{NAME}}{$a}
    }
  };
  return FRM_Catch($@) if $@;
  readingsSingleUpdate($hash, "state", "Initialized", 1);
  return undef;
}

sub
FRM_RCIN_Attr($$$$) {
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
          $main::attr{$name}{$attribute}=$value; # store value, but don't send it to the the board until everything is up
          if ($main::init_done) {
            FRM_RCIN_apply_attribute($hash,$attribute);
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
sub FRM_RCIN_apply_attribute { # TODO this one is identical to FRM_RCOUT_apply_attribute, merge
  my ($hash,$attribute) = @_;
  my $name = $hash->{NAME};

  return "Unknown attribute $attribute, choose one of " . join(" ", sort keys %attributes)
  	if(!defined($attributes{$attribute}));

  FRM_Client_FirmataDevice($hash)->rc_set_parameter($attributes{$attribute},
                                                    $hash->{PIN},
                                                    $main::attr{$name}{$attribute});
}

sub FRM_RCIN_observer
{
  my ( $key, $value, $hash ) = @_;
  my $name = $hash->{NAME};
  
  my %a = reverse(%attributes);
  my $attrName = $a{$key};
  
COMMAND_HANDLER: {
    ($key eq $Device::Firmata::Protocol::RCINPUT_COMMANDS->{RCINPUT_MESSAGE}) and do {

      my ($longCode, $bitCount, $delay, $protocol, $tristateCode, $rawData) = @$value;
      my $rawInt = join(" ", @$rawData);
      my $rawHex = join(" ", map { sprintf "%04X", $_ } @$rawData);

      Log3 $hash, 4, "message: " . join(", ", @$value);
      if ($main::attr{$name}{"verbose"} > 3) {
        my $s = $rawHex;
        my $rawBlock = "";
        while ($s) {
          $rawBlock .= substr($s, 0, 40, '')."\n";
        }
        Log3 $hash, 4, "raw data:\n" . $rawBlock;
      }
      
      readingsBeginUpdate($hash);
      readingsBulkUpdate($hash, 'value', $longCode);
      readingsBulkUpdate($hash, 'tristateCode', $tristateCode);
      readingsBulkUpdate($hash, 'bitCount', $bitCount);
      readingsBulkUpdate($hash, 'delay', $delay);
      readingsBulkUpdate($hash, 'protocol', $protocol);
      if (defined $main::attr{$name}{'rawDataEnabled'} and $main::attr{$name}{'rawDataEnabled'} ne 0) {
        readingsBulkUpdate($hash, 'rawData', $rawHex);
      }
      readingsEndUpdate($hash, 1);
      last;
    };
    defined($attrName) and do {
      $value = shift @$value;
      Log3 $name, 4, "$attrName: $value";

      $main::attr{$name}{$attrName}=$value;
      # TODO refresh web GUI somehow?
      last;
    };
};
}

1;

=pod
=begin html

<a name="FRM_RCIN"></a>
<h3>FRM_RCIN</h3>
  <p>
   Represents a pin of an <a href="http://www.arduino.cc">Arduino</a> running
   <a href="http://www.firmata.org">Firmata</a> configured to receive data via
   the RCSwitch library.<br />
   Requires a defined <a href="#FRM">FRM</a>-device to work.<br><br> 
  </p>
  <a name="FRM_RCINdefine"></a>
  <h4>Define</h4>
   <p>
    <code>define &lt;name&gt; FRM_RCIN &lt;pin&gt;</code> <br/>
    Defines the FRM_RCIN device. &lt;pin&gt> is the arduino-pin to use.
   </p>
  <a name="FRM_RCINset"></a>
  <h4>Set</h4>
  <p>
   N/A
  </p>
  <a name="FRM_RCINget"></a>
  <h4>Get</h4>
  <p>
   N/A
  </p>
  <a name="FRM_RCINattr"></a>
  <h4>Attributes</h4>
  <ul>
    <li><a href="#IODev">IODev</a><br/>
      Specify which <a href="#FRM">FRM</a> to use.
    </li>
    <li>
      <code>tolerance</code>: RCSwitch parameter <code>receiveTolerance</code> in percent
      (default: 60; see RCSwitch for details)
    </li>
    <li>
      <code>rawDataEnabled</code>: If set to 1, an additional reading
      <code>rawData</code> will be created, containing the received data in raw
      format (default: 0 which means that reporting of raw data is disabled)
    </li>
    <li><a href="#eventMap">eventMap</a><br></li>
    <li><a href="#readingFnAttributes">readingFnAttributes</a><br></li>
    </ul>
<br>

=end html
=cut
