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
