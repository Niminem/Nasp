# Nasp Refactoring Plan

## Overview

**Nasp** is a CLI tool for developing Google Apps Script projects locally using Nim. It's inspired by [Clasp](https://github.com/google/clasp) and enables:
- Local development with version control
- Nim-to-JavaScript compilation for Apps Script
- Bidirectional sync between local files and Google's Apps Script platform
- Remote function execution
- OAuth2 authentication management

## Current Architecture Analysis

### File Structure

```
src/
├── nasp.nim                    # Main CLI (453 lines - too large)
├── nasplib/
│   ├── credentials.nim         # Credentials parsing
│   ├── oauth2.nim              # OAuth2 implementation
│   └── gcp_apis.nim            # Google API wrappers
```

### Current Commands

1. **init** - Initialize nasp project
2. **create** - Create new Apps Script project
3. **clone** - Clone existing Apps Script project
4. **pull** - Pull latest changes from Apps Script
5. **push** - Push local changes to Apps Script
6. **open** - Open editor/logs/GCP dashboard
7. **run** - Execute Apps Script functions remotely
8. **scopes** - Manage OAuth scopes

## Issues & Areas for Refactoring

### 1. Separation of Concerns
- **Problem**: `nasp.nim` mixes CLI parsing, business logic, file I/O, and API calls
- **Impact**: Hard to test, maintain, and extend
- **Solution**: Split into layers:
  - CLI layer (command parsing/routing)
  - Service layer (project management, authentication, compilation)
  - Data layer (file operations, config management)

### 2. Authentication Flow
- **Problem**: `authenticate()` (lines 32-79) is long and handles multiple responsibilities
- **Impact**: Token refresh logic embedded in main flow, hard to test
- **Solution**: Extract to dedicated `AuthService` with clear responsibilities

### 3. Error Handling
- **Problem**: Inconsistent patterns (`quit()`, exceptions, early returns)
- **Impact**: Some error messages could be more informative
- **Solution**: Unified error handling strategy with custom exception types

### 4. File Operations
- **Problem**: File I/O scattered across handlers, path manipulation duplicated
- **Impact**: Code duplication, inconsistent behavior
- **Solution**: Centralized file manager module

### 5. Configuration Management
- **Problem**: `nasp.json` and `.access.json` read/written in multiple places, no validation
- **Impact**: No schema validation, potential for corruption
- **Solution**: Config manager with validation and schema

### 6. Build System
- **Problem**: `buildFromNimFiles()` uses `execCmdEx` directly, flags hard-coded
- **Impact**: Not configurable, hard to test
- **Solution**: Build configuration system with configurable flags

### 7. Code Duplication
- **Problem**: Similar patterns in command handlers, repeated parameter validation
- **Impact**: Maintenance burden, inconsistent behavior
- **Solution**: Shared utilities and typed parameter objects

### 8. Type Safety
- **Problem**: Heavy use of `Table[string, string]` for parameters, JSON parsing without strong types
- **Impact**: Runtime errors, poor IDE support
- **Solution**: Typed parameter objects per command

### 9. Testing Considerations
- **Problem**: Hard to test due to tight coupling, file I/O and HTTP calls not easily mockable
- **Impact**: No tests, regression risk
- **Solution**: Dependency injection or interfaces for testability

### 10. Documentation
- **Problem**: README incomplete, no inline documentation for complex functions
- **Impact**: Hard for new contributors, unclear architecture
- **Solution**: Comprehensive documentation and architecture docs

## Comparison with Clasp

### Current Nasp Run Command

**Implementation** (lines 343-378):
- ✅ Basic function execution
- ✅ Parameter passing via `--args`
- ✅ Error handling
- ❌ No `--nondev` flag (always runs in `devMode: true`)
- ❌ Uses `--args` instead of `--params` (clasp uses `--params`)
- ❌ No validation that script is deployed as API executable
- ❌ No check for `executionApi` in `appsscript.json`

### Missing Features from Clasp

#### High Priority

1. **Deployments**
   - `create-deployment` / `update-deployment` / `delete-deployment`
   - Version management
   - Deployment descriptions
   - **Why**: Essential for production use, required for non-dev mode runs

2. **Versions**
   - `create-version` with descriptions
   - `list-versions`
   - **Why**: Version control and deployment management

3. **Logs**
   - `logs` with `--watch`, `--json`, `--simplified`
   - StackDriver log integration
   - **Why**: Critical for debugging and monitoring

#### Medium Priority

4. **Status**
   - `show-file-status` (shows which files differ)
   - `--json` output option
   - **Why**: Helpful for seeing what changed before push

5. **API Management**
   - `list-apis`
   - `enable-api` / `disable-api`
   - `open-api-console`
   - **Why**: Required for enabling APIs needed by scripts

#### Low Priority

6. **Enhanced Open Commands**
   - `open-script` (current)
   - `open-web-app`
   - `open-container`
   - `open-credentials-setup`
   - **Why**: Convenience features

7. **Run Command Enhancements**
   - `--nondev` flag
   - Better parameter naming (`--params` instead of `--args`)
   - Validation for API executable deployment
   - Better error messages
   - **Why**: Parity with clasp, better UX

### Run Command Requirements (from Clasp)

From [clasp run documentation](https://github.com/google/clasp/blob/master/docs/run.md):

1. **Prerequisites validation**:
   - Script must be deployed as API executable
   - `appsscript.json` must have:
     ```json
     "executionApi": {
       "access": "ANYONE"  // or "MYSELF" or "DOMAIN"
     }
     ```

2. **API enabling**:
   - Required APIs must be enabled in GCP project

3. **Function scopes**:
   - Function must have proper OAuth scopes

## Proposed Architecture

### New File Structure

```
src/
├── nasp.nim                    # Main CLI entry point (thin router)
├── nasplib/
│   ├── commands/
│   │   ├── init.nim
│   │   ├── create.nim
│   │   ├── clone.nim
│   │   ├── pull.nim
│   │   ├── push.nim
│   │   ├── run.nim            # Enhanced run command
│   │   ├── deploy.nim          # NEW: Deployments
│   │   ├── versions.nim           # NEW: Versions
│   │   ├── logs.nim             # NEW: Logs
│   │   ├── status.nim           # NEW: Status
│   │   ├── apis.nim             # NEW: API management
│   │   ├── open.nim             # Enhanced open commands
│   │   └── scopes.nim
│   ├── services/
│   │   ├── auth_service.nim     # Authentication & token management
│   │   ├── project_service.nim # Project operations
│   │   ├── deployment_service.nim # Deployment operations
│   │   ├── build_service.nim   # Nim compilation
│   │   └── file_service.nim    # File operations
│   ├── models/
│   │   ├── project.nim         # Project configuration types
│   │   ├── deployment.nim      # Deployment types
│   │   ├── version.nim         # Version types
│   │   └── config.nim           # Config types
│   ├── utils/
│   │   ├── validation.nim      # Parameter & config validation
│   │   ├── formatting.nim      # Output formatting
│   │   ├── errors.nim          # Error types
│   │   └── logger.nim           # Debug logging
│   ├── credentials.nim
│   ├── oauth2.nim
│   └── gcp_apis.nim
```

### Service Layer Responsibilities

#### AuthService
- Token management (access/refresh)
- OAuth2 flow
- Token validation
- Scope management

#### ProjectService
- Project CRUD operations
- Project content management
- Project metadata

#### DeploymentService
- Create/update/delete deployments
- List deployments
- Deployment validation

#### BuildService
- Nim compilation
- Build configuration
- File exclusion logic

#### FileService
- File I/O operations
- Path manipulation
- Directory creation
- File filtering

### Model Layer

#### Project Config
```nim
type
  ProjectConfig* = object
    projectDir*: string
    creds*: string
    scriptId*: string
    projectId*: string
    scopes*: seq[string]
```

#### Access Config
```nim
type
  AccessConfig* = object
    accessToken*: string
    refreshToken*: string
    timestamp*: DateTime
    expiresIn*: int
```

#### Command Parameters
```nim
type
  RunParams* = object
    func*: string
    params*: Option[string]  # JSON array string
    nondev*: bool
  
  DeployParams* = object
    versionNumber*: Option[int]
    description*: Option[string]
    deploymentId*: Option[string]
```

## Refactoring Phases

### Phase 1: Foundation (Core Infrastructure)
**Goal**: Establish clean architecture foundation

1. **Create service layer structure**
   - Extract `AuthService` from `authenticate()`
   - Create `ProjectService` for project operations
   - Create `FileService` for file operations

2. **Create model layer**
   - Define typed config objects
   - Create command parameter types
   - Add validation logic

3. **Improve error handling**
   - Define custom exception types
   - Create error handling utilities
   - Standardize error messages

4. **Add logging system**
   - Debug logging with `DEBUG=nasp:*` support
   - Structured logging
   - Log levels

**Estimated effort**: 2-3 days

### Phase 2: Command Refactoring
**Goal**: Refactor existing commands to use new architecture

1. **Extract commands to separate modules**
   - Move each command handler to `commands/` directory
   - Update main CLI to route to command modules
   - Maintain backward compatibility

2. **Enhance run command**
   - Add `--nondev` flag
   - Rename `--args` to `--params`
   - Add executionApi validation
   - Improve error messages

3. **Improve existing commands**
   - Better parameter validation
   - Consistent error handling
   - JSON output options where applicable

**Estimated effort**: 2-3 days

### Phase 3: Missing Features (High Priority)
**Goal**: Add essential missing features from Clasp

1. **Deployments**
   - `create-deployment` command
   - `update-deployment` command
   - `delete-deployment` command
   - `list-deployments` command

2. **Versions**
   - `create-version` command
   - `list-versions` command

3. **Logs**
   - `logs` command with StackDriver integration
   - `--watch`, `--json`, `--simplified` flags

**Estimated effort**: 3-4 days

### Phase 4: Missing Features (Medium Priority)
**Goal**: Add helpful features from Clasp

1. **Status**
   - `show-file-status` command
   - Compare local vs remote files

2. **API Management**
   - `list-apis` command
   - `enable-api` / `disable-api` commands
   - `open-api-console` command

3. **Enhanced Open Commands**
   - `open-web-app`
   - `open-container`
   - `open-credentials-setup`

**Estimated effort**: 2-3 days

### Phase 5: Polish & Documentation
**Goal**: Improve UX and documentation

1. **Documentation**
   - Complete README.md
   - Add architecture documentation
   - Add inline code documentation
   - Create contributing guide

2. **Testing**
   - Add unit tests for services
   - Add integration tests for commands
   - Mock HTTP and file operations

3. **UX Improvements**
   - Better error messages
   - Progress indicators
   - Colorized output (optional)
   - Help text improvements

**Estimated effort**: 2-3 days

## Immediate Action Items

### Quick Wins (Can be done immediately)

1. **Fix run command**
   - Add `--nondev` flag
   - Rename `--args` to `--params`
   - Add basic executionApi validation

2. **Add debug logging**
   - Support `DEBUG=nasp:*` environment variable
   - Add debug statements throughout

3. **Improve error messages**
   - More descriptive error messages
   - Include actionable suggestions

### Before Major Refactoring

1. **Create test suite structure**
   - Set up testing framework
   - Create test utilities for mocking

2. **Document current behavior**
   - Document all commands and their behavior
   - Create test cases for regression testing

3. **Backup and version control**
   - Ensure all changes are committed
   - Create refactoring branch

## Implementation Guidelines

### Code Style
- Follow Nim style guide
- Use meaningful names
- Add documentation comments for public APIs
- Keep functions focused and small (< 50 lines when possible)

### Error Handling
- Use custom exception types
- Provide context in error messages
- Include actionable suggestions
- Log errors before raising

### Testing
- Test services in isolation
- Mock external dependencies (HTTP, file I/O)
- Test error cases
- Test edge cases

### Documentation
- Document public APIs
- Include usage examples
- Document architecture decisions
- Keep README up to date

## Success Criteria

### Phase 1 Complete
- [ ] Service layer extracted and tested
- [ ] Model layer defined
- [ ] Error handling standardized
- [ ] Logging system working

### Phase 2 Complete
- [ ] All commands refactored to new structure
- [ ] Run command enhanced with clasp parity
- [ ] All existing functionality preserved
- [ ] No regressions

### Phase 3 Complete
- [ ] Deployments fully implemented
- [ ] Versions fully implemented
- [ ] Logs fully implemented
- [ ] All features tested

### Phase 4 Complete
- [ ] Status command implemented
- [ ] API management implemented
- [ ] Enhanced open commands implemented

### Phase 5 Complete
- [ ] Documentation complete
- [ ] Test coverage > 70%
- [ ] All features documented
- [ ] Contributing guide created

## References

- [Clasp GitHub Repository](https://github.com/google/clasp)
- [Clasp Run Documentation](https://github.com/google/clasp/blob/master/docs/run.md)
- [Apps Script API Reference](https://developers.google.com/apps-script/api/reference/rest)
- [Google Drive API Reference](https://developers.google.com/drive/api/reference/rest)

## Notes

- Maintain backward compatibility during refactoring
- Test each phase before moving to next
- Get user feedback on UX improvements
- Consider performance implications of new architecture
- Keep nimble package structure compatible

