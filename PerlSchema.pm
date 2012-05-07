package XML::PerlSchema;

use strict;
use warnings;

my $VERSION = 1.00;

use XML::Twig;

################################################################################
# This is where we store the schema checking code
################################################################################

my %t;

################################################################################
# Public method : new
################################################################################

sub new {
    my ($class) = @_;

    my $self = {};

    # Now set up the variables we require

    $self->{FatalError}    = 0;
    $self->{ErrorMessage}  = '';
    $self->{SchemasLoaded} = 0;
    $self->{XMLLoaded}     = 0;
    $self->{XMLRoot}       = '';
    $self->{AllTheErrors}  = ();
    $self->{CountErrors}   = 0;

    bless $self, ref($class) || $class;

    return $self;
}

################################################################################
# Public method : ErrorMessage
################################################################################

sub ErrorMessage {
    my ($self) = @_;

    return $self->{ErrorMessage};
}

################################################################################
# Public method : ErrorCount
################################################################################

sub ErrorCount {
    my ($self) = @_;

    return $self->{CountErrors};
}

################################################################################
# Public method : ErrorList
################################################################################

sub ErrorList {
    my ($self) = @_;

    return @{ $self->{AllTheErrors} };
}

################################################################################
# Public method : LoadPerlSchema
################################################################################

sub LoadPerlSchema {
    my ( $self, $filename ) = @_;

    my $data = '';

    # Load the file

    eval {
        open( FILE, $filename ) or die;
        $data = join ( '', <FILE> );
        close(FILE);
    };

    if ($@) {
        $self->{ErrorMessage} = "Unable to read schema from $filename";
        $self->{FatalError}   = 1;
        return -1;
    }

    $self->_load_the_code( $filename, $data );
}

################################################################################
# Public method : LoadXML
################################################################################

sub LoadXML {
    my ( $self, $filename ) = @_;

    if ( ( $self->{SchemasLoaded} == 0 ) or ( $self->{FatalError} == 1 ) ) {
        $self->{ErrorMessage} = 'No schemas (successfully) loaded';
        return -1;
    }

    if ( !-e $filename ) {
        $self->{ErrorMessage} = "Unable to locate $filename";
        return -1;
    }

    $self->{XMLRoot} = new XML::Twig();

    eval { $self->{XMLRoot}->parsefile($filename); };

    if ($@) {
        $self->{ErrorMessage} = "XML::Twig failed to parse $filename";
        return -1;
    }

    $self->{XMLLoaded}++;

    return 0;
}

################################################################################
# Public method : Validate
################################################################################

sub Validate {
    my ($self) = @_;

    if ( $self->{XMLLoaded} == 0 ) {
        $self->{ErrorMessage} = 'No XML file (successfully) loaded';
        return -1;
    }

    # Before we start lets clear some variables

    $self->{AllTheErrors} = ();
    $self->{CountErrors} = 0;

    $self->_parse_this( $self->{XMLRoot}->root );

    eval { $self->{XMLRoot}->purge; };

    return 0;
}

################################################################################
# Private method : _load_the_code
################################################################################

sub _load_the_code {
    my ( $self, $filename, $data ) = @_;

    # Exec it into code

    eval $data;

    if ($@) {
        $self->{ErrorMessage} = "The schema in $filename is invalid: $@";
        $self->{FatalError}   = 1;
        return -1;
    }

    # Now check that all is OK

    foreach my $ent ( keys(%t) ) {
        if ( ref( $t{$ent} ) ne 'HASH' ) {
            $self->{ErrorMessage} =
              "$ent should be HASH not " . ref( $t{$ent} );
            $self->{FatalError} = 1;
            return -1;
        }
        else {
            foreach my $attr ( keys( %{ $t{$ent} } ) ) {
                if ( ref( $t{$ent}->{$attr} ) ne 'CODE' ) {
                    $self->{ErrorMessage} =
                      "$ent -> $attr should be CODE not " . ref( $t{$ent}->{$attr} );
                    $self->{FatalError} = 1;
                    return -1;
                }
            }
        }
    }

    # Everything is ok then

    $self->{SchemasLoaded}++;

    return 0;
}

################################################################################
# Private method : _parse_this
################################################################################

sub _parse_this {
    my ( $self, $root ) = @_;

    my $roottype = $root->gi;

    # Check out the attributes

    my $atts = $root->atts;
    if ( ref($atts) eq 'HASH' ) {
        foreach my $att ( keys( %{$atts} ) ) {
            $self->_check( $roottype, $att, $root->{att}->{$att} );
        }
    }

    # Now check out the nodes

    foreach my $child ( $root->children ) {
        my $type = $child->gi;

        if ( ( $type eq '#PCDATA' ) or ( $type eq '#ENT' ) ) {
            $self->_check( $roottype, $type, $child->text );
        }
        else {
            $self->_parse_this($child);
        }
    }

    eval { $root->purge; };
}

################################################################################
# Private method : _check
################################################################################

sub _check {
    my ( $self, $element, $attribute, $data ) = @_;

    if ( defined( $t{$element}->{$attribute} ) ) {
        my $message = &{ $t{$element}->{$attribute} }($data);
        if ( $message ne '' ) {
            $self->_record_error( $element, $attribute, $data, $message );
        }
    }
    else {

        # If there is no exact match can we use the default

        if ( defined( $t{'*'}->{$attribute} ) ) {
            my $message = &{ $t{'*'}->{$attribute} }($data);
            if ( $message ne '' ) {
                $self->_record_error( $element, $attribute, $data, $message );
            }
        }
    }
}

################################################################################
# Private method : _record_error
################################################################################

sub _record_error {
    my ( $self, $element, $attribute, $data, $errmsg ) = @_;

    push (
        @{ $self->{AllTheErrors} },
        {
            element   => $element,
            attribute => $attribute,
            data      => $data,
            error     => $errmsg
        }
    );

    $self->{CountErrors}++;
}

1;

__END__

=head1 NAME

XML::PerlSchema - An XML Schema engine for validating XML documents using Perl

=head1 VERSION

This document refers to version 1.00 of XML::PerlSchema, released October 3, 2002

=head1 SYNOPSIS

  use XML::PerlSchema;

  my $x = new XML::PerlSchema();

  if($x->LoadPerlSchema('sub.txt') == -1) {
    print $x->ErrorMessage(),"\n";
  }

  if($x->LoadXML('fred.xml')  == -1) {
    print $x->ErrorMessage(),"\n";
  }

  if($x->Validate()  == -1) {
    print $x->ErrorMessage(),"\n";
  } else {
    if($x->ErrorCount() == 0) {
      print "There were no errors\n";
    } else {
      # Pack all the errors together

      my %errorhash;

      foreach my $error ($x->ErrorList()) {
        my $string = $error->{element} .' '. 
          $error->{attribute} .' ['. 
          $error->{data} .'] '. 
          $error->{error};
        $errorhash{$string}++;
      }

      # Report the number of times the error occurs

      foreach my $key (sort(keys(%errorhash))) {
        printf("%5d of %s\n", $errorhash{$key}, $key);
      }
      print "\nThere were ",$x->ErrorCount()," errors\n";
    }
  }

=head1 DESCRIPTION

=head2 Overview

I have a need to validate XML data beyond that of wellformedness and validity but did not have the time to absorb the joys that is XML Schema so I put together a little hack that will allow me to validate the XML. This code borrows from XPathScript, if you dont know XpathScript then this will mean nothing to you but if you do then you will realise that I have still alot to learn.

A schema is written in Perl as a file containing declarations as follows...

  $t{element}->{attribute} = sub {
    my ($text) = shift;

    # your code goes here

    return $result;
  };

The value returned by the sub is a string with the empty string indicating no error. A non empty string is considered to be an error and the message desribing the error. Thus...

  $t{employee}->{id} = sub {
    my ($text) = shift;

    if($text !~ m/^abc\d{4}$/) {
      return 'Employee id is of the format \'abc9999\'';
    } else {
      return '';
    }
  };

(Note the closing ';' on the last line of that definition, miss that off and you have a really difficult bug to find)

Will validate the B<id> attribute of the B<employee> element and if it does not match the given regex will return the error message otherwise it will return the empty string to indicate that all is ok. Just put a whole load of them is a file and you have a schema. The attibutes B<#PCDATA> and B<#ENT> match the data associated with an element and the entities in that data.

A special case of C<< $t{'*'}->{attribute} >> is used to catch any defaults that no specific rules exist for. The schema engine will first try to use match a spcific rule like C<< $t{employee}->{id} >> first and if it is not found will look for C<< $t{'*'}->{id} >> and try to use that. If no rule is found then the element attribute pair passes.

There is a file called C<helpers.txt> which contains some predefined validation functions to make writting the schemas easier. Just include it as a schema in a LoadPerlSchema()

=head2 Plans for the future

=over 4

=item Helper functions

The helper functions in C<helper.txt> should move into the module itself whilst becoming more XML Schema like

=item The XML parser

XML::Twig is fine and dandy but eats up memory likes it was going out of fashion so this may be replaced by something quicker and more frugal

=item XML Schema

The missing method here is obviously LoadXMLSchema() to compliment LoadPerlSchema(). The plan is to write an XML Schema parser that will convert the validations into a string of Perl that will be fed in by LoadPerlSchema(), or rather the private method _load_the_code(). We can dream

=item The name

It really should be called XML::Schema shouldn't it. But I am assuming that better people than I are beavering away to create that perfect XML Schema engine for Perl. Indeed Dom told me that I am not the only person that is developing one so I have left the namespace entry free for a more thorough implementation

=item Other tools

I have a working, in the beta sense of the word, tool to extract a schema from valid XML and writes a Perl Schema file that can be used to validate other files of the same type. But at present it eats even more memory up than XML::PerlSchema so it will not be appearing until I get a replacement for XML::Twig and work out a better data structure

=back

=head2 Constructor and initialization

The constructor C<new XML::PerlSchema()> takes no parameters and returns an XML::PerlSchema class object

=head2 Class and object methods

After the class is created schemas are loaded with LoadPerlSchema(). Then the XML is loaded with LoadXML() and if this is sucessfull it can then be validates with Validate(). If Validate() returns a -1 there were some errors. ErrorCount() will tell you how many errors there were and ErrorList() will allow you to retrieve the actual errors as a list of anonymous hashes

You can then load more schemas, different XML files and continue to validate

=over 4

=item ErrorMessage

If any of the subsequent methods returns a -1 to indicate an error then use this method to get the error message that describes the condition

=item LoadPerlSchema

Takes a single argument, the name of the Perl schema code. Returns 0 if the code loads successfully otherwise returns -1. See ErrorMessage() above. This method can be called several times to load the schema in piecemeal before calling LoadXML()

=item LoadXML

Takes a single argument, the name of a well formed XML file (prefereable valid). Returns 0 if the XML loads successfully otherwise returns a -1 if the XML could not be loaded by XML::Twig. See ErrorMessage() above

=item Validate

Takes no arguments and performs a validation of the supplied XML file. If there were no validation errors it will return 0, otherwise it will return -1. You must then use ErrorCount() and ErrorList() to assess the errors

=item ErrorCount

Returns the number of errors that occured during the validation of the supplied XML file

=item ErrorList

Returns a list of all the errors that occured during the validation of the supplied XML file. The list is made up of anonymous hashes that have the following keys

=over 4

=item element

The XML element name that was being validated

=item attribute

The name of the attribute of the aforementioned XML element that was being validated

=item data

The data from the XML element and attribute defined above

=item error

The actual validation error

=back

=back

=head1 DIAGNOSTICS

=item 'Unable to read schema from ?'

The filename supplied to LoadPerlSchema() could not be opened / read

=item 'No schemas (successfully) loaded'

Trying to load an XML file in LoadXML() but have not successfully loaded a schema at this point

=item 'Unable to locate ?'

The filename supplied to LoadXML() could not be opened / read

=item 'XML::Twig failed to parse ?'

The filename supplied to LoadXML() could not be loaded into XML::Twig and Twig has died. Are you sure that the XML is well formed?

=item 'No XML files (successfully) loaded'

A call has been made to Validate() but either no XML has been loaded by LoadXML() or the XML loaded by LoadXML() was invalid and caused an error and so there is no XML to validate

=item 'The schema in ? is invalid ...'

The schema supplied to LoadPerlSchema() has been loaded but Perl has found it to be invalid

=item 'B<element> should be HASH not ?'

The Perl schema should be of the format C<< $t{B<element>}->{B<attribute>} = sub { >> and this indicates that the C<$t{B<element>}> does not access a hash

=item 'B<element> -> B<attribute> should be CODE not ?'

The Perl schema should be of the format C<< $t{B<element>}->{B<attribute>} = sub { >> and this indicates that the C<< $t{B<element>}->{B<attribute>} >> does not access a subroutine

=head1 BUGS

At present there are no known bugs. Should you encounter any please report them to the author

=head1 SEE ALSO

XML::Twig - The XML parser used by XML::PerlSchema

=head1 AUTHOR

Peter Hickman (peterhi@ntlworld.com)

=head1 COPYRIGHT

Copyright (c) 2002, Peter Hickman. All Rights Reserved.
This module is free software. It may be used, redistribute 
and/or modified under the same terms as Perl itself.


