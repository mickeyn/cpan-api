package MetaCPAN::Pod::XHTML;

use strict;
use warnings;

# Keep the coding style of Pod::Simple for consistency and performance.
# Pod::Simple::XHTML expects you to subclass and then override methods.

use parent 'Pod::Simple::XHTML';

sub start_X {
    $_[0]{_in_X_} = 1;
}

sub end_X {
    $_[0]{_in_X_} = 0;
    $_[0]{'scratch'}
        .= '<a id="' . $_[0]->idify( $_[0]{_last_X_} ) . '"></a>';
}

sub handle_text {
    if ( $_[0]{_in_X_} ) {
        $_[0]{_last_X_} = $_[1];
    }
    else {
        $_[0]->SUPER::handle_text( $_[1] );
    }
}

sub link_mappings {
    my $self = shift;
    if (@_) {
        $self->{_link_map} = $_[0];
    }
    $self->{_link_map};
}

sub resolve_pod_page_link {
    my ( $self, $module, $section ) = @_;
    my $link_map = $self->{_link_map} || {};
    if ( $module and my $link = $link_map->{$module} ) {
        $module = $link;
    }
    $self->SUPER::resolve_pod_page_link( $module, $section );
}

sub start_item_text {

    # see end_item_text
}

sub end_item_text {

    # idify =item content, reset 'scratch'
    my $id   = $_[0]->idify( $_[0]{'scratch'} );
    my $text = $_[0]{scratch};
    $_[0]{'scratch'} = '';

    # construct whole element here because we need the
    # contents of the =item to idify it
    if ( $_[0]{'in_dd'}[ $_[0]{'dl_level'} ] ) {
        $_[0]{'scratch'} = "</dd>\n";
        $_[0]{'in_dd'}[ $_[0]{'dl_level'} ] = 0;
    }

    $_[0]{'scratch'} .= qq{<dt id="$id">$text</dt>\n<dd>};
    $_[0]{'in_dd'}[ $_[0]{'dl_level'} ] = 1;
    $_[0]->emit;
}

# Custom handling of errata section

sub _gen_errata {
    return;    # override the default errata formatting
}

sub end_Document {
    my $self = shift;
    $self->_emit_custom_errata() if $self->{errata};
    $self->SUPER::end_Document(@_);
}

sub _emit_custom_errata {
    my $self = shift;

    my $tag = sub {
        my $name       = shift;
        my $attributes = '';
        if ( ref( $_[0] ) ) {
            my $attr = shift;
            while ( my ( $k, $v ) = each %$attr ) {
                $attributes .= qq{ $k="} . $self->encode_entities($v) . '"';
            }
        }
        my @body = map { /^</ ? $_ : $self->encode_entities($_) } @_;
        return join( '', "<$name$attributes>", @body, "</$name>" );
    };

    my @errors = map {
        my $line  = $_;
        my $error = $self->{'errata'}->{$line};
        (
            $tag->( 'dt', "Around line $line:" ),
            $tag->( 'dd', map { $tag->( 'p', $_ ) } @$error ),
        );
    } sort { $a <=> $b } keys %{ $self->{'errata'} };

    my $error_count = keys %{ $self->{'errata'} };
    my $s = $error_count == 1 ? '' : 's';

    $self->{'scratch'} = $tag->(
        'div',
        { id => "pod-errors" },
        $tag->( 'p', { class => 'title' }, "$error_count POD Error$s" ),
        $tag->(
            'div',
            { id => "pod-error-detail" },
            $tag->(
                'p',
                'The following errors were encountered while parsing the POD:'
            ),
            $tag->( 'dl', @errors ),
        ),
    );
    $self->emit;
}

1;

=pod

=head2 perldoc_url_prefix

Set perldoc domain to C<metacpan.org>.

=cut
