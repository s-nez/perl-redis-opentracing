package Redis::OpenTracing;

use strict;
use warnings;

use syntax 'maybe';

our $VERSION = 'v0.1.1';

use Moo;
use Types::Standard qw/HashRef Maybe Object Str Value is_Str/;

use OpenTracing::AutoScope;
use Scalar::Util 'blessed';



has 'redis' => (
    is => 'ro',
    isa => Object, # beyond current scope to detect if it is a Redis like client
    required => 1,
);



has '_redis_client_class_name' => (
    is => 'lazy',
    isa => Str,
);

sub _build__redis_client_class_name {
    blessed( shift->redis )
};



sub _operation_name {
    my ( $self, $method_name ) = @_;
    
    return $self->_redis_client_class_name . '::' . $method_name;
}



has 'tags' => (
    is => 'ro',
    isa => HashRef[Value],
    default => sub { {} }, # an empty HashRef
);



has '_peer_address' => (
    is => 'lazy',
    isa => Maybe[ Str ],
);

sub _build__peer_address {
    my ( $self ) = @_;
    
    return "@{[ $self->redis->{ server } ]}"
        if exists $self->redis->{ server };
    # currently, we're fine with any stringification of a blessed hashref too
    # but for Redis, Redis::Fast, Test::Mock::Redis, this is just a string
    
    return
}



our $AUTOLOAD; # keep 'use strict' happy

sub AUTOLOAD {
    my $self = shift;
    
    my $method_call    = do { $_ = $AUTOLOAD; s/.*:://; $_ };
    my $component_name = $self->_redis_client_class_name( );
    my $db_statement   = uc($method_call);
    my $operation_name = $self->_operation_name( $method_call );
    my $peer_address   = $self->_peer_address( );
    
    my $method_wrap = sub {
        OpenTracing::AutoScope->start_guarded_span(
            $operation_name,
            tags => {
                'component'     => $component_name,
                
                maybe
                'peer.address'  => $peer_address,
                
                %{ $self->tags( ) },
                
                'db.statement'  => $db_statement,
                'db.type'       => 'redis',
                'span.kind'     => 'client',
                
            },
        );
        
        return $self->redis->$method_call(@_);
    };
    
    # Save this method for future calls
    no strict 'refs';
    *$AUTOLOAD = $method_wrap;
    
    goto $method_wrap;
}



sub DESTROY { } # we don't want this to be dispatched



1;
