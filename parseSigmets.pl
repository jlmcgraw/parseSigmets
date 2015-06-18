#!/usr/bin/perl

use Modern::Perl '2014';

use Regexp::Grammars;
use File::Slurp qw(read_file);
use Data::Dumper;
$Data::Dumper::Indent   = 2;
$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Purity   = 1;    # fill in the holes for eval
use Params::Validate qw(:all);
use Getopt::Std;
use vars qw/ %opt /;

exit main(@ARGV);

sub main {
    my $opt_string = 'v';
    my $arg_num    = scalar @ARGV;

    unless ( getopts( "$opt_string", \%opt ) ) {
        usage();
        exit(1);
    }
    if ( $arg_num < 1 ) {
        usage();
        exit(1);
    }

    my $file = $ARGV[0];

    # say $file;

    # open($FH, '<', $file) or die $!;

    my $sigmetFileText = read_file($file) or die $!;

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
        <rule: Sigmet>
            <A_Header> <B_Header> <C_Body> =
            
                <rule: A_Header>
                    \w{6} <FIR> \d{6} <CORRECTION>?

                <rule: B_Header>     
                    <firAts=FIR> SIGMET <SEQUENCE> (VALID|WALID) <timeStart=TIME>\/<timeEnd=TIME> <firIssuing=FIR> -
                
                #
                <rule: C_Body>                                   #Body of the sigmet is:
                    <A_Amendment>*					#zero or more amendments
                    <B_FirInfo> 					#Need FIR info
                    <C_Phenomenon> 					#Need the Phenomenon
                    <D_When>* 						#Zero or more times
                    <[E_Location]>* 					#Zero or more locations
                    [-]? 						#Sometimes there's a "-" in there for no good reason
                    <[F_Level]>* 					#Zero or more flightLevel info
                    <[G_Movement]>* 					#Zero or more movement info
                    <H_Intensity>?					#Zero or one intensity
                
                <token: FIR> 	   	\w{4}  			#A FIR is 4 alpha characters
                <token: CORRECTION>   	\w{3}  		        #Correction is 3 alpha characters or blank
                <token: SEQUENCE>   	\w{1,3}		        #SEQUENCE is up to 3 alpha characters
                <token: TIME> 		\d{6}  			#Time is 4 digits characters

                    <rule: A_Amendment>   
                        AMD SIGMET \d+

                    <rule: B_FirInfo>   
                        <FIR> <longFirName> \s+ (FIR\/UIR|FIR\/CTA|FIR|UIR|CTA)
                        
                        <rule: longFirName> 
                            [\w\s]+

                    <rule: C_Phenomenon> 
                        <TS>| <TURB> |<ICE> |<DS> | <CB> | <MTW>

                            <rule: TS> 
                                <[tsAdjective]>* <tsType>
                                
                                <rule: tsAdjective> 
                                    (EMBD\/ISOL | OBSC | EMBD | FRQ | SQL | ISOL | OCNL)
                                
                                <rule: tsType>
                                    (TS | TSGR)

                            <rule: TURB>
                                <[turbAdjective]>* <turbType>
                                
                                <rule: turbAdjective>
                                    (SEV | MOD | OCNL)
                                
                                <rule: turbType>
                                    TURB

                            <rule: ICE> 	   	
                                <[iceAdjective]>* <iceType>
                                <rule: iceAdjective>
                                    (SEV | MOD)
                                <rule: iceType>
                                    ( ICG 
                                    | ICE \s? ( \( FZRA \) )*
                                    )

                            <rule: DS>
                                <[dsAdjective]>* <dsType>
                                
                                <rule: dsAdjective>
                                    (HVY)
                                <rule: dsType>
                                    DS

                            <rule: CB> 
                                <[cbAdjective]>* <cbType>
                                <rule: cbAdjective> 
                                    (EMBD\/ISOL | OBSC | EMBD | FRQ | SQL | ISOL)
                                <rule: cbType>
                                    (TS | TSGR)
                            
                            <rule: MTW>
                                <[mtwAdjective]>* <mtwType>
                                    <rule: mtwAdjective>
                                        (SEV)
                                    <rule: mtwType>
                                        (MTW)
                        
                    <rule: D_When> 
                                ( OBS AND FCST AT <obsAndForcast=zuluTime> 
                                | FCST AND OBS AT <obsAndForcast=zuluTime> 
                                | OBS AT <obsAndForcast=zuluTime> AND FCTS
                                | OBS AT <observed=zuluTime>
                                | FCST AND OBS
                                | OBS\/FCS
                                | OBS
                                | FCST
                                )
                        <token: zuluTime>
                            \d{4}Z  		#Time is 4 digits characters

                    <rule: E_Location>
                        WI (WI)? (AREA)? <[Area]>           #I've seen the WI repeated
                            <rule: Area>
                                <[Point]>+ % <separator> 
                                
                                <rule: separator>
                                    (\s | - | AND |)
                                
                                <rule: Point>
                                    <Latitude> <Longitude>
                                    
                                        <token: Latitude>
                                            (N|S)\d{4}
                                        <token: Longitude>
                                            (E|W)\d{5}
                    
                    <rule: F_Level> 
                                ( BTN FL <low=flightLevel> \/ FL <high=flightLevel>
                                | (CB)? TOP ABV FL<flightLevel>
                                | TOP ETI FL<low=flightLevel> \/ <high=flightLevel>
                                | TOP FL<low=flightLevel> \/ <high=flightLevel>
                                | TOP FL?<at=flightLevel>
                                | TOP <low=flightLevel> \/ <high=flightLevel>
                                | FL<low=flightLevel> \/ <high=flightLevel>
                                | FL<at=flightLevel>
                                )
                        <token: flightLevel>
                            \d{2,3}
                                                        
                    <rule: G_Movement> 
                        (	
                        MOV <direction> (AT)? (<speed>)? (<units>)?
                        | STNR 
                        | STNRY)
                        
                        <rule: direction>
                            (\w+)
                        <rule: speed>
                            ( \w+ 
                            | \d+ )
                        <rule: units>
                            ( KT 
                            | KMH )
                    
                    <rule: H_Intensity> 
                        ( INTSF 
                        | WKN 
                        | NC )
                    
                \.?             #Period at the end sometimes
    }xms;

    my $parsed_sigmets;
    my $sigmetDataPoints = 1;

    #Generic regex for a sigmet
    my $roughSigmetRegex = qr/
                            (   
                            \w{6}
                                \s+
                            \w{4}
                                \s+
                            \d{6}
                                .*?
                            \=
                            )/xs;

    #Do a rough pass through the file to pull out everythig that looks vaguely like
    #a SIGMET.  This will suck up malformed ones too and mess up the following one most likely
    #but it's better than hanging
    my @sigmetsArray = $sigmetFileText =~ /$roughSigmetRegex/ig;

    my $sigmetArrayLength = 0 + @sigmetsArray;
    my $sigmet_count      = $sigmetArrayLength / $sigmetDataPoints;

    if ( $sigmetArrayLength >= $sigmetDataPoints ) {

        say "Found $sigmet_count sigmets in file";

        for ( my $i = 0 ;
            $i < $sigmetArrayLength ; $i = $i + $sigmetDataPoints )
        {
            my $thisSigmetText = $sigmetsArray[$i];

#             #Some are split mid-word, just pull everything back together by deleting new-lines
            $thisSigmetText =~ s/\R//g;

            #        say $thisSigmetText;
            if ( $thisSigmetText =~ $sigmetParser ) {
                say "Matched!";
#                 say $thisSigmetText;
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
                say Dumper $parsedSigmetsHashReference;

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
                #             say "$VAR1->{Sigmet}{C_Body}{E_Location}{Area}";
                #             foreach my $k ( sort keys %$VAR1 ) {
                #                 print "$k\n";
                #                 foreach my $o ( sort keys %{ $VAR1->{$k} } ) {
                #                     print "\t$o =>  $VAR1->{$k}{$o}\n";
                #                 }
                #                 print "\n";
                #             }

#                 #---------------------------------
#                 #Returns an array reference
#                 my @testArray;
# 
#                 my $link_tags =
#                   search_collection( $parsedSigmetsHashReference, "Area",
#                     "Point", \@testArray );
# 
#                 if ($link_tags) {
#                     say @$link_tags;
#                 }

                # 	    map { say $_->{TagBody}{Text} } @$link_tags;

            }
            else {
                say "Can't parse SIGMET!";
                say $thisSigmetText;

            }
            say "------------------------------------";
        }
    }
    return 0;
}

sub coordinateToDecimal {

    my ($coordinate) = @_;

    my ( $declination, $number ) = $coordinate =~ / ( [NSEW] ) ( \d + )/x;

    return "" if !( $declination && $number );

    my ( $degrees, $minutes, $signedDegrees );

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

sub usage {
    say "Usage: $0 -v <config file>\n";
    say "-v: enable debug output";
    return 0;
}
