#############################################
package main;

use strict;
use warnings;

#####################################

use constant {
  PINMODE_RCOUTPUT              => 10,
  
  RCOUTPUT_PROTOCOL             => 0x11,
  RCOUTPUT_PULSE_LENGTH         => 0x12,
  RCOUTPUT_REPEAT_TRANSMIT      => 0x14,
  
  RCOUTPUT_CODE_TRISTATE        => 0x21,
  RCOUTPUT_CODE_LONG            => 0x22,
  RCOUTPUT_CODE_CHAR            => 0x24,
  RCOUTPUT_CODE_PACKED_TRISTATE => 0x28,
};


my %gets = (
  "raw" => 1,
);

my %sets = (
  "tristateCode"     => RCOUTPUT_CODE_PACKED_TRISTATE,
  "longCode"         => RCOUTPUT_CODE_LONG,
  "charCode"         => RCOUTPUT_CODE_CHAR,
);

my %rcswitchAttributes = (
  "protocol"         => RCOUTPUT_PROTOCOL,
  "pulseLength"      => RCOUTPUT_PULSE_LENGTH,
  "repeatTransmit"   => RCOUTPUT_REPEAT_TRANSMIT,
);

my %moduleAttributes = (
  defaultBitCount  => 24,
);

my @clients = qw( IT );

sub
FRM_RCOUT_Initialize($)
{
  my ($hash) = @_;

  $hash->{DefFn}     = "FRM_Client_Define";
  $hash->{UndefFn}   = "FRM_Client_Undef";
  $hash->{InitFn}    = "FRM_RCOUT_Init";
  $hash->{AttrFn}    = "FRM_RCOUT_Attr";
  $hash->{GetFn}     = "FRM_RCOUT_Get";
  $hash->{SetFn}     = "FRM_RCOUT_Set";
 
  LoadModule("FRM_RC");
  
  $hash->{AttrList}  = "IODev"
                         . " " . join(" ", keys %rcswitchAttributes)
                         . " " . join(" ", keys %moduleAttributes)
                         . " " . join(" ", keys %main::rcAttributes)
                         . " " . $main::readingFnAttributes;

  $hash->{Clients} = join (':', @clients);
}

sub
FRM_RCOUT_Init($$)
{
  my ($hash, $args) = @_;
  FRM_RC_Init($hash, PINMODE_RCOUTPUT, \&FRM_RCOUT_handle_rc_response, \%rcswitchAttributes, \%moduleAttributes, $args);
}

sub
FRM_RCOUT_Attr($$$$)
{
  my ($command, $name, $attribute, $value) = @_;
  return FRM_RC_Attr($command, $name, $attribute, $value, \%rcswitchAttributes);
}

# FRM_RCOUT_Get behaves as CUL_Get so that 10_IT can use FRM_RCOUT as IODev
sub
FRM_RCOUT_Get($@)
{
  my ($self, $name, $get, $codeCommand) = @_;

  if(!defined($get) or !defined($gets{$get})) {
    return undef;
  }

  my ($code) = $codeCommand =~ /is([01fF]+)/;
  my $set = FRM_RCOUT_Set($self, $self->{NAME}, "tristateCode", $code);
  return "raw => $codeCommand";
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
    if ($command eq RCOUTPUT_CODE_PACKED_TRISTATE) {
      @code = FRM_RC_get_tristate_bits($a[2]);
    } elsif ($command eq RCOUTPUT_CODE_LONG) {
      my $value = $a[2];
      my $bitCount = $a[3];
      $bitCount = $main::attr{$hash->{NAME}}{defaultBitCount} if not defined $bitCount;
      $bitCount = $moduleAttributes{defaultBitCount} if not defined $bitCount; # if defaultBitCount was deleted
      @code = ($bitCount, $value);
    } elsif ($command eq RCOUTPUT_CODE_CHAR) {
        @code = map {ord($_)} split("", $a[2]);
    }
     FRM_RCOUT_send_code(FRM_Client_FirmataDevice($hash), $command, $hash->{PIN}, @code);
  };
  return $@;
}

sub FRM_RCOUT_handle_rc_response {
  my ( $hash, $command, @data ) = @_;

  if ($command eq RCOUTPUT_CODE_PACKED_TRISTATE) {
    # unpack tristates bits:
    # the microcontroller sends 4 tristate bits per byte,
    # the result will contain a list of tristate bits
    foreach (0..@data-1) {
      my $byte = shift @data;
      foreach (0..3) {
        push @data, FRM_RCOUT_get_tristate_bit($byte, $_);
      }
    }
    my $tristateCode = FRM_RC_get_tristate_code(@data);
    @data = ($tristateCode);
  } elsif ($command eq RCOUTPUT_CODE_LONG) {
    push @data, (shift @data) + ((shift @data) << 8);
    push @data, (shift @data) + ((shift @data) << 8)
               + ((shift @data) << 16) + ((shift @data) << 24);

  } elsif ($command eq RCOUTPUT_CODE_CHAR) {
    my $charCode = join("", map { chr($_); } @data);
    @data = ($charCode);
  } else { # parameter as int
      push @data, (shift @data) + ((shift @data) << 8);
  }
  
  FRM_RCOUT_observer($command, \@data, $hash);
}

sub FRM_RCOUT_observer
{
  my ( $key, $data, $hash ) = @_;
  my $name = $hash->{NAME};
  
  my %s = reverse(%sets);
  my %a = reverse(%rcswitchAttributes);
  my $subcommand = $s{$key};
  my $attrName = $a{$key};
  
COMMAND_HANDLER: {
    defined($subcommand) and do {
      if ("tristateCode" eq $subcommand) {
        my $tristateCode = shift @$data;
        Log3($name, 4, "$subcommand: $tristateCode");
        readingsSingleUpdate($hash, $subcommand, $tristateCode, 1);
      } elsif ("longCode" eq $subcommand) {
        my $bitCount = shift @$data;
        my $longCode  = shift @$data;
        Log3($name, 4, "$subcommand: $longCode/$bitCount");
        readingsBeginUpdate($hash);
        readingsBulkUpdate($hash, $subcommand, $longCode);
        readingsBulkUpdate($hash, "bitCount", $bitCount);
        readingsEndUpdate($hash, 1);
      } elsif ("charCode" eq $subcommand || "tristateString" eq $subcommand) {
        my $charCode = shift @$data; 
        Log3($name, 4, "$subcommand: $charCode");
        readingsSingleUpdate($hash, $subcommand, $charCode, 1);
      } else {
        readingsSingleUpdate($hash, "state", "unknown subcommand $subcommand", 1);
      }
      last;
    };
    defined($attrName) and do {
      my $value = shift @$data;
      Log3($name, 4, "$attrName: $value");

      $main::attr{$name}{$attrName}=$value;
      # TODO refresh web GUI somehow?
      last;
    };
};
}

sub FRM_RCOUT_send_code {
  my ( $firmata, $subcommand, $pin, @code ) = @_;
  my $protocol = $firmata->{protocol};
main::Log3("sender", 3, "pin $pin: " . join(",", @code));  
  my @transferCode = ();
  if ($subcommand eq RCOUTPUT_CODE_PACKED_TRISTATE) {
  
    # @code is a list of tristate bits.
    # 4 tristate bits per byte will be sent to the microcontroller;
    # the last byte has to be filled up with value-less data
    my @transferSymbols = FRM_RC_align(@code);

    # pack each 4 tristate bits into 1 byte
    for (my $i = 0; $i < @transferSymbols; $i++) {
      if (($i & 0x03) eq 0) { # add a new empty byte every 4th tristate bit
        push @transferCode, 0;
      }
      push @transferCode,
           FRM_RCOUT_set_tristate_bit(pop(@transferCode), $i, $transferSymbols[$i]);
    }
  } elsif ($subcommand eq RCOUTPUT_CODE_LONG) {
    my ($bitCount, $longCode) = @code;
    push @transferCode, (($bitCount >> 0) & 0xFF,
                         ($bitCount >> 8) & 0xFF);
    push @transferCode, (($longCode >>  0) & 0xFF,
                         ($longCode >>  8) & 0xFF,
                         ($longCode >> 16) & 0xFF,
                         ($longCode >> 24) & 0xFF
                        );
  } elsif ($subcommand eq RCOUTPUT_CODE_CHAR) {
    push @transferCode, @code;
    push @transferCode, 0; # terminate char[] with null byte
  } else {
    die "Unsupported subcommand $subcommand";
  }
  
  return FRM_RC_send_message($firmata, $subcommand, $pin, @transferCode);
}

# extract tristate bit from byte (containing 4 tristate bits)
sub FRM_RCOUT_get_tristate_bit {
  my ( $byte, $index ) = @_;
  my $shift = 2 * ($index & 0x03);
  return (($byte << $shift) >> 6) & 0x03;
}

# set a tristate bit (2 bit) within a byte
sub FRM_RCOUT_set_tristate_bit {
  my ( $byte, $index, $tristateValue ) = @_;
  my $shift = 6-(2*($index & 0x03));
  my $value = ($tristateValue & 0x03) << $shift;
  my $clear = ~(3 << (6-(2*$index))) & 0xFF;
  my $result = ($byte & $clear) | $value;
  return $result;
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
