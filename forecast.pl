#!/usr/bin/perl -w
use strict;
use warnings;

die "Usage: forecast learn.csv forecast.csv [result]\n"
	if (1 > @ARGV);


my $learn_fname = shift @ARGV;
my $forecast_fname = shift @ARGV || "work.csv"; 
my $res_fname = shift @ARGV || "result.txt";

my $learn_data = [];


open my $fin, "<$learn_fname";
while (<$fin>) {
	chomp;
	push (@$learn_data, $_);
}
close $fin;

my $min_price = $learn_data->[0] || -1;
foreach my $price (@$learn_data) {
	if ($min_price > $price) {
		$min_price = $price;
	}
	next;
}


my $max_price = $learn_data->[0] || -1;
foreach my $price (@$learn_data) {
	if ($max_price < $price) {
		$max_price = $price;
	}
	next;
}

my $price_amplitude = $max_price-$min_price || -1;

# создать диапазоны (ровни квантования)
my $dia_cnt = 90;
my $dia_size = $price_amplitude / $dia_cnt || -1;
my $quant_levels = [];
$quant_levels->[0] = $min_price;
$quant_levels->[$dia_cnt-1] = $max_price;
foreach my $level (1..$dia_cnt-2) {
	$quant_levels->[$level] = $quant_levels->[$level-1] + $dia_size;
}


my $from = 0;
my $to = 0;

# определить диапазон цены на первом шаге
my $price = $learn_data->[0];
foreach my $i (0..@$quant_levels-1) {
	#print " level : $quant_levels->[$i]  -- price: $price\n";  
	if ($i < @$quant_levels-1) {
		if ($quant_levels->[$i+1] > $price && $price > $quant_levels->[$i]) {
			$from = $i+1;
		}
	} elsif ($quant_levels->[$i] > $price && $price > $quant_levels->[$i-1]) {
			$from = $i+1;
	}
}

# создать матрицу переходов из состояния в состояние
my $trans_tab_len = $dia_cnt-1; 
my $trans_tab = [];
foreach my $from (0..$trans_tab_len-1) {
	foreach my $to (0..$trans_tab_len) { #  +1 столбец для суммы по строке	
		$trans_tab->[$from][$to] = 0.0;
	}
}

#to csv (пока debug)
open my $fmx_csv, ">trans_tab.csv";
foreach my $from (0..$trans_tab_len-1) {
	foreach my $to (0..$trans_tab_len) { #  +1 столбец для суммы по строке	
		print $fmx_csv "$trans_tab->[$from][$to]\t";
	}
	print $fmx_csv "\n";
}
close $fmx_csv;

foreach my $price (1..@$learn_data-1) {
	foreach my $i (0..@$quant_levels-1) {
		if ($i < @$quant_levels-1) {
			if ($quant_levels->[$i+1] > $learn_data->[$price] && $learn_data->[$price] > $quant_levels->[$i]) {
				$trans_tab->[$from][$to] += 1;
				$to = $from;
				$from = $i+1;
			}
		} elsif ($quant_levels->[$i] > $learn_data->[$price] && $learn_data->[$price] > $quant_levels->[$i-1]) {
				$trans_tab->[$from][$to] += 1; 
				$to = $from;
				$from = $i+1;
		}
	}
}

open $fmx_csv, ">trans_tab_filledin.csv";
foreach my $from (0..$trans_tab_len-1) {
	foreach my $to (0..$trans_tab_len) { #  +1 столбец для суммы по строке	
		print $fmx_csv "$trans_tab->[$from][$to]\t";
	}
	print $fmx_csv "\n";
}
close $fmx_csv;


# пощитать сумму по строке для таблицы переходов
foreach my $from (0..$trans_tab_len-1) {
	my $line_sum = 0;
	foreach my $to (0..$trans_tab_len-1) { 
		$line_sum += $trans_tab->[$from][$to];
	}
	$trans_tab->[$from][$trans_tab_len] = $line_sum; # занести сумму по строке в последний столбец
		#unless ($line_sum < 5) || 0.0;
}


open $fmx_csv, ">trans_tab_filledin_linesum.csv";
foreach my $from (0..$trans_tab_len-1) {
	foreach my $to (0..$trans_tab_len) { #  +1 столбец для суммы по строке	
		print $fmx_csv "$trans_tab->[$from][$to]\t";
	}
	print $fmx_csv "\n";
}
close $fmx_csv;

# создать таблицу переходных вероятностей 
my $trans_P_tab = [];
foreach my $from (0..$trans_tab_len-1) {
	my $line_sum = $trans_tab->[$from][$trans_tab_len];
	next if (0 == $line_sum);
	foreach my $to (0..$trans_tab_len-1) {
		my $probability = $trans_tab->[$from][$to] / $line_sum;
		$trans_P_tab->[$from][$to] = $probability;# || 0.0 if (1.0 == $probability);
	}
}

open $fmx_csv, ">trans_P_tab.csv";
foreach my $from (0..$trans_tab_len-1) {
	foreach my $to (0..$trans_tab_len-1) {
		print $fmx_csv "$trans_P_tab->[$from][$to]\t";
	}
	print $fmx_csv "\n";
}
close $fmx_csv;


# Произвести прогнозирование на один шаг вперёд
my $total_qoality  = 0.0;
my $dyn_quality = []; # это вектор значений
my $succ_step = 0;
my $total_step = 0;

# Считать данные для анализа
my $proc_data = [];
open $fin, "<$forecast_fname";
while (<$fin>) {
	chomp;
	push @$proc_data, $_;
}
close $fin;



# Описание алгоритма
# Определить диапазон цены на шаге 0(начало)
# сделать прогноз на следующий шаг

# определить диапазон цены на первом шаге
#$price = $proc_data->[0];

foreach my $i (0..@$proc_data-1) {
	my $from = 0;
	my $to = 0;
	my $price = $proc_data->[$i];
	foreach my $i (0..@$quant_levels-1) {
		if ($i < @$quant_levels-1) {
			if ($quant_levels->[$i+1] > $price && $price > $quant_levels->[$i]) {
				$from = $i+1;
			}
		} elsif ($quant_levels->[$i] > $price && $price > $quant_levels->[$i-1]) {
			$from = $i+1;
		}
	}

	# определить наивероятнейшее значение на следующем шаге, спрогнозировать уровень цены
	my $most_prob = $trans_P_tab->[$from][0];
	foreach my $i (1..@$trans_P_tab-1) {
		if ($most_prob < $trans_P_tab->[$from][$i]) {
			print "$from;  [$from] -> [$to]\n";
			$most_prob = $trans_P_tab->[$from][$i];
			$to = $i;
		}
	}

	$total_step++;
	if ($quant_levels->[$to-1] < $price && $price < $quant_levels->[$to]) {
		$succ_step++;
	}

	# определить качество прогноза...
	#print "cur price: $price\n\t\t\tforecast price diano: $to\n";
	#print "--$quant_levels->[$to]\n  next price:$proc_data->[$i]\n--$quant_levels->[$to-1]\n";
}

$total_qoality = $succ_step/$total_step;
print "total quality: $total_qoality\n";

print "min: $min_price\nmax: $max_price\namp:$price_amplitude\ndia count: $dia_cnt\ndia size: $dia_size\n";
