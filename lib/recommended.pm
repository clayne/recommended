use 5.008001;
use strict;
use warnings;

package recommended;
# ABSTRACT: Load recommended modules on demand when available

use version;
use Carp ();
use Module::Runtime 0.014 (); # bugfixes for use_package_optimistically

our $VERSION = '0.002';

# $MODULES{$type}{$caller}{$mod} = [$min_version, $satisfied]
my %MODULES;

# for testing and diagnostics
sub __modules { return \%MODULES }

sub import {
    my $class  = shift;
    my $caller = caller;
    for my $arg (@_) {
        my $type = ref $arg;
        if ( !$type ) {
            $MODULES{$class}{$caller}{$arg} = [ 0, undef ];
        }
        elsif ( $type eq 'HASH' ) {
            while ( my ( $mod, $ver ) = each %$arg ) {
                Carp::croak("module '$mod': '$ver' is not a valid version string")
                  if !version::is_lax($ver);
                $MODULES{$class}{$caller}{$mod} = [ $ver, undef ];
            }
        }
        else {
            Carp::croak("arguments to 'recommended' must be scalars or a hash ref");
        }
    }
}

sub has {
    my ( $class, $mod, $ver ) = @_;
    my $caller = caller;
    my $spec   = $MODULES{$class}{$caller}{$mod};

    return unless $spec;

    if ( defined $ver ) {
        Carp::croak("module '$mod': '$ver' is not a valid version string")
          if !version::is_lax($ver);
    }
    else {
        # shortcut if default already checked
        return $spec->[1] if defined $spec->[1];
        $ver = $spec->[0];
    }

    # don't call with a version; we want this to die only on compile failure
    Module::Runtime::use_package_optimistically($mod);

    my $ok = $INC{ Module::Runtime::module_notional_filename($mod) }
      && $mod->VERSION >= version->new($ver);

    return $spec->[1] = $ok ? 1 : 0;
}

1;

=head1 SYNOPSIS

    use recommended 'Foo::Bar', {
        'Bar::Baz' => '1.23',
        'Wibble'   => '0.14',
    };

    if ( recommended->has( 'Foo::Bar' ) ) {
        # do something with Foo::Bar
    }

    # default version required
    if ( recommended->has( 'Wibble' ) ) {
        # do something with Wibble if >= version 0.14
    }

    # custom version required
    if ( recommended->has( 'Wibble', '0.10' ) ) {
        # do something with Wibble if >= version 0.10
    }

=head1 DESCRIPTION

This module gathers a list of recommended modules and versions and provides
means to check if they are available.  It is a thin veneer around
L<Module::Runtime>.

There are two major benefits over using L<Module::Runtime> directly:

=for :list
* Self-documents recommended modules together with versions at the top of your
  code, while still loading them on demand elsewhere.
* Dies if a recommended module exists but fails to compile, but doesn't die
  if the module is missing or the version is insufficient.  This is not
  something that L<Module::Runtime> offers in a single subroutine.

=head1 USAGE

=head2 import

    use recommended 'Foo::Bar', {
        'Bar::Baz' => '1.23',
        'Wibble'   => '0.14',
    };

Scalar import arguments are treated as module names with a minimum required
version of zero.  Hash references are treated as module/minimum-version pairs.
If you repeat, the later minimum version overwrites the earlier one.

The list of modules and versions are kept separate for each calling package.

=head2 has

    recommended->has( $module );
    recommended->has( $module, $alt_minimum_version );

The C<has> method takes a module name and optional alternative minimum version
requirement and returns true if the following conditions are met:

=for :list
* the module was recommended in the current package (via C<use recommended>)
* the module can be loaded
* the module meets the default or alternate minimum version

Otherwise, it returns false.  If the module exists but fails to compile, an
error is thrown.  This avoids some edge-cases where things are left in an
incomplete state or subsequent normal loads of the module by other packages get
a misleading error.

The module is loaded without invoking the module's C<import> method, as running
import on an optional module at runtime is just weird.

=head1 SEE ALSO

=for :list
* L<Module::Runtime>
* L<Test::Requires>

=cut

# vim: ts=4 sts=4 sw=4 et:
