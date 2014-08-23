#############################################
package main;

use strict;
use warnings;

#####################################

use constant {
  PINMODE_RCINPUT  => 11,

  RCINPUT_TOLERANCE             => 0x31,
  RCINPUT_RAW_DATA              => 0x32,
  RCINPUT_MESSAGE               => 0x41,
};

my %rcswitchAttributes = (
  "tolerance"        => RCINPUT_TOLERANCE,
  "rawDataEnabled"   => RCINPUT_RAW_DATA,
);

my %moduleAttributes = (
);

sub
FRM_RCIN_Initialize($)
{
  my ($hash) = @_;

  $hash->{DefFn}     = "FRM_Client_Define";
  $hash->{UndefFn}   = "FRM_Client_Undef";
  $hash->{InitFn}    = "FRM_RCIN_Init";
  $hash->{AttrFn}    = "FRM_RCIN_Attr";
  
  LoadModule("FRM_RC");

  $hash->{AttrList}  = "IODev"
                       . " " . join(" ", keys %rcswitchAttributes)
                       . " " . join(" ", keys %main::rcAttributes)
                       . " " . $main::readingFnAttributes;
}

sub
FRM_RCIN_Init($$)
{
  my ($hash, $args) = @_;
  FRM_RC_Init($hash, PINMODE_RCINPUT, \&FRM_RCIN_handle_rc_response, \%rcswitchAttributes, \%moduleAttributes, $args);
}

sub
FRM_RCIN_Attr($$$$) {
  my ($command, $name, $attribute, $value) = @_;
  return FRM_RC_Attr($command, $name, $attribute, $value, \%rcswitchAttributes);
}

sub FRM_RCIN_handle_rc_response {
  my ( $hash, $command, @data ) = @_;

  if ($command eq RCINPUT_MESSAGE) {
    my $value   = ((shift @data) << 24) + ((shift @data) << 16)
                  + ((shift @data) <<  8) + (shift @data);
    my $bitCount  = ((shift @data) <<  8) + (shift @data);
    my $delay     = ((shift @data) <<  8) + (shift @data);
    my $protocol  = ((shift @data) <<  8) + (shift @data);
    my $tristateCode = FRM_RCIN_long_to_tristate_code($value, $bitCount);
    my @rawData = ();
    while (@data > 1) {
      push @rawData, (shift @data) + ((shift @data) << 8);
    }
    @data = ($value, $bitCount, $delay, $protocol, $tristateCode, \@rawData);

  } else { # parameter as int
      push @data, (shift @data) + ((shift @data) << 8);
  }

  FRM_RCIN_observer($command, \@data, $hash);
}

sub FRM_RCIN_observer
{
  my ( $key, $value, $hash ) = @_;
  my $name = $hash->{NAME};
  
  my %a = reverse(%rcswitchAttributes);
  my $attrName = $a{$key};
  
COMMAND_HANDLER: {
    ($key eq RCINPUT_MESSAGE) and do {

      my ($longCode, $bitCount, $delay, $protocol, $tristateCode, $rawData) = @$value;
      my $rawInt = join(" ", @$rawData);
      my $rawHex = join(" ", map { sprintf "%04X", $_ } @$rawData);

      Log3($hash, 4, "message: " . join(", ", @$value));
      my $verboseLevel = $main::attr{$name}{"verbose"};
      if (defined $verboseLevel and $verboseLevel > 3) {
        my $s = $rawHex;
        my $rawBlock = "";
        while ($s) {
          $rawBlock .= substr($s, 0, 40, '')."\n";
        }
        Log3($hash, 4, "raw data:\n" . $rawBlock);
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
      Log3($name, 4, "$attrName: $value");

      $main::attr{$name}{$attrName}=$value;
      # TODO refresh web GUI somehow?
      last;
    };
};
}

sub FRM_RCIN_long_to_tristate_code {
  my ($value, $bitCount) = @_;
  my @tristateBits;
  for (my $shift = $bitCount-2; $shift >= 0; $shift-=2) {
    push @tristateBits, ($value >> $shift) & 3;
  }
  my $tristateCode = FRM_RC_get_tristate_code(@tristateBits);
  return $tristateCode;
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
