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
  "message" => "",
);

sub
FRM_RCSWITCH_Initialize($)
{
  my ($hash) = @_;

  $hash->{SetFn}     = "FRM_RCSWITCH_Set";
  $hash->{DefFn}     = "FRM_Client_Define";
  $hash->{InitFn}    = "FRM_RCSWITCH_Init";
  $hash->{UndefFn}   = "FRM_Client_Undef";
  $hash->{AttrFn}    = "FRM_RCSWITCH_Attr";
  
  $hash->{AttrList}  = "dummy-attr IODev $main::readingFnAttributes";
  main::LoadModule("FRM");
}

sub
FRM_RCSWITCH_Init($$)
{
  my ($hash,$args) = @_;
  my $ret = FRM_Init_Pin_Client($hash,$args,PIN_RCSWITCH);
  return $ret if (defined $ret);
  eval {
    my $firmata = FRM_Client_FirmataDevice($hash);
    FRM_RCSWITCH_apply_attribute($hash, "dummy-attr");
  };
  return FRM_Catch($@) if $@;
  main::readingsSingleUpdate($hash,"state","Initialized",1);
  return undef;
}

sub
FRM_RCSWITCH_Attr($$$$) {
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
        ($attribute eq "dummy-attr") and do {
          if ($main::init_done) {
          	$main::attr{$name}{$attribute}=$value;
            FRM_RCSWITCH_apply_attribute($hash,$attribute);
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

sub FRM_RCSWITCH_apply_attribute {
  my ($hash,$attribute) = @_;
  if ($attribute eq "dummy-attr") {
    my $name = $hash->{NAME};
    # do something with the attribute
  }
}

sub
FRM_RCSWITCH_Set($@)
{
  my ($hash, @a) = @_;
  return "Need at least one parameters" if(@a < 2);
  return "Unknown argument $a[1], choose one of " . join(" ", sort keys %sets)
  	if(!defined($sets{$a[1]}));
  my $command = $a[1];
  my $value = $a[2];
  eval {
    FRM_Client_FirmataDevice($hash)->rcswitch_send($hash->{PIN}, $value);
    main::readingsSingleUpdate($hash,"state",$value, 1);
  };
  return $@;
}

1;

=pod
=begin html

<a name="FRM_RCSWITCH"></a>
<h3>FRM_RCSWITCH</h3>
<ul>
  represents a pin of an <a href="http://www.arduino.cc">Arduino</a> running <a href="http://www.firmata.org">Firmata</a>
  configured to send data via the RCSwitch library.<br>
  Requires a defined <a href="#FRM">FRM</a>-device to work.<br><br> 
  
  <a name="FRM_RCSWITCHdefine"></a>
  <b>Define</b>
  <ul>
  <code>define &lt;name&gt; FRM_RCSWITCH &lt;pin&gt;</code> <br>
  Defines the FRM_RCSWITCH device. &lt;pin&gt> is the arduino-pin to use.
  </ul>
  
  <br>
  <a name="FRM_RCSWITCHset"></a>
  <b>Set</b><br>
  <ul>
  <code>set &lt;name&gt; message &lt;message&gt;</code><br>sends a tristate message in tristate format, e.g. <code>00FFF FF0FF F0<code> <br/> 
  </ul>
  <a name="FRM_RCSWITCHget"></a>
  <b>Get</b><br>
  <ul>
  N/A
  </ul><br>
  <a name="FRM_RCSWITCHattr"></a>
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
