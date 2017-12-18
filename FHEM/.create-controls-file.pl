#!/usr/bin/perl
use File::stat;
use Date::Format qw(time2str);

sub cancel {
  print "Error: @_\n" and exit 1;
}

if (@ARGV == 0) {
  cancel "Please provide a list of files as arguments.";
}
foreach (@ARGV) {
  my $stat = stat $_;
  -f -r $stat or cancel "'$_' is not a readable file.";
  my $mtime = time2str "%Y_%d_%m_%H:%M:%S", $stat->mtime;
  my $size  = $stat->size;
  print "UPD $mtime $size $_\n";
}

