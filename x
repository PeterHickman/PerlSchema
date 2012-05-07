#!/usr/bin/perl

use strict;
use warnings;

$| = -1;

use PerlSchema;

my @schemas = ( 'helpers.txt', 'sub.txt' );
my $xml     = 't54.xml';

my $x = new XML::PerlSchema();

print "Loading Schemas\n";
print "===============\n";

foreach my $file (@schemas) {
    printf( "%-15s ==> ", $file );

    if ( $x->LoadPerlSchema($file) == -1 ) {
        print $x->ErrorMessage(), "\n";
    }
    else {
        print "OK\n";
    }
}
print "\n";

print "Loading XML\n";
print "===========\n";
printf( "%-15s ==> ", $xml );

if ( $x->LoadXML($xml) == -1 ) {
    print $x->ErrorMessage(), "\n";
}
else {
    print "OK\n";
}
print "\n";

print "Validating XML\n";
print "==============\n";

if ( $x->Validate() == -1 ) {
    print $x->ErrorMessage(), "\n";
}
else {
    if ( $x->ErrorCount() == 0 ) {
        print "There were no errors\n";
    }
    else {

        # Pack all the errors together

        my %errorhash;

        foreach my $error ( $x->ErrorList() ) {
            my $string = $error->{element} . ' ' . $error->{attribute} . ' [' . $error->{data} . '] ' . $error->{error};
            $errorhash{$string}++;
        }

        # Report the number of times the error occurs

        foreach my $key ( sort( keys(%errorhash) ) ) {
            printf( "%5d of %s\n", $errorhash{$key}, $key );
        }
        print "\nThere were ", $x->ErrorCount(), " errors\n";
    }
}

print "\nAll done\n";
