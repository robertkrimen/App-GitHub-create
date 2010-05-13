package App::GitHub::create;
# ABSTRACT: Create a github repository from the command-line

=head1 SYNOPSIS

    # Update the description of github:alice/example
    github-create --login alice --token 42fe60... --repository example --description "Xyzzy"

    # Pulling login and token from $HOME/.github
    github-create --repository example --description "Xyzzy"

=head1 DESCRIPTION

A simple tool for creating a new github repository

=head1 GitHub identity format ($HOME/.github or $HOME/.github-identity)

    login <login>
    token <token>

Optionally GnuPG encrypted

=cut

use strict;
use warnings;

use Config::Identity::GitHub;
use LWP::UserAgent;
use Getopt::Long qw/ GetOptions /;
my $agent = LWP::UserAgent->new;

sub create {
    my $self = shift;
    my %given = @_;
    my ( $login, $token, $name, $description, $homepage, $public );

    ( $name, $description, $homepage, $public ) =
        @given{qw/ name description homepage public /};
    defined $_ && length $_ or die "Missing name\n" for $name;

    ( $login, $token ) = @given{qw/ login token /};
    unless( defined $token && length $token ) {
        my %identity = Config::Identity::GitHub->load;
        ( $login, $token ) = @identity{qw/ login token /};
    }


    my @arguments;
    push @arguments, 'name' => $name if defined $name;
    push @arguments, 'description' => $description if defined $description;
    push @arguments, 'homepage' => $homepage if defined $homepage;
    push @arguments, 'public' => $public if defined $public and $public;

    my $uri = "https://github.com/api/v2/json/repos/create";
    my $response = $agent->post( $uri,
        [ login => $login, token => $token, @arguments ] );

    unless ( $response->is_success ) {
        die $response->status_line, ": ", $response->decoded_content, "\n";
    }

    return $response;
}

sub usage (;$) {
    my $error = shift;
    my $exit = 0;
    if ( defined $error ) {
        if ( $error ) {
            if ( $error =~ m/^\-?\d+$/ ) { $exit = $error }
            else {
                chomp $error;
                warn $error, "\n";
                $exit = -1;
            }
        }
    }
    warn <<_END_;

Usage: github-create [opt] --name <name>

    --login ...         Your github login
    --token ...         The github token associated with the given login

                        Although required, if a login/token are not given,
                        github-create will attempt to load it from 
                        \$HOME/.github or \$HOME/.github-identity (see
                        Config::Identity for more information)

    --name ...          The name of the repository to create (required)
    --description ...   A description of the repository (optional)
    --homepage ...      A homepage for the repository (optional)
    --private           The repository is private (default)
    --public            The repository is public

    --help, -h, -?      This help

_END_

    exit $exit;
}

sub run {
    my $self = shift;
    my @arguments = @_;

    my ( $login, $token, $help );
    my ( $name, $homepage, $description, $private, $public );

    usage 0 unless @arguments;

    {
        local @ARGV = @arguments;
        GetOptions(
            'help|h|?' => \$help,

            'login=s' => \$login,
            'token=s' => \$token,

            'name=s' => \$name,
            'description=s' => \$description,
            'homepage=s' => \$homepage,
    
            'private' => \$private,
            'public' => \$public,
        );
    }

    usage 0 if $help;

    unless ( defined $name && length $name ) {
        usage <<_END_;
github-create: Missing name (--name)
_END_
    }

    if ( $private and $public ) {
        usage <<_END_;
github-create: Repository cannot be both private AND public
_END_
    }
    $public = $public ? 1 : 0;

    eval {
        my $response = $self->create(
            login => $login, token => $token,
            name => $name, description => $description, homepage => $homepage, public => $public,
        );

        print $response->as_string, "\n";
    };
    if ($@) {
        usage <<_END_;
github-create: $@
_END_
    }
}

#    for my $option (keys %options) {
#        next unless $options{$option};
#        push @arguments, "values[has_$option]" => 'true';
#    }

#    --enable ...        Enable wiki, issues, and/or the downloads page
#                        Can be a series of options separated by a comma:
#                        
#                            all         Enable everything
#                            none        Disable everything
#                            wiki        Enable the wiki
#                            issues      Enable issues
#                            downloads   Enable downloads

#                        The default is 'none'

#    my %options;
#    my @enable = split m/\s*,\s*/, $enable;
#    for ( @enable ) {
#        s/^\s*//, s/\s*$//;
#        next unless $_;
#        if      ( m/^none$/i )      { undef %options }
#        elsif   ( m/^all$/i )       { %options = qw/ wiki 1 issues 1 downloads 1 / }
#        elsif   ( m/^wiki$/i )      { $options{lc $_} = 1 }
#        elsif   ( m/^issues$/i )    { $options{lc $_} = 1 }
#        elsif   ( m/^downloads$/i ) { $options{lc $_} = 1 }
#        else                        { usage <<_END_ }
#github-create: Unknown enable option: $_
#_END_
#    }
    
1;
