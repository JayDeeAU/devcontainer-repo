#!/usr/bin/env bash

# Set bash options for safer error handling
set -uo pipefail  # -u: Fail on undefined variables, -o pipefail: Captures errors in pipes

# Error handler function
handle_error() {
  local line=$1
  local command=$2
  local code=$3
  echo "❌ Error occurred at line $line: Command '$command' exited with status $code"
  echo "Please report this issue with the details above"
  
  # Clean up temp directory if it exists
  if [ -n "${TEMP_DIR:-}" ] && [ -d "$TEMP_DIR" ]; then
    echo "Cleaning up temporary files in $TEMP_DIR"
    rm -rf "$TEMP_DIR"
  fi
  
  exit 1
}

# Set up error trap - capture line number, command and exit code
trap 'handle_error ${LINENO} "$BASH_COMMAND" $?' ERR

# -------------------------------------------------------------------
# secrets_scan.sh
# 📦 Shell-agnostic secrets scanner with support for CI/CD environments
# -------------------------------------------------------------------

# Show help if requested
if [[ "$#" -ge 1 && ("$1" == "--help" || "$1" == "-h") ]]; then
  echo "
Usage: $0 [mode] [options]

Mode:
  loose     Use LOOSE mode - more targeted patterns with fewer false positives (default)
  strict    Use STRICT mode - broader patterns that may include more false positives

Options:
  --verbose           Show more detailed output
  --high-only         Only fail on HIGH severity findings (good for CI/CD)
  path/to/allow.txt   Path to acceptable findings file (default: .gitleaks-acceptable.txt)

Examples:
  $0                            # Run in loose mode
  $0 strict                     # Run in strict mode
  $0 loose --verbose            # Run in loose mode with verbose output
  $0 loose --high-only          # Run in loose mode, only fail on high severity findings
  $0 loose custom-allow.txt     # Run with custom acceptable findings file
"
  exit 0
fi

USE_BAT=false  # Set to true if you want pretty output (bat required)

STRICT_MODE="${1:-loose}"  # Accepts "strict" or "loose"

echo "🔍 Starting secret scan in: $(pwd)"
echo "🔧 Using shell: $SHELL"

# Initialize match counter and arrays
MATCHES=0
MATCH_FILES=()

# Create temporary directory for match details
TEMP_DIR=$(mktemp -d)
# Use trap to clean up temp directory even if the script errors out
trap 'echo "Cleaning up temp files in $TEMP_DIR"; rm -rf "$TEMP_DIR"' EXIT INT TERM

# Check if .gitignore exists and add its patterns
GITIGNORE_GLOBS=()
if [[ -f ".gitignore" ]]; then
  echo "📄 Found .gitignore file, adding its patterns to exclusions"
  while IFS= read -r pattern; do
    # Skip empty lines and comments
    if [[ -z "$pattern" || "$pattern" == \#* ]]; then
      continue
    fi
    
    # Convert .gitignore pattern to ripgrep glob format
    if [[ "$pattern" == /* ]]; then
      # If pattern starts with slash, it's a root pattern
      GITIGNORE_GLOBS+=(--glob "!$pattern")
    else
      # Otherwise, it applies to any directory level
      GITIGNORE_GLOBS+=(--glob "!**/$pattern")
    fi
  done < ".gitignore"
  echo "✓ Added ${#GITIGNORE_GLOBS[@]} patterns from .gitignore"
fi

# Excluded directories
EXCLUDE_DIRS=(
  --glob '!**/node_modules/**'
  --glob '!**/.git/**'
  --glob '!**/venv/**'
  --glob '!**/__pycache__/**'
  --glob '!**/new_sales_polling/**'
  --glob '!**/webhooks/**'
  --glob '!**/*openapi*'
)

# Combine manual exclusions with .gitignore patterns
EXCLUDE_DIRS=("${EXCLUDE_DIRS[@]}" "${GITIGNORE_GLOBS[@]}")

# Set verbosity flag
VERBOSE=false
if [[ "$#" -ge 2 && "$2" == "--verbose" ]]; then
  VERBOSE=true
  echo "🔍 Running in VERBOSE mode (more detailed output)"
fi

# Set acceptable findings file location
ACCEPTABLE_FINDINGS_FILE=".gitleaks-acceptable.txt"
# Check if third argument is --high-only or a file path
if [[ "$#" -ge 3 && "$3" != "--high-only" ]]; then
  ACCEPTABLE_FINDINGS_FILE="$3"
fi

# Check if we should only report high severity findings
HIGH_SEVERITY_ONLY=false
if [[ "$#" -ge 2 && "$2" == "--high-only" ]]; then
  HIGH_SEVERITY_ONLY=true
  echo "🔍 Running in HIGH SEVERITY ONLY mode (will ignore lower severity findings)"
fi
if [[ "$#" -ge 3 && "$3" == "--high-only" ]]; then
  HIGH_SEVERITY_ONLY=true
  echo "🔍 Running in HIGH SEVERITY ONLY mode (will ignore lower severity findings)"
fi

# Check for acceptable findings file
ACCEPTABLE_FINDINGS=()
if [[ -f "$ACCEPTABLE_FINDINGS_FILE" ]]; then
  echo "📄 Found acceptable findings file: $ACCEPTABLE_FINDINGS_FILE"
  while IFS= read -r line; do
    # Skip empty lines and comments
    if [[ -z "$line" || "$line" == \#* ]]; then
      continue
    fi
    
    ACCEPTABLE_FINDINGS+=("$line")
  done < "$ACCEPTABLE_FINDINGS_FILE"
  echo "✓ Loaded ${#ACCEPTABLE_FINDINGS[@]} acceptable findings"
else
  echo "ℹ️ No acceptable findings file found. All findings will be reported."
fi

# Make sure to include all INI files
EXTENSIONS=(
  '*.env'
  '*.env.*'
  '.env'
  '.env.*'
  '*.py'
  '*.json'
  '*.yaml'
  '*.yml'
  '*.ts'
  '*.js'
  '*.sh'
  '*.conf'
  '*.ini'
  'Dockerfile*'
  'docker-compose*'
  '*.properties'
  '*.config'
  '*.cfg'
  '*.xml'
  '*.tf'    # Terraform
  '*.tfvars' # Terraform variables
  '*.pem'   # Private keys
  '*.key'   # Potential key files
)

# Configuration files that need stricter scanning (more aggressive patterns)
CONFIG_FILES=(
  '.env'
  '*.env'
  '*.env.*'
  '*.ini'
  '*.conf'
  '*.cfg'
  '*.properties'
  '*.tfvars'
  '*.yaml'
  '*.yml'
  'config.*'
)

echo "🔎 Will scan ${#EXTENSIONS[@]} file types with special attention to ${#CONFIG_FILES[@]} config file types"

# Smart loose patterns (real secret candidates)
# Simplified for better compatibility - broken into smaller, more manageable patterns
LOOSE_PATTERNS=(
  "access[_-]?token[\"\\'=:\\s]+[A-Za-z0-9_.\-]{10,}"
  "auth[_-]?token[\"\\'=:\\s]+[A-Za-z0-9_.\-]{10,}"
  "apikey[\"\\'=:\\s]+[A-Za-z0-9_.\-]{10,}"
  "client[_-]?secret[\"\\'=:\\s]+[A-Za-z0-9_.\-]{10,}"
  "secret[\"\\'=:\\s]+[A-Za-z0-9_.\-]{10,}"
  "Bearer\\s+[A-Za-z0-9\-_=]+\\.[A-Za-z0-9\-_=]+\\.[A-Za-z0-9\-_=]+"  # JWT
  "AKIA[0-9A-Z]{16}"  # AWS access key ID
  "sk_live_[0-9a-zA-Z]{24}"  # Stripe live key
  "sk_test_[0-9a-zA-Z]{24}"  # Stripe test key
  "token[\"\\'=:\\s]+[A-Za-z0-9_.\-]{10,}"
  "password[\"\\'=:\\s]+[A-Za-z0-9_.\-]{8,}"
)

# Strict patterns (false positives included)
STRICT_PATTERNS=(
  'token'
  'secret'
  'password'
  'auth'
  'client'
)

# Add comprehensive patterns from industry best practices
# These patterns have been simplified to avoid regex errors
ADDITIONAL_PATTERNS=(
  # AWS Patterns
  "AKIA[0-9A-Z]{16}"
  "aws.*access.*key.*=\\s*[A-Za-z0-9/\\+=]{40}"
  "aws.*secret.*key.*=\\s*[A-Za-z0-9/\\+=]{40}"
  
  # Private Keys
  "-----BEGIN.*PRIVATE KEY"
  
  # Generic API Keys/Tokens with specific formatting
  "[a-zA-Z0-9_-]*:[a-zA-Z0-9_-]+@[a-zA-Z0-9]+"
  "eyJ[A-Za-z0-9-_]{20,}"  # JWT Tokens
  "gh[pousr]_[A-Za-z0-9_]{36}"  # GitHub Tokens
  
  # Cloud Service Provider Patterns
  "AIza[0-9A-Za-Z-_]{35}"  # Google API Key
  "ya29\\.[0-9A-Za-z\\-_]+"  # Google OAuth
  
  # Service-specific credentials
  "client_id\\s*=\\s*[a-zA-Z0-9._\\-]+"          # Client IDs
  "client_secret\\s*=\\s*[a-zA-Z0-9._\\-]+"      # Client secrets
  "api_key\\s*=\\s*[a-zA-Z0-9._\\-]+"            # API keys
  "access_token\\s*=\\s*[a-zA-Z0-9._\\-]+"       # Access tokens
  
  # Database Connection Strings
  "postgres(ql)?://[^:]+:[^@]+@[^/]+"  # PostgreSQL connection
  "mysql://[^:]+:[^@]+@[^/]+"         # MySQL connection
  "mongodb(\\+srv)?://[^:]+:[^@]+@[^/]+"  # MongoDB connection
  "redis://[^:]+:[^@]+@.+"               # Redis connection
  "DATABASE_URL\\s*=\\s*.+:.+@.+"        # Generic database URL
  
  # Payment Service Patterns
  "sk_live_[0-9a-zA-Z]{24}"  # Stripe Secret Key
  "rk_live_[0-9a-zA-Z]{24}"  # Stripe Restricted Key
  
  # More specific token formats
  "xox[baprs]-[0-9a-zA-Z]{10,48}"  # Slack API Token
  "T[a-zA-Z0-9_]{8}/B[a-zA-Z0-9_]{8}/[a-zA-Z0-9_]{24}"  # Slack Webhook
  
  # Common password patterns
  "password\\s*=\\s*[^\\s]+"  # Generic password assignment
  "pwd\\s*=\\s*[^\\s]+"       # Abbreviated password
  "pass\\s*=\\s*[^\\s]+"      # Another common password variable
  
  # Dangerous logging patterns - simplified
  "console\\.log.*pass"
  "console\\.log.*password"
  "console\\.log.*secret"
  "console\\.log.*token"
  "console\\.log.*key"
  "console\\.log.*cred"
  "print.*pass"
  "print.*password"
  "print.*secret"
  "print.*token"
  "print.*key"
  "echo.*password"
  "echo.*secret"
  "echo.*token"
  "echo.*key"
  
  # Return/response exposure patterns
  "return.*password"
  "return.*token"
  "return.*secret"
  "return.*key"
  "res\\.send.*password"
  "res\\.send.*token"
  "res\\.send.*secret"
  "res\\.json.*password"
  "res\\.json.*token"
  "res\\.json.*secret"
  
  # INI section headers
  "\\[.*api.*\\]"
  "\\[.*key.*\\]"
  "\\[.*secret.*\\]"
  "\\[.*credential.*\\]"
  "\\[.*auth.*\\]"
)

# Positive patterns that should ALWAYS be flagged regardless of context
# These are high-confidence patterns for actual secrets (not variable references)
OVERRIDE_PATTERNS=(
  # Client secrets
  "client_secret\\s*=\\s*[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"
  "client_secret\\s*=\\s*[a-zA-Z0-9._\\-]+"
  
  # Actual tokens (not variable references)
  "token\\s*=\\s*[\"\\''][0-9a-zA-Z._=/-]{16,}[\"\\'']"
  "secret\\s*=\\s*[\"\\''][0-9a-zA-Z._=/-]{16,}[\"\\'']"
  "password\\s*=\\s*[\"\\''][0-9a-zA-Z._=/-]{8,}[\"\\'']"
  "access_key\\s*=\\s*[\"\\''][0-9a-zA-Z]{16,}[\"\\'']"
  
  # Database connection strings and credentials
  "DATABASE_URL\\s*=\\s*[^=]+(:|%3A)[^=]+(@|%40)"
  "(POSTGRES|SQL|DB|MYSQL|MONGO)(_)?PASS(WORD)?\\s*=\\s*[^\\s$]+"
  
  # Password patterns in config/env files
  "PASSWORD\\s*=\\s*[^\\s$]+"
  "PASS\\s*=\\s*[^\\s$]+"
  "PWD\\s*=\\s*[^\\s$]+"
)

# Context-aware filtering to reduce false positives 
# Simplified to avoid regex errors
EXCLUSION_PATTERNS=(
  # Exclude simple debug statements that DON'T contain sensitive info
  "console\\.log\\([\"\\''][^\"\\']*[\"\\'']\\)"
  
  # Exclude test or example code
  "example|sample|mock|dummy|test|placeholder|template|default"
  
  # Exclude comments
  "\\s*//|\\s*#"
  
  # Exclude TODOs and FIXMEs
  "TODO|FIXME"
  
  # Exclude development URLs
  "github\\.com|localhost|127\\.0\\.1"
  
  # Exclude docstrings about tokens
  "token management|token information|token endpoints"
  
  # Exclude common variable assignments without actual secrets
  "token\\s*=\\s*\\w+\\.json"
  "token\\s*=\\s*\\w+\\.copy"
  
  # Exclude function parameters that reference tokens but don't contain actual secrets
  "refresh_token=refresh_token"
)

if [[ "$STRICT_MODE" == "strict" ]]; then
  echo "⚠️  Running in STRICT mode (more false positives)"
  PATTERNS=("${STRICT_PATTERNS[@]}")
else
  echo "🔍 Running in LOOSE mode (real secrets only)"
  PATTERNS=("${LOOSE_PATTERNS[@]}" "${ADDITIONAL_PATTERNS[@]}")
fi

# Check if ripgrep is installed
if ! command -v rg &> /dev/null; then
  echo "❌ Error: ripgrep (rg) is not installed. Please install it first."
  exit 1
fi

# Define the severity marker function
mark_severity() {
  local content="$1"
  local file="$2"
  
  # First categorize the type of risk
  local risk_type="HARDCODED SECRET"
  
  # Check for data exposure
  if [[ "$content" =~ console\. ]] || [[ "$content" =~ print ]] || [[ "$content" =~ echo ]]; then
    risk_type="DATA EXPOSURE IN LOGS"
  elif [[ "$content" =~ return ]] || [[ "$content" =~ res\. ]] || [[ "$content" =~ response ]]; then
    risk_type="DATA EXPOSURE IN RESPONSE"
  elif [[ "$content" =~ \[ ]] && [[ "$content" =~ \] ]]; then
    risk_type="SENSITIVE CONFIG SECTION"
  fi
  
  # High severity - actual value assignments in config or .env files
  if [[ "$file" =~ \.(ini|conf|env|cfg|yaml|yml|properties|tfvars)$ ]] || [[ "$file" == ".env" ]] || [[ "$file" =~ \.env\. ]]; then
    if [[ "$content" =~ (client_secret|api_key|password|token|access_key|DATABASE_URL|POSTGRES_PASSWORD)[[:space:]]*= ]]; then
      echo "🔴 HIGH SEVERITY - $risk_type"
      return
    fi
  fi
  
  # Logging/exposure of sensitive data
  if [[ "$content" =~ console\. ]] && 
     { [[ "$content" =~ pass ]] || 
       [[ "$content" =~ secret ]] || 
       [[ "$content" =~ token ]] || 
       [[ "$content" =~ api ]] || 
       [[ "$content" =~ cred ]]; }; then
    echo "🔴 HIGH SEVERITY - $risk_type"
    return
  fi
  
  if [[ "$content" =~ print ]] && 
     { [[ "$content" =~ pass ]] || 
       [[ "$content" =~ token ]] || 
       [[ "$content" =~ secret ]] || 
       [[ "$content" =~ api ]]; }; then
    echo "🔴 HIGH SEVERITY - $risk_type"
    return
  fi
  
  # Medium severity - possible hardcoded values in code
  if [[ "$content" =~ (=|:)[[:space:]]*[\"\'][0-9a-zA-Z._=/-]{16,}[\"\'] ]]; then
    echo "🟠 MEDIUM SEVERITY - $risk_type"
    return
  fi
  
  # Database credentials in any file
  if [[ "$content" =~ (postgres|sql|mysql|mongo) ]] && [[ "$content" =~ (password|pass|pwd) ]]; then
    echo "🔴 HIGH SEVERITY - $risk_type"
    return
  fi
  
  # Password in variable name with value that contains special chars
  if [[ "$content" =~ (password|pass|pwd)[[:space:]]*= ]] && [[ "$content" =~ [\!\@\#\$\%\^\&\*] ]]; then
    echo "🔴 HIGH SEVERITY - $risk_type"
    return
  fi
  
  # Low severity - may be a variable reference or false positive
  echo "🟡 LOW SEVERITY - $risk_type"
}

# Track progress
TOTAL_PATTERNS=${#PATTERNS[@]}
CURRENT_PATTERN=0

echo "🔎 Starting scan with $TOTAL_PATTERNS patterns against ${#EXTENSIONS[@]} file extensions"
echo "🔧 Using ${#EXCLUSION_PATTERNS[@]} exclusion patterns to reduce false positives"

# Create the matches file
touch "$TEMP_DIR/matches.txt"

# First, specifically target config files which are higher risk
echo "🔍 First phase: Scanning configuration files (highest risk for secrets)"

# Create list of config file globs
CONFIG_GLOBS=()
for ext in "${CONFIG_FILES[@]}"; do
  CONFIG_GLOBS+=(--glob "$ext")
done

# Config-specific patterns (simplified versions to avoid regex errors)
CONFIG_PATTERNS=(
  "password\\s*=\\s*[^\\s$]+"
  "secret\\s*=\\s*[^\\s$]+"
  "key\\s*=\\s*[^\\s$]+"
  "token\\s*=\\s*[^\\s$]+"
  "auth\\s*=\\s*[^\\s$]+"
  "credential\\s*=\\s*[^\\s$]+"
  "api[_-]?key\\s*=\\s*[^\\s$]+"
  "database\\s*=\\s*[^\\s$]+"
  "user\\s*=\\s*[^\\s$]+"
  "pass\\s*=\\s*[^\\s$]+"
  "pwd\\s*=\\s*[^\\s$]+"
)

# Scan config files specifically
for pattern in "${CONFIG_PATTERNS[@]}"; do
  echo "  🔍 Scanning config files for: $pattern"
  
  error_log="$TEMP_DIR/config_scan_error.log"
  
  # Execute ripgrep with simplified pattern
  rg --no-config --no-heading --line-number --color=never "$pattern" "${CONFIG_GLOBS[@]}" "${EXCLUDE_DIRS[@]}" . > "$TEMP_DIR/config_scan_results.txt" 2>"$error_log" || true
  
  # Fixed: Get result count without arithmetic comparison which was causing errors
  result_count=0
  if [[ -f "$TEMP_DIR/config_scan_results.txt" ]]; then
    result_count=$(grep -c "." "$TEMP_DIR/config_scan_results.txt" 2>/dev/null || echo 0)
  fi
  
  if [ "$result_count" -gt 0 ]; then
    echo "  → Found $result_count potential matches in config files"
    
    # Add matches to main results file
    cat "$TEMP_DIR/config_scan_results.txt" >> "$TEMP_DIR/matches.txt"
  fi
done

echo "✅ Completed config file scanning"
echo "🔎 Starting main pattern scanning"

# Now continue with the regular pattern scanning
for pattern in "${PATTERNS[@]}"; do
  # Fixed: Use let for arithmetic operations which is more shell-compatible
  let "CURRENT_PATTERN=CURRENT_PATTERN+1" || true
  echo "🔎 [$CURRENT_PATTERN/$TOTAL_PATTERNS] Scanning for pattern: $pattern"
  
  # Search across all file extensions at once
  GLOBS=()
  for ext in "${EXTENSIONS[@]}"; do
    GLOBS+=(--glob "$ext")
  done
  
  # Perform the search with proper error handling
  # The || true ensures the script continues even if rg finds no matches (returns non-zero)
  echo "  Running: rg --pcre2 \"$pattern\" (with ${#GLOBS[@]} file types and ${#EXCLUDE_DIRS[@]} exclusion patterns)"
  
  # Add debug info if requested
  if [[ "$VERBOSE" == true ]]; then
    echo "  Pattern: $pattern"
    echo "  Excluding directories defined in EXCLUDE_DIRS and .gitignore patterns"
  fi
  
  # Create a unique error log file for each pattern
  error_log="$TEMP_DIR/rg_error_${CURRENT_PATTERN}.log"
  
  # Safer execution with full error handling
  rg --no-config --no-heading --line-number --color=never --pcre2 "$pattern" "${GLOBS[@]}" "${EXCLUDE_DIRS[@]}" . > "$TEMP_DIR/pattern_${CURRENT_PATTERN}_results.txt" 2>"$error_log" || true
  
  # Check if there was an error with this pattern
  if [[ -s "$error_log" ]]; then
    # Check if it's a regex syntax error
    if grep -q "syntax error" "$error_log" || grep -q "regex parse error" "$error_log"; then
      echo "⚠️ Warning: Pattern may be too complex for PCRE2. Simplifying and retrying..."
      # Try a simplified version by removing some complexity
      simplified_pattern=$(echo "$pattern" | sed 's/\\s\+/\\s*/g' | sed 's/{[0-9]\+,}/{10,}/g')
      echo "  Retrying with simplified pattern: $simplified_pattern"
      rg --no-config --no-heading --line-number --color=never --pcre2 "$simplified_pattern" "${GLOBS[@]}" "${EXCLUDE_DIRS[@]}" . > "$TEMP_DIR/pattern_${CURRENT_PATTERN}_results.txt" 2>"$error_log" || true
      
      # If still an error, try basic regex
      if [[ -s "$error_log" ]]; then
        echo "  Still encountering issues, trying basic regex instead of PCRE2..."
        basic_pattern=$(echo "$pattern" | sed 's/\\s/[[:space:]]/g' | sed 's/{[0-9]\+,}/{10,}/g' | sed 's/\\./\./g')
        rg --no-config --no-heading --line-number --color=never "$basic_pattern" "${GLOBS[@]}" "${EXCLUDE_DIRS[@]}" . > "$TEMP_DIR/pattern_${CURRENT_PATTERN}_results.txt" 2>"$error_log" || true
      fi
    fi
  fi
  
  # Get the result count - fixed to avoid arithmetic comparison errors
  result_count=0
  if [[ -f "$TEMP_DIR/pattern_${CURRENT_PATTERN}_results.txt" ]]; then
    result_count=$(grep -c "." "$TEMP_DIR/pattern_${CURRENT_PATTERN}_results.txt" 2>/dev/null || echo 0)
  fi
  
  echo "  → Found $result_count potential matches"
  
  # Fix: Use -gt format for integer comparison to avoid syntax errors
  if [ "$result_count" -gt 0 ]; then
    echo "✓ Processing matches for pattern: $pattern"
    
    # Debug the results
    if [[ $result_count -gt 0 && "$VERBOSE" == true ]]; then
      echo "  → First match example: $(head -n1 "$TEMP_DIR/pattern_${CURRENT_PATTERN}_results.txt")"
    fi
    
    # Process each match carefully with proper error handling
    while IFS= read -r line || [[ -n "$line" ]]; do
      # Skip empty lines
      [[ -z "$line" ]] && continue
      
      # Extract file path and line number
      file=$(echo "$line" | cut -d: -f1)
      lineno=$(echo "$line" | cut -d: -f2)
      content=$(echo "$line" | cut -d: -f3-)
      
      # Verify extracted data
      if [[ -z "$file" || -z "$lineno" ]]; then
        echo "  WARNING: Invalid match format: $line"
        continue
      fi
      
      # Check if match is in acceptable findings
      is_acceptable=false
      match_fingerprint="${file}:${lineno}:${pattern}"
      
      for acceptable in "${ACCEPTABLE_FINDINGS[@]}"; do
        # Check if the line exactly matches an acceptable finding
        if [[ "$match_fingerprint" == "$acceptable" ]]; then
          echo "  → Acceptable finding in $file line $lineno (exact match)"
          is_acceptable=true
          break
        fi
        
        # Check if there's a pattern match (e.g., filename:* or *:pattern)
        if [[ "$acceptable" == *"*"* ]]; then
          # Convert the acceptable finding to a regex pattern
          regex_pattern=$(echo "$acceptable" | sed 's/\*/.*/g')
          if [[ "$match_fingerprint" =~ $regex_pattern ]]; then
            echo "  → Acceptable finding in $file line $lineno (pattern match: $acceptable)"
            is_acceptable=true
            break
          fi
        fi
      done
      
      # Skip if acceptable
      if [[ "$is_acceptable" == true ]]; then
        continue
      fi

      # If we're in high-severity-only mode, check the severity before reporting
      if [[ "$HIGH_SEVERITY_ONLY" == true ]]; then
        severity=$(mark_severity "$content" "$file")
        if [[ "$severity" != *"HIGH SEVERITY"* ]]; then
          echo "  → Skipping non-high severity finding in $file line $lineno (--high-only mode)"
          continue
        fi
      fi
      
      # First check if this is a definite override pattern that should always be included
      is_override=false
      for override in "${OVERRIDE_PATTERNS[@]}"; do
        if echo "$content" | grep -q -P "$override" 2>/dev/null; then
          echo "  → High confidence match in $file line $lineno (matched override pattern)"
          is_override=true
          break
        fi
      done
      
      # If it's an override pattern, include it no matter what
      if [[ "$is_override" == true ]]; then
        # Add to match files array if not already there
        if ! echo " ${MATCH_FILES[*]} " | grep -q " ${file} "; then
          MATCH_FILES+=("$file")
        fi
        
        # Save details to temp file
        echo "$line" >> "$TEMP_DIR/matches.txt"
        
        # Increment match counter - fixed to use let for better compatibility
        let "MATCHES=MATCHES+1" || true
        continue
      fi
      
      # Filter false positives by checking for exclusion patterns
      is_excluded=false
      for exclusion in "${EXCLUSION_PATTERNS[@]}"; do
        if echo "$content" | grep -q -P "$exclusion" 2>/dev/null; then
          echo "  → Filtered likely false positive in $file line $lineno (matched exclusion)"
          is_excluded=true
          break
        fi
      done
      
      # Skip if excluded
      if [[ "$is_excluded" == true ]]; then
        continue
      fi
      
      # Context-aware filtering based on file type and content
      # Check if it's a code file with variable assignment
      if [[ "$file" =~ \.(py|js|ts|java|rb|go)$ ]]; then
        # Look for variable assignments that are likely not real secrets
        if [[ "$content" =~ (=|:)\ *[A-Za-z0-9_]+\. ]] && 
           [[ ! "$content" =~ console\. ]] &&
           [[ ! "$content" =~ print ]] &&
           [[ ! "$content" =~ return ]]; then
          echo "  → Filtered likely code reference in $file line $lineno (variable reference)"
          continue
        fi
      fi
      
      # Add to match files array if not already there
      if ! echo " ${MATCH_FILES[*]} " | grep -q " ${file} "; then
        MATCH_FILES+=("$file")
      fi
      
      # Save details to temp file
      echo "$line" >> "$TEMP_DIR/matches.txt"
      
      # Increment match counter - fixed to use let for better compatibility
      let "MATCHES=MATCHES+1" || true
    done < "$TEMP_DIR/pattern_${CURRENT_PATTERN}_results.txt"
  else
    echo "  → No results for this pattern"
  fi
done

echo
echo "=== SCAN SUMMARY ==="
echo

# Check if we actually found any matches
if [[ -f "$TEMP_DIR/matches.txt" && -s "$TEMP_DIR/matches.txt" ]]; then
  TOTAL_MATCHES=$(wc -l < "$TEMP_DIR/matches.txt")
  echo "🚨 Found $TOTAL_MATCHES potential secrets in ${#MATCH_FILES[@]} files."
  
  # Calculate severity breakdown
  HIGH_COUNT=0
  MEDIUM_COUNT=0
  LOW_COUNT=0
  FINGERPRINTS=()
  
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    
    # Extract parts carefully
    file=$(echo "$line" | cut -d: -f1)
    lineno=$(echo "$line" | cut -d: -f2)
    content=$(echo "$line" | cut -d: -f3-)
    
    # Determine severity
    severity=$(mark_severity "$content" "$file")
    
    # Create fingerprint
    fingerprint="${file}:${lineno}"
    FINGERPRINTS+=("$fingerprint")
    
    # Count by severity - fixed to use let for increment
    if [[ "$severity" == *"HIGH SEVERITY"* ]]; then
      let "HIGH_COUNT=HIGH_COUNT+1" || true
    elif [[ "$severity" == *"MEDIUM SEVERITY"* ]]; then
      let "MEDIUM_COUNT=MEDIUM_COUNT+1" || true
    else
      let "LOW_COUNT=LOW_COUNT+1" || true
    fi
  done < "$TEMP_DIR/matches.txt"
  
  echo "  🔴 HIGH SEVERITY: $HIGH_COUNT findings"
  echo "  🟠 MEDIUM SEVERITY: $MEDIUM_COUNT findings"
  echo "  🟡 LOW SEVERITY: $LOW_COUNT findings"
  echo
  
  # Group findings by risk type for easier analysis
  echo "=== FINDINGS BY RISK TYPE ==="
  echo
  
  # Initialize counters for each risk type
  HARDCODED_COUNT=0
  LOG_EXPOSURE_COUNT=0
  RESPONSE_EXPOSURE_COUNT=0
  CONFIG_COUNT=0
  
  # Count findings by risk type
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    
    # Get content
    content=$(echo "$line" | cut -d: -f3-)
    file=$(echo "$line" | cut -d: -f1)
    
    # Determine risk type - fixed to use let for increment
    if [[ "$content" =~ console\. ]] || [[ "$content" =~ print ]] || [[ "$content" =~ echo ]]; then
      let "LOG_EXPOSURE_COUNT=LOG_EXPOSURE_COUNT+1" || true
    elif [[ "$content" =~ return ]] || [[ "$content" =~ res\. ]] || [[ "$content" =~ response ]]; then
      let "RESPONSE_EXPOSURE_COUNT=RESPONSE_EXPOSURE_COUNT+1" || true
    elif [[ "$file" =~ \.(ini|conf|env|cfg|yaml|yml|properties|tfvars)$ ]] || [[ "$file" == ".env" ]]; then
      let "CONFIG_COUNT=CONFIG_COUNT+1" || true
    else
      let "HARDCODED_COUNT=HARDCODED_COUNT+1" || true
    fi
  done < "$TEMP_DIR/matches.txt"
  
  echo "  📊 FINDINGS BY RISK TYPE:"
  echo "     - $HARDCODED_COUNT hardcoded secrets"
  echo "     - $LOG_EXPOSURE_COUNT data exposures in logs"
  echo "     - $RESPONSE_EXPOSURE_COUNT data exposures in responses"
  echo "     - $CONFIG_COUNT sensitive configuration items"
  echo
  echo "=== DETAILED MATCHES ==="
  echo
  
  # Display detailed matches with safeguards
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    
    # Extract parts carefully
    file=$(echo "$line" | cut -d: -f1)
    lineno=$(echo "$line" | cut -d: -f2)
    
    # Get content, being careful about colons in the content
    content=$(echo "$line" | cut -d: -f3-)
    
    # Determine severity
    severity=$(mark_severity "$content" "$file")
    
    # Create fingerprint for this finding
    fingerprint="${file}:${lineno}"
    
    echo "⚠️  $severity - MATCH FOUND in $file line $lineno:"
    echo "   FINGERPRINT: $fingerprint"
    
    if [[ -f "$file" ]]; then
      if [[ "$USE_BAT" == true ]] && command -v bat &> /dev/null; then
        bat --style=numbers --color=always --highlight-line "$lineno" "$file" | head -n $((lineno + 2)) | tail -n 5
      else
        # Display more context (lines before and after)
        # Fixed: Use arithmetic calculation for safer operations
        start_line=1
        if [ "$lineno" -gt 3 ]; then
          start_line=$((lineno - 2))
        fi
        
        end_line=$((lineno + 2))
        
        echo "   CODE CONTEXT:"
        line_content="   --------------------------------------------------"
        echo "$line_content"
        
        # Get lines before
        for (( i=start_line; i<lineno; i++ )); do
          ctx_line=$(sed "${i}q;d" "$file" 2>/dev/null || echo "[Could not display line]")
          printf "   %3d | %s\n" "$i" "$ctx_line"
        done
        
        # Highlight the line with the finding
        finding_line=$(sed "${lineno}q;d" "$file" 2>/dev/null || echo "[Could not display line]")
        printf "   %3d | %s  <-- ⚠️ FINDING HERE\n" "$lineno" "$finding_line"
        
        # Get lines after
        for (( i=lineno+1; i<=end_line; i++ )); do
          ctx_line=$(sed "${i}q;d" "$file" 2>/dev/null || echo "")
          # Skip if past EOF
          [[ -z "$ctx_line" ]] && continue
          printf "   %3d | %s\n" "$i" "$ctx_line"
        done
        echo "   --------------------------------------------------"
      fi
    else
      echo "   [File not accessible: $file]"
      echo "   MATCH: $content"
    fi
    echo
  done < "$TEMP_DIR/matches.txt"
  
  # Write fingerprints to file for future use
  echo "# Generated fingerprints from scan on $(date)" > "$TEMP_DIR/fingerprints.txt"
  echo "# Add lines from this file to .gitleaks-acceptable.txt to whitelist them" >> "$TEMP_DIR/fingerprints.txt"
  echo "# Format: file:line:pattern" >> "$TEMP_DIR/fingerprints.txt"
  echo "" >> "$TEMP_DIR/fingerprints.txt"
  
  # Write each unique fingerprint with pattern
  PROCESSED_FINGERPRINTS=()
  
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    
    # Extract parts carefully
    file=$(echo "$line" | cut -d: -f1)
    lineno=$(echo "$line" | cut -d: -f2)
    
    # Create fingerprint
    fingerprint="${file}:${lineno}"
    
    # Check if we've already processed this finding
    if echo "${PROCESSED_FINGERPRINTS[*]}" | grep -q "$fingerprint"; then
      continue
    fi
    
    # Add to processed list
    PROCESSED_FINGERPRINTS+=("$fingerprint")
    
    # Add appropriate pattern
    for pattern in "${PATTERNS[@]}"; do
      if grep -q "$pattern" <<< "$line"; then
        echo "${file}:${lineno}:${pattern}" >> "$TEMP_DIR/fingerprints.txt"
        break
      fi
    done
  done < "$TEMP_DIR/matches.txt"
  
  # Copy fingerprints file to current directory
  cp "$TEMP_DIR/fingerprints.txt" "./secrets_scan_fingerprints.txt"
  
  # Provide remediation guidance
  echo
  echo "=== REMEDIATION GUIDANCE ==="
  echo
  echo "🛠️  Next steps by risk type:"
  
  if [[ $HARDCODED_COUNT -gt 0 ]]; then
    echo
    echo "   🔑 HARDCODED SECRETS ($HARDCODED_COUNT findings):"
    echo "     - Remove hardcoded secrets from code and use environment variables instead"
    echo "     - Store secrets in a secure vault like AWS Secrets Manager, HashiCorp Vault, etc."
    echo "     - Use a .env file (not committed to version control) for local development"
    echo "     - Consider any already-committed secrets compromised and rotate them immediately"
  fi
  
  if [[ $LOG_EXPOSURE_COUNT -gt 0 ]]; then
    echo
    echo "   📝 DATA EXPOSURE IN LOGS ($LOG_EXPOSURE_COUNT findings):"
    echo "     - Never log sensitive values like passwords, tokens, or keys"
    echo "     - Use redaction patterns like console.log('token:', '***REDACTED***')"
    echo "     - Create helper functions that automatically redact sensitive fields"
    echo "     - Implement proper debug levels to control what gets logged"
  fi
  
  if [[ $RESPONSE_EXPOSURE_COUNT -gt 0 ]]; then
    echo
    echo "   🌐 DATA EXPOSURE IN RESPONSES ($RESPONSE_EXPOSURE_COUNT findings):"
    echo "     - Never return sensitive values in API responses"
    echo "     - Create data sanitization functions that strip sensitive fields before sending"
    echo "     - Use response schemas or serializers that explicitly define what gets returned"
    echo "     - Add unit tests to verify sensitive data isn't leaked in responses"
  fi
  
  if [[ $CONFIG_COUNT -gt 0 ]]; then
    echo
    echo "   ⚙️ SENSITIVE CONFIGURATION ($CONFIG_COUNT findings):"
    echo "     - Move sensitive values from configuration files to environment variables"
    echo "     - Use .env.example files with placeholder values as templates"
    echo "     - In CI/CD environments, use secure environment variable storage"
    echo "     - For infrastructure-as-code, use secure variable handling mechanisms"
  fi
  
  echo
  echo "🔁 CI/CD Integration:"
  echo "   A file 'secrets_scan_fingerprints.txt' has been created with fingerprints of all findings."
  echo "   To suppress known/acceptable findings in CI/CD:"
  echo "   1. Review the fingerprints and copy acceptable ones to .gitleaks-acceptable.txt"
  echo "   2. Run with --high-only flag to only fail on high severity findings"
  echo "   Example: $0 loose --high-only"
  echo
  
  # In CI/CD mode, only exit with error if there are HIGH severity findings
  if [[ "$HIGH_SEVERITY_ONLY" == true ]]; then
    if [ "$HIGH_COUNT" -gt 0 ]; then
      echo "❌ CI/CD Check Failed: $HIGH_COUNT high severity findings detected"
      exit 1
    else
      echo "✅ CI/CD Check Passed: No high severity findings detected"
      exit 0
    fi
  else
    exit 1
  fi
else
  echo "✅ No secrets detected in the scanned files."
  
  # Count how many files were actually eligible for scanning
  eligible_files=$(find . -type f \( $(for ext in "${EXTENSIONS[@]}"; do printf " -name '%s' -o" "$ext"; done | sed 's/ -o$//') \) | grep -v -E "node_modules|\.git|venv|__pycache__|new_sales_polling|webhooks" | wc -l | tr -d ' ')
  echo "   Scanned approximately $eligible_files files matching the target extensions."
  
  # Debug info about patterns and extensions
  echo
  echo "Debug information:"
  echo "   - Using ${#PATTERNS[@]} patterns in $STRICT_MODE mode"
  echo "   - Using ${#EXCLUSION_PATTERNS[@]} exclusion patterns to reduce false positives"
  echo "   - Using ${#EXCLUDE_DIRS[@]} directory exclusion patterns (including .gitignore)"
  echo "   - Searching for ${#EXTENSIONS[@]} file extensions"
  echo "   - Loaded ${#ACCEPTABLE_FINDINGS[@]} acceptable findings"
  
  exit 0
fi