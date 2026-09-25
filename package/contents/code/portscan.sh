#!/bin/bash
# My IP & Geo - TCP port check for one host on the local network (Scanner -> Ports).
# Non-blocking TCP connects, up to 1000 at a time, in one Perl process. Perl comes from perl-base,
# an Essential package that is always installed on Debian/Ubuntu, so no root, nmap, netcat or
# extra packages are needed; the full range 1-65535 takes seconds on a LAN.
# It only checks whether a port accepts a TCP connection and sends no data.
#
#   portscan.sh <host> <from>-<to> [runid]
#
# Output:
#   SCAN <host> <ports>
#   OPEN <port> <service>          one line per open port, lowest first
#   DONE <open_count>
#   TIME <seconds>
#   ERROR <message>                on bad input or when the scan could not finish
# runid only makes the command string unique so the executable engine re-runs it.

host=$1
spec=$2

# Only a bare IPv4/IPv6 literal is accepted, so the value can carry nothing but an address
case "$host" in
    ''|*[!0-9.:a-fA-F]*) echo "ERROR invalid host"; exit 0 ;;
esac

# "from-to", each end clamped to 1..65535, low end first
from=${spec%%-*}; to=${spec##*-}
case "$from" in ''|*[!0-9]*) echo "ERROR bad range"; exit 0 ;; esac
case "$to" in ''|*[!0-9]*) echo "ERROR bad range"; exit 0 ;; esac
clamp() {
    local v=$1
    [ ${#v} -gt 5 ] && v=65535
    v=$((10#$v))
    [ "$v" -lt 1 ] && v=1
    [ "$v" -gt 65535 ] && v=65535
    echo "$v"
}
from=$(clamp "$from"); to=$(clamp "$to")
if [ "$from" -gt "$to" ]; then tmp=$from; from=$to; to=$tmp; fi

if ! command -v perl >/dev/null 2>&1; then echo "ERROR perl not found"; exit 0; fi

echo "SCAN $host $((to - from + 1))"
# Microseconds; the decimal separator of $EPOCHREALTIME follows the locale ("." or ",")
t0=${EPOCHREALTIME//[.,]/}

# Resolve the neighbour (ARP) first: while it is unknown the kernel queues only a few hundred
# packets, so the first burst of connects could be lost
ping -c 1 -W 1 "$host" >/dev/null 2>&1

out=$(timeout 170 perl - "$host" "$from" "$to" 1000 0.3 <<'PERL'
use strict;
use warnings;
use Socket qw(AF_INET AF_INET6 SOCK_STREAM inet_pton pack_sockaddr_in pack_sockaddr_in6);
use Fcntl qw(F_GETFL F_SETFL O_NONBLOCK);

my ($host, $from, $to, $inflight, $wait) = @ARGV;
my ($family, $addr);
if (defined($addr = inet_pton(AF_INET, $host)))     { $family = AF_INET }
elsif (defined($addr = inet_pton(AF_INET6, $host))) { $family = AF_INET6 }
else { print "ERROR invalid host\n"; exit 0 }

my @open;
my $port = $from;
while ($port <= $to) {
    # Start up to $inflight connects without waiting for them
    my %pending;                                        # fileno => [handle, port]
    while ($port <= $to && keys(%pending) < $inflight) {
        socket(my $fh, $family, SOCK_STREAM, 0) or last;   # out of descriptors: finish these first
        fcntl($fh, F_SETFL, fcntl($fh, F_GETFL, 0) | O_NONBLOCK);
        my $sa = $family == AF_INET ? pack_sockaddr_in($port, $addr) : pack_sockaddr_in6($port, $addr);
        if (connect($fh, $sa)) { push @open, $port; close $fh }
        else { $pending{fileno $fh} = [$fh, $port] }
        $port++;
    }
    if (!%pending && $port <= $to) { print "ERROR no free sockets\n"; exit 0 }

    # A socket becomes writable when its connect has finished: connected (open) or refused (closed).
    # Ports without any answer within $wait seconds are filtered.
    my $left = $wait;
    while (%pending && $left > 0) {
        my $want = '';
        vec($want, $_, 1) = 1 for keys %pending;
        my $ready = $want;
        my ($n, $timeleft) = select(undef, $ready, undef, $left);
        last if !defined $n || $n <= 0;
        $left = $timeleft;
        for my $fd (keys %pending) {
            next unless vec($ready, $fd, 1);
            my ($fh, $p) = @{ delete $pending{$fd} };
            push @open, $p if defined getpeername($fh);    # only a connected socket has a peer
            close $fh;
        }
    }
    close $_->[0] for values %pending;
}

for my $p (sort { $a <=> $b } @open) {
    my $svc = getservbyport($p, 'tcp');
    print "OPEN $p ", (defined $svc ? $svc : ''), "\n";
}
print "DONE ", scalar(@open), "\n";
PERL
)
rc=$?

case "$out" in
    *DONE*) printf '%s\n' "$out" ;;
    *ERROR*) printf '%s\n' "$out" | grep -m1 '^ERROR'; exit 0 ;;
    *) [ "$rc" -eq 124 ] && echo "ERROR scan took too long" || echo "ERROR scan failed"; exit 0 ;;
esac

t1=${EPOCHREALTIME//[.,]/}
ms=$(( (10#$t1 - 10#$t0) / 1000 ))
printf 'TIME %d.%d\n' $((ms / 1000)) $((ms % 1000 / 100))
