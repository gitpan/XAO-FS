=head1 NAME

XAO::DO::FS::List - List class for XAO::FS

=head1 SYNOPSIS

 my $customers_list=$odb->fetch('/Customers');

 my $customer=$customers_list->get('cust0001');

=head1 DESCRIPTION

List object usually used as is without overwriting it. The XAO
class name for the list object is FS::List.

A list object provides methods for managing a list of FS::Hash objects
of the same class -- storing, retrieving and searching on them.

List class shares most of the API with the Hash class.

Here is the list of all List methods (alphabetically):

=over

=cut

###############################################################################
package XAO::DO::FS::List;
use strict;
use XAO::Utils;
use XAO::Objects;

use base XAO::Objects->load(objname => 'FS::Glue');

use vars qw($VERSION);
$VERSION=(0+sprintf('%u.%03u',(q$Id: List.pm,v 2.1 2005/01/14 00:23:54 am Exp $ =~ /\s(\d+)\.(\d+)\s/))) || die "Bad VERSION";

###############################################################################

=item check_name ()

Object names in lists have nearly the same set of restrains as
in hashes with just one exception - they can start from a digit.
Such behavior might be extended to hashes in later versions to
eliminate this difference.

For example, 123ABC456 is a legal Hash id inside of a List, but
is not a legal property ID or List ID inside of a Hash.

=cut

sub check_name ($$) {
    my $self=shift;
    my $name=shift;
    return (defined($name) &&
           $name =~ /^[a-z0-9_]+$/i &&
           length($name)<=$self->key_length);
}

###############################################################################

=item container_key ()

Returns key that refers to the current List in the upper level Hash.

=cut

# defined in Glue.

###############################################################################

=item container_object ()

Returns a reference to the hash that contains
current list.

Example:

 my $customer=$orders_list->container_object();

Do not abuse this method, it involves a lot of overhead and can slow
your application down if abused.

=cut

sub container_object ($) {
    my $self=shift;

    my $base_name=$$self->{base_name};
    my $base_id=$$self->{base_id};
    $base_name && $base_id ||
        $self->throw("container_object - the object was not retrieved from the database");

    if($base_name eq 'FS::Global') {
        return $self->_glue->fetch('/');
    }

    my $list_base_name=$self->_glue->upper_class($base_name);
    my $key_name=$self->_glue->_list_key_name($base_name,$list_base_name);

    ##
    # This is an optimisation for the case where current object has an
    # URI already. It might not have it if container_object() is called
    # from new() to determine URI in case of Collection.
    #
    my $uri=$self->uri;
    if(defined($uri)) {
        my @path=split(/\/+/,$uri);
        $uri=join('/',@path[0..$#path-1]);
    }

    XAO::Objects->new(
        objname => $base_name,
        glue => $self->_glue,
        unique_id => $base_id,
        key_name => $key_name,
        list_base_name => $list_base_name,
        uri => $uri,
    );
}

###############################################################################

=item delete ($)

Deletes object from the list - first calls destroy on the object to
recursively delete its content and then drops it from the list.

=cut

sub delete ($$) {
    my $self=shift;
    my $name=shift;

    if($$self->{detached}) {
        $self->throw("delete - is not implemented yet for detached mode");
    } else {
        $self->_list_unlink_object($name);
    }
}

###############################################################################

=item describe ()

Describes itself, returns a hash reference with at least the following
elements:

 type       => 'list'
 class      => class name of Hashes stored inside
 key        => key name

=cut

sub describe ($;$) {
    my $self=shift;
    return {
        type    => @_ ? 'hash' : 'list',
        class   => $$self->{class_name},
        key     => $$self->{key_name},
    };
}

###############################################################################

=item detach ()

Detaches current object from the database. Not implemented, but safe to
use in read-only situations.

=cut

sub detach ($) {
    ## Nothing
}

###############################################################################

=item exists ($)

Checks if an object with the given name exists in the list and returns
boolean value.

=cut

sub exists ($$) {
    my $self=shift;
    my $name=shift;
    $self->_list_exists($name);
}

###############################################################################

=item get (@)

Retrieves a Hash object from the List using the given name.

As a convenience you can pass more then one object name to the get()
method to retrieve multiple Hash references at once.

If an object does not exist an error will be thrown.

=cut

sub get ($$) {
    my $self=shift;

    my @results=map {
        my $id=$self->_find_unique_id($_) ||
            throw $self "get - no such object ($_, uri=".$self->uri.")";

        $self->check_name($_) ||
            throw $self "get - wrong name ($_)";

        XAO::Objects->new(
            objname => $$self->{class_name},
            glue => $self->_glue,
            uri => $self->uri($_),
            unique_id => $id,
            key_name => $$self->{key_name},
            key_value => $_,
            list_base_name => $$self->{base_name},
            list_base_id => $$self->{base_id},
            list_key_value => $$self->{key_value},
        );
    } @_;

    @_==1 ? $results[0] : @results;
}

###############################################################################

=item get_new ()

Convenience method that returns new empty detached object of the type,
that list can store.

=cut

sub get_new ($) {
    my $self=shift;
    $self->_glue->new(objname => $$self->{class_name});
}

###############################################################################

=item glue ()

Returns the Glue object which was used to retrieve the current object
from.

=cut

# Implemented in Glue

###############################################################################

=item key_length

Returns key length for the given list. Default is 30.

=cut

sub key_length ($) {
    my $self=shift;
    return $$self->{key_length} || 30;
}

###############################################################################

=item keys ()

Returns unsorted list of all keys for all objects stored in that list.

=cut

sub keys ($) {
    my $self=shift;

    if($$self->{detached}) {
        $self->throw("keys - is not implemented yet for detached mode");
    } else {
        @{$self->_list_keys()};
    }
}

###############################################################################

=item new (%)

You cannot use this method directly. Use some equivalent of the
following code to get List reference:

 $hash->add_placeholder(name => 'Orders',
                        type => 'list',
                        class => 'Data::Order',
                        key => 'order_id');

....

 my $orders_list=$hash->get('Orders');

=cut

sub new ($%) {
    my $class=shift;
    my $self=$class->SUPER::new(@_);
    my $args=get_args(\@_);
    $$self->{class_name}=$args->{class_name};
    $$self->{base_name}=$args->{base_name};
    $$self->{base_id}=$args->{base_id};
    $$self->{key_value}=$args->{key_value};

    $self->_list_setup();

    if(! defined($$self->{uri})) {
        my $uri=$$self->{key_value};
        my $p=$self;
        while(defined($p=$p->container_object)) {
            my $ck=$p->container_key();
            $ck='' unless defined($ck);
            $uri=$ck . '/' . $uri;
        }
        $$self->{uri}=$uri;
    }

    $self;
}

###############################################################################

=item objtype ()

For all List objects always return a string 'List'.

=cut

sub objtype ($) {
    'List';
}

###############################################################################

=item put ($;$)

The only difference between list object's put() and data object's put()
is that key argument is not required. Unique key would be generated and
returned from the method if only one argument is given.

Key is guaranteed to consist of up to 20 alphanumeric characters. Key
would uniquely identify stored object in the current list scope, it does
not have to be unique among all objects of that class.

Value have to be a reference to an object of the same class as was
defined when that list object was created.

Example of adding new object into list:

 my $customer=XAO::Objects->new(objname => 'Data::Customer');
 my $id=$custlist->put($customer);

Attempt to put already attached data object into an attached list under
the same key name is meaningless and would do nothing.

B<Note:> An object stored by calling put() method is not modified and
remains in detached state if it was detached. If an object already
existed in the list under the same ID - its content would be totally
replaced by new object's content. It is safe to call put() to store
attached object under new name - the object would be cloned. In order to
retrieve new stored object from database you will have to call get().

=cut

sub put ($$;$) {
    my $self=shift;

    my ($value,$name);
    if(@_ == 1) {
        $name=undef;
        $value=$_[0];
    }
    else {
        ($name,$value)=@_;
        $self->check_name($name) ||
            throw $self "put - wrong name (name=$name, class=$$self->{class_name}";
    }

    if($$self->{detached}) {
        $self->throw("put - is not implemented yet for detached mode");
    } else {
        $self->_list_store_object($name,$value);
    }
}

###############################################################################

=item search (@)

Returns a reference to the list of IDs of objects corresponding to the
given criteria.

Takes a perl array or perl array reference of the following format:

 [ [ 'first_name', 'ws', 'a'], 'or', [ 'age', 'gt', 20 ] ]

All innermost conditions consist of exactly three elements -- first is
an object property name, second is a comparison operator and third is
some arbitrary value to compare field with or array reference.

As a convenience if right hand side value refers to an array in
condition then the meaning of that block is to compare given field
using given operator with all listed values and join results using OR
logical operator. These two examples are completely equal and would be
translated to the same database query:

 my $r=$list->search('name', 'wq', [ 'big', 'ugly' ]);

 my $r=$list->search([ 'name', 'wq', 'big' ], 
                     'or',
                     [ 'name', 'wq', 'ugly' ]);

It is possible to search on properties of some objects related to the
objects in the list. Let's say you have a list with specification values
inside of a product. To search for products having specific value in
their specification you would then do:

 my $r=$list->search(['Specification/name', 'eq', 'Width'],
                     'and',
                     ['Specification/value', 'eq', '123']);

You are not limited to object down the tree, you can search on object up
the tree as well. Obviously this is mostly useful for collection objects
because otherwise there is a single object on top and search turns into
boolean yes/no ordeal.

Example:

 my $r=$invoices->search([ '/Customers/name', 'cs', 'John' ],
                         'and',
                         [ '../gross_premium', 'lt', 1000 ]);

Sometimes it might be necessary to check is a pair of objects inside of
some container have specific properties. This can be achieved with
instance specificators:

 my $r=$products->search([ [ 'Spec/1/name', 'eq', 'Width' ],
                           'and',
                           [ 'Spec/1/value', 'eq', '123' ],
                         ],
                         'and',
                         [ [ 'Spec/2/name', 'eq', 'Height' ],
                           'and',
                           [ 'Spec/2/value', 'eq', '345' ],
                         ]);

Numbers 1 and 2 here suggest that first name/value pair must be checked
on the same object, while the second - on another. Numbers do not have
any meaning by themselves - 1 and 2 can be substituted with 234 and 345
without changing effect in any way. Some very complex criteria can
be expressed this way and in most cases execution by the underlying
database layer will be quite optimal as no postprocessing is usually
required.

Another example is to use asterisk which means "assume a new instance
every time". This can be useful if we want to find an object which
container contains a couple of objects each satisfying some simple
criteria. For instance, to find an imaginary person profile that has
both sound and image attached:

 my $r=$profiles->search([ 'Files/*/mime_type', 'sw', 'image/' ],
                         'and',
                         [ 'Files/*/mime_type', 'sw', 'audio/' ]);

In theory bizarre cases like this should work as well, although no good
example of real life usage comes to mind:

 my $r=$list->search([ '../../A/1/B/2/C/name', 'cs', 't1' ],
                     'and',
                     [ '/X/A/2/B/1/C/desc', 'eq', 't2' ]);

See also 'index' option below for a way to suggest a most effective
index.

This can be extended as deep as you want. See also collection()
method on Glue and L<XAO::DO::FS::Collection> for
additional search capabilities.

Multiple blocks may be combined into complex expressions using logical
operators.

Comparison operators:

=over

=item cs

True if the field contains given string. There are no limitations as to
what could be in the string. Having dictionary on the field will not
speed up search.

=item eq

True if equal.

=item ge

True if greater or equal.

=item gt

True if greater.

=item le

True if less or equal.

=item lt

True if less.

=item ne

True if not equal.

=item sw

True if property starts with the given string. For example ['name',
'sw', 'mar'] will match 'Marie Ann', but will not match 'Ann Marie'.

In most databases (MySQL included) this type of search is optimized
using indexes if they are available. Consider making the field indexable
if you plan to perform this type of search frequently.

=item wq

True if property contains the given word completely. For example
['name', 'wq', 'ann'] would match 'Ann Peters' and 'Marie Ann', but
would not match 'Annette'.

For best performance please make this kind of search only on fields of
type 'words' -- in that case the search is performed by dictionary and
is very fast.

=item ws

True if property contains a word that starts with the given
text. For example ['name', 'ws', 'an'] would match 'Andrew'
and 'Marie Ann', but 'Joann' would not match.

Works best on fields of type 'words'.

=back

Logical operators:

=over

=item and - true if both are true (has an alias -- '&&')

=item or - true if either one is true (has an alias -- '||')

=back

Examples:

 ##
 # Search for persons in the given age bracket
 #
 my $list=$persons->search([ 'age', 'ge', 25 ],
                           'and',
                           [ 'age', 'le', 35 ]);

 ##
 # A little more complex search.
 #
 my $list=$persons->search([ 'name', 'ws', 'john' ],
                           'and',
                           [ [ 'balance', 'ge', 10000 ],
                             'or',
                             [ 'rating', 'ge', 2.5 ]
                           ]);

The search() method can also accept additional options that can alter
results. Supported options are:

=over

=item orderby

To sort results using any field in either ascending or descending
order. Example:

 my $list=$persons->search('age', 'gt', 60, {
                               'orderby' => [
                                   ascend => 'first_name',
                                   descend => 'second_name',
                               ]
                          });

B<Note>, that you pass an array reference, not a hash reference to
preserve the order of arguments.

If you want to order using just one field it is safe to pass that field
name without wrapping it into array reference (sorting will be performed
in ascending order then):

 my $list=$persons->search('age', 'gt', 60, {
                               'orderby' => 'first_name'
                          });

B<Caveats:> There is no way to alter sorting tables that would be used
by the database. It is generally safe to assume that english letters and
digits would be sorted in the expected way. But there is no guarantee of
that.

Remember that even though you sort results on the content of a field it
is not that field that would be returned to you, you will still get a
list of object IDs unless you also use 'result' option.

=item distinct

To only get the rows that have unique values in the given
field. Example:

 my $color_ids=$products->search('category_id', 'eq', 123, {
                                    'distinct' => 'color'
                                }); 

=item debug

Turns on debug messages in the underlying driver. Messages will be
printed to standard error stream and their content depends on the
specific driver. Usually that would be a fully prepared SQL query just
before sending it to the SQL engine.

=item index

Accepts one argument -- a field name (or a path to a field) that should
be used as an index. Normally you do not need to use this option as
in most cases underlying driver/database will make a right decision
automatically. This might make sense together with 'debug' option and
manual checking of specific queries performance.

Example which might make sense if you know for sure that restriction by
image will significantly reduce number of hits, while ages range leaves
too many matches open for checks.

 my $r=$list->search([ [ 'age', 'gt', 10 ],
                       'and',
                       [ 'age', 'lt', 60 ],
                     ],
                     'and',
                     [ 'Files/mime_type', 'sw', 'image/' ],
                     { index => 'Files/mime_type' });

=item limit

Indicates that you are only interested in some limited number of results
allowing database to return just as many and therefor optimize the query
or data transfer.

Remember, that you can still get more results then you ask for if
underlying database does not support this feature.

 my $subset=$persons->search('eye_color','eq','brown', {
                                 'limit' => 100
                            });

=item result

Note: [Not completely implemented yet]

Be default search() method returns a reference to an array of object
keys. Result options allows you to alter that behavior.

Generally you can pass single description of return value or multiple
descriptions as an array reference. In the first case what you get then
is array of scalars, in the second case -- you get an array of arrays of
scalars.

Description of return value can be a scalar -- in that case it is simply
a name of field in the database; or it can be a hash reference. For hash
reference the only required field is 'type', that determines type of the
result. Other parameters in the hash depend on the specific type.

Recognized types are:

=over

=item count

No other parameters, return number of would-be results for the
search. Resulting array will have only one row if 'count' is used.

=item key

Returns object ID, just the same as would be returned by default.

=item sum

Returns arithmetic sum of all 'name' fields in the resulting set.

=back

Examples:

 my $rr=$data->search('last_name','cs','smit', {
                    orderby => 'last_name',
                    result => [qw(id last_name first_name age)]
                });

 my $rr=$data->search({
                    result => {
                        type    => 'count',
                    },
                 });
 my $count=$rr->[0];

 my $rr=$data->search({
                    result => [ {
                        type    => 'count',
                    }, {
                        type    => 'sum',
                        name    => 'gross_rev',
                    }
                ] });
 my ($count,$sum)=@{$rr->[0]};

=back

Beware that these options usually significantly decrease search
performance. Only use them when you would do sorting or select unique
rows in your code anyway.

As a degraded case of search it is safe to pass nothing or just options
to select everything in the given list. Examples:

 ##
 # These two lines are roughly equivalent. Note that you get an array
 # reference in the first line and an array itself in the second.
 #
 my $keys=$products->search();

 my @keys=$products->keys();

 ##
 # This is the way to get all the keys ordered by price.
 #
 my $keys=$products->search({ orderby => 'price' });

=cut

sub search ($@) {
    my $self=shift;

    if($$self->{detached}) {
        $self->throw("search - is not implemented yet for detached mode");
    } else {
        $self->_list_search(@_);
    }
}

###############################################################################

=item values ()

Returns a list of all Hash objects in the list.

B<Note:> the order of values is the same as the order of keys returned
by keys() method. At least until you modify the object directly on
indirectly. It is not recommended to use values() method for the reason
of pure predictability.

=cut

# implemented in Glue.pm

###############################################################################

=item uri ($)

Returns complete URI to either the object itself (if no argument is
given) or to a property with the given name.

That URI can then be used to retrieve a property or object using
$odb->fetch($uri). Be aware, that fetch() is relatively slow method and
should not be abused.

Example:

 my $uri=$customer->uri;
 print "URI of that customer is: $uri\n";

=cut

# Implemented in Glue

###############################################################################
1;
__END__

=back

=head1 AUTHORS

Copyright (c) 2005 Andrew Maltsev

Copyright (c) 2001-2004 Andrew Maltsev, XAO Inc.

<am@ejelta.com> -- http://ejelta.com/xao/

=head1 SEE ALSO

Further reading:
L<XAO::FS>,
L<XAO::DO::FS::Hash> (aka FS::Hash),
L<XAO::DO::FS::Glue> (aka FS::Glue).

=cut
