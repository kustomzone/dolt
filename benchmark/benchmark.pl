#!/usr/bin/perl -w
################################################################################### 
#
#
# benchmark.pl - Dolt benchmarking script
#
#
# Description: Dolt benchmarking script. 
# Author: Tim Sehn
# Date: March, 2019
#
###################################################################################

use strict;

use Data::Dumper;
use Getopt::Long;
use List::Util qw(shuffle);

# These are defaults and will al be able to be overridden with command line args.
use constant BENCHMARK_ROOT => '/var/tmp';

use constant LOG_LEVEL       => 2; # 0 = quiet, 1 = status, 2 = verbose
use constant UNSAFE          => 0;
use constant PRESERVE_INPUTS => 0;

use constant DOLT_PATH => '~/go/bin/';

###################################################################################
#
# Configuration
#
###################################################################################

# Ideally, we will store the configuration in a dolt repository. We will pull down 
# the repo and extract all this information from the repository. Then, we'll 
# insert the output with the configuration version identifier in the output.

# Define the benchmarks we will run.
my $benchmark_config = {
    # Version the configuration to store with the output
    version => 0.0.1,
    # Define the schema and size of the test database.
    # This creates a set of csv files and a dolt schema file which are used in the
    # benchmark tests. The gen field is either increment or rand. Types supported 
    # are int and string.
    seed => {
	name   => 'test.csv',
	size   => 10,
	schema_file => 'test.schema',
	schema => [
	    {
		name    => 'id',
		type    => 'int',
		primary => 1,
		gen     => 'increment',
	    },
	    {
		name    => 'int1',
		type    => 'int',
		primary => 0,
		gen     => 'rand',
		size    => 10,
	    },
	    {
		name    => 'int2',
		type    => 'int',
		primary => 0,
		gen     => 'rand',
		size    => 100,
	    },
	    {
		name    => 'int3',
		type    => 'int',
		primary => 0,
		gen     => 'rand',
		size    => 1000,
	    },
	    {
		name    => 'int4',
		type    => 'int',
		primary => 0,
		gen     => 'rand',
		size    => 10000,
	    },
	    {
		name    => 'int5',
		type    => 'int',
		primary => 0,
		gen     => 'rand',
		size    => 100000,
	    },
	    {
		name    => 'string1',
		type    => 'string',
		primary => 0,
		gen     => 'rand',
		size    => 1,
	    },
	    {
		name    => 'string2',
		type    => 'string',
		primary => 0,
		gen     => 'rand',
		size    => 2,
	    },
	    {
		name    => 'string3',
		type    => 'string',
		primary => 0,
		gen     => 'rand',
		size    => 4,
	    },
	    {
		name    => 'string4',
		type    => 'string',
		primary => 0,
		gen     => 'rand',
		size    => 8,
	    },
	    {
		name    => 'string5',
		type    => 'string',
		primary => 0,
		gen     => 'rand',
		size    => 16,
	    },
	    ],
    },
    # This configuration defines which csv files we'll create to represent
    # a small, medium, and large change. The pct key/value pair is used to
    # calculate the percentage chance that a column value is changed.
    changes => [
	{
	    file => 'small-change.csv',
	    pct  => 0.001,
	},
	{
	    file => 'medium-change.csv',
	    pct  => 0.01,
	},
	{
	    file => 'large-change.csv',
	    pct  => 0.05,
	},
    ],
    benchmarks => { 
	git => {
	    root => 'git-benchmark',
	    tests => [
		{
		    name => 'raw',
		    command => 'git',
		},
		{
		    name => 'init',
		    command => 'git init',
		},
		{
		    prep => ['cp ../test.csv .'],
		    name => 'add',
		    command => 'git add test.csv',
		},
		{
		    name => 'commit',
		    command => 'git commit -m "first test commit"',
		    check_disk => 1,
		},
		{
		    prep => ['cp ../small-change.csv ./test.csv'],
		    name => 'small diff',
		    command => 'git diff test.csv',
		    post => [
			'git add test.csv',
			'git commit -m "Committed small diff"'
			],
		    check_disk => 1, 
		},
		{
		    prep => ['cp ../medium-change.csv ./test.csv'],
		    name => 'medium diff',
		    command => 'git diff test.csv',
		    post => [
			'git add test.csv',
			'git commit -m "Committed medium diff"'
			],
		    check_disk => 1,
		},
		{
		    prep => ['cp ../large-change.csv ./test.csv'],
		    name => 'large diff',
		    command => 'git diff test.csv',
		    post => [
			'git add test.csv',
			'git commit -m "Committed large diff"'
			],
		    check_disk => 1,
		}
		]
	},
        dolt => {
	    root => 'dolt-benchmark',
	    tests => [
		{
		    name => 'raw',
		    command => 'dolt',
		},
		{
		    name => 'init',
		    command => 'dolt init',
		},
		{
		    prep => [
			'dolt table create -s ../test.schema test',
			'dolt table import -u test ../test.csv',
			],
			name =>'add',
			command=> 'dolt add test',
		},
		{
		    name => 'commit',
		    command => 'dolt commit -m "first test commit"',
		    check_disk => 1,
		},
		{
		    prep => ['dolt table import -u test ../small-change.csv'],
		    name => 'small diff',
		    command => 'dolt diff test',
		    post => [
			'dolt add test',
			'dolt commit -m "Committed small diff"',
			],
		    check_disk => 1,
		},
		{
		    prep => ['dolt table import -u test ../medium-change.csv'],
		    name => 'medium diff',
		    command => 'dolt diff test',
		    post => [
			'dolt add test',
			'dolt commit -m "Committed medium diff"',
			],
		    check_disk => 1,
		},
		{
		    prep => ['dolt table import -u test ../large-change.csv'],
		    name => 'large diff',
		    command => 'dolt diff test',
		    post => [
			'dolt add test',
			'dolt commit -m "Committed large diff"',
			],
		    check_disk => 1,
		}
	    ]
        }
    }
};

###################################################################################
#
# Execute the Benchmark
#
###################################################################################

# Process command line arguments
my $root      = BENCHMARK_ROOT;
my $log_level = LOG_LEVEL;
my $unsafe    = UNSAFE;
my $preserve  = PRESERVE_INPUTS;
my $dolt_path = DOLT_PATH;
GetOptions(
    "root=s"      => \$root,
    "loglevel=i"  => \$log_level,
    "preserve"    => \$preserve,
    "unsafe"      => \$unsafe)
or die("Error in command line arguments\n");

# Set up the environment
$ENV{'PATH'} = "$ENV{PATH}:$dolt_path";
$ENV{'NOMS_VERSION_NEXT'} = 1;

# Make sure root exists
if ( -d $root ) {
    output("Changing directory to $root", 2);
    chdir($root) or die("Could not cd to $root\n");
} else {
    die("Could not run benchmarks in $root. Directory does not exist.\n");
}

# Build input files
my $test_csv    = $benchmark_config->{'seed'}{'name'};
my $schema_file = $benchmark_config->{'seed'}{'schema_file'};
my $schema      = $benchmark_config->{'seed'}{'schema'};
my $rows        = $benchmark_config->{'seed'}{'size'};
my $columns     = scalar(@{$schema});
my $changes     = $benchmark_config->{'changes'};

output("Building input files...$rows rows, $columns columns", 1);
generate_dolt_schema($schema_file, $schema);
create_test_input_csvs($test_csv, $rows, $schema, $changes);

# TO DO: Gather system information to insert into the output.

# Run the benchmarks
my %data;
foreach my $benchmark ( keys %{$benchmark_config->{'benchmarks'}} ) {
    output("Executing $benchmark benchmark...", 1);

    my $benchmarks = $benchmark_config->{'benchmarks'};
    my $benchmark_root = $benchmarks->{$benchmark}{'root'};
    if ( -d $benchmark_root ) {
	if ( $unsafe ) {
	    output("Deleting $root/$benchmark_root because it alreadys exists", 2);
	    run_command("rm -rf $benchmark_root");
	} else {
	    error_exit("$root/$benchmark_root must not exist to run benchmark");
	}
    }

    output("Changing directory to $benchmark_root\n", 2);
    mkdir($benchmark_root) or error_exit("Could not mkdir $benchmark_root");
    chdir($benchmark_root) or error_exit("Could not cd to $benchmark_root");

    foreach my $test ( @{$benchmarks->{$benchmark}{'tests'}} ) {
	output("Running test: " . $test->{'name'}, 1);

	foreach my $prep ( @{$test->{'prep'}} ) {
	    run_command($prep);
	}
	
	my ($real, $user, $system) = time_command($test->{'command'});

	$data{$test->{'name'}}{$benchmark}{'real'}   = $real;
	$data{$test->{'name'}}{$benchmark}{'user'}   = $user;
	$data{$test->{'name'}}{$benchmark}{'system'} = $system;

        foreach my $post ( @{$test->{'post'}} ) {
            run_command($post);
        }

	if ( $test->{'check_disk'} ) {
	    $data{$test->{'name'}}{$benchmark}{'disk'} = disk_usage();
	}
    }

    output("Changing directory to $root and removing $benchmark_root", 2);
    chdir($root);
    run_command("rm -rf $benchmark_root") unless $preserve;
}

# Cleanup
output("Cleaning up...", 1); 
cleanup($root, $benchmark_config, $preserve, $unsafe);

# Output
output_data(\%data, $benchmark_config->{'benchmarks'}, $log_level);

exit 0;

###################################################################################
#
# Functions
#
###################################################################################

# System utility functions

sub time_command {
    my $command = shift;

    output("Running:\n\t$command", 2);

    # time outputs to STDERR so I'll trash STDOUT and grab STDERR from
    # STDOUT which `` writes to
    my $piped_command;
    if ( LOG_LEVEL > 1 ) {
	$piped_command = "{ time $command ;} 2>&1";
    } else {
	$piped_command = "{ time $command ;} 2>&1 1>/dev/null";
    }

    my $output = `$piped_command`;
    # To Do: Some of these commands expect to exit 1. ie, git and dolt.
    # I need to build in an expect into the benchmark definition
    # if ($?) {
    #     die "Error running: $piped_command\n";
    # }

    $output =~ /real\s+(.+)\nuser\s+(.+)\nsys\s+(.+)\n/;

    output("Output:\n\t$output", 2) if $output;

    my $real   = convert_time_output_to_ms($1);
    my $user   = convert_time_output_to_ms($2);
    my $system = convert_time_output_to_ms($3);

    return ($real, $user, $system);
}

sub disk_usage {
    my $verbose = shift;

    output("Checking disk usage...", 2);

    my $command = 'du -h -d 0';
    output("Running $command", 2);
    my $output = `$command`;
    output("Output:\n\t$output", 2) if $output;

    $output =~ /^\s*([\d\w\.]+)\s+\./;

    return $1;
}

sub run_command {
    my $command = shift;

    output("Running:\n\t$command", 2);
    my $output = `$command 2>&1`;
    output("Output:\n\t$output", 2) if $output;
    if ($?) {
	error_exit("Error running: $command");
    }
}

sub convert_time_output_to_ms {
    my $time = shift;

    $time =~ /(\d+)m(\d+)\.(\d+)s/;

    my $minutes = $1;
    my $seconds = $2;
    my $ms      = $3;

    return $ms + ($seconds*1000) + ($minutes*60*1000);
}

# CSV Creation functions

sub create_test_input_csvs {
    my $csv     = shift;
    my $size    = shift;
    my $schema  = shift;
    my $changes = shift;

    my @all_filehandles;
    open(CSV, ">", $csv) or error_exit("Could not open $csv: $!\n");
    push @all_filehandles, *CSV;

    foreach my $change ( @{$changes} ){
	open($change->{'filehandle'}, '>', $change->{'file'}) 
	    or error_exit("Could not open ". $change->{'file'} . ": $!");
	push @all_filehandles, $change->{'filehandle'};
    }

    # Create header row and write it to all csvs
    my $first = 1;
    foreach my $column ( @{$schema} ) {
	write_to_files(',', @all_filehandles) unless $first; 
	write_to_files($column->{'name'}, @all_filehandles);
	$first = 0;
    }
    write_to_files("\n", @all_filehandles);;

    # Create mock data

    # Create an array with the data and write the original CSV 
    my @values;
    foreach ( my $i = 0; $i < $size; $i++ ) {
	$first = 1;
	$values[$i] = [];
        foreach my $column ( @{$schema} ) {
            print CSV ',' unless $first;
	    $first = 0;
            my $value = generate_value($column->{'type'},
                                       $column->{'gen'},
                                       $column->{'size'},
                                       $i);
            print CSV $value;
	    push @{$values[$i]}, $value;
	    
	}
	print CSV "\n";
    }

    # Shuffle the rows and change the values
    foreach my $change ( @{$changes} ) {
	my $fh = $change->{'filehandle'};
	my @shuffle = shuffle(@values);
	foreach my $row ( @shuffle ) {
	    my $first = 1;
	    my $i = 0;
	    foreach my $column ( @{$schema} ) {
		my $value = $row->[$i];

		print $fh ',' unless $first;
		$first = 0;

		if ( rand() < $change->{'pct'} ) {
                    $value = generate_value($column->{'type'},
                                            $column->{'gen'},
                                            $column->{'size'},
                                            $row->[0]);
		}

		print $fh $value;
		$i++;
	    }
	    print $fh "\n";
	}
    }

    foreach my $fh (@all_filehandles) {
	close $fh;
    }
}

sub generate_value {
    my $type = shift;
    my $gen  = shift;
    my $size = shift;
    my $i    = shift; # Used for increment

    if ( $type eq 'int' ) {
	return $i if ( $gen eq 'increment' );
	if ( $gen eq 'rand' ) {
	    return int(rand($size+1));
	} else {
	    error_exit("Do not understand generator: $gen");
	}
    } elsif ( $type eq 'string' ) {
	if ( $gen eq 'rand' ) {
	    return rndStr($size, 'a'..'z', 0..9);
	} else {
            error_exit("Do not understand generator: $gen");
	}
    } else {
	error_exit("Do not understand type: $type");
    }
}

sub write_to_files {
    my $string = shift;
    my @filehandles = @_;

    foreach my $filehandle ( @filehandles ) {
	print $filehandle $string;
    }
}

# Perl wizardry. Do not question.
sub rndStr { 
    join('', @_[ map{ rand @_ } 1 .. shift ]); 
}

# Generate schema

sub generate_dolt_schema {
    my $schema_file = shift;
    my $schema      = shift;

    my $filehandle;
    open($filehandle, '>', $schema_file)
	or error_exit("Could not open $schema_file");

    print $filehandle "{\n\"columns\":[\n";
    
    my $first = 1;
    my $tag = 0;
    foreach my $column ( @{$schema} ) {
	print $filehandle ",\n" unless $first;
	$first = 0;
	generate_column_schema($column, $tag, $filehandle);
	$tag++;
    }

    print $filehandle "]\n}\n";
}

sub generate_column_schema {
    my $col_schema = shift;
    my $tag        = shift;
    my $filehandle = shift;

    print $filehandle "{\n\"tag\": $tag,\n";
    print $filehandle "\"name\":\"$col_schema->{name}\",\n";
    print $filehandle "\"kind\":\"$col_schema->{type}\",\n";
    if ( $col_schema->{primary} ) {
	print $filehandle "\"is_part_of_pk\": true,\n" . 
	    "\"col_constraints\": [\n{\n\"constraint_type\": \"not_null\",\n" .
	    "\"params\": null\n}\n]\n";
    } else {
	print $filehandle "\"is_part_of_pk\": false,\n" .
	    "\"col_constraints\": []\n";
    }

    print $filehandle "}";
}

sub cleanup { 
    my $root             = shift;
    my $benchmark_config = shift;
    my $preserve         = shift;
    my $unsafe           = shift;

    return if $preserve;

    chdir($root) or error_exit("Could not cd to $root");

    my $seed = $benchmark_config->{'seed'}{'name'};
    my $schema = $benchmark_config->{'seed'}{'schema_file'};
    my $changes = $benchmark_config->{'changes'};

    output("Removing $seed and $schema files", 2);
    unlink($seed) if ( -e $seed);
    unlink($schema) if ( -e $schema );
    foreach my $change ( @{$changes} ) {
	output("Removing $change->{file}", 2);
	unlink($change->{'file'}) if ( -e $change->{'file'} );
    }

    output("Removing repository roots",2);
    foreach my $benchmark ( keys %{$benchmark_config->{'benchmarks'}} ) {
	my $benchmark_root = $benchmark_config->{'benchmarks'}{$benchmark}{'root'};
	run_command("rm -rf $benchmark_root");
    }
}

# Data
sub output_data {
    my $data       = shift;
    my $benchmarks = shift;
    my $log_level  = shift;

    return if ( $log_level == 0 );

    print Dumper $data if ( $log_level >= 2 );

    print "\n--- Times ---\n";
    foreach my $test ( @{$benchmarks->{'dolt'}{'tests'}} ) {
	my $test_name = $test->{'name'};

	print "$test_name:\n";
	print "\tDolt: $data->{$test_name}{dolt}{real}ms\n";
	print "\tGit:  $data->{$test_name}{'git'}{'real'}ms\n";
    }

    print "\n--- Disk ---\n";
    foreach my $test ( @{$benchmarks->{'dolt'}{'tests'}} ) {
	my $test_name = $test->{'name'};
	if ( $data->{$test_name}{'dolt'}{'disk'} ) {
	    print "$test_name:\n";
	    print "\tDolt: $data->{$test_name}{dolt}{disk}\n";
	    print "\tGit:  $data->{$test_name}{'git'}{'disk'}\n";
	}
    }
}

# Logging

# 0 = quiet, 1 = status, 2 = verbose
sub output {
    my $message = shift;
    my $level   = shift;

    my $now = localtime();

    # Take advantage of log level being global
    print "$now: $message\n" if ( $level <= $log_level );
}

sub error_exit {
    my $message = shift;

    print STDERR "$message\n";

    print "Exiting early...attempting to cleanup...\n";

    # Take advantage that these are global so I don't have to pass them around.
    cleanup($root, $benchmark_config, $preserve, $unsafe);

    exit 1;
}
