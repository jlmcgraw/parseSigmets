#!/usr/bin/perl

use Modern::Perl '2015';

use Regexp::Grammars;
use File::Slurp qw(read_file);
use Data::Dumper;
$Data::Dumper::Indent   = 2;
$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Purity   = 1;    # fill in the holes for eval
use Params::Validate qw(:all);

my $file = $ARGV[0];

# say $file;

# open($FH, '<', $file) or die $!;

my $sigmetFileText = read_file($file);

# my $roughSigmetParser = qr{
# <File>						#Define a file
#   <rule: File>       ( <[Sigmet]>* )  	# That contains junk, or zero or more sigmets [save each one separately]
#   <rule: Sigmet>     	<Header1> <.Body> =
#     <rule: Header1>    		\w{6} <FIR> \d{6}
#     <rule: Body>     		.*?
#     <token: FIR> 	\w{4}  		#FIR is 4 alpha characters
# }xms;

my $sigmetParser = qr{
<logfile: parser_log.txt > # Log description of the grammar 
<nocontext:> # Switch off debugging noise
<timeout: 1>  #Stop if processing takes longer than this

<Sigmet>						#Define a file      
  <rule: Sigmet>     <AHeader> <BHeader> <CBody> =
    <rule: AHeader>    \w{6} <FIR> \d{6} <CORRECTION>?	
   
    <rule: BHeader>     <firAts=FIR> SIGMET <SEQUENCE> VALID <timeStart=TIME>\/<timeEnd=TIME> <firIssuing=FIR> -
    
    <rule: CBody>                                       #Body of the sigmet is:
      <AAmendment>*					#zero or more amendments
      <BFirInfo> 					#Need FIR info
      <CPhenomenon> 					#Need the Phenomenon
      <DWhen>* 						#Zero or more times
      <[ELocation]>* 					#Zero or more locations
      [-]? 						#Sometimes there's a "-" in there for no good reason
      <[FLevel]>* 					#Zero or more flightLevel info
      <[GMovement]>* 					#Zero or more movement info
      <HIntensity>?					#Zero or one intensity
      
      <token: FIR> 	   	\w{4}  			#FIR is 4 alpha characters
      <token: CORRECTION>   	\w{3}  		#Correction is 3 alpha characters or blank
      <token: SEQUENCE>  	\w{1,3}			#SEQUENCE  is up to 3 alpha characters
      <token: TIME> 		\d{6}  			#Time is 4 digits characters

    <rule: AAmendment>   AMD SIGMET \d+

    <rule: BFirInfo>   <FIR> <longFirName> \s+ (FIR\/UIR|FIR\/CTA|FIR|UIR|CTA)
      <rule: longFirName> [\w\s]+

    <rule: CPhenomenon> <TS>| <TURB> |<ICE> |<DS> | <CB> 

      <rule: TS> 	  	 <[tsAdjective]>* <tsType>
	<rule: tsAdjective> 	(EMBD\/ISOL | OBSC | EMBD | FRQ | SQL | ISOL | OCNL)
	<rule: tsType>     	(TS | TSGR)

      <rule: TURB> 	   	<[turbAdjective]>* \s+ <turbType>
	<rule: turbAdjective> 	(SEV | MOD | OCNL)
	<rule: turbType>     	TURB

      <rule: ICE> 	   	<[iceAdjective]>* \s+ <iceType>
	<rule: iceAdjective> 	(SEV | MOD)
	<rule: iceType>		(
			      ICG |
			      ICE \s? ( \( FZRA \) )*
			      )

      <rule: DS> 	  	 <[dsAdjective]>* \s+ <dsType>
	<rule: dsAdjective> 	(HVY)
	<rule: dsType>     	DS

      <rule: CB> 	  	 <[cbAdjective]>* <cbType>
	<rule: cbAdjective> 	(EMBD\/ISOL | OBSC | EMBD | FRQ | SQL | ISOL)
	<rule: cbType>     	(TS | TSGR)
	
    <rule: DWhen> ( OBS AND FCST AT <obsAndForcast=zuluTime> 
		  | FCST AND OBS AT <obsAndForcast=zuluTime> 
		  | OBS AT <obsAndForcast=zuluTime> AND FCTS
		  | OBS AT <observed=zuluTime>
		  | FCST AND OBS
		  | OBS\/FCS
		  | OBS
		  | FCST
		  )
      <token: zuluTime> 	   \d{4}Z  		#Time is 4 digits characters

    <rule: ELocation> 		WI <[Area]>
      <rule: Area>    		<[Point]>+ % <separator> 
	<rule: separator> 	(\s | - | AND |)
	<rule: Point>     	<Latitude> <Longitude>
	  <token: Latitude>   	(N|S)\d{4}
	  <token: Longitude>  	(E|W)\d{5}
      
    <rule: FLevel> ( BTN FL <low=flightLevel> \/ FL <high=flightLevel>
		  | TOP ABV FL<flightLevel>
		  | TOP ETI FL<low=flightLevel> \/ <high=flightLevel>
		  | TOP FL<low=flightLevel> \/ <high=flightLevel>
		  | TOP FL?<at=flightLevel>
		  | TOP <low=flightLevel> \/ <high=flightLevel>
		  | FL<low=flightLevel> \/ <high=flightLevel>
		  | FL<at=flightLevel>
		  )
      <token: flightLevel> 	\d{3}
                                           
    <rule: GMovement> (	MOV <direction> (AT)? (<speed>)? (<units>)?
			| STNR)
      <rule: direction> (\w+)
      <rule: speed> 	(\w+ | \d+ )
      <rule: units> 	(KT | KMH )
    
    <rule: HIntensity> (INTSF | WKN | NC)
}xms;

my $parsed_sigmets;
my $sigmetDataPoints = 1;

my $roughSigmetRegex = qr/(\w{6} \s+ \w{4} \s+ \d{6} .*? \=)/xs;

#Do a rough pass through the file to pull out everythig that looks vaguely like
#a SIGMET.  This will suck up malformed ones too and mess up the following one most likely
#but it's better than hanging
my @sigmetsArray = $sigmetFileText =~ /$roughSigmetRegex/ig;

my $sigmetArrayLength = 0 + @sigmetsArray;
my $sigmet_count      = $sigmetArrayLength / $sigmetDataPoints;

if ( $sigmetArrayLength >= $sigmetDataPoints ) {

    say "Found $sigmet_count sigmets in file";

    for ( my $i = 0 ; $i < $sigmetArrayLength ; $i = $i + $sigmetDataPoints ) {
        my $thisSigmetText = $sigmetsArray[$i];

#Some are split mid-word, just pull everything back together by deleting new-lines
        $thisSigmetText =~ s/\n//g;

        #        say $thisSigmetText;
        if ( $thisSigmetText =~ $sigmetParser ) {
            say "Matched!";

            #Get a reference to the results hash
            my $parsedSigmetsHashReference = \%/;

#             foreach my $key ( keys %$parsedSigmetsHashReference ) {
#                 foreach my $key2 ( keys $parsedSigmetsHashReference->{$key} ) {
#                     say ref $key2;
#                     say $parsedSigmetsHashReference->{$key}{$key2};
#                 }
# 
#                             
#             }
#  say Dumper $parsedSigmetsHashReference;
     #             #------------------------------------------
     #             use Storable;
     #             store( $parsedSigmetsHashReference, "sigmetHash.txt" );
     #             my $restoredHashref = retrieve("sigmetHash.txt");
     #
     #             foreach my $key ( sort keys %$restoredHashref ) {
     #                 print $restoredHashref->{$key};
     #             }
     #
     #             #------------------------------
     #             use File::Slurp;
     #             write_file 'mydump.log', Dumper($parsedSigmetsHashReference);

            #------------------------------

            # 	    my $copy = dclone($parsedSigmetsHashReference);
            #            my %test = Dumper $parsedSigmetsHashReference;
            #            Dumper \%test;
            #            print Dumper $copy;

            # 	    print Data::Dumper->Dump([\%hash], ["hashname"]), $/;

            #-----------------------------
            #             $Data::Dumper::Terse = 1;
            #             my $wtf = Dumper $parsedSigmetsHashReference;
            #
            # # #              say $wtf;
            # #             my $VAR1;
            #
            #             my %copied_hash = %{ eval $wtf };
            #             say $copied_hash{'Sigmet'};
            #             eval $wtf;

            #             Dumper \%copied_hash;
            #             say "$VAR1->{Sigmet}{CBody}{ELocation}{Area}";
            #             foreach my $k ( sort keys %$VAR1 ) {
            #                 print "$k\n";
            #                 foreach my $o ( sort keys %{ $VAR1->{$k} } ) {
            #                     print "\t$o =>  $VAR1->{$k}{$o}\n";
            #                 }
            #                 print "\n";
            #             }

#---------------------------------
#             #Returns an array reference
#             my @testArray;
#
#             my $link_tags = search_collection( $parsedSigmetsHashReference, "Area", "Point", \@testArray );
#
#             if ($link_tags) {
#                 say @$link_tags;
#             }

            # 	    map { say $_->{TagBody}{Text} } @$link_tags;

        }
        else {
            say "Can't parse SIGMET!" . @!;
            say $thisSigmetText;

        }
        say "------------------------------------";
    }
}
my %VAR1 = {
          'Sigmet' => {
                        'AHeader' => {
                                       'FIR' => 'SBBS'
                                     },
                        'BHeader' => {
                                       'SEQUENCE' => '3',
                                       'firAts' => 'SBBS',
                                       'firIssuing' => 'SBBS',
                                       'timeEnd' => '160910',
                                       'timeStart' => '160640'
                                     },
                        'CBody' => {
                                     'BFirInfo' => {
                                                     'FIR' => 'SBBS',
                                                     'longFirName' => 'BRASILIA'
                                                   },
                                     'CPhenomenon' => {
                                                        'TS' => {
                                                                  'tsAdjective' => [
                                                                                     'EMBD'
                                                                                   ],
                                                                  'tsType' => 'TS'
                                                                }
                                                      },
                                     'DWhen' => 'FCST',
                                     'ELocation' => [
                                                      {
                                                        'Area' => [
                                                                    {
                                                                      'Point' => [
                                                                                   {
                                                                                     'Latitude' => 'S2118',
                                                                                     'Longitude' => 'W04703'
                                                                                   },
                                                                                   {
                                                                                     'Latitude' => 'S2014',
                                                                                     'Longitude' => 'W05034'
                                                                                   },
                                                                                   {
                                                                                     'Latitude' => 'S1712',
                                                                                     'Longitude' => 'W04958'
                                                                                   },
                                                                                   {
                                                                                     'Latitude' => 'S1659',
                                                                                     'Longitude' => 'W04705'
                                                                                   },
                                                                                   {
                                                                                     'Latitude' => 'S2118',
                                                                                     'Longitude' => 'W04703'
                                                                                   }
                                                                                 ],
                                                                      'separator' => '-'
                                                                    }
                                                                  ]
                                                      }
                                                    ],
                                     'FLevel' => [
                                                   {
                                                     'at' => '410'
                                                   }
                                                 ],
                                     'GMovement' => [
                                                      {
                                                        'direction' => 'E',
                                                        'speed' => '05KT'
                                                      }
                                                    ],
                                     'HIntensity' => 'NC'
                                   }
                      }
        };
say $VAR1{Sigmet}{CBody}{ELocation};

# say coordinateToDecimal("S3250");
# say coordinateToDecimal("W06150");

sub coordinateToDecimal {

    #      N0533 W01656
    my ($coordinate) = @_;

    my ( $declination, $number ) = $coordinate =~ / ( [NSEW] ) ( \d + )/x;

    my $signedDegrees;

    return "" if !( $declination && $number );

    my ( $degrees, $minutes );

    given ($declination) {
        when (/N|S/) {
            $degrees = substr( $number, 0, 2 );
            $minutes = substr( $number, 2, 2 );
            $degrees = $degrees / 1;
            $minutes = $minutes / 60;
            $signedDegrees = ( $degrees + $minutes );

            #Latitude is invalid if less than -90  or greater than 90
            $signedDegrees = "" if ( abs($signedDegrees) > 90 );
        }
        when (/E|W/) {
            $degrees = substr( $number, 0, 3 );
            $minutes = substr( $number, 3, 2 );
            $degrees = $degrees / 1;
            $minutes = $minutes / 60;
            $signedDegrees = ( $degrees + $minutes );

            #Longitude is invalid if less than -180 or greater than 180
            $signedDegrees = "" if ( abs($signedDegrees) > 180 );
        }
        default {
        }
    }

    given ($declination) {
        when (/S|W/) { $signedDegrees = -($signedDegrees); }
    }

    # say "Coordinate: $coordinate to $signedDegrees"        if $debug;
    say "Deg: $degrees, Min:$minutes, Decl:$declination";
    return ($signedDegrees);
}

sub search_collection {

    #Is it a bug in that the first call to this has no $results parameter?
    my ( $collection, $target_key, $target_val, $results ) = validate_pos(
        @_,
        { type => HASHREF },
        { type => SCALAR },
        { type => SCALAR },
        { type => ARRAYREF },
    );

    #     say 'ref $collection  ' . ref $collection;

    #Search each item in the referenced array
    if ( ref $collection eq "ARRAY" ) {
        for ( @{$collection} ) {
            $results =
              search_collection( $_, $target_key, $target_val, $results );
        }
        return $results;
    }

    if ( ref $collection eq "HASH" ) {
        for ( keys %{$collection} ) {
            my $value = $collection->{$_};

            #Search if the item is a hash or an array
            #say '$collection->{$_}  ' . $value;
            if ( ref($value) eq 'HASH' || ref($value) eq 'ARRAY' ) {
                $results = search_collection( $value, $target_key, $target_val,
                    $results );
            }

            #             say "Checking key $_ against target_key $target_key";

            if ( uc $_ eq uc $target_key ) {

                say "yo " . $target_key;
                say ref $results;

                if ( ref $results eq "ARRAY" ) {
                    push @$results, $collection;
                }
                return $results;
            }

        }
    }
    say "what?";

}
