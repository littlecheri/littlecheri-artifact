/* Courtesy of https://blog.memzero.de/fn-wrapper-macro-magic/ */

// Get Nth argument.
#define CPP_NTH(_0, _1, _2, _3, _4, _5, _6, _7, _8, n, ...) n
// Get number of arguments (uses gcc/clang extension for empty argument).
#define CPP_ARGC(...) CPP_NTH(_0, ##__VA_ARGS__, 8, 7, 6, 5, 4, 3, 2, 1, 0)

// Utility to concatenate preprocessor tokens.
#define CONCAT2(lhs, rhs) lhs##rhs
#define CONCAT1(lhs, rhs) CONCAT2(lhs, rhs)

#define ARGS0()
#define ARGS1() a0
#define ARGS2() a1, ARGS1()
#define ARGS3() a2, ARGS2()
#define ARGS4() a3, ARGS3()
#define ARGS5() a4, ARGS4()
#define ARGS6() a5, ARGS5()
#define ARGS7() a6, ARGS6()
#define ARGS8() a7, ARGS7()
#define ARGS9() a8, ARGS8()

// Invoke correct ARGSn macro depending on #arguments.
#define ARGS(...) CONCAT1(ARGS, CPP_ARGC(__VA_ARGS__))()

#define TYPEDARGS0() void // void because otherwise compiler complains about function not having a prototype
#define TYPEDARGS1(ty)      ty a0
#define TYPEDARGS2(ty, ...) ty a1, TYPEDARGS1(__VA_ARGS__)
#define TYPEDARGS3(ty, ...) ty a2, TYPEDARGS2(__VA_ARGS__)
#define TYPEDARGS4(ty, ...) ty a3, TYPEDARGS3(__VA_ARGS__)
#define TYPEDARGS5(ty, ...) ty a4, TYPEDARGS4(__VA_ARGS__)
#define TYPEDARGS6(ty, ...) ty a5, TYPEDARGS5(__VA_ARGS__)
#define TYPEDARGS7(ty, ...) ty a6, TYPEDARGS6(__VA_ARGS__)
#define TYPEDARGS8(ty, ...) ty a7, TYPEDARGS7(__VA_ARGS__)
#define TYPEDARGS9(ty, ...) ty a8, TYPEDARGS8(__VA_ARGS__)

// Invoke correct TYPEDARGSn macro depending on #arguments.
#define TYPEDARGS(...) CONCAT1(TYPEDARGS, CPP_ARGC(__VA_ARGS__))(__VA_ARGS__)

#define UNINIT_WRAPPER_DECL(ret, fn, ...)\
  ret __attribute__((noinline,cheri_uninit)) __uninit_wrap_##fn(TYPEDARGS(__VA_ARGS__));

#ifdef INSTRUMENT_UNINIT
#include <stdint.h>
extern uint64_t _uninit_call_count;
#define UNINIT_WRAPPER_IMPL UNINIT_WRAPPER_IMPL_INSTRUMENTATION
#else
#define UNINIT_WRAPPER_IMPL UNINIT_WRAPPER_IMPL_PERFORMANCE
#endif /* INSTRUMENT_UNINIT */

#define UNINIT_WRAPPER_DECL_IMPL(...) \
  UNINIT_WRAPPER_DECL(__VA_ARGS__) \
  UNINIT_WRAPPER_IMPL(__VA_ARGS__)

// wrapper for instrumented runs
#define UNINIT_WRAPPER_IMPL_INSTRUMENTATION(ret, fn, ...)                    \
  ret __attribute__((noinline,cheri_uninit)) __uninit_wrap_##fn(TYPEDARGS(__VA_ARGS__)) { \
    _uninit_call_count++; \
    return fn(ARGS(__VA_ARGS__));      \
  }

// wrapper for performance runs
#define UNINIT_WRAPPER_IMPL_PERFORMANCE(ret, fn, ...)                    \
  ret __attribute__((noinline,cheri_uninit)) __uninit_wrap_##fn(TYPEDARGS(__VA_ARGS__)) { \
    return fn(ARGS(__VA_ARGS__));      \
  }

#ifdef WRAP_UNINIT
#define MAYBE_UNINIT_WRAPPER(fn) __uninit_wrap_##fn
#else
#define MAYBE_UNINIT_WRAPPER(fn) fn
#endif
