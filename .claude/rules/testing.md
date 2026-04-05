# Testing Rules for molt

## TDD Required

- Write failing tests before implementation (Red-Green-Refactor)
- Every new function must have boundary value tests

## Boundary Value Checklist

For every function, test:
- Zero / empty inputs
- Negative values where positive expected
- Maximum / overflow values
- Off-by-one boundaries (e.g., 499 vs 500 for HTTP status)
- Division by zero paths
- Error/exception paths

## Test Execution

```sh
moon test --target native   # full suite (208 tests)
moon test                   # wasm-gc subset (152 tests)
```

- native-only packages: worker, coordinator, tui, rate_limiter
- Adding Config fields breaks ALL existing Config literals in test files
- After any type change, grep and update all construction sites
