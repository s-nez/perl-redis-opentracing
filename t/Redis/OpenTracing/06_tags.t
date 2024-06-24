use Test::Most;

use strict;
use warnings;

use OpenTracing::Implementation qw/Test/;
use Test::OpenTracing::Integration;

subtest "Tags with default values" => sub {
    
    reset_spans;
    
    my $test_object = bless {}, 'MyTestApp::Default';
    
    $test_object->get_some_keys( );
    
    global_tracer_cmp_easy(
        [
            {
                operation_name => 'MyTestApp::Default::get_some_keys',
            },
            {
                operation_name => re( qr/Test::Mock::Redis::NoOp::keys$/ ),
                tags           => {
                    'component'     => 'Test::Mock::Redis::NoOp',
                    'db.statement'  => 'KEYS',
                    'db.type'       => 'redis',
                    'span.kind'     => 'client',
                }
            },
        ],
        "Got some expected spans for default instantiation"
    )
};



subtest "Tags with provided values" => sub {
    
    reset_spans;
    
    my $test_object = bless {}, 'MyTestApp::TagValues';
    
    $test_object->get_some_keys( );
    
    global_tracer_cmp_easy(
        [
            {
                operation_name => 'MyTestApp::TagValues::get_some_keys',
            },
            {
                operation_name => re( qr/Test::Mock::Redis::NoOp::keys$/ ),
                tags           => {
                    'component'     => 'Redis::TagValues',    # provided
                    'db.statement'  => 'KEYS',                # redis-command
                    'db.type'       => 'redis',               # hard coded
                    'peer.address'  => 'test://peer_address', # provided
                    'span.kind'     => 'client',              # hard coded
                }
            },
        ],
        "Got some expected spans for provided instantiation"
    )
};

done_testing;



package MyTestApp::Default;

use strict;
use warnings;

use lib 't/lib';

use OpenTracing::AutoScope;
use Redis::OpenTracing;
use Test::Mock::Redis::NoOp;

sub get_some_keys{
    OpenTracing::AutoScope->start_guarded_span( );
    
    my $self = shift;
    
    my $redis_test = Redis::OpenTracing->new(
        redis => Test::Mock::Redis::NoOp->mock_new( ),
    );
    
    return $redis_test->keys( );
    
}



package MyTestApp::TagValues;

use strict;
use warnings;

use lib 't/lib';

use OpenTracing::AutoScope;
use Redis::OpenTracing;
use Test::Mock::Redis::NoOp;

sub get_some_keys{
    OpenTracing::AutoScope->start_guarded_span( );
    
    my $self = shift;
    
    my $redis_test = Redis::OpenTracing->new(
        redis => Test::Mock::Redis::NoOp->mock_new( ),
        tags => {
            'component'     => 'Redis::TagValues',            # overrides
            'peer.address'  => 'test://peer_address',         # has no default
            'db.statement'  => 'BOOH',                        # redis-command
            'db.type'       => 'not-me',                      # 'redis'
            'span.kind'     => 'server',                      # 'client'
        }
    );
    
    return $redis_test->keys( );
    
}



1;
