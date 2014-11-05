package main;

use strict;
use warnings;

our ($readingFnAttributes, %attr);

use constant {
  PINMODE_RCINPUT   => 11,

  RCINPUT_TOLERANCE => 0x31,
  RCINPUT_RAW_DATA  => 0x32,
  RCINPUT_MESSAGE   => 0x41,
};

use constant RCIN_PARAMETERS => {
  tolerance => RCINPUT_TOLERANCE,
  rawData   => RCINPUT_RAW_DATA,
};
use constant RCIN_PARAMETER_NAMES => { reverse(%{RCIN_PARAMETERS()}) };

use constant CLIENTS              => qw( IT );

my %matchListRCIN = (
	"1:IT" => "^i......\$",
);

sub
FRM_RCIN_Initialize($)
{
  my ($hash) = @_;

  $hash->{DefFn}     = 'FRM_RC_Define';
  $hash->{UndefFn}   = 'FRM_RC_Undefine';
  $hash->{InitFn}    = 'FRM_RCIN_Init';
  $hash->{NotifyFn}  = 'FRM_RCIN_Notify';
  $hash->{AttrFn}    = 'FRM_RCIN_Attr';
  
  LoadModule('FRM_RC');

  $hash->{AttrList} = join(' ', FRM_RCIN_get_attributes(),
                                keys %{RC_ATTRIBUTES()},
                                $readingFnAttributes);
  $hash->{Clients}  = join (':', CLIENTS);
  $hash->{MatchList} = \%matchListRCIN;
}

sub
FRM_RCIN_Init($$)
{
  my ($hash, $args) = @_;
  return FRM_RC_Init($hash, PINMODE_RCINPUT, \&FRM_RCIN_handle_rc_response, $args);
}

sub FRM_RCIN_Notify {
  my ($hash, $dev) = @_;
  return FRM_RC_Notify($hash, $dev, RCIN_PARAMETERS);
}

sub
FRM_RCIN_Attr($$$$) {
  my ($command, $name, $attribute, $value) = @_;
  return FRM_RC_Attr($command, $name, $attribute,
                     FRM_RCIN_get_internal_value($attribute, $value),
                     RCIN_PARAMETERS);
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

  FRM_RCIN_notify($hash, $command, \@data);
}

sub FRM_RCIN_notify
{
  my ($hash, $key, $value) = @_;
  my $name = $hash->{NAME};
  my $attrName = RCIN_PARAMETER_NAMES->{$key};
  
  COMMAND_HANDLER: {
    ($key eq RCINPUT_MESSAGE) and do {

      my ($longCode, $bitCount, $delay, $protocol, $tristateCode, $rawData) = @$value;
      my $rawInt = join(' ', @$rawData);
      my $rawHex = join(' ', map { sprintf "%04X", $_ } @$rawData);

      Log3($hash, 4, 'message: ' . join(', ', @$value));
      my $verboseLevel = $attr{$name}{'verbose'};
      if (defined $verboseLevel and $verboseLevel > 3 and defined $rawHex and $rawHex) {
        my $s = $rawHex;
        my $rawBlock = '';
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
      if (FRM_RCIN_is_rawdata_enabled($name)) {
        readingsBulkUpdate($hash, 'rawData', $rawHex);
      }
      readingsEndUpdate($hash, 1);
 	  my $icode = sprintf('i%06x', $longCode);
	  Dispatch($hash, $icode, undef);
      last;
    };
    defined($attrName) and do {
      $value = FRM_RCIN_get_user_value($attrName, shift @$value);
      Log3($hash, 4, "$attrName: $value");
    
      $attr{$name}{$attrName}=$value;
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

sub FRM_RCIN_get_attributes {
  return map({$_ eq 'rawData' ? $_ . ':enabled,disabled': $_}
             keys %{RCIN_PARAMETERS()});
}

sub FRM_RCIN_get_internal_value($$) {
  my ($attribute, $value) = @_;
  if ($attribute eq 'rawData') {
    $value = $value eq 'enabled' ? 1 : 0;
  }
  return $value;
}

sub FRM_RCIN_get_user_value($$) {
  my ($attribute, $value) = @_;
  if ($attribute eq 'rawData') {
    $value = $value ? 'enabled' : 'disabled'; 
  }
  return $value;
}

sub FRM_RCIN_is_rawdata_enabled($) {
  my $name = shift;
  my $rawData = $attr{$name}{'rawData'};
  return defined $rawData && $rawData eq 'enabled';	
}

1;

=pod

=begin html

<a name="FRM_RCIN"></a>
<h3>FRM_RCIN</h3>
  <p>
   Represents a pin of an <a href="http://www.arduino.cc">Arduino</a> running
   <a href="http://www.firmata.org">Firmata</a> configured to receive data via
   the <a href="https://code.google.com/p/rc-switch/">RCSwitch</a> library.<br />
   Requires a defined <a href="#FRM">FRM</a>-device to work.<br><br> 
  </p>
  <a name="FRM_RCINdefine"></a>
  <h4>Define</h4>
   <p><pre>    define &lt;name&gt; FRM_RCIN &lt;pin&gt;</pre> <br/>
    Defines the FRM_RCIN device. <code>&lt;pin&gt</code> is the arduino-pin to use.
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
    <li>
     <a href="#IODev">IODev</a>: specify which <a href="#FRM">FRM</a> device
     to use.
    </li>
    <li>
      <code>tolerance</code>: RCSwitch parameter <code>receiveTolerance</code> in percent
      (default: 60; see RCSwitch documentation for details)
    </li>
    <li>
      <code>rawData</code>: If set to <code>enabled</code>, an additional reading
      <code>rawData</code> will be created, containing the received data in raw
      format (default: <code>disabled</code>)
    </li>
    <li><a href="#FRM_RCattr">FRM_RC attributes</a></li>
    <li><a href="#eventMap">eventMap</a></li>
    <li><a href="#readingFnAttributes">readingFnAttributes</a></li>
    </ul>
<br>

=end html
=cut
