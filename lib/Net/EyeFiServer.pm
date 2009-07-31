package Net::EyeFiServer;

use strict;
use 5.008_001;

our $VERSION = '0.01';

use XML::LibXML;
use Digest::MD5;
use Archive::Tar;

sub new {
    my $class = shift;
    my %params = @_;
    my $upload_key = delete $params{upload_key};
    my $xml_parser = XML::LibXML->new();
    return bless { upload_key => $upload_key, xml_parser => $xml_parser }, $class;
}

sub upload_key { $_[0]->{upload_key} }
sub xml_parser { $_[0]->{xml_parser} }

sub handle {
    my ($self, $method, $params, $fh, $cb) = @_; 
    my $cmd = 'CMD_' . $method;

    return unless $self->can($cmd);

    my $result = $self->$cmd($params, $fh, $cb);
    $self->build_response_envelope($method, $result)
}

sub calc_credential {
    my $self = shift;
    my ($macaddress, $cnonce, $snonce) = @_;
    my $string = join('', $macaddress, $cnonce, $self->upload_key, $snonce);
    my @bin;
    while( $string =~ m/[0-9a-f]{2}/gi ) {
        push @bin, ord pack("H2", $&) 
    }
    return Digest::MD5::md5_hex(pack "C*", @bin);
}

sub build_response_envelope {
    my ($self, $method, $params) = @_;
    my $doc = XML::LibXML->createDocument( "1.0", "UTF-8" );
    my $env = $doc->createElement('SOAP-ENV:Envelope');
    $env->setAttribute('xmlns:SOAP-ENV', 'http://schemas.xmlsoap.org/soap/envelope/');

    my $body = $doc->createElement('SOAP-ENV:Body');

    my $res = $doc->createElement($method . 'Response');
    $res->setAttribute('xmlns', 'http://localhost/api/soap/eyefilm');

    while (my ($k, $v) = each %$params) {
        my $e = $doc->createElement($k);
        $e->appendChild($doc->createTextNode($v));
        $res->appendChild($e);
    }
    $body->appendChild($res);
    $env->appendChild($body);
    $doc->setDocumentElement($env);
    return $doc->toString;
}

sub parse_request_envelope {
    my ($self, $soap_env) = @_;
    my $tree = $self->xml_parser->parse_string($soap_env);
    my $xbase_path = '/SOAP-ENV:Envelope/SOAP-ENV:Body';
    my $body = $tree->findnodes($xbase_path)->[0];
    my $method = $body->firstChild->nodeName;
    $method =~ s/^\w+://;
    my $nodes = $body->firstChild->childNodes;
    my $params = +{ map {$_->nodeName => $_->textContent } @$nodes };
    return $method, $params;
}

sub CMD_StartSession {
    my ($self, $args) = @_; 
    my $macaddress            = delete $args->{macaddress};
    my $cnonce                = delete $args->{cnonce};
    my $transfermode          = delete $args->{transfermode};
    my $transfermodetimestamp = delete $args->{transfermodetimestamp};

    my $credential = $self->calc_credential($macaddress, $cnonce, '');
    my $snonce = Digest::MD5::md5_hex(time + $$);

    push @{ $self->{session} }, { snonce => $snonce, macaddress => $macaddress };

    return {snonce => $snonce, credential => $credential};
}

sub CMD_GetPhotoStatus {
    my ($self, $args) = @_; 
    my $macaddress = delete $args->{macaddress};
    my $credential = delete $args->{credential};
    my ($session) = grep {$_->{macaddress} eq $macaddress} @{ $self->{session} };
    unless ($session) {
        ## 
    }
    my $snonce = $session->{snonce};
    unless ($credential eq $self->calc_credential($macaddress, '', $snonce) ) {
        ## 
    }

    ## GetPhotoStatusResponse
    my $fileid = 10000;
    my $offset = 0;

    return {fileid => $fileid, offset => $offset};
}

## MIME
sub CMD_UploadPhoto  {
    my ($self, $args, $fh, $cb) = @_; 
    my $fileid        = delete $args->{fileid};
    my $macaddress    = delete $args->{macaddress};
    my $filename      = delete $args->{filename};
    my $filesize      = delete $args->{filesize};
    my $filesignature = delete $args->{filesignature};
    my $encryption    = delete $args->{encription};
    my $flags         = delete $args->{flags};

    my $tar = Archive::Tar->new;
    seek($fh, 0, 0);
    $tar->read($fh);

    for my $file ( $tar->list_files() ) {
        if ($file . '.tar' eq $filename) {
            my $data = $tar->get_content( $file );
            $cb->($data);
        }
    }

    return { success => 'true' }
}

1;
__END__

=encoding utf-8

=for stopwords

=head1 NAME

Net::EyeFiServer -

=head1 SYNOPSIS

  use Net::EyeFiServer;

=head1 DESCRIPTION

Net::EyeFiServer is

=head1 AUTHOR

Masayoshi Sekimura E<lt>sekimura@cpan.orgE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

=cut
