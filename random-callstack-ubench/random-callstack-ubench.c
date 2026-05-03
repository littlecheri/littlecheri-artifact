#include "wrap_uninit.h"
#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <stdint.h>
#include <assert.h>
#include <inttypes.h>
#include <time.h>
#include <stdbool.h>

#ifdef __riscv
extern uint64_t __stack_size;
#else
uint64_t __stack_size = 0x100000;
#endif
void adjust_stack_size(uint64_t);

int secure_threshold, secure_calls, plain_calls, total_calls;
int frame_return_multiplier, depth_return_multiplier, return_threshold;
int warmup = 50;

#ifdef UBENCH_LARGE_ALLOC
#define STACK_ALLOCATION 250
#else
#ifdef UBENCH_SMALL_ALLOC
#define STACK_ALLOCATION 25
#else
#define STACK_ALLOCATION 100
#endif
#endif

#define DEFAULT_STACK_SIZE ((uint64_t) &__stack_size) // don't ask me why this works like this
#define SECURE_CALL_RATIO .1
#define RETURN_PROBABILITY .45
#define MAX_DEPTH 1000
#define MAX_TOTAL_CALLS 5000
#define MAX_CALLS_SINGLE_FRAME 4

#ifdef INSTRUMENT_UNINIT
#define CONDITIONAL_DEBUG_PRINT_DEPTH printf("%d,", current_depth);
#define CONDITIONAL_DEBUG_PRINT_SECURE printf("S\n");
#define CONDITIONAL_DEBUG_PRINT_PLAIN printf("P\n");
#define CONDITIONAL_DEBUG_PRINT_AND_RETURN { printf("R\n"); return; }
uint64_t _plain_call_count;
uint64_t _uninit_call_count;
void write_stats(FILE* stats_out)
{
    // assert(secure_calls == _uninit_call_count);
	fprintf(stats_out, "secureCalls    %ld    "
		"# Amount of secure calls made during the benchmark\n",
		_uninit_call_count);
}
#else
#define CONDITIONAL_DEBUG_PRINT_DEPTH
#define CONDITIONAL_DEBUG_PRINT_SECURE
#define CONDITIONAL_DEBUG_PRINT_PLAIN
#define CONDITIONAL_DEBUG_PRINT_AND_RETURN return;
#endif

void foo(int);
#ifdef WRAP_UNINIT
void __attribute__((noinline,cheri_uninit)) __uninit_wrap_foo(int current_depth) {
#ifdef INSTRUMENT_UNINIT
    _uninit_call_count++;
#endif
    return foo(current_depth);
}
#else
#define __uninit_wrap_foo __plain_wrap_foo
#endif


void __attribute__((noinline)) __plain_wrap_foo(int current_depth) {
#ifdef INSTRUMENT_UNINIT
    _plain_call_count++;
#endif
    return foo(current_depth);
}

void __attribute__((noinline)) do_plain_call(int current_depth) {
    return __plain_wrap_foo(current_depth);
}

void __attribute__((noinline)) do_secure_call(int current_depth) {
    return __uninit_wrap_foo(current_depth);   
}

void foo(int current_depth)
{
    char allocation[STACK_ALLOCATION];
    int calls_current_frame = 0;

    while (true) {
        CONDITIONAL_DEBUG_PRINT_DEPTH

        // hard limit on depth, number of calls in frame and total number of calls
        if (current_depth >= MAX_DEPTH) CONDITIONAL_DEBUG_PRINT_AND_RETURN
        if (total_calls >= MAX_TOTAL_CALLS) CONDITIONAL_DEBUG_PRINT_AND_RETURN
        if (calls_current_frame >= MAX_CALLS_SINGLE_FRAME) CONDITIONAL_DEBUG_PRINT_AND_RETURN
        
        if (!warmup) {
            int r = rand();

            // random return proportional to depth in call stack
            r = rand();
            if (r < (current_depth * depth_return_multiplier)) CONDITIONAL_DEBUG_PRINT_AND_RETURN
            
            r = rand();
            if (r < return_threshold) CONDITIONAL_DEBUG_PRINT_AND_RETURN
        } else {
            warmup--;
        }

        total_calls++; calls_current_frame++;
        if (rand() < secure_threshold) {
            secure_calls++;
            CONDITIONAL_DEBUG_PRINT_SECURE
            do_secure_call(current_depth + 1);
        } else {
            plain_calls++;
            CONDITIONAL_DEBUG_PRINT_PLAIN
            do_plain_call(current_depth + 1);
        }
    }
    
    asm(""); // inserted to prevent tail call optimization

    // CONDITIONAL_DEBUG_PRINT_DEPTH
    // return;
}

int main(int argc, char* argv[])
{
    float secure_call_ratio = SECURE_CALL_RATIO;
    uint64_t stack_size = DEFAULT_STACK_SIZE;
    uint32_t seed;
    FILE *seed_file;
    bool seed_given = false;
#ifdef INSTRUMENT_UNINIT
    char* outfile_name = NULL;
#endif

    int opt;
    while ((opt = getopt(argc, argv, "s:o:r:")) != -1) {
        switch (opt) {
            case 's':
                seed_file = fopen(optarg, "r");
                if (seed_file == NULL) break;
                fscanf(seed_file, "%" SCNu32, &seed);
                fclose(seed_file);
                seed_given = true;
                break;
#ifdef INSTRUMENT_UNINIT
            case 'o':
                outfile_name = optarg;
                break;
#endif
            case 'r':
                secure_call_ratio = atof(optarg);
                break;
            case '?':
            default:
                fprintf(stderr,
                        "Usage: %s -s <random generator seed> -d <max depth of callstack> -r <ratio of secure calls to plain calls>\n",
                        argv[0]);
                return EXIT_FAILURE;
        }
    }

    if (!seed_given) seed = time(NULL);

    printf("#Random Seed: %u\n", seed);
    srand(seed);

#ifdef INSTRUMENT_UNINIT
    if (!outfile_name) {
        puts("Missing outfile for instrumentation!\n");
        return 1;
    }
#endif

    secure_calls = 0;
    plain_calls = 0;
    total_calls = 0;

    secure_threshold = (int) ((float) RAND_MAX * secure_call_ratio);
    depth_return_multiplier = RAND_MAX/MAX_DEPTH;
    return_threshold = (int) ((float) RAND_MAX * RETURN_PROBABILITY);

    while(total_calls < MAX_TOTAL_CALLS) {
        foo(0);
    }
        

    float actual_ratio = (float) secure_calls / (float) plain_calls;
#ifdef INSTRUMENT_UNINIT
    fprintf(stderr, "Stack size: %" PRIu64 "\n", stack_size);
    fprintf(stderr, "Requested ratio: %f\n", secure_call_ratio);
    fprintf(stderr, "Secure threshold: %d\n", secure_threshold);
    fprintf(stderr, "Secure calls made: %d\n", secure_calls);
    fprintf(stderr, "Plain calls made: %d\n", plain_calls);
    fprintf(stderr, "Actual plain calls made: %lu\n", _plain_call_count);
    fprintf(stderr, "Actual ratio: %f\n", actual_ratio);
    FILE *stats_out = fopen(outfile_name, "w");
    write_stats(stats_out);
	fclose(stats_out);
#endif

    puts("Benchmark execution completed successfully.\n");
    return 0;
}

