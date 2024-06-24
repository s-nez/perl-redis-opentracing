use Test::More;
use Test::Exception;
use Test::Deep qw/superhashof re/;

use lib 't/lib';

use OpenTracing::Implementation qw/Test/;
use Test::OpenTracing::Integration;
use Test::Mock::Redis::NoOp;

use Redis::OpenTracing;

my $redis;

lives_ok {
    $redis = Redis::OpenTracing->new(
        redis => Test::Mock::Redis::NoOp->mock_new(),
    );
} "Instatiated and wrapped `Redis::NoOp` inside `Redis::OpenTracing`";

is $redis->ping, "PONG",
    "... and seems to be okay";

throws_ok {
    $redis->dies("Nope, not doing this");
} qr/^Nope, not doing this.*09_errors\.t line \d+\.$/s,
    "... and dies with the appropriate message reporting the caller";

global_tracer_cmp_easy(
    [
        {
            operation_name  => "Test::Mock::Redis::NoOp::ping",
            tags            => {
                'component'     => "Test::Mock::Redis::NoOp",
                'db.statement'  => "PING",
                'db.type'       => "redis",
                'span.kind'     => "client",
            },
        },
        {
            operation_name  => "Test::Mock::Redis::NoOp::dies",
            tags            => {
                'component'     => "Test::Mock::Redis::NoOp",
                'db.statement'  => "DIES",
                'db.type'       => "redis",
                'span.kind'     => "client",
                
                'error'         => 1,
                'message'       => re(qr/^Nope, not doing this.*/),
                'error.kind'    => "REDIS_EXCEPTION",
            },
        }
    ],
   "... and we do have the expected spans" 
);



done_testing();
