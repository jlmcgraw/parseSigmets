#!/usr/bin/perl

use Modern::Perl '2015';

use Regexp::Grammars;
use File::Slurp qw(read_file);
use Data::Dumper;
$Data::Dumper::Indent = 1;
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


my $sigmetParser = qr{
<logfile: parser_log.txt > # Log description of the grammar 
<nocontext:> # Switch off debugging noise
<File>					#Define a file
<rule: File>       <[Junk]>* | <[Sigmet]>*  	# That contains many sigmets, so save each one separately

<rule: Junk> (^Document.*?$
| ^Description.*?$
 | ^[_]+$ 
 | ^No reports are currently available.*?$
)
<rule: Sigmet>     <Header1> <Header> <Body> =
<rule: Header1>    \w{6} <FIR> \d{6}
<rule: Header>     <firAts=FIR> SIGMET <SEQUENCE> VALID <timeStart=TIME>\/<timeEnd=TIME> <firIssuing=FIR> -
<rule: Body>       <Amendment> <FirInfo> <Phenomenon> <When> <[Location]>+ .*?

  <token: FIR> 	   	\w{4}  		#FIR is 4 alpha characters
  <token: SEQUENCE>  	\w+ 		#SEQUENCE  is up to 3 alpha characters
  <token: TIME> 	\d{6}  		#Time is 4 digits characters

  <rule: Amendment>   AMD SIGMET \d+ | \s?

<rule: FirInfo>   <FIR> <longFirName> \s+ (FIR\/UIR|FIR\/CTA|FIR|UIR|CTA)
  <rule: longFirName> [\w\s]+

<rule: Phenomenon> <TS>| <TURB> |<ICE> |<DS>

  <rule: TS> 	   <[tsAdjective]>* <tsType>
  <rule: tsAdjective> (EMBD\/ISOL|OBSC|EMBD|FRQ|SQL|ISOL)
  <rule: tsType>     (TS|TSGR)

  <rule: TURB> 	   <[turbAdjective]>* \s+ <turbType>
  <rule: turbAdjective> (SEV|MOD)
  <rule: turbType>     TURB

  <rule: ICE> 	   <[iceAdjective]>* \s+ <iceType>
  <rule: iceAdjective> (SEV|MOD)
  <rule: iceType>     (
		      ICG|
		      ICE\s?\(FZRA\)
		      )

  <rule: DS> 	   <[dsAdjective]>* \s+ <dsType>
  <rule: dsAdjective> (HVY)
  <rule: dsType>     DS

<rule: When> ( OBS AT <observed=zuluTime> 
	      | OBS AND FCST AT <obsAndForcast=zuluTime> 
	      | FCST AND OBS AT <obsAndForcast=zuluTime> 
	      | FCST AND OBS
	      | OBS\/FCS
	      | OBS
	      | FCST
	      |							#Allow an empty "When" 
	      )
  <token: zuluTime> 	   \d{4}Z  		#Time is 4 digits characters

<rule: Location> 	WI <[Area]>
			| \s+
  <rule: Area>    	<[Point]>+ % (\s+ | - | AND)
  <rule: Point>     	<Latitude> <Longitude>
  <token: Latitude>   	(N|S)\d{4}
  <token: Longitude>  	(E|W)\d{5}
  
<rule: Level> (
	      TOP ABV FL<flightLevel>
	      | TOP ETI FL<low=flightLevel>\/<high=flightLevel> 
	      | FL<low=flightLevel>\/<high=flightLevel>
	      | FL<at=flightLevel
	      )
  <token: flightLevel> 	   \d{3}Z  		#Time is 4 digits characters

<rule: Movement>  MOV (?<direction>\w+)  (?<speed>\d+) (KMH|KT)
                | MOV (?<speed>\w+) (?<direction>\w+)
                | MOV (?<direction>\w+)  


<rule: Intensity> (INTSF|WKN|NC)
}xms;

# SCIZ SIGMET 3 VALID 121030/121430 SCIP-
# SCIZ ISLA DE PASCUA FIR EMBD/ISOL TS WI S3000 W13100 - S3338 W12021 -
# S3827 W12336 - S3838 W13100 AND S3000 W13100 TOP ETI FL350/400 MOV 
# SLOW ESE NC=

# ULAA SIGMET 4 VALID 121300/121700 ULAA-
# ULAA ARKHANGELSK FIR SEV TURB FCST FL200/380 MOV SE 40KMH NC=

my $parsed_xml;

if ( $sigmetFileText =~ $sigmetParser ) {
    say "Matched!";
    $parsed_xml = \%/;
    print Dumper $parsed_xml;
}
else {
    die "Can't parse SIGMET!\n" . @!;
}

