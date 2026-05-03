rule plot_ideal_inst_overhead:
    # output: ideal_inst_overhead.eps
    # input: sail stats for all enabled benchmarks
    # configure plotting tool with y-axis (benchmark), and stacking parameters:
    #     revoc > reserve stack > encap > clear
    # but how to let it determine generally how to derive overheads?
    # maybe with a kind of test?