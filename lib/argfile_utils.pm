#****************************************************************************
#* argfile_utils.pm
#*
#* Utility methods for parsing argument files
#****************************************************************************

# Global variables aren't a great idea...
$unget_ch_1 = -1;
$unget_ch_2 = -1;

sub process_argfile {
	my($dir,$file) = @_;
	my(@args, @sub_args);
	my($ch,$ch2,$tok);
	my($argfile,$subdir);
	my($l_unget_ch_1, $l_unget_ch_2);
	
	unless (-f $file) {
		if (-f "${dir}/${file}") {
			$file = "${dir}/${file}";
		}
	}
	
	open(my $fh,"<", $file) or die "Failed to open $file";
	$unget_ch_1 = -1;
	$unget_ch_2 = -1;
	
	while (!(($tok = read_tok($fh)) eq "")) {
		if ($tok =~ /^\+/) {
			push(@plusargs, $tok);
		} elsif ($tok =~ /^-/) {
			# Option
			if (($tok eq "-f") || ($tok eq "-F")) {
				# Read the next token
				$argfile = read_tok($fh);
				
				# Resolve argfile path
				$argfile = expand($argfile);
				
				unless (-f $argfile) {
					if (-f "$dir/$argfile") {
						$argfile = "$dir/$argfile";
					}
				}
				
				if ($tok eq "-F") {
					$subdir = dirname($argfile);
				} else {
					$subdir = $dir;
				}
				
				$l_unget_ch_1 = $unget_ch_1;
				$l_unget_ch_2 = $unget_ch_2;
				
				@sub_args = process_argfile($subdir, $argfile);
				
				# Now add those to our arguments
				for (my $i=0; $i<=$#sub_args; $i++) {
					push(@args, $sub_args[$i]);
				}

				$unget_ch_1 = $l_unget_ch_1;	
				$unget_ch_2 = $l_unget_ch_2;	
			} else {
#				print("Unknown option\n");
				push(@args, $tok);
			}
		} else {
			push(@args, $tok);
		}		
	}

	close($fh);
	
	return @args;
}

sub process_testlist($) {
	my($testlist_f) = @_;
	my($ch,$ch2,$tok);
	my($cc1, $cc2, $line, $idx);
	my(@tokens);
	my($test_cnt, $testname, $i, $tok);
	
	open(my $fh, "<", "$testlist_f") or die "Failed to open $testlist_f";
	$unget_ch_1 = -1;
	$unget_ch_2 = -1;

	while (1) {
		@tokens = read_test_line($fh);
		if ($#tokens < 0) {
			last;
		}
		$test_cnt=1;
		$testname="";
		for ($i=0; $i<=$#tokens; $i++) {
			$tok = $tokens[$i];
			
			if ($tok =~ /^-/) {
				if ($tok eq "-count") {
					$i++;
					$test_cnt=$tokens[$i];
				}
			} else {
				if ($testname eq "") {
					$testname = $tok;
				} else {
					print "Error: multiple tests specified in testlist: $tok\n";
				}
			}
		}
		
		if ($testname eq "") {
			print "Error: no test name specified\n";
		} else {
			for ($i=0; $i<$test_cnt; $i++) {
				push(@testlist, $testname);
			}
		}
	}
	
	close($fh);
}

sub read_test_line($) {
	my($fh) = @_;
	my($ch,$ch2,$line);
	my($cc1,$cc2);
	my($idx,$tok);
	my(@tokens);

	while (($ch = get_ch($fh)) != -1) {
		# Strip comments
		if ($ch eq "/") {
			$ch2 = get_ch($fh);
			if ($ch2 eq "*") {
				$cc1 = -1;
				$cc2 = -1;
			
				while (($ch = get_ch($fh)) != -1) {
					$cc2 = $cc1;
					$cc1 = $ch;
					if ($cc1 eq "/" && $cc2 eq "*") {
						last;
					}
				}
			
				next;
			} elsif ($ch2 eq "/") {
				while (($ch = get_ch($fh)) != -1 && !($ch eq "\n")) {
					;
				}
				unget_ch($ch);
				next;
			} else {
				unget_ch($ch2);
			}
		} elsif ($ch =~ /^\s*$/) { # Whitespace
			while (($ch = get_ch($fh)) != -1 && $ch =~ /^\s*$/) { }
			unget_ch($ch);
			next;
		} else {
			last;
		}
	}

	$tok = "";

	# Read a line
	$line = "";
	while ($ch != -1) {
		if ($ch eq "\\") {
			print "ch=\\\n";
		}
		if ($ch eq "\n" && length($line) > 0) {
			if (!(substr($line, length($line)-1, 1) eq "\\")) {
				last;
			}
		}
		# Remove the line separator
		if ($ch eq "\n" && substr($line, length($line)-1, 1) eq "\\") {
			$line = substr($line, 0, length($line)-1);
		}
		unless ($ch eq "\n" || $ch eq "\r") {
			$line .= $ch;
		} elsif ($ch eq "\n") {
			# Replace with whitespace
			$line .= " ";
		}
		$ch = get_ch($fh);
	}
	unget_ch($ch);
	
	# Now, scan through the line 
	for ($idx=0; $idx<length($line); $idx++) {
		$tok="";
		# Skip whitespace
		if (substr($line, $idx, 1) =~ /^\s*$/) {
			next;
		}
		while (!(substr($line, $idx, 1) =~ /^\s*$/)) {
			$tok .= substr($line, $idx, 1);
			$idx++;
		}
		push(@tokens, $tok);
	}
	
	return @tokens;
}

sub read_tok($) {
	my($fh) = @_;
	my($ch,$ch2,$tok);
	my($cc1,$cc2);
	
	while (($ch = get_ch($fh)) != -1) {
		if ($ch eq "/") {
			$ch2 = get_ch($fh);
			if ($ch2 eq "*") {
				$cc1 = -1;
				$cc2 = -1;
			
				while (($ch = get_ch($fh)) != -1) {
					$cc2 = $cc1;
					$cc1 = $ch;
					if ($cc1 eq "/" && $cc2 eq "*") {
						last;
					}
				}
			
				next;
			} elsif ($ch2 eq "/") {
				while (($ch = get_ch($fh)) != -1 && !($ch eq "\n")) {
					;
				}
				unget_ch($ch);
				next;
			} else {
				unget_ch($ch2);
			}
		} elsif ($ch =~/^\s*$/) {
			while (($ch = get_ch($fh)) != -1 && $ch =~/^\s*$/) { }
			unget_ch($ch);
			next;
		} else {
			last;
		}
	}

	$tok = "";
		
	while ($ch != -1 && !($ch =~/^\s*$/)) {
		$tok .= $ch;
		$ch = get_ch($fh);
	}
	unget_ch($ch);	
		
	return $tok;
}

sub unget_ch($) {
	my($ch) = @_;

	$unget_ch_2 = $unget_ch_1;	
	$unget_ch_1 = $ch;
}

sub get_ch($) {
	my($fh) = @_;
	my($ch) = -1;
	my($count);
	
	if ($unget_ch_1 != -1) {
		$ch = $unget_ch_1;
		$unget_ch_1 = $unget_ch_2;
		$unget_ch_2 = -1;
	} else {
		$count = read($fh, $ch, 1);
		
		if ($count <= 0) {
			$ch = -1;
		}
	}
	
	return $ch;
}

sub expand($) {
	my($val) = @_;
	my($offset) = 0;
	my($ind,$end,$tok);
	
	while (($ind = index($val, "\$", $offset)) != -1) {
		$end = index($val, "}", $index);
		$tok = substr($val, $ind+2, ($end-($ind+2)));

		if (exists $ENV{${tok}}) {
			$val = substr($val, 0, $ind) . $ENV{${tok}} . 
				substr($val, $end+1, length($val)-$end);
		}
		
		$offset = $ind+1;
	}
	
	return $val;
}


1;
