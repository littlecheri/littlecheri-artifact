set datafile separator ','
set terminal pngcairo size 2000,1000 font "Helvetica,18"
set output ARGV[2]

set title 'Call depth time series'
set xlabel 'Time'
set ylabel 'Depth'
set label 1 ARGV[3] at screen 0.0415,.96 boxed

plot ARGV[1] using ($0):1:(strcol(2) eq "S" ? 1 : NaN) with points pt 5 ps variable lc 0 title "Secure", \
     ARGV[1] using ($0):1:(strcol(2) eq "S" ? NaN : .8) with points pt 1 ps variable lc 0 title "Plain"