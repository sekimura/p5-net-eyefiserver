#!/usr/bin/env perl

use Mojolicious::Lite;

use Net::EyeFiServer;

### you can find your own UploadKey in Settings.xml
my $s = Net::EyeFiServer->new( upload_key => 'XXXX-YOUR-UPLOAD-KEY-XXXXXXXXXXx' );

any '/api/soap/eyefilm/v1' => sub {
    my $self = shift;
    my ($method, $params) = $s->parse_request_envelope($self->req->body);
    my $xml = $s->handle($method, $params);
    $self->render(text => $xml);
};

any '/api/soap/eyefilm/v1/upload' => sub {
    my $self = shift;
    my $soap_envelope;
    my $fh;
    for my $part (@{ $self->req->content->parts }) {
        my $content_disposition = $part->headers->content_disposition;
        if ($content_disposition =~ /SOAPENVELOPE/) {
            $soap_envelope = $part->build_body;
        }
        if ($content_disposition =~ /FILENAME/) {
            $fh = $part->file->handle;
        }
    }
    my ($method, $params) = $s->parse_request_envelope($soap_envelope);
    my $xml = $s->handle($method, $params, $fh, sub{
        warn 'XXXX ' . length $_[0]; ### image file data;
    });
    $self->render(text => $xml);
};

shagadelic;
__DATA__

@@ index.html.eplite
% my $self = shift;
% $self->stash(layout => 'funky');
Yea baby!

@@ layouts/funky.html.eplite
% my $self = shift;
<!html>
    <head><title>Funky!</title></head>
    <body>
        <%= $self->render_inner %>
    </body>
</html>
