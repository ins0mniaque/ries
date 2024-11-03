#!/usr/bin/perl
#
# Your computer science professor doesn't want you to know how easy
# it is to "parse" postfix. Here's a hint: The entire grammar for a
# Turing-complete postfix computer language is:
#
#   Program ::= Expression
#   Expression ::= Token | Expression UnaryOp | Expression Expression BinaryOp
#   Token ::= Constant | Variable
#
# (plus lists of about 10 UnaryOps and 10 BinaryOps, which is enough
# to make the language useful for practical work)

# Define the hash (a.k.a. "dictionary") of RIES symbol names
%name = (
 # constants
  '0' => '0', '1' => '1', '2' => '2', '3' => '3', '4' => '4',
  '5' => '5', '6' => '6', '7' => '7', '8' => '8', '9' => '9',
  'e' => 'e', 'f' => 'phi', 'p' => 'pi', 'x' => 'x',
 # single-argument functions
  'C' => 'cos', 'E' => 'exp', 'l' => 'ln', 'n' => 'neg', 'q' => 'sqrt',
  's' => 'square', 'r' => 'recip', 'S' => 'sin', 'T' => 'tan',
  'W' => 'lambert',
 # two-argument functions
  '+' => 'add', '-' => 'sub', '*' => 'mult', '/' => 'div', '^' => 'pow',
  'A' => 'atan2', 'L' => 'logba', 'v' => 'root',
);

$symchars = '[';
foreach $k (sort (keys %name)) {
  if (($k eq '-') || ($k eq '^')) {
    $symchars .= "\\$k";
  } else {
    $symchars .= "$k";
  }
  $standard_symbols .= " $k";
}
$symchars .= ']+';
# symchars is now: [*+\-/0123456789ACELSTW\^eflnpqrsvx]+

$help = qq`
NAME

   pf2if.pl   -- Postfix to Internal Function conversion for RIES

DESCRIPTION

This program takes input like:

  x1A = p5+r                         for x = T + 1.54028e-05 {76}

and converts it to a nested function format:

  atan2(x,1) = recip(add(pi,5))      for x = T + 1.54028e-05 {76}

where each function e.g. 'recip', 'add', etc. represents one of the
operations RIES knows about (the functions built-in or "internal" to
RIES, contrasted with a hypothetical user-defined function). This
format is quite different from "infix", which would be:

  arctan(1/x) = 1/(pi+5)             for x = T + 1.54028e-05 {76}

The need for a program like this is greater now than in the 1990s or
earlier, because computer science classes switched from systems
programming languages (like C) to multi-modular languages (Java,
Python). They stopped teaching data structures and parsing because
these were intended to be provided by imported modules or libraries.

You can supply a single argument, which should be a filename
containing output of RIES that was generated with the -F0 option. If
you don't give a filename, it reads the standard input.

BUGS

If the input is from RIES but using a set of symbols other than these
standard ones:

 $standard_symbols

then the parsing won't work. In this case, as well as with input from
any other source (not RIES), the output will usually be the same as
the input, but with occasional infix expressions where previously
there were none.

EXAMPLE

  ries -F0 0.1234321 | ./pf2if.pl

`;

$ignored_block_comment = qq`

REVISION HISTORY:
 20230731 First version
 20230803 Better built-in help

TO-DO

Something about higher-level education reform?

NOTES

An overview of computer language translation is at:

  en.wikipedia.org/wiki/Parsing

It is useful to think of language translation as comprising four
steps, which generally occur in this sequence though might be combined
in some way:

  * Tokenize (Lexical Analysis): Go through the input in sequence (start
    to end) one character at a time, identifying characters or groups of
    characters as being e.g. variable names, keywords like IF or WHILE,
    constants like 3.45, etc.

  * Parsing (Semantic Analysis): Go through the tokens in sequence, keeping
    track of how they fit into grammar rules (e.g. the proper ordering(s) of
    the parts of an assignment statement); and build data structures to
    keep track of all the information about ordering and structure

  * Assemble output: Use the data structures created during parsing to
    generate a new structure (component parts, sub-parts, ordering thereof,
    etc.) describing everything that must be given as output.

  * De-tokenize: Generate exact output text for each token in the output.

This program counts on RIES to do the first step; the other three are
performed by the &pf2if() function. It essentially does thr 3rd and
4th steps at the same time by generating stringified versions of the
(infix) syntax trees, and using the stack to implicitly perform the
2nd step and reorder the strings (partial expressions) as needed.

`;

# 'stack effect', as in RIES this is 'a' for constants, 'b' for
# one-argument functions and 'c' for two-argument functions
%seft = (
  '0' => 'a', '1' => 'a', '2' => 'a', '3' => 'a', '4' => 'a',
  '5' => 'a', '6' => 'a', '7' => 'a', '8' => 'a', '9' => 'a',
  'e' => 'a', 'f' => 'a', 'p' => 'a', 'x' => 'a',
  'C' => 'b', 'E' => 'b', 'l' => 'b', 'n' => 'b', 'q' => 'b',
  's' => 'b', 'r' => 'b', 'S' => 'b', 'T' => 'b', 'W' => 'b',
  '+' => 'c', '-' => 'c', '*' => 'c', '/' => 'c', '^' => 'c',
  'A' => 'c', 'L' => 'c', 'v' => 'c',
);

# Some languages define a "log of A to base B" function instead of
# "log to base B of A", If you want that, the arguments of 'L' need
# to be reversed.
$reverse{'L'} = 1; # 1=true, 0=false
# Others you might reverse: A=atan2(a,b)=arctan(b/a), v=root(a,b)=b^(1/a)

# Postfix to functional conversion. It's hard to even call this a "parser"
# because postfix parses itself. We do however need a stack of syntax
# trees, but these can be represented by their formatted output. Thus,
# instead of holding numeric results (as it would if this were a
# postfix interpreter), the stack holds unevaluated subexpressions each
# of which is simply a string of symbols with parentheses and commas.
sub pf2if
{
  my($postfix_expr) = @_;
  my(@stack); my($sp, $c, $sft, $nam, $arg1, $arg2);

  # We start the stack pointer at 2 to allow underflow, this is to prevent
  # a 'negative subscript' error from Perl in the event this function is
  # given a string that is incomplete or otherwise unparsable.
  $sp = 2;
  foreach $c (split('', $postfix_expr)) {
    $sft = $seft{$c}; $nam = $name{$c};
    if ($sft eq 'a') {
      # Push a constant onto the stack
      $stack[$sp++] = $nam;
    } elsif ($sft eq 'b') {
      # Get one argument from the stack
      $arg1 = $stack[--$sp];
      # Push function(arg1) onto the stack
      $stack[$sp++] = "$nam($arg1)";
    } elsif ($sft eq 'c') {
      # Get two arguments from the stack
      $arg2 = $stack[--$sp]; $arg1 = $stack[--$sp];
      # Push function(arg1,arg2) onto the stack
      if ($reverse{$c}) {
        # No, make that function(arg2,arg1) instead
        $stack[$sp++] = "$nam($arg2,$arg1)";
      } else {
        $stack[$sp++] = "$nam($arg1,$arg2)";
      }
    } else {
      # Unknown symbol
      return $postfix_expr;
    }
    if ($sp <= 2) {
      # It looks like we might get an array indexing error soon, avoid the
      # humiliation by exiting voluntarily!
      return $postfix_expr;
    }
  }
  # If the input was complete and well-formed, the stack will end up with
  # exactly 1 item on it.
  if ($sp == 3) {
    return $stack[--$sp];
  } # else, just return the original input unmodified
  return $postfix_expr;
} # End of pf.2if

# Example:
#   print (&pf2if("9p/5vs") . "\n"); exit(0);
# should print "square(root(div(9,pi),5))"

while ($arg = shift) {
  if ($arg =~ m/^-[-]?h(elp)?$/) {
    print $help; exit(0);
  } elsif (-f $arg) {
    close STDIN;
    open(STDIN, $arg);
  } else {
    die "Unknown argument or no such file: $arg\n";
  }
}

# A result from "ries -F0 1.2345" contains two of these 'symchars' strings
# with an equals sign between them and some extra text at the end
$result_line_regex = "^( +)($symchars) = ($symchars)( .+)\$";
# If your language uses the original POSIX regex API, then you need to
# do a "regex compile" now (such as re.compile() in Python)

$contains_brace_regex = "[{]"; # Or use something like mystring.contains("{")

while ($input_line = <>) {
  if (!($input_line =~ m/$contains_brace_regex/)) {
    # This is not a result item because it lacks the "{123}" score at the end
    print $input_line;
  } elsif ($input_line =~ m|$result_line_regex|) {
    # matched something like " xlC = 221nA*r  for x = T - 3.27774e-08 {108}"
    $pre = $1; $expr1 = $2; $expr2 = $3; $post = $4;
    $expr1 = &pf2if($expr1); $expr2 = &pf2if($expr2);
    print "$pre$expr1 = $expr2$post\n";
  } else {
    # Also not a result item
    print $input_line;
  }
}
