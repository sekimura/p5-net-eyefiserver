use inc::Module::Install;
name 'Net-EyeFiServer';
all_from 'lib/Net/EyeFiServer.pm';

build_requires 'Test::More';
use_test_base;
auto_include_deps;
author_tests('xt');
WriteAll;
