# Changelog

## [0.1.9](https://github.com/paveg/molt/compare/molt-v0.1.8...molt-v0.1.9) (2026-04-10)


### Features

* add --compression flag (default off) to control Accept-Encoding ([#17](https://github.com/paveg/molt/issues/17)) ([0eb84ee](https://github.com/paveg/molt/commit/0eb84ee5c7e67d983cb42fbda19ca2a234d91e81)), closes [#14](https://github.com/paveg/molt/issues/14)

## [0.1.8](https://github.com/paveg/molt/compare/molt-v0.1.7...molt-v0.1.8) (2026-04-10)


### Features

* wire --insecure flag to HTTPS cert verification ([#12](https://github.com/paveg/molt/issues/12)) ([69d81cb](https://github.com/paveg/molt/commit/69d81cbcd4fe05790dbe44446833a7fcb0ec4013))

## [0.1.7](https://github.com/paveg/molt/compare/molt-v0.1.6...molt-v0.1.7) (2026-04-08)


### Features

* add Vercel Skills support and coordinator integration tests ([#9](https://github.com/paveg/molt/issues/9)) ([224aa97](https://github.com/paveg/molt/commit/224aa97bb8d531a46112c5faa829471a0dbe2b64))

## [0.1.6](https://github.com/paveg/molt/compare/molt-v0.1.5...molt-v0.1.6) (2026-04-06)


### Bug Fixes

* replace deprecated starts_with/ends_with with has_prefix/has_suffix ([0555710](https://github.com/paveg/molt/commit/055571069de1eebcaf6891d4a0c2050a6c712bf4))

## [0.1.5](https://github.com/paveg/molt/compare/molt-v0.1.4...molt-v0.1.5) (2026-04-06)


### Performance Improvements

* hot path optimizations for high-throughput scenarios ([ac65576](https://github.com/paveg/molt/commit/ac65576b499900bf3efaf598842263dfc4890a6d))

## [0.1.4](https://github.com/paveg/molt/compare/molt-v0.1.3...molt-v0.1.4) (2026-04-06)


### Bug Fixes

* 4 bugs, 9 boundary tests, rate limiter bounded queue ([5fe50f9](https://github.com/paveg/molt/commit/5fe50f91ece55965a2b31dead32da6dec9e44230))

## [0.1.3](https://github.com/paveg/molt/compare/molt-v0.1.2...molt-v0.1.3) (2026-04-05)


### Bug Fixes

* improve TUI layout with single-column stats ([fbefd97](https://github.com/paveg/molt/commit/fbefd9713dadccd62eccd756b72895c1ac030044))

## [0.1.2](https://github.com/paveg/molt/compare/molt-v0.1.1...molt-v0.1.2) (2026-04-05)


### Bug Fixes

* merge release build into release-please workflow ([eb3d68c](https://github.com/paveg/molt/commit/eb3d68c7e72da288deca16519a91381ddd9fb418))

## [0.1.1](https://github.com/paveg/molt/compare/molt-v0.1.0...molt-v0.1.1) (2026-04-05)


### Features

* add --body-file (-B) CLI option for reading request body from file ([f74c488](https://github.com/paveg/molt/commit/f74c48864de3c1a963e7d640130404a3764ba424))
* add --serve built-in test server, boundary tests, code simplification ([814dfd6](https://github.com/paveg/molt/commit/814dfd64a507bb5e9235198691ef27ce06c6dd77))
* add --timeout / -t CLI option for per-request timeout ([dd577ac](https://github.com/paveg/molt/commit/dd577ac3f92c45b595b7290c790f936af8d1b7a6))
* add --timeout, --body-file, --rate flags with error classification ([a0939de](https://github.com/paveg/molt/commit/a0939de98226df4c0ab43ec560efa5941270bd1a))
* add 9 features, code simplification, CD pipeline, and full HTTP methods ([0c07d43](https://github.com/paveg/molt/commit/0c07d43db3574be8ac41d41f4f68d43e248d403f))
* add classify_error for precise error categorization and timeout wrapping ([db7561e](https://github.com/paveg/molt/commit/db7561e40da578a7180fb2a3d395675d0fa99bba))
* add config validation tests ([731d2ac](https://github.com/paveg/molt/commit/731d2ac5b88122a96ff835a4df93666162fde160))
* add proper exit codes for CI/CD integration ([8d66e7d](https://github.com/paveg/molt/commit/8d66e7de4ba65b8e6d4610f045ab654d44d19f4c))
* add TTFB, CSV, debug, redirect, keepalive control, count suffixes, histogram fix ([9a8f4e2](https://github.com/paveg/molt/commit/9a8f4e2d5fff0d9aa4d1af6ef756d90e62fdc570))
* implement async HTTP worker loop ([093e253](https://github.com/paveg/molt/commit/093e253962de0fa2cbda98bb3bf3341fdd11772a))
* implement CLI entry point with argparse ([00fb2ef](https://github.com/paveg/molt/commit/00fb2ef670f42715c8ded9d0c997eac2cfecf144))
* implement Collector with HDR Histogram-based stats aggregation ([ecc596d](https://github.com/paveg/molt/commit/ecc596d438e7452e6cb414610c1585e5abff6e6a))
* implement Coordinated Omission correction with TDD ([6533460](https://github.com/paveg/molt/commit/6533460ebc20b1682c7b95e90c44ba17d13a5eeb))
* implement Coordinator with TaskGroup-based worker management ([702a2ba](https://github.com/paveg/molt/commit/702a2ba5c5bff76a180e675146f18036ba0817db))
* implement duration parser with full test coverage ([daade93](https://github.com/paveg/molt/commit/daade930cb204180452b5444806b388634603fcd))
* implement Gil Tene HDR Histogram with percentile accuracy ([bce4439](https://github.com/paveg/molt/commit/bce4439b49a1ca4dd53dbce6205e68701fd13b84))
* implement text summary reporter ([0cd6c0d](https://github.com/paveg/molt/commit/0cd6c0de4db0f0eeaa7d6b95c9d7f6653a75c182))
* implement token bucket rate limiter ([6e76124](https://github.com/paveg/molt/commit/6e76124c5e99c8929fb899cc45a857e4953e2dd0))
* implement TUI real-time display with mizchi/tui ([ee8d52e](https://github.com/paveg/molt/commit/ee8d52e545d850cc07e485949bf58c57feea0928))
* Phase 2 - JSON output, rate limiter, HTTP methods, CO correction ([82d1098](https://github.com/paveg/molt/commit/82d1098b869ff577f8eee76410fac983882249cd))
* scaffold project structure with shared types ([5e09871](https://github.com/paveg/molt/commit/5e09871a1987c0c9b13f0b7bb9a4bcd6d92864f5))
* wire --rate (-r) flag for token bucket rate limiting ([47f244a](https://github.com/paveg/molt/commit/47f244a23615f955cb44b4de1cf8494353ec1b6d))


### Bug Fixes

* add boundary guards to Histogram::new and Histogram::record ([bd1deef](https://github.com/paveg/molt/commit/bd1deef3fde5f4ada9c204244e13829cbb27dfa9))
* allow --serve without URL argument ([258f180](https://github.com/paveg/molt/commit/258f180f7d192fe3c0502c9bda89d16bd864d226))
* CI uses moon update instead of moon install, update docs ([348e67f](https://github.com/paveg/molt/commit/348e67f956c5e4d87b9b7e7908581b8a577cae31))
* clamp corrected latency to zero floor ([164506a](https://github.com/paveg/molt/commit/164506a98172f5c78e1e7256c3230cd97652bfaf))
* CRITICAL+IMPORTANT issues with boundary value tests ([abc15da](https://github.com/paveg/molt/commit/abc15da36b198d7e58c71fd93e9642d945c52270))
* guard against division by zero in compute_scheduled_time and clamp negative rate in RateLimiter ([0eb1ca9](https://github.com/paveg/molt/commit/0eb1ca94fac18c65c94e9c8cd02b92bf88a7d6ce))
* limit format check to .mbt files only ([8880a32](https://github.com/paveg/molt/commit/8880a3251852b5e51910aec36a013598e87ef19b))
* MUST-priority boundary guards with TDD ([69ee2ae](https://github.com/paveg/molt/commit/69ee2aea903dd22b466f1687c34d8304f8d60e5b))
* rate limiter precision, CLI input validation, and duration overflow ([59a667b](https://github.com/paveg/molt/commit/59a667bc330581ab6e4d033d391a64fccba4fc29))
* reject CRLF characters in parse_header to prevent header injection ([d284e74](https://github.com/paveg/molt/commit/d284e7499f37391b1ef53049247699f0e4ecc2da))
* treat HTTP 5xx as failures, add JSON string escaping and missing fields ([0e9a91c](https://github.com/paveg/molt/commit/0e9a91cfe7b5e7829754e3e0d93149b59979bd7e))
* URL parsing for Worker and argv handling for CLI ([ab8a858](https://github.com/paveg/molt/commit/ab8a85856ba391d0c8a1d2084da316d909d1dd76))
