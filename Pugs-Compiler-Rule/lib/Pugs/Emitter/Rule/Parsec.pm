package Pugs::Emitter::Rule::Parsec;

# p6-rule parsec emitter

use strict;
use warnings;
use Pugs::Grammar::MiniPerl6;
use Data::Dumper;
$Data::Dumper::Indent = 1;

sub call_constant {
    my $str = shift;
    $str =~ s/\\/\\\\/g;
    $str =~ s/"/\\"/g;
    return 'symbol "' . $str . '"';
}

sub emit {
    my ($grammar, $ast, $param) = @_;
    emit_rule( $ast, '' ) . "\n";
}

sub emit_rule {
    my $n = $_[0];
    my $tab = $_[1];
    die "unknown node: ", Dumper( $n )
        unless ref( $n ) eq 'HASH';
    #print "NODE ", Dumper($n);
    my ( $k, $v ) = each %$n;
    # XXX - use real references
    no strict 'refs';
    my $code = &$k( $v, $tab );
    return $code;
}

#rule nodes

sub non_capturing_group {}
sub quant {
    my $term = $_[0]->{'term'};
    return emit_rule( $term, $_[1] );
}

sub alt {
    my @s;
    for ( @{$_[0]} ) { 
        my $tmp = emit_rule( $_, $_[1].'  ' );
        push @s, $tmp if $tmp;   
    }
    return join "\n$_[1]<|>\n$_[1]", @s;
}

sub concat {
    my $indent = $_[1] . '  ';
    my $result = 'do';
    for ( @{$_[0]} ) { 
        my $tmp = emit_rule( $_, $indent );
	$result .= "\n$indent" . $tmp if $tmp;
    }
    return $result;
}

sub code {}
sub dot {}
sub variable {}
sub special_char {}
sub match_variable {}

sub closure {
    my $miniperl6 = substr $_[0], 1, length($_[0]) - 2;
    my $haskell   = Pugs::Grammar::MiniPerl6->ProductionRule($miniperl6);
    $haskell =~ s/\n/\n$_[1]/sg;
    # print ">>> MiniPerl6\n$miniperl6\n===\n$haskell\n<<< Haskell\n";
    return "$haskell";
}

sub capturing_group {}

sub named_capture {
    my $name    = $_[0]{ident};
    my $program = $_[0]{rule};

    return "$name <- " . emit_rule($program, $_[1] . '  ');
}

sub before {}
sub after {}
sub colon {}
sub constant {}

use vars qw( %char_class );
BEGIN {
    %char_class = map { $_ => 1 } qw( 
alpha
alnum
ascii
blank
cntrl
digit
graph
lower
print
punct
space
upper
word
xdigit
);
}

sub metasyntax {
    # <cmd>
    my $cmd = $_[0];   
    my $prefix = substr( $cmd, 0, 1 );
    if ( $prefix eq '@' ) {
        # XXX - wrap @array items - see end of Pugs::Grammar::Rule
        # TODO - param list
=cut
        return 
            "$_[1] do {\n" . 
            "$_[1]    my \$match;\n" . 
            "$_[1]    for my \$subrule ( $cmd ) {\n" . 
            "$_[1]        \$match = " . 
                call_subrule( '$subrule', '', () ) . ";\n" .
            "$_[1]        last if \$match;\n" . 
            "$_[1]    }\n" .
            "$_[1]    my \$bool = (!\$match != 1);\n" . 
            "$_[1]    \$pos = \$match->to if \$bool;\n" . 
            "$_[1]    \$bool;\n" . 
            "$_[1] }";
=cut
    }
    if ( $prefix eq '$' ) {
=cut
        if ( $cmd =~ /::/ ) {
            # call method in fully qualified $package::var
            # ...->match( $rule, $str, $grammar, $flags, $state )  
            # TODO - send $pos to subrule
            return 
                "$_[1]         do {\n" .
                "$_[1]           push \@match,\n" . 
                "$_[1]             $cmd->match( \$s, \$grammar, {p => \$pos}, undef );\n" .
                "$_[1]           \$pos = \$match[-1]->to;\n" .
                "$_[1]           !\$match[-1] != 1;\n" .
                "$_[1]         }"
        }
        # call method in lexical $var
        # TODO - send $pos to subrule
        return 
                "$_[1]         do {\n" .
                "$_[1]           my \$r = Pugs::Runtime::Rule::get_variable( '$cmd' );\n" . 
                "$_[1]           push \@match,\n" . 
                "$_[1]             \$r->match( \$s, \$grammar, {p => \$pos}, undef );\n" .
                "$_[1]           \$pos = \$match[-1]->to;\n" .
                "$_[1]           !\$match[-1] != 1;\n" .
                "$_[1]         }"
=cut
    }
    if ( $prefix eq q(') ) {   # single quoted literal ' 
        $cmd = substr( $cmd, 1, -1 );
        return call_constant( $cmd );
    }
    if ( $prefix eq q(") ) {   # interpolated literal "
        $cmd = substr( $cmd, 1, -1 );
        warn "<\"...\"> not implemented";
        return;
    }
    if ( $prefix =~ /[-+[]/ ) {   # character class 
=cut
	   if ( $prefix eq '-' ) {
	       $cmd = '[^' . substr($cmd, 2);
	   } 
       elsif ( $prefix eq '+' ) {
	       $cmd = substr($cmd, 2);
	   }
	   # XXX <[^a]> means [\^a] instead of [^a] in perl5re

	   return call_perl5($cmd, $_[1]);
=cut
    }
    if ( $prefix eq '?' ) {   # non_capturing_subrule / code assertion
=cut
        $cmd = substr( $cmd, 1 );
        if ( $cmd =~ /^{/ ) {
            warn "code assertion not implemented";
            return;
        }
        return
	    "$_[1] do { my \$match =\n" .
	    call_subrule( $cmd, $_[1] . "          " ) . ";\n" .
	    "$_[1]      my \$bool = (!\$match != 1);\n" .
	    "$_[1]      \$pos = \$match->to if \$bool;\n" .
	    "$_[1]      \$bool;\n" .
	    "$_[1] }";
=cut
    }
    if ( $prefix eq '!' ) {   # negated_subrule / code assertion 
=cut
        $cmd = substr( $cmd, 1 );
        if ( $cmd =~ /^{/ ) {
            warn "code assertion not implemented";
            return;
        }
        return 
            "$_[1] ... negate( '$_[0]', \n" .
            call_subrule( $_[0], $_[1]."  " ) .
            "$_[1] )\n";
=cut
    }
    if ( $cmd eq '.' ) {
            warn "<$cmd> not implemented";
            return;
    }
    if ( $prefix =~ /[_[:alnum:]]/ ) {  
        # "before" and "after" are handled in a separate rule
        if ( $cmd eq 'cut' ) {
            warn "<$cmd> not implemented";
            return;
        }
        if ( $cmd eq 'commit' ) {
            warn "<$cmd> not implemented";
            return;
        }
        if ( $cmd eq 'prior' ) {
            warn "<$cmd> not implemented";
            return;
        }
        if ( $cmd eq 'null' ) {
            warn "<$cmd> not implemented";
            return;
        }
        if ( exists $char_class{$cmd} ) {
            # XXX - inlined char classes are not inheritable, but this should be ok
=cut
            return
                "$_[1] ( ( substr( \$s, \$pos, 1 ) =~ /[[:$cmd:]]/ ) 
$_[1]     ? do { $direction$direction\$pos; 1 }
$_[1]     : 0
$_[1] )";
=cut
        }
        # capturing subrule
        # <subrule ( param, param ) >
=cut
        my ( $subrule, $param_list ) = split( /[\(\)]/, $cmd );
        $param_list = '' unless defined $param_list;
        my @param = split( ',', $param_list );
        # TODO - send $pos to subrule
        return named_capture(
            { ident => $subrule, 
              rule => 
                "$_[1]         do {\n" . 
                "$_[1]           push \@match,\n" . 
                    call_subrule( $subrule, $_[1]."        ", @param ) . ";\n" .
                "$_[1]           my \$bool = (!\$match[-1] != 1);\n" .
                "$_[1]           \$pos = \$match[-1]->to if \$bool;\n" .
                #"print !\$match[-1], ' ', Dumper \$match[-1];\n" .
                "$_[1]           \$bool;\n" .
                "$_[1]         }",
	      flat => 1
            }, 
            $_[1],    
        );
=cut
    }
    die "<$cmd> not implemented";
}

1;
