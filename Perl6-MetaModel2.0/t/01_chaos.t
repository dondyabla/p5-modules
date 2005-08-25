#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 52;
use Test::Exception;

do 'lib/chaos.pl';

## test the opaque instance containers

my $i;
$i = ::create_opaque_instance(\$i, (foo => 1));
ok(ref($i), 'Dispatchable');

is(::opaque_instance_id($i), 1, '... got the right ID');
is(::opaque_instance_class($i), $i, '... got the right class');
is_deeply(
    ::opaque_instance_attrs($i), 
    { foo => 1 }, 
    '... got the right attrs');
    
my $j = ::create_opaque_instance(\$i, (bar => 1));
ok(ref($j), 'Dispatchable');

is(::opaque_instance_id($j), 2, '... got the right ID');    
is(::opaque_instance_class($j), $i, '... got the right class');
is_deeply(
    ::opaque_instance_attrs($j), 
    { bar => 1 }, 
    '... got the right attrs');
    
## test out some of the global functions ...

dies_ok { ::SELF() } '... cannot call $?SELF outside of a valid context';
dies_ok { ::CLASS() } '... cannot call $?CLASS outside of a valid context';
    
## test the method constructors

{
    my $m = ::make_method(sub { return 'Foo' }, $i);
    ok(ref($m), 'Perl6::Method');

    is($m->(), 'Foo', '... got the right return value');

    my $m2 = ::make_method(sub { return ::SELF() }, $i);
    ok(ref($m2), 'Perl6::Method');

    is($m2->('Bar'), 'Bar', '... got the right return value');
    
    my $m3 = ::make_method(sub { return ::CLASS() }, $i);
    ok(ref($m3), 'Perl6::Method');

    is($m3->(), $i, '... got the right return value');    
}

{
    my $m = ::make_class_method(sub { return 'Foo::Bar' }, $i);
    ok(ref($m), 'Perl6::ClassMethod');

    is($m->(), 'Foo::Bar', '... got the right return value');
    
    my $m2 = ::make_class_method(sub { return ::SELF() }, $i);
    ok(ref($m2), 'Perl6::ClassMethod');

    is($m2->('Bar::Baz'), 'Bar::Baz', '... got the right return value');    
    
    my $m3 = ::make_class_method(sub { return ::CLASS() }, $i);
    ok(ref($m3), 'Perl6::Method');

    is($m3->(), $i, '... got the right return value');       
}

{
    my $m = ::make_submethod(sub { return 'Baz' }, $i);
    ok(ref($m), 'Perl6::Submethod');
    is($m->($i), 'Baz', '... got the right return value');
    
    my $m2 = ::make_submethod(sub { return 'Baz' }, $i);
    ok(ref($m2), 'Perl6::Submethod');
    is($m2->($j), 'Baz', '... got the right return value');    

    my $m3 = ::make_submethod(sub { return ::SELF() }, $i);
    ok(ref($m3), 'Perl6::Submethod');
    is($m3->($j), $j, '... got the right return value');    
    
    my $m4 = ::make_submethod(sub { return ::CLASS() }, $i);
    ok(ref($m4), 'Perl6::Submethod');
    is($m4->($j), $i, '... got the right return value');        
    
    {
        no strict 'refs';
        no warnings 'redefine';
        
        *{'::next_METHOD'} = sub { "fake next_METHOD" };
    
        my $m = ::make_submethod(sub { return 'Baz' }, $j);
        ok(ref($m), 'Perl6::Submethod');
        is($m->($i), 'fake next_METHOD', '... got the right return value');    
    }
    
    {
        my $m = ::make_submethod(sub { return 'Baz' }, $j);
        ok(ref($m), 'Perl6::Submethod');
        ok($Perl6::Submethod::FORCE, '... $Perl6::Submethod::FORCE is defined');
        is($m->($Perl6::Submethod::FORCE, $i), 'Baz', '... got the right return value (with force call)');          
    }
}

{
    
    my $pm = ::make_private_method(sub { return 'Foo' }, $i);
    ok(ref($pm), 'Perl6::PrivateMethod');    

    my $m = ::make_method(sub { $pm->() }, $i);
    ok(ref($m), 'Perl6::Method');
    
    is($m->(), 'Foo', '... called private method successfully');
    
    my $m2 = ::make_method(sub { $pm->() }, $j);
    ok(ref($m2), 'Perl6::Method');    

    dies_ok {
        $m2->();
    } '... cannot call a private method from a different class';
}

## check some attribute stuff

{
   my $scalar = ::make_attribute('$.scalar');
   isa_ok($scalar, 'Perl6::Attribute');
   
   is(::instantiate_attribute_container($scalar), undef, '... got the right attribute container');
   
   my $array = ::make_attribute('@.array');
   isa_ok($array, 'Perl6::Attribute');

   is_deeply(::instantiate_attribute_container($array), [], '... got the right attribute container');
   
   my $hash = ::make_attribute('%.hash');      
   isa_ok($hash, 'Perl6::Attribute');    

   is_deeply(::instantiate_attribute_container($hash), {}, '... got the right attribute container');    
}

{
   my $scalar = ::make_class_attribute('$.scalar');
   isa_ok($scalar, 'Perl6::ClassAttribute');

   is(::instantiate_attribute_container($scalar), undef, '... got the right attribute container');

   my $array = ::make_class_attribute('@.array');
   isa_ok($array, 'Perl6::ClassAttribute');

   is_deeply(::instantiate_attribute_container($array), [], '... got the right attribute container');

   my $hash = ::make_class_attribute('%.hash');      
   isa_ok($hash, 'Perl6::ClassAttribute');    

   is_deeply(::instantiate_attribute_container($hash), {}, '... got the right attribute container');    
}
