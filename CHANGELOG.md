# Changelog

## [0.2.0](https://github.com/flakeyard/workflow-release/compare/v0.1.1...v0.2.0) (2026-11-02)


### Features

* check the App key where the token is created ([#11](https://github.com/flakeyard/workflow-release/issues/11)) ([cab9363](https://github.com/flakeyard/workflow-release/commit/cab9363ac02b253edf15319640fba938acbec887))
* decide whether a release is due ([#10](https://github.com/flakeyard/workflow-release/issues/10)) ([da96e84](https://github.com/flakeyard/workflow-release/commit/da96e846c1ce15522b75de71b13c278010ecb7c1))
* gate only the job that releases ([#12](https://github.com/flakeyard/workflow-release/issues/12)) ([4648ded](https://github.com/flakeyard/workflow-release/commit/4648ded71b4c7c6577f660b1747a23ec24585306))


### Bug Fixes

* abandon by reverting, no takeover without a run, skip release/v0 ([#14](https://github.com/flakeyard/workflow-release/issues/14)) ([e7d0835](https://github.com/flakeyard/workflow-release/commit/e7d0835cbefcdb7e7f76ac334d08931abcbadf6f))

## [0.1.1](https://github.com/flakeyard/workflow-release/compare/v0.1.0...v0.1.1) (2026-10-31)


### Bug Fixes

* fail when a released tag or its release cannot be read ([#2](https://github.com/flakeyard/workflow-release/issues/2)) ([faee35a](https://github.com/flakeyard/workflow-release/commit/faee35a999858b20e4d580a7673278d88981bc67))
* publish a release only in the run of its commit ([#6](https://github.com/flakeyard/workflow-release/issues/6)) ([28d7b4e](https://github.com/flakeyard/workflow-release/commit/28d7b4e52b2a51c431faa8459a01227f2dce446c))

## 0.1.0 (2026-10-28)


### Features

* follow v0 releases and document the bootstrap ([17e2111](https://github.com/flakeyard/workflow-release/commit/17e21113fff94da06546928bfa20960bf98ebf57))
* reusable release workflow ([cc4a62d](https://github.com/flakeyard/workflow-release/commit/cc4a62d9198a4ab6a37d7a8dd82c58181d2100fc))


### Bug Fixes

* address the audit and merge the run checks into preflight ([afd1486](https://github.com/flakeyard/workflow-release/commit/afd1486e5bc909dc7c28d13a5533f85774ffff57))
* address the design review ([b2aafb8](https://github.com/flakeyard/workflow-release/commit/b2aafb86d5810121b0788191376219f1af09fd15))
* recover pending release pull requests and skip branch creation ([79cd1f7](https://github.com/flakeyard/workflow-release/commit/79cd1f7ef685314d2b091089d9761e8a14cd46f9))
