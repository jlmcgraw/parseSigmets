#!/usr/bin/perl

use Modern::Perl '2015';

use Regexp::Grammars;
use File::Slurp qw(read_file);
use Data::Dumper;
$Data::Dumper::Indent   = 3;
$Data::Dumper::Sortkeys = 1;

my $file = $ARGV[0];

# say $file;

# open($FH, '<', $file) or die $!;

my $sigmetFileText = read_file($file);

# my  $latexParser = qr{
#         <File>
#
#         <rule: File>       <[Element]>*
#
#         <rule: Element>    <Command> | <Literal>
#
#         <rule: Command>    \\  <Literal>  <Options>?  <Args>?
#
#         <rule: Options>    \[  <[Option]>+ % (,)  \]
#
#         <rule: Args>       \{  <[Element]>*  \}
#
#         <rule: Option>     [^][\$&%#_{}~^\s,]+
#
#         <rule: Literal>    [^][\$&%#_{}~^\s]+
#     }xms
#
# my $xmlParser = qr{
# <logfile: parser_log >                                                  # Log description of the grammar
# <nocontext:>                                                            # Switch off debugging noise
#
# <Document>                                                              # Define a document
# <rule: Document>        <[Element]>*                                    # Contains many elements
# <rule: Element>         <XMLDecl> | <SelfClosingTag>  | <NormalTag>     # Which can be XML declarations, tags or
#                                                                         # self closing tags
# <rule: XMLDecl>         \<\?xml <[Attribute]>* \?\>                     # An xml can have zero or more attributes
# <rule: SelfClosingTag>  \< <TagName> <[Attribute]>* / \>                # A self closing tag similarly
# <rule: NormalTag>       \< <TagName> <[Attribute]>* \>                  # A normal tag can also have attributes
# 			    <TagBody>?                                  #   And a body
# 			<EndTag(:TagName)>                              # And an end tag named the same
# <token: TagName>        [^\W\d][^\s\>]+                                 # A Name begins with a non-digit non-non word char
# <rule: EndTag>		\< / <:TagName> \>                              # An end tag is a tagname in <>s with a leading /
# <rule: TagBody>         <[NormalTag]>* | <[SelfClosingTag]>* | <Text>   # A tag body may contain text, or more tags
#                                                                         # note that NormalTags are recursive.
# <rule: Text>            [^<]+                                           # Text is one or more non < chars
# <rule: Attribute>       <AttrName> = \" <AttrValue> \"                  # An attribute is a key="value"
# <token: AttrName>       [^\W\d][^\s]+                                   # Attribute names defined similarly to tag names
# <token: AttrValue>      [^"]+                                           # Attribute values are series of non " chars
# }xms;

#<rule: Body>
#<rule: Phenomenon> |<TC>|<MTW>|<SS>|<VA>

#

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
<timeout: 5>  #Stop if processing takes longer than this

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
#                                          TOP ETI FL350/420 MOVSLOW ESE NC
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

            #---------

            

            my $parsedSigmetsHashReference = \%/;
            
#             print Dumper $parsedSigmetsHashReference;
# 	    my $link_tags = search_collection( $parsedSigmetsHashReference, "Area", "link" );
# 
# 	    map { say $_->{TagBody}{Text} } @$link_tags;

            
#             print Dumper $parsedSigmetsHashReference;

            #             #             print Dumper $parsed_sigmets;
            #             foreach ( sort keys %parsedSigmets ) {
            #                 print "$_ : $parsedSigmets{$_}\n";
            #             }
            #
            #                         foreach my $key ( keys %{parsed_sigmets} ) {
            #                             say parsed_sigmets{$key};
            #                         }
            #             for ( keys %{$parsed_sigmets} ) {
            #                my $value = $parsed_sigmets->{$_};
            #                say $value;
            #             }
        }
        else {
            say "Can't parse SIGMET!" . @!;
            say $thisSigmetText;

        }
        say "------------------------------------";
    }
}


say coordinateToDecimal("S3250");
say coordinateToDecimal("W06150");

# if ( $sigmetFileText =~ $roughSigmetParser ) {
#     say "Matched!";
#
#     $parsed_sigmets = \%/;
#
#     foreach my $key ( keys %$parsed_sigmets ) {
#         say $parsed_sigmets->{$key};
#         say "------------------------------------";
#     }
#
#         print Dumper $parsed_sigmets;
# }
# else {
#     die "Can't parse SIGMET!\n" . @!;
# }

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
    my ( $collection, $target_key, $target_val, $results ) = @_;
    say ref $collection;
    if ( ref $collection eq "ARRAY" ) {
        for ( @{$collection} ) {
            $results =
              search_collection( $_, $target_key, $target_val, $results );
        }
        return $results;
    }

    for ( keys %{$collection} ) {
        my $value = $collection->{$_};

        if ( ref($value) eq 'HASH' || ref($value) eq 'ARRAY' ) {
            $results =
              search_collection( $value, $target_key, $target_val, $results );
        }

        if ( uc $_ eq uc $target_key ) {
            push @$results, $collection;
        }
    }

    return $results;
}