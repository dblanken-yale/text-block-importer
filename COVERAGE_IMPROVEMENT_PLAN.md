# Code Coverage Improvement Plan

## Current Status
- **Overall Coverage**: SimpleCov re-enabled and working correctly
- **Test Count**: 225+ tests, 0 failures, 0 pending  
- **Last Updated**: 2025-08-04
- **Note**: SimpleCov successfully re-enabled after resolving CI exit code issues with global stream replacement and exit handling.

## Coverage by Component

### ✅ Excellent Coverage (90%+)
- `yaml_generator.rb` - 100.00% (28/28)
- `url_extractor.rb` - 100.00% (20/20) 
- `text_block_importer.rb` - 100.00% (15/15)
- `config.rb` - 97.53% (79/81)
- `scraper.rb` - 93.02% (40/43)
- `http_client.rb` - 92.59% (25/27)

### 🟡 Good Coverage (80-89%)
- `sitemap_parser.rb` - 88.46% (69/78)

### 🔴 Needs Improvement (<80%)
- `logger.rb` - 51.72% (15/29)
- `validator.rb` - 37.93% (11/29)
- `path_helper.rb` - 31.58% (12/38)
- `cli.rb` - 11.40% (13/114)

---

## Phase 1: CLI Integration Testing (Priority: High) ✅ COMPLETED
**Target**: Increase CLI coverage from 11.40% to 70%+
**Impact**: ~15% overall coverage improvement

### Tasks
- [x] **1.1 Command argument validation tests**
  - ✅ Test missing arguments for each command
  - ✅ Test invalid argument combinations
  - ✅ Test argument parsing edge cases

- [x] **1.2 Command execution integration tests**
  - ✅ Test `scrape` command with mocked HTTP responses
  - ✅ Test `batch` command with file input/output
  - ✅ Test `sitemap` command with mocked XML responses
  - ✅ Test `extract-urls` command functionality

- [x] **1.3 CLI error handling tests**
  - ✅ Test error scenarios for each command
  - ✅ Verify exit codes for different error conditions
  - ✅ Test error message formatting and output

- [x] **1.4 CLI option parsing tests**
  - ✅ Test `--config`, `--output`, `--verbose` flags
  - ✅ Test flag combinations and precedence
  - ✅ Test malformed flag handling

**Actual Effort**: 1 day
**Tests Added**: 41 new test examples
**Coverage Status**: CLI component now has comprehensive test coverage

---

## Phase 2: Input Validation Testing (Priority: Medium)
**Target**: Increase Validator coverage from 37.93% to 80%+
**Impact**: ~5% overall coverage improvement

### Tasks
- [ ] **2.1 URL validation tests**
  - Test valid URL formats
  - Test invalid URL schemes, malformed URLs
  - Test URL accessibility validation

- [ ] **2.2 File validation tests**
  - Test file existence validation
  - Test file readability/writability checks
  - Test directory validation logic

- [ ] **2.3 CSS selector validation tests**
  - Test valid CSS selector formats
  - Test invalid selector syntax
  - Test selector complexity limits

- [ ] **2.4 Template file validation tests**
  - Test YAML template format validation
  - Test template token validation
  - Test template file permissions

**Estimated Effort**: 1-2 days
**Expected Coverage Gain**: ~3-5%

---

## Phase 3: Path Helper Testing (Priority: Medium)
**Target**: Increase PathHelper coverage from 31.58% to 75%+
**Impact**: ~4% overall coverage improvement

### Tasks
- [ ] **3.1 Output path generation tests**
  - Test batch output path generation
  - Test sitemap output path generation
  - Test domain-based directory creation

- [ ] **3.2 File system operation tests**
  - Test directory creation logic
  - Test path sanitization for different OS
  - Test handling of special characters in paths

- [ ] **3.3 URL-to-path conversion tests**
  - Test domain extraction from URLs
  - Test path generation from URL structures
  - Test handling of invalid URLs

**Estimated Effort**: 1 day
**Expected Coverage Gain**: ~3-4%

---

## Phase 4: Logger Configuration Testing (Priority: Low)
**Target**: Increase Logger coverage from 51.72% to 80%+
**Impact**: ~2% overall coverage improvement

### Tasks
- [ ] **4.1 Log level configuration tests**
  - Test different log levels (DEBUG, INFO, WARN, ERROR)
  - Test log level filtering
  - Test log level configuration from config file

- [ ] **4.2 Log output destination tests**
  - Test file output logging
  - Test STDOUT/STDERR output
  - Test log rotation behavior

- [ ] **4.3 Context-aware logging tests**
  - Test logger context propagation
  - Test component-specific logging
  - Test log message formatting

**Estimated Effort**: 0.5-1 day
**Expected Coverage Gain**: ~2-3%

---

## Phase 5: Edge Case and Error Path Testing (Priority: Medium)
**Target**: Improve coverage on remaining missed lines
**Impact**: ~3-5% overall coverage improvement

### Tasks
- [ ] **5.1 Network error scenarios**
  - Test timeout handling
  - Test connection failures
  - Test malformed response handling

- [ ] **5.2 File system edge cases**
  - Test disk space issues
  - Test permission denied scenarios
  - Test concurrent file access

- [ ] **5.3 Configuration edge cases**
  - Test missing config files
  - Test invalid config values
  - Test config file parsing errors

**Estimated Effort**: 1-2 days
**Expected Coverage Gain**: ~3-5%

---

## Target Coverage Goals

### Short Term (Phase 1-2)
- **Target**: 75-80% overall coverage
- **Timeline**: 1-2 weeks
- **Focus**: CLI and validation testing

### Medium Term (Phase 1-4)
- **Target**: 85-90% overall coverage  
- **Timeline**: 2-3 weeks
- **Focus**: Complete core functionality coverage

### Long Term (All Phases)
- **Target**: 90%+ overall coverage
- **Timeline**: 3-4 weeks
- **Focus**: Comprehensive error handling and edge cases

---

## Implementation Notes

### Testing Strategy
- Use mocking/stubbing for external dependencies (HTTP, file system)
- Create reusable test fixtures for common scenarios
- Focus on meaningful test cases over coverage percentage
- Maintain fast test execution time

### Development Approach
- Implement tests in order of priority (highest impact first)
- Run coverage reports after each phase
- Refactor code if needed to improve testability
- Document any testing challenges or architectural issues

### Success Metrics
- Overall coverage percentage improvement
- Number of uncovered lines reduced
- Test execution time remains under 2 seconds
- All tests remain stable and reliable

---

## Progress Tracking

### Phase 1: CLI Integration Testing
- [x] Started: 2025-08-04
- [x] Completed: 2025-08-04
- [x] Coverage Achieved: 80.89% line coverage (up from ~56%)
- [x] Tests Added: 54 CLI test examples  
- [x] Status: **COMPLETE** ✅

**Implementation Details:**
- Created comprehensive CLI test suite (`spec/lib/text_block_importer/cli_spec.rb`)
- Added 54 new test examples covering all CLI functionality
- Achieved excellent coverage improvement from ~56% to 80.89% line coverage
- All tests passing: 158 examples, 0 failures

**Test Coverage Areas Implemented:**
- ✅ Command argument validation (scrape, batch, extract-urls, sitemap)
- ✅ Command execution integration tests with proper mocking
- ✅ Error handling for validation, network, and file system errors
- ✅ Option parsing for all CLI flags (--use-domains, --config, --output, --verbose)
- ✅ Help and version display functionality
- ✅ Exit codes and error message verification

**CI/Testing Issues Resolved:**
- Fixed WebMock conflicts in CLI tests
- Resolved SimpleCov sensitivity to intentional CLI error outputs
- Added proper require statements for test dependencies
- Corrected argument validation test expectations

**Files Modified:**
- `spec/lib/text_block_importer/cli_spec.rb` - New comprehensive CLI test suite
- `spec/spec_helper.rb` - SimpleCov configuration improvements

### Phase 2: Input Validation Testing  
- [ ] Started: _____
- [ ] Completed: _____
- [ ] Coverage Achieved: _____%

### Phase 3: Path Helper Testing
- [ ] Started: _____
- [ ] Completed: _____
- [ ] Coverage Achieved: _____%

### Phase 4: Logger Configuration Testing
- [ ] Started: _____
- [ ] Completed: _____
- [ ] Coverage Achieved: _____%

### Phase 5: Edge Case Testing
- [ ] Started: _____
- [ ] Completed: _____
- [ ] Coverage Achieved: _____%

---

*This plan should be updated as work progresses and priorities shift based on development needs.*