package XAO::testcases::FS::basic;
use strict;
use XAO::Utils;
use XAO::Objects;
use Error qw(:try);

use base qw(XAO::testcases::FS::base);

sub test_xaofs {
    my $self=shift;

    my $odb=$self->{odb};
    $self->assert(defined($odb) && ref($odb),
                  'Object database creating failure');

    my %matrix=(
        t1 => {
            path    => '/Customers/c2/name',
            result  => 'Test Customer #2',
        },
        t2 => {
            path    => 'xaofs://uri/Customers/c2/name',
            result  => 'Test Customer #2',
        },
        t3 => {
            path    => 'xaofs://collection/class/Data::Customer/2/name',
            result  => 'Test Customer #2',
        },
        t4 => {
            path    => 'xaofs://collection/class/Data::Customer',
            result  => 'XAO::DO::FS::Collection',
        },
        t5 => {
            path    => 'xaofs://collection/class/Data::Customer/',
            result  => 'XAO::DO::FS::Collection',
        },
        t6 => {
            path    => 'xaofs://uri/Customers',
            result  => 'XAO::DO::FS::List',
        },
    );

    foreach my $test (values %matrix) {
        my $path=$test->{path};

        my $got=$odb->fetch($path);
        my $expect=$test->{result};
        $self->assert((ref($got) || $got) eq $expect,
                      "Expected '$expect', got '$got'");
    }
}

sub test_objtype {
    my $self=shift;
    my $odb=$self->{odb};

    my $ot=$odb->objtype;
    $self->assert($ot eq 'Glue',
                  "Glue object returned wrong 'objtype' ($ot)");

    my $list=$odb->fetch('/Customers');
    $ot=$list->objtype;
    $self->assert($ot eq 'List',
                  "List object returned wrong 'objtype' ($ot)");

    my $hash=$list->get('c1');

    $ot=$hash->objtype;
    $self->assert($ot eq 'Hash',
                  "Hash object returned wrong 'objtype' ($ot)");

    $self->assert($hash->upper_class eq 'FS::Global',
                  "Wrong upper_class() for the customer Hash");
}

sub test_uri {
    my $self=shift;
    my $odb=$self->{odb};

    my $global=$odb->fetch('/');

    my $uri=$global->uri;
    $self->assert($uri eq '/',
                  "Global returned bad URI ('$uri' != '/')");

    $uri=$global->uri('Customers');
    $self->assert($uri eq '/Customers',
                  "Global returned bad URI ('$uri' != '/Customers')");

    my $list=$global->get('Customers');

    $uri=$list->uri;
    $self->assert($uri eq '/Customers',
                  "Customers returned bad URI ('$uri' != '/Customers')");

    $uri=$list->uri('c2');
    $self->assert($uri eq '/Customers/c2',
                  "Customers returned bad URI ('$uri' != '/Customers/c2')");

    my $hash=$odb->fetch('/Customers/c1');

    $uri=$hash->uri;
    $self->assert($uri eq '/Customers/c1',
                  "Hash returned bad URI ('$uri' != '/Customers/c1')");

    $uri=$hash->uri('name');
    $self->assert($uri eq '/Customers/c1/name',
                  "Hash returned bad URI ('$uri' != '/Customers/c1/name')");
}

sub test_upper_class {
    my $self=shift;
    my $odb=$self->{odb};

    my $got=$odb->upper_class('FS::Global');
    $self->assert(!defined($got),
                  "Got wrong upper class for Global (" . ($got || '') . ")");

    $got=$odb->upper_class('Data::Customer');
    $self->assert($got eq 'FS::Global',
                  "Got wrong upper class for Data::Customer ($got)");
}

1;
