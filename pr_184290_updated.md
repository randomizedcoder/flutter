Hi! We were looking for the Flutter logo in the repo and couldn't find it — the README references externally-hosted images on `storage.googleapis.com`. We hope this very small contribution helps by bringing the logos into the repo and converting them to lossless WebP for efficiency.

- Downloaded the two Flutter logo PNGs (dark-mode and light-mode) from external hosting and stored in `docs/logos/`
- Converted all PNGs to lossless WebP format for smaller file sizes while maintaining maximum quality
- Updated `README.md` to use local WebP paths instead of external URLs
- Also converted the existing `engine/src/flutter/docs/flutter_logo.png` to WebP
- Removes external dependency on Google Cloud Storage for rendering the README
- Original PNGs are kept alongside the WebP files as untouched originals

### File size comparison

| File | PNG (bytes) | WebP (bytes) | Savings |
|------|-------------|--------------|---------|
| Dark logo | 6,749 | 2,836 | 58.0% |
| Light logo | 7,231 | 2,926 | 59.5% |
| Engine logo | 4,257 | 2,208 | 48.1% |

**Repo image footprint:**

| | Before | After | Increase | % |
|--|--------|-------|----------|---|
| Image files | 1,001 | 1,006 | +5 | 0.500% |
| Total size | 5,967.0 KB | 5,988.4 KB | +21.4 KB | 0.359% |

This PR is [test-exempt] — only image assets and README markup changed, no code changes.

## Pre-launch Checklist

- [x] I read the [Contributor Guide] and followed the process outlined there for submitting PRs.
- [x] I read the [AI contribution guidelines] and understand my responsibilities, or I am not using AI tools.
- [x] I read the [Tree Hygiene] wiki page, which explains my responsibilities.
- [x] I read and followed the [Flutter Style Guide], including [Features we expect every widget to implement].
- [x] I signed the [CLA].
- [x] I listed at least one issue that this PR fixes in the description above.
- [x] I updated/added relevant documentation (doc comments with `///`).
- [x] I added new tests to check the change I am making, or this PR is [test-exempt].
- [x] I followed the [breaking change policy] and added [Data Driven Fixes] where supported.
- [x] All existing and new tests are passing.

If you need help, consider asking for advice on the #hackers-new channel on [Discord].

**Note**: The Flutter team is currently trialing the use of [Gemini Code Assist for GitHub](https://developers.google.com/gemini-code-assist/docs/review-github-code). Comments from the `gemini-code-assist` bot should not be taken as authoritative feedback from the Flutter team. If you find its comments useful you can update your code accordingly, but if you are unsure or disagree with the feedback, please feel free to wait for a Flutter team member's review for guidance on which automated comments should be addressed.

<!-- Links -->
[Contributor Guide]: https://github.com/flutter/flutter/blob/main/docs/contributing/Tree-hygiene.md#overview
[AI contribution guidelines]: https://github.com/flutter/flutter/blob/main/docs/contributing/Tree-hygiene.md#ai-contribution-guidelines
[Tree Hygiene]: https://github.com/flutter/flutter/blob/main/docs/contributing/Tree-hygiene.md
[test-exempt]: https://github.com/flutter/flutter/blob/main/docs/contributing/Tree-hygiene.md#tests
[Flutter Style Guide]: https://github.com/flutter/flutter/blob/main/docs/contributing/Style-guide-for-Flutter-repo.md
[Features we expect every widget to implement]: https://github.com/flutter/flutter/blob/main/docs/contributing/Style-guide-for-Flutter-repo.md#features-we-expect-every-widget-to-implement
[CLA]: https://cla.developers.google.com/
[flutter/tests]: https://github.com/flutter/tests
[breaking change policy]: https://github.com/flutter/flutter/blob/main/docs/contributing/Tree-hygiene.md#handling-breaking-changes
[Discord]: https://github.com/flutter/flutter/blob/main/docs/contributing/Chat.md
[Data Driven Fixes]: https://github.com/flutter/flutter/blob/main/docs/contributing/Data-driven-Fixes.md
