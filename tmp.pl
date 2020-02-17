my $src_fname = shift @ARGV;
my $lrn_fname = "learn.csv";
my $wrk_fname = "work.csv";

open my $fin, "<$src_fname";
open my $fout, ">$lrn_fname";
my $lineno = 1;
while (<$fin>) {
	chomp;
	if (3000 == $lineno++) {
		close $fout;
		open $fout, ">$wrk_fname"; 
	}
	# 2009.12.21,00:00,1.43110,1.43470,1.43110,1.43420,5504 
	if ( m/(.+?)\,(.+?)\,(.+?)\,(.+?)\,(.+?)\,(.+?)/) {
		#print "[$1] [$2] [$3] [$4] [$5] [$6]\n";
		print $fout "$3\n"; 
	}
}
close $fout;
