#!/usr/bin/env python3
"""
Enhanced Python Secrets Scanner

A simple but powerful tool for detecting hardcoded credentials, exposed sensitive data,
and other security issues in source code.

Features:
- Detects hardcoded secrets and credentials
- Finds instances where sensitive data might be exposed through logs or responses
- Manages acceptable findings via a allowlist file
- Provides clear, actionable output sorted by severity
- Supports both loose and strict scanning modes
- Integrates with CI/CD pipelines

Usage:
    python secrets_scanner.py [options]

Options:
    --mode {loose,strict}    Scanning mode, default: loose
    --verbose                Show more detailed output
    --high-only              Only fail on HIGH severity findings (good for CI/CD)
    --allow-file PATH        Path to acceptable findings file (default: .gitleaks-acceptable.txt)
    --directory PATH         Directory to scan (default: current directory)
    --scan-gitignored        Scan files that are excluded by .gitignore
    --check-git-history      Check if gitignored files were previously committed
"""

import os
import sys
import re
import argparse
import fnmatch
import subprocess
from pathlib import Path
from datetime import datetime
from enum import Enum
from typing import List, Set, Dict, Tuple, Optional, Pattern


class Severity(Enum):
    """Enumeration for different severity levels of findings."""
    HIGH = "🔴 HIGH SEVERITY"
    MEDIUM = "🟠 MEDIUM SEVERITY"
    LOW = "🟡 LOW SEVERITY"


class RiskType(Enum):
    """Enumeration for different risk types."""
    HARDCODED_SECRET = "HARDCODED SECRET"
    DATA_EXPOSURE_LOGS = "DATA EXPOSURE IN LOGS"
    DATA_EXPOSURE_RESPONSE = "DATA EXPOSURE IN RESPONSE"
    SENSITIVE_CONFIG = "SENSITIVE CONFIG SECTION"


class Finding:
    """Class representing a secret finding."""
    
    def __init__(self, file_path: str, line_number: int, 
                 line_content: str, pattern: str, 
                 severity: Severity = Severity.LOW, 
                 risk_type: RiskType = RiskType.HARDCODED_SECRET,
                 is_gitignored: bool = False,
                 in_git_history: bool = False):
        self.file_path = file_path
        self.line_number = line_number
        self.line_content = line_content
        self.pattern = pattern
        self.severity = severity
        self.risk_type = risk_type
        self.fingerprint = f"{file_path}:{line_number}"
        self.full_fingerprint = f"{file_path}:{line_number}:{pattern}"
        self.is_gitignored = is_gitignored
        self.in_git_history = in_git_history
    
    def __str__(self) -> str:
        return f"{self.severity.value} - {self.risk_type.value} in {self.file_path}:{self.line_number}"


class GitUtils:
    """Utility class for Git operations."""
    
    @staticmethod
    def is_git_repository(directory: str = ".") -> bool:
        """Check if the directory is a Git repository."""
        try:
            result = subprocess.run(
                ["git", "-C", directory, "rev-parse", "--is-inside-work-tree"],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                check=False
            )
            return result.returncode == 0 and result.stdout.strip() == "true"
        except Exception:
            return False
    
    @staticmethod
    def get_gitignore_patterns(directory: str = ".") -> List[str]:
        """Get the patterns from .gitignore file."""
        gitignore_path = os.path.join(directory, ".gitignore")
        patterns = []
        
        if os.path.isfile(gitignore_path):
            try:
                with open(gitignore_path, 'r') as f:
                    for line in f:
                        line = line.strip()
                        if not line or line.startswith('#'):
                            continue
                        patterns.append(line)
            except Exception as e:
                print(f"⚠️ Warning: Could not read .gitignore file: {e}")
        
        return patterns
    
    @staticmethod
    def is_file_gitignored(file_path: str, directory: str = ".") -> bool:
        """Check if a file is ignored by Git."""
        try:
            result = subprocess.run(
                ["git", "-C", directory, "check-ignore", "-q", file_path],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=False
            )
            return result.returncode == 0
        except Exception:
            return False
    
    @staticmethod
    def is_file_in_git_history(file_path: str, directory: str = ".") -> bool:
        """Check if a file has been previously committed to Git."""
        try:
            rel_path = os.path.relpath(file_path, directory)
            result = subprocess.run(
                ["git", "-C", directory, "log", "--all", "--name-only", "--format=format:", "--", rel_path],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                check=False
            )
            return bool(result.stdout.strip())
        except Exception as e:
            print(f"⚠️ Warning: Could not check git history for {file_path}: {e}")
            return False


class SecretsScanner:
    """A simpler, more direct scanner for finding secrets in code."""
    
    def __init__(self, mode: str = "loose", verbose: bool = False, 
                high_only: bool = False, allow_file: str = ".gitleaks-acceptable.txt",
                directory: str = ".", scan_gitignored: bool = False,
                check_git_history: bool = False, use_detect_secrets: bool = False):
        
        """Initialize the Scanner with the given settings."""
        self.mode = mode
        self.verbose = verbose
        self.high_only = high_only
        self.allow_file = allow_file
        self.directory = directory
        self.scan_gitignored = scan_gitignored
        self.check_git_history = check_git_history
        self.use_detect_secrets = use_detect_secrets
        self.findings: List[Finding] = []
        self.acceptable_findings: List[str] = []
        
        # Check if detect-secrets is available when requested
        if self.use_detect_secrets:
            try:
                import detect_secrets
                print("✓ detect-secrets library found and will be used for additional scanning")
            except ImportError:
                print("⚠️ Warning: detect-secrets library not installed but --use-detect-secrets was specified")
                print("   Install with: pip install detect-secrets")
                print("   Continuing with only direct pattern scanning")
                self.use_detect_secrets = False
    
        
        # Check if we're in a Git repository
        self.is_git_repo = GitUtils.is_git_repository(directory)
        if self.check_git_history and not self.is_git_repo:
            print("⚠️ Warning: --check-git-history specified but not in a Git repository. Feature will be disabled.")
            self.check_git_history = False
        
        # File extensions to scan
        self.extensions = [
            '*.env', '*.env.*', '.env', '.env.*', '*.py', '*.json', 
            '*.yaml', '*.yml', '*.ts*', '*.*js*', '*.sh*.*', '*.conf', '*rc',
            '*.ini', 'Dockerfile*', 'docker-compose*', '*.properties', '*.txt',
            '*.config', '*.cfg', '*.xml', '*.tf', '*.tfvars', '*.pem', '*.key'
        ]
        
        # Config files to pay special attention to
        self.config_files = [
            '.env', '*.env', '*.env.*', '*.ini', '*.conf', '*.cfg',
            '*.properties', '*.tfvars', '*.yaml', '*.yml', 'config.*'
        ]
        
        # Excluded directories and paths
        self.exclude_dirs = [
            '**/node_modules/**', '**/.git/**', '**/venv/**', 
            '**/__pycache__/**', '**/new_sales_polling/**', 
            '**/webhooks/**', '**/*openapi*', '*sample*'
        ]
        
        # Add gitignore patterns if not scanning gitignored files
        if not self.scan_gitignored:
            self._add_gitignore_patterns()
        
        # Load acceptable findings
        self._load_acceptable_findings()
        
        # Load patterns based on mode
        self._load_patterns()
        
        # Pre-compile patterns for efficiency
        self._compile_patterns()
    
    def _load_acceptable_findings(self) -> None:
        """Load the list of acceptable findings from the allowlist file."""
        if os.path.isfile(self.allow_file):
            print(f"📄 Found acceptable findings file: {self.allow_file}")
            try:
                with open(self.allow_file, 'r') as f:
                    for line in f:
                        line = line.strip()
                        if not line or line.startswith('#'):
                            continue
                        self.acceptable_findings.append(line)
                print(f"✓ Loaded {len(self.acceptable_findings)} acceptable findings")
            except Exception as e:
                print(f"⚠️ Warning: Could not read allowlist file: {e}")
        else:
            print(f"ℹ️ No acceptable findings file found at {self.allow_file}. All findings will be reported.")
    
    def _add_gitignore_patterns(self) -> None:
        """Add patterns from .gitignore to excluded directories."""
        if os.path.isfile('.gitignore'):
            print("📄 Found .gitignore file, adding its patterns to exclusions")
            try:
                with open('.gitignore', 'r') as f:
                    for line in f:
                        line = line.strip()
                        if not line or line.startswith('#'):
                            continue
                        
                        # Convert .gitignore pattern to glob format
                        if line.startswith('/'):
                            pattern = line[1:]
                        else:
                            pattern = f"**/{line}"
                            
                        if pattern not in self.exclude_dirs:
                            self.exclude_dirs.append(pattern)
                print(f"✓ Added patterns from .gitignore")
            except Exception as e:
                print(f"⚠️ Warning: Could not read .gitignore file: {e}")
    
    def _load_patterns(self) -> None:
        """Load the appropriate regex patterns based on the scanning mode."""
        # Load patterns from bash script - these are simplified for readability
        self.loose_patterns = [
            r"access[_-]?token[\"\\'=:\\s]+[A-Za-z0-9_.-]{10,}",
            r"auth[_-]?token[\"\\'=:\\s]+[A-Za-z0-9_.-]{10,}",
            r"apikey[\"\\'=:\\s]+[A-Za-z0-9_.-]{10,}",
            r"client[_-]?secret[\"\\'=:\\s]+[A-Za-z0-9_.-]{10,}",
            r"secret[\"\\'=:\\s]+[A-Za-z0-9_.-]{10,}",
            r"Bearer\s+[A-Za-z0-9_-]+",  # Simplified JWT pattern
            r"AKIA[0-9A-Z]{16}",  # AWS access key ID
            r"sk_live_[0-9a-zA-Z]{24}",  # Stripe live key
            r"sk_test_[0-9a-zA-Z]{24}",  # Stripe test key
            r"token[\"\\'=:\\s]+[A-Za-z0-9_.-]{10,}",
            r"password[\"\\'=:\\s]+[A-Za-z0-9_.-]{8,}"
        ]
        
        # Additional patterns for loose mode
        self.additional_patterns = [
            # AWS Patterns
            r"aws.*access.*key.*=\s*[A-Za-z0-9/+=]{20,}",
            r"aws.*secret.*key.*=\s*[A-Za-z0-9/+=]{20,}",
            
            # Private Keys
            r"-----BEGIN.*PRIVATE KEY",
            
            # Generic API Keys/Tokens
            r"[a-zA-Z0-9_-]*:[a-zA-Z0-9_-]+@[a-zA-Z0-9]+",
            r"eyJ[A-Za-z0-9_-]{20,}",  # JWT Tokens
            r"gh[pousr]_[A-Za-z0-9_]{20,}",  # GitHub Tokens
            
            # Cloud Service Provider Patterns
            r"AIza[0-9A-Za-z_-]{30,}",  # Google API Key
            r"ya29\.[0-9A-Za-z_-]+",  # Google OAuth
            
            # Service-specific credentials
            r"client_id\s*=\s*[a-zA-Z0-9._-]+",          # Client IDs
            r"client_secret\s*=\s*[a-zA-Z0-9._-]+",      # Client secrets
            r"api_key\s*=\s*[a-zA-Z0-9._-]+",            # API keys
            r"access_token\s*=\s*[a-zA-Z0-9._-]+",       # Access tokens
            
            # Database Connection Strings
            r"postgres(ql)?://[^:]+:[^@]+@[^/]+",  # PostgreSQL connection
            r"mysql://[^:]+:[^@]+@[^/]+",         # MySQL connection
            r"mongodb(\+srv)?://[^:]+:[^@]+@[^/]+",  # MongoDB connection
            r"redis://[^:]+:[^@]+@.+",               # Redis connection
            r"DATABASE_URL\s*=\s*.+:.+@.+",        # Generic database URL
            
            # Payment Service Patterns
            r"sk_live_[0-9a-zA-Z]{24}",  # Stripe Secret Key
            r"rk_live_[0-9a-zA-Z]{24}",  # Stripe Restricted Key
            
            # More specific token formats
            r"xox[baprs]-[0-9a-zA-Z]{10,}",  # Slack API Token
            r"T[a-zA-Z0-9_]{8}/B[a-zA-Z0-9_]{8}/[a-zA-Z0-9_]{24}",  # Slack Webhook
            
            # Common password patterns
            r"password\s*=\s*[^\s]+",  # Generic password assignment
            r"pwd\s*=\s*[^\s]+",       # Abbreviated password
            r"pass\s*=\s*[^\s]+",      # Another common password variable
            
            # Dangerous logging patterns
            r"console\.log.*pass",
            r"console\.log.*password",
            r"console\.log.*secret",
            r"console\.log.*token",
            r"console\.log.*key",
            r"console\.log.*cred",
            r"print.*pass",
            r"print.*password",
            r"print.*secret",
            r"print.*token",
            r"print.*key",
            r"echo.*password",
            r"echo.*secret",
            r"echo.*token",
            r"echo.*key",
            
            # Return/response exposure patterns
            r"return.*password",
            r"return.*token",
            r"return.*secret",
            r"return.*key",
            r"res\.send.*password",
            r"res\.send.*token",
            r"res\.send.*secret",
            r"res\.json.*password",
            r"res\.json.*token",
            r"res\.json.*secret",
            
            # INI section headers
            r"\[.*api.*\]",
            r"\[.*key.*\]",
            r"\[.*secret.*\]",
            r"\[.*credential.*\]",
            r"\[.*auth.*\]"
        ]
        
        # Strict patterns (broader, more false positives)
        self.strict_patterns = [
            r'token',
            r'secret',
            r'password',
            r'auth',
            r'client'
        ]
        
        # Override patterns (always HIGH severity)
        self.override_patterns = [
            # Client secrets
            r"client_secret\s*=\s*[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}",
            r"client_secret\s*=\s*[a-zA-Z0-9._-]+",
            
            # Actual tokens
            r"token\s*=\s*[\"''][0-9a-zA-Z._=/-]{16,}[\"'']",
            r"secret\s*=\s*[\"''][0-9a-zA-Z._=/-]{16,}[\"'']",
            r"password\s*=\s*[\"''][0-9a-zA-Z._=/-]{8,}[\"'']",
            r"access_key\s*=\s*[\"''][0-9a-zA-Z]{16,}[\"'']",
            
            # Database connection strings and credentials
            r"DATABASE_URL\s*=\s*[^=]+(:|%3A)[^=]+(@|%40)",
            r"(POSTGRES|SQL|DB|MYSQL|MONGO)(_)?PASS(WORD)?\s*=\s*[^\s$]+",
            
            # Password patterns in config/env files
            r"PASSWORD\s*=\s*[^\s$]+",
            r"PASS\s*=\s*[^\s$]+",
            r"PWD\s*=\s*[^\s$]+"
        ]
        
        # Config-specific patterns
        self.config_patterns = [
            r"password\s*=\s*[^\s$]+",
            r"secret\s*=\s*[^\s$]+",
            r"key\s*=\s*[^\s$]+",
            r"token\s*=\s*[^\s$]+",
            r"auth\s*=\s*[^\s$]+",
            r"credential\s*=\s*[^\s$]+",
            r"api[_-]?key\s*=\s*[^\s$]+",
            r"database\s*=\s*[^\s$]+",
            r"user\s*=\s*[^\s$]+",
            r"pass\s*=\s*[^\s$]+",
            r"pwd\s*=\s*[^\s$]+"
        ]
        
        # Exclusion patterns to reduce false positives
        self.exclusion_patterns = [
            # Exclude simple debug statements
            r"console\.log\([\"''][^\"\'']*[\"'']\)",
            
            # Exclude test or example code
            r"example|sample|mock|dummy|test|placeholder|template|default",
            
            # Exclude comments
            r"\s*//|\s*#",
            
            # Exclude TODOs and FIXMEs
            r"TODO|FIXME",
            
            # Exclude development URLs
            r"github\.com|localhost|127\.0\.1",
            
            # Exclude docstrings about tokens
            r"token management|token information|token endpoints",
            
            # Exclude common variable assignments without actual secrets
            r"token\s*=\s*\w+\.json",
            r"token\s*=\s*\w+\.copy",
            
            # Exclude function parameters that reference tokens
            r"refresh_token=refresh_token"
            
            # Exclude local host ips
            r"0.0.0.0"
        ]
        
        print(f"🔍 Running in {self.mode.upper()} mode")
    
    def _compile_patterns(self) -> None:
        """Pre-compile regex patterns for efficiency."""
        # Determine which patterns to use based on mode
        if self.mode == "strict":
            patterns_to_use = self.strict_patterns
        else:  # loose mode
            patterns_to_use = self.loose_patterns + self.additional_patterns
        
        # Compile main patterns
        self.compiled_patterns = []
        for pattern in patterns_to_use:
            try:
                self.compiled_patterns.append((re.compile(pattern, re.IGNORECASE), pattern))
            except re.error as e:
                print(f"⚠️ Warning: Could not compile pattern '{pattern}': {e}")
                # Try a simplified version
                try:
                    simplified = pattern.replace('\\s+', '\\s*').replace('{10,}', '{10,100}')
                    self.compiled_patterns.append((re.compile(simplified, re.IGNORECASE), pattern))
                    print(f"  ✓ Using simplified pattern instead: '{simplified}'")
                except re.error:
                    print(f"  ❌ Still couldn't compile pattern. Skipping: {pattern}")
        
        # Compile override patterns
        self.compiled_overrides = []
        for pattern in self.override_patterns:
            try:
                self.compiled_overrides.append((re.compile(pattern, re.IGNORECASE), pattern))
            except re.error as e:
                print(f"⚠️ Warning: Could not compile override pattern '{pattern}': {e}")
        
        # Compile config-specific patterns
        self.compiled_config_patterns = []
        for pattern in self.config_patterns:
            try:
                self.compiled_config_patterns.append((re.compile(pattern, re.IGNORECASE), pattern))
            except re.error as e:
                print(f"⚠️ Warning: Could not compile config pattern '{pattern}': {e}")
        
        # Compile exclusion patterns
        self.compiled_exclusions = []
        for pattern in self.exclusion_patterns:
            try:
                self.compiled_exclusions.append(re.compile(pattern, re.IGNORECASE))
            except re.error as e:
                print(f"⚠️ Warning: Could not compile exclusion pattern '{pattern}': {e}")
    
    def _should_scan_file(self, file_path: str) -> bool:
        """Check if a file should be scanned based on extensions and exclusions."""
        # Check exclusions first
        for pattern in self.exclude_dirs:
            if fnmatch.fnmatch(file_path, pattern):
                return False
        
        # Check if file is gitignored
        if self.is_git_repo and not self.scan_gitignored:
            if GitUtils.is_file_gitignored(file_path, self.directory):
                return False
        
        # Check if file matches any of our extensions
        file_name = os.path.basename(file_path)
        return any(fnmatch.fnmatch(file_name, ext) for ext in self.extensions)
    
    def _is_acceptable_finding(self, finding: Finding) -> bool:
        """Check if a finding is in the list of acceptable findings."""
        for acceptable in self.acceptable_findings:
            # Check for exact match
            if finding.full_fingerprint == acceptable:
                if self.verbose:
                    print(f"  → Acceptable finding in {finding.file_path} line {finding.line_number} (exact match)")
                return True
            
            # Check for pattern match
            if '*' in acceptable:
                # Convert the pattern to a regex
                regex_pattern = acceptable.replace('*', '.*')
                if re.match(regex_pattern, finding.full_fingerprint):
                    if self.verbose:
                        print(f"  → Acceptable finding in {finding.file_path} line {finding.line_number} (pattern match: {acceptable})")
                    return True
        
        return False
    
    def _determine_severity_and_risk(self, file_path: str, line_content: str, matching_pattern: str) -> Tuple[Severity, RiskType]:
        """Determine the severity and risk type of a finding."""
        # Start with risk type determination
        risk_type = RiskType.HARDCODED_SECRET
        
        # Check for data exposure
        if any(term in line_content.lower() for term in ["console.", "print", "echo"]):
            risk_type = RiskType.DATA_EXPOSURE_LOGS
        elif any(term in line_content.lower() for term in ["return", "res.", "response"]):
            risk_type = RiskType.DATA_EXPOSURE_RESPONSE
        elif "[" in line_content and "]" in line_content:
            risk_type = RiskType.SENSITIVE_CONFIG
        
        # Check if this is an override pattern (always HIGH)
        for compiled_pattern, pattern in self.compiled_overrides:
            if compiled_pattern.search(line_content):
                return Severity.HIGH, risk_type
        
        # Determine file type - config files have higher severity
        is_config_file = False
        file_ext = os.path.splitext(file_path)[1].lower()
        file_name = os.path.basename(file_path)
        
        if (file_ext in ['.ini', '.conf', '.env', '.cfg', '.yaml', '.yml', '.properties', '.tfvars'] or 
            file_name == '.env' or file_name.startswith('.env.')):
            is_config_file = True
        
        # High severity - actual value assignments in config files
        if is_config_file:
            sensitive_terms = ["client_id", "client_secret", "api_key", "password", "token", "access_key", 
                           "DATABASE_URL", "POSTGRES_PASSWORD", "secret", "key", "auth", "credential"]
            if any(term.lower() in line_content.lower() and "=" in line_content for term in sensitive_terms):
                return Severity.HIGH, risk_type
        
        # High severity for specific patterns in logging
        if ("console." in line_content.lower() or "print" in line_content.lower() or "echo" in line_content.lower()) and any(
            term in line_content.lower() for term in ["pass", "secret", "token", "api", "cred"]):
            return Severity.HIGH, risk_type
        
        # Medium severity - possible hardcoded values in code
        if re.search(r'(=|:)\s*["\'][0-9a-zA-Z._=/-]{16,}["\']', line_content):
            return Severity.MEDIUM, risk_type
        
        # Database credentials in any file
        if any(db in line_content.lower() for db in ["postgres", "sql", "mysql", "mongo"]) and any(term in line_content.lower() for term in ["password", "pass", "pwd"]):
            return Severity.HIGH, risk_type
        
        # Password with special chars
        if re.search(r'(password|pass|pwd)\s*=', line_content.lower()) and any(char in line_content for char in ['!', '@', '#', '$', '%', '^', '&', '*']):
            return Severity.HIGH, risk_type
        
        # FORCE HIGH for client_id/client_secret
        if "client_id" in line_content.lower() or "client_secret" in line_content.lower():
            return Severity.HIGH, risk_type
        
        # Low severity (default)
        return Severity.LOW, risk_type
    
    def _get_context_lines(self, file_path: str, line_number: int, context: int = 2) -> List[str]:
        """Get context lines around a line in a file."""
        try:
            with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                lines = f.readlines()
                
            start = max(0, line_number - context - 1)
            end = min(len(lines), line_number + context)
            
            return lines[start:end]
        except Exception as e:
            return [f"[Could not read file: {e}]"]
    
    def _should_exclude(self, line_content: str) -> bool:
        """Check if the line matches any exclusion pattern."""
        for pattern in self.compiled_exclusions:
            if pattern.search(line_content):
                return True
        return False
    
    def _collect_files_to_scan(self) -> List[str]:
        """Collect all files that should be scanned."""
        files_to_scan = []
        gitignored_files = []
        
        # Walk the directory and collect files
        for root, _, files in os.walk(self.directory):
            for file in files:
                file_path = os.path.join(root, file)
                file_name = os.path.basename(file_path)
                
                # Skip excluded directories
                should_exclude = False
                for pattern in self.exclude_dirs:
                    if fnmatch.fnmatch(file_path, pattern):
                        should_exclude = True
                        break
                
                if should_exclude:
                    continue
                
                # Check if file matches any of our extensions
                if not any(fnmatch.fnmatch(file_name, ext) for ext in self.extensions):
                    continue
                
                # Check if file is gitignored
                if self.is_git_repo and GitUtils.is_file_gitignored(file_path, self.directory):
                    if self.scan_gitignored:
                        gitignored_files.append(file_path)
                    else:
                        continue
                else:
                    files_to_scan.append(file_path)
        
        # Add gitignored files to scan list if requested
        if self.scan_gitignored:
            files_to_scan.extend(gitignored_files)
            
        print(f"🔎 Will scan {len(files_to_scan)} files ({len(gitignored_files)} gitignored)")
        return files_to_scan

    def scan(self) -> List[Finding]:
        """
        Scan the directory for secrets, including historical files.
        
        This scan identifies:
        1. Secrets in current tracked files
        2. Secrets in files that were previously committed to Git but are now gitignored
        
        Returns:
            A list of findings in the directory
        """
        print(f"🔍 Starting secret scan in: {os.path.abspath(self.directory)}")
        
        # PART 1: Identify and collect all files that should be scanned
        
        # First, collect regular files (not gitignored)
        regular_files = []
        for root, _, files in os.walk(self.directory):
            for file in files:
                file_path = os.path.abspath(os.path.join(root, file))
                
                # Skip if in hard exclusions
                should_exclude = False
                for pattern in self.exclude_dirs:
                    if fnmatch.fnmatch(file_path, pattern):
                        should_exclude = True
                        break
                
                if should_exclude:
                    continue
                
                # Check if file matches extensions we care about
                file_name = os.path.basename(file_path)
                if not any(fnmatch.fnmatch(file_name, ext) for ext in self.extensions):
                    continue
                
                # Check if file is gitignored - if so, skip for regular scan
                if self.is_git_repo and GitUtils.is_file_gitignored(file_path, self.directory):
                    continue
                
                regular_files.append(file_path)
        
        # Second, if we're in a Git repo, collect historical sensitive files
        historical_files = []
        if self.is_git_repo:
            try:
                # Get all files ever in Git history
                history_cmd = subprocess.run(
                    ["git", "-C", self.directory, "log", "--all", "--name-only", "--format="],
                    stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True
                )
                historical_file_paths = set()
                for file in history_cmd.stdout.strip().split('\n'):
                    if file.strip():
                        historical_file_paths.add(os.path.abspath(os.path.join(self.directory, file)))
                
                # Get currently tracked files
                tracked_cmd = subprocess.run(
                    ["git", "-C", self.directory, "ls-files"],
                    stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True
                )
                tracked_files = set(
                    os.path.abspath(os.path.join(self.directory, file)) 
                    for file in tracked_cmd.stdout.strip().split('\n') 
                    if file.strip()
                )
                
                # Find historical files that are now gitignored
                for file_path in historical_file_paths:
                    # Skip if in hard exclusions
                    should_exclude = False
                    for pattern in self.exclude_dirs:
                        if fnmatch.fnmatch(file_path, pattern):
                            should_exclude = True
                            break
                    
                    if should_exclude:
                        continue
                    
                    # Check if file exists and should be scanned based on extension
                    if os.path.exists(file_path):
                        file_name = os.path.basename(file_path)
                        if any(fnmatch.fnmatch(file_name, ext) for ext in self.extensions):
                            # Check if file is now gitignored
                            if GitUtils.is_file_gitignored(file_path, self.directory):
                                # Determine if it's still tracked or only in history
                                is_tracked = file_path in tracked_files
                                historical_files.append((file_path, is_tracked))
            except Exception as e:
                print(f"⚠️ Warning: Error checking Git history: {e}")
        
        # Print scan summary
        print(f"🔎 Will scan {len(regular_files)} regular files")
        if historical_files:
            still_tracked = sum(1 for _, tracked in historical_files if tracked)
            print(f"🔍 Also scanning {len(historical_files)} historical files that are now gitignored:")
            print(f"   - {still_tracked} files are still tracked by Git (need attention)")
            print(f"   - {len(historical_files) - still_tracked} files are only in Git history")
        
        # PART 2: Scan all files
        
        # Combine all files to scan
        all_files_to_scan = regular_files + [f for f, _ in historical_files]
        findings = []
        
        # Run the direct pattern scanner on all files
        for file_idx, file_path in enumerate(all_files_to_scan):
            if self.verbose or file_idx % 100 == 0:
                print(f"  [{file_idx+1}/{len(all_files_to_scan)}] Scanning: {file_path}")
            
            # Determine if this is a historical gitignored file
            is_historical = any(f == file_path for f, _ in historical_files)
            is_still_tracked = False
            if is_historical:
                is_still_tracked = next((tracked for f, tracked in historical_files if f == file_path), False)
            
            try:
                with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                    for i, line in enumerate(f, 1):
                        # Skip if line should be excluded
                        if self._should_exclude(line):
                            continue
                        
                        # Check each pattern
                        all_patterns = (
                            self.compiled_patterns + 
                            self.compiled_overrides + 
                            self.compiled_config_patterns
                        )
                        
                        for compiled_pattern, pattern_str in all_patterns:
                            match = compiled_pattern.search(line)
                            if match:
                                # Determine severity and risk
                                severity, risk_type = self._determine_severity_and_risk(file_path, line, pattern_str)
                                
                                # Check gitignored status
                                is_gitignored = is_historical or (
                                    self.is_git_repo and GitUtils.is_file_gitignored(file_path, self.directory)
                                )
                                
                                # Create finding
                                finding = Finding(
                                    file_path=file_path,
                                    line_number=i,
                                    line_content=line.strip(),
                                    pattern=pattern_str,
                                    severity=severity,
                                    risk_type=risk_type,
                                    is_gitignored=is_gitignored,
                                    in_git_history=is_historical
                                )
                                
                                # Set higher severity for historical files still tracked
                                if is_historical and is_still_tracked and severity != Severity.HIGH:
                                    finding.severity = Severity.HIGH
                                    if self.verbose:
                                        print(f"  ↑ Increased severity to HIGH for tracked gitignored file in history")
                                
                                # Skip if acceptable
                                if self._is_acceptable_finding(finding):
                                    continue
                                
                                # Skip if high-only mode and not high severity
                                if self.high_only and finding.severity != Severity.HIGH:
                                    if self.verbose:
                                        print(f"  → Skipping non-high severity finding (--high-only mode)")
                                    continue
                                
                                findings.append(finding)
            except Exception as e:
                print(f"⚠️ Warning: Could not scan file {file_path}: {e}")
        
        # PART 3: Optionally use detect-secrets for additional coverage
        
        if self.use_detect_secrets:
            try:
                detect_secrets_findings = self._run_detect_secrets_scan(all_files_to_scan)
                findings.extend(detect_secrets_findings)
            except Exception as e:
                print(f"⚠️ Warning: Error running detect-secrets scan: {e}")
        
        # Remove duplicates (same file:line findings)
        unique_findings = {}
        for finding in findings:
            if finding.fingerprint not in unique_findings:
                unique_findings[finding.fingerprint] = finding
        
        self.findings = list(unique_findings.values())
        print(f"✓ Scan complete: Found {len(self.findings)} findings in {len(all_files_to_scan)} files")
        return self.findings

    # def scan(self) -> List[Finding]:
    #     """Scan the directory for secrets using both our patterns and optionally detect-secrets."""
    #     print(f"🔍 Starting secret scan in: {os.path.abspath(self.directory)}")
        
    #     # Collect all files to scan
    #     files_to_scan = self._collect_files_to_scan()
        
    #     # First use our direct pattern scanner
    #     print("🔍 Phase 1: Running direct pattern scanner")
    #     direct_findings = self._run_direct_scan(files_to_scan)
        
    #     # Then optionally use detect-secrets
    #     if self.use_detect_secrets:
    #         print("🔍 Phase 2: Running detect-secrets scanner for additional coverage")
    #         try:
    #             detect_secrets_findings = self._run_detect_secrets_scan(files_to_scan)
                
    #             # Merge findings, avoiding duplicates (same file and line)
    #             fingerprints = set(f.fingerprint for f in direct_findings)
    #             for finding in detect_secrets_findings:
    #                 if finding.fingerprint not in fingerprints:
    #                     direct_findings.append(finding)
    #                     fingerprints.add(finding.fingerprint)
                
    #             print(f"✓ Added {len(detect_secrets_findings)} unique findings from detect-secrets")
    #         except Exception as e:
    #             print(f"⚠️ Warning: Error running detect-secrets scan: {e}")
    #             print("   Continuing with only direct scan results")
        
    #     self.findings = direct_findings
    #     print(f"✓ Completed scanning with {len(self.findings)} total findings")
    #     return self.findings
    
    def _run_detect_secrets_scan(self, files_to_scan: List[str]) -> List[Finding]:
        """Run a scan using detect-secrets library for additional pattern coverage."""
        try:
            from detect_secrets import SecretsCollection
            from detect_secrets.settings import transient_settings

            # Create config for standard plugins
            # This explicitly enables all available plugins
            from detect_secrets.plugins.artifactory import ArtifactoryDetector
            from detect_secrets.plugins.aws import AWSKeyDetector
            from detect_secrets.plugins.azure_storage_key import AzureStorageKeyDetector
            from detect_secrets.plugins.basic_auth import BasicAuthDetector
            from detect_secrets.plugins.cloudant import CloudantDetector
            from detect_secrets.plugins.discord import DiscordBotTokenDetector
            from detect_secrets.plugins.github_token import GitHubTokenDetector
            from detect_secrets.plugins.gitlab_token import GitLabTokenDetector
            from detect_secrets.plugins.high_entropy_strings import Base64HighEntropyString, HexHighEntropyString
            from detect_secrets.plugins.ibm_cloud_iam import IbmCloudIamDetector
            from detect_secrets.plugins.ibm_cos_hmac import IbmCosHmacDetector
            from detect_secrets.plugins.ip_public import IPPublicDetector
            from detect_secrets.plugins.jwt import JwtTokenDetector
            from detect_secrets.plugins.keyword import KeywordDetector
            from detect_secrets.plugins.mailchimp import MailchimpDetector
            from detect_secrets.plugins.npm import NpmDetector
            from detect_secrets.plugins.openai import OpenAIDetector
            from detect_secrets.plugins.private_key import PrivateKeyDetector
            from detect_secrets.plugins.pypi_token import PypiTokenDetector
            from detect_secrets.plugins.sendgrid import SendGridDetector
            from detect_secrets.plugins.slack import SlackDetector
            from detect_secrets.plugins.softlayer import SoftlayerDetector
            from detect_secrets.plugins.square_oauth import SquareOAuthDetector
            from detect_secrets.plugins.stripe import StripeDetector
            from detect_secrets.plugins.telegram_token import TelegramBotTokenDetector
            from detect_secrets.plugins.twilio import TwilioKeyDetector
            
            # Create a list of plugin configs
            plugin_configs = [
                {'name': 'ArtifactoryDetector'},
                {'name': 'AWSKeyDetector'},
                {'name': 'AzureStorageKeyDetector'},
                {'name': 'BasicAuthDetector'},
                {'name': 'CloudantDetector'},
                {'name': 'DiscordBotTokenDetector'},
                {'name': 'GitHubTokenDetector'},
                {'name': 'GitLabTokenDetector'},
                {'name': 'Base64HighEntropyString', 'limit': 4.5},
                {'name': 'HexHighEntropyString', 'limit': 3.0},
                {'name': 'IbmCloudIamDetector'},
                {'name': 'IbmCosHmacDetector'},
                {'name': 'IPPublicDetector'},
                {'name': 'JwtTokenDetector'},
                {'name': 'KeywordDetector'},
                {'name': 'MailchimpDetector'},
                {'name': 'NpmDetector'},
                {'name': 'OpenAIDetector'},
                {'name': 'PrivateKeyDetector'},
                {'name': 'PypiTokenDetector'},
                {'name': 'SendGridDetector'},
                {'name': 'SlackDetector'},
                {'name': 'SoftlayerDetector'},
                {'name': 'SquareOAuthDetector'},
                {'name': 'StripeDetector'},
                {'name': 'TelegramBotTokenDetector'},
                {'name': 'TwilioKeyDetector'}
            ]
            
            config = {'plugins_used': plugin_configs}
            
            # Use the configuration with transient_settings
            with transient_settings(config):
                # Create a SecretsCollection with the configured plugins
                secrets = SecretsCollection()
                
                # Make sure plugins are populated
                from detect_secrets.settings import get_plugins
                plugins = get_plugins()
                if not plugins:
                    print(f"⚠️ Warning: No detect-secrets plugins were loaded!")
                    return []
                
                print(f"    🔧 Using {len(plugins)} detect-secrets plugins for scanning")
                
                # Scan each file manually to handle errors gracefully
                scanned_count = 0
                for file_idx, file_path in enumerate(files_to_scan):
                    if self.verbose and file_idx % 100 == 0:
                        print(f"    [{file_idx+1}/{len(files_to_scan)}] detect-secrets scanning: {file_path}")
                    
                    try:
                        # Directly scan the file with each plugin
                        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                            for i, line in enumerate(f, 1):
                                for plugin in plugins:
                                    try:
                                        # Analyze the line for secrets
                                        detected_secrets = plugin.analyze_line(
                                            filename=file_path,
                                            line=line,
                                            line_number=i-1  # 0-based index
                                        )
                                        
                                        # Add any detected secrets to the collection
                                        for secret in detected_secrets:
                                            secrets_dict = secrets.data.setdefault(file_path, {})
                                            secrets_by_type = secrets_dict.setdefault(secret.type, [])
                                            secrets_by_type.append(secret)
                                    except Exception as e:
                                        if self.verbose:
                                            print(f"    ⚠️ Plugin error in {plugin.__class__.__name__}: {e}")
                        
                        scanned_count += 1
                    except Exception as e:
                        if self.verbose:
                            print(f"    ⚠️ detect-secrets error scanning {file_path}: {e}")
                
                # Convert results to our Finding format
                findings = []
                
                # Process the results
                for filename, secrets_dict in secrets.data.items():
                    for secret_type, secrets_list in secrets_dict.items():
                        for secret in secrets_list:
                            # Get line content
                            line_content = ""
                            try:
                                with open(filename, 'r', encoding='utf-8', errors='ignore') as f:
                                    for i, line in enumerate(f, 1):
                                        if i == secret.line_number + 1:  # Adjust for 0-based index
                                            line_content = line.strip()
                                            break
                            except Exception:
                                line_content = f"<Could not read line {secret.line_number + 1}>"
                            
                            # Determine severity and risk type
                            severity, risk_type = self._determine_severity_and_risk(
                                filename, line_content, f"detect-secrets:{secret_type}"
                            )
                            
                            # Check if file is gitignored
                            is_gitignored = False
                            in_git_history = False
                            if self.is_git_repo:
                                is_gitignored = GitUtils.is_file_gitignored(filename, self.directory)
                                if is_gitignored and self.check_git_history:
                                    in_git_history = GitUtils.is_file_in_git_history(filename, self.directory)
                            
                            # Create a finding
                            finding = Finding(
                                file_path=filename,
                                line_number=secret.line_number + 1,  # Adjust for 0-based index
                                line_content=line_content,
                                pattern=f"detect-secrets:{secret_type}",
                                severity=severity,
                                risk_type=risk_type,
                                is_gitignored=is_gitignored,
                                in_git_history=in_git_history
                            )
                            
                            # Skip if acceptable
                            if self._is_acceptable_finding(finding):
                                continue
                            
                            # Skip if we're only reporting high severity findings and this isn't high
                            if self.high_only and severity != Severity.HIGH:
                                continue
                            
                            findings.append(finding)
                
                print(f"  ✓ detect-secrets found {len(findings)} potential secrets in {scanned_count} files")
                return findings
                
        except ImportError as e:
            print(f"⚠️ Warning: detect-secrets library not found: {e}")
            print("   Install with: pip install detect-secrets")
            return []
        except Exception as e:
            print(f"⚠️ Error using detect-secrets: {e}")
            return []
    
    def _run_direct_scan(self, files_to_scan: List[str]) -> List[Finding]:
        """Run our direct pattern scanner."""
        findings = []
        
        # First scan config files separately with config-specific patterns
        config_files = [f for f in files_to_scan if any(fnmatch.fnmatch(os.path.basename(f), pattern) for pattern in self.config_files)]
        if config_files:
            print(f"  🔍 Scanning {len(config_files)} configuration files for sensitive data")
            for file_path in config_files:
                if self.verbose:
                    print(f"    Scanning config file: {file_path}")
                
                try:
                    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                        for i, line in enumerate(f, 1):
                            # Skip if line should be excluded
                            if self._should_exclude(line):
                                continue
                            
                            # Check each config pattern
                            for compiled_pattern, pattern_str in self.compiled_config_patterns:
                                match = compiled_pattern.search(line)
                                if match:
                                    # Configuration files are usually high severity
                                    severity, risk_type = Severity.HIGH, RiskType.SENSITIVE_CONFIG
                                    
                                    # Check if file is gitignored
                                    is_gitignored = False
                                    in_git_history = False
                                    if self.is_git_repo:
                                        is_gitignored = GitUtils.is_file_gitignored(file_path, self.directory)
                                        if is_gitignored and self.check_git_history:
                                            in_git_history = GitUtils.is_file_in_git_history(file_path, self.directory)
                                    
                                    # Create a finding
                                    finding = Finding(
                                        file_path=file_path,
                                        line_number=i,
                                        line_content=line.strip(),
                                        pattern=pattern_str,
                                        severity=severity,
                                        risk_type=risk_type,
                                        is_gitignored=is_gitignored,
                                        in_git_history=in_git_history
                                    )
                                    
                                    # Skip if acceptable
                                    if self._is_acceptable_finding(finding):
                                        continue
                                    
                                    # Skip if we're only reporting high severity findings and this isn't high
                                    if self.high_only and severity != Severity.HIGH:
                                        if self.verbose:
                                            print(f"    → Skipping non-high severity finding in {finding.file_path} line {finding.line_number} (--high-only mode)")
                                        continue
                                    
                                    # Add to findings
                                    findings.append(finding)
                except Exception as e:
                    print(f"⚠️ Warning: Could not scan file {file_path}: {e}")
        
        # Now scan all files with main patterns
        non_config_files = [f for f in files_to_scan if f not in config_files]
        print(f"  🔍 Scanning {len(non_config_files)} regular files for secrets")
        
        for file_idx, file_path in enumerate(non_config_files):
            if self.verbose or file_idx % 100 == 0 or file_idx == len(non_config_files) - 1:
                print(f"    [{file_idx+1}/{len(non_config_files)}] Scanning: {file_path}")
            
            try:
                with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                    for i, line in enumerate(f, 1):
                        # Skip if line should be excluded
                        if self._should_exclude(line):
                            continue
                        
                        # First check override patterns - they always get reported
                        for compiled_pattern, pattern_str in self.compiled_overrides:
                            match = compiled_pattern.search(line)
                            if match:
                                # Determine severity and risk (overrides are typically HIGH)
                                severity, risk_type = self._determine_severity_and_risk(file_path, line, pattern_str)
                                
                                # Check if file is gitignored
                                is_gitignored = False
                                in_git_history = False
                                if self.is_git_repo:
                                    is_gitignored = GitUtils.is_file_gitignored(file_path, self.directory)
                                    if is_gitignored and self.check_git_history:
                                        in_git_history = GitUtils.is_file_in_git_history(file_path, self.directory)
                                
                                # Create a finding
                                finding = Finding(
                                    file_path=file_path,
                                    line_number=i,
                                    line_content=line.strip(),
                                    pattern=f"OVERRIDE: {pattern_str}",
                                    severity=severity,
                                    risk_type=risk_type,
                                    is_gitignored=is_gitignored,
                                    in_git_history=in_git_history
                                )
                                
                                # Skip if acceptable
                                if self._is_acceptable_finding(finding):
                                    continue
                                
                                # Skip if we're only reporting high severity findings and this isn't high
                                if self.high_only and severity != Severity.HIGH:
                                    if self.verbose:
                                        print(f"    → Skipping non-high severity finding in {finding.file_path} line {finding.line_number} (--high-only mode)")
                                    continue
                                
                                # Add to findings
                                findings.append(finding)
                        
                        # Now check regular patterns
                        for compiled_pattern, pattern_str in self.compiled_patterns:
                            match = compiled_pattern.search(line)
                            if match:
                                # Determine severity and risk
                                severity, risk_type = self._determine_severity_and_risk(file_path, line, pattern_str)
                                
                                # Check if file is gitignored
                                is_gitignored = False
                                in_git_history = False
                                if self.is_git_repo:
                                    is_gitignored = GitUtils.is_file_gitignored(file_path, self.directory)
                                    if is_gitignored and self.check_git_history:
                                        in_git_history = GitUtils.is_file_in_git_history(file_path, self.directory)
                                
                                # Create a finding
                                finding = Finding(
                                    file_path=file_path,
                                    line_number=i,
                                    line_content=line.strip(),
                                    pattern=pattern_str,
                                    severity=severity,
                                    risk_type=risk_type,
                                    is_gitignored=is_gitignored,
                                    in_git_history=in_git_history
                                )
                                
                                # Skip if acceptable
                                if self._is_acceptable_finding(finding):
                                    continue
                                
                                # Skip if we're only reporting high severity findings and this isn't high
                                if self.high_only and severity != Severity.HIGH:
                                    if self.verbose:
                                        print(f"    → Skipping non-high severity finding in {finding.file_path} line {finding.line_number} (--high-only mode)")
                                    continue
                                
                                # Add to findings
                                findings.append(finding)
            except Exception as e:
                print(f"⚠️ Warning: Could not scan file {file_path}: {e}")
        
        print(f"  ✓ Direct scanner found {len(findings)} potential secrets")
        return findings    
    

    def _generate_fingerprints_file(self) -> str:
        """
        Generate a file with fingerprints of all findings.
        
        Returns:
            The path to the generated file
        """
        fingerprints_file = "secrets_scan_fingerprints.txt"
        
        with open(fingerprints_file, 'w') as f:
            f.write(f"# Generated fingerprints from scan on {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write(f"# Add lines from this file to {self.allow_file} to allowlist them\n")
            f.write("# Format: file:line:pattern\n\n")
            
            processed = set()
            for finding in self.findings:
                if finding.fingerprint not in processed:
                    f.write(f"{finding.full_fingerprint}\n")
                    processed.add(finding.fingerprint)
        
        return fingerprints_file
    
    def print_report(self) -> bool:
        """
        Print a report of the findings.
        
        This method generates a detailed report of the findings,
        including severity, risk type, and specific remediation guidance.
        
        Returns:
            True if any high severity findings were found, False otherwise
        """
        if not self.findings:
            print("\n✅ No secrets detected in the scanned files.")
            return False
        
        # Group findings by severity
        high_findings = [f for f in self.findings if f.severity == Severity.HIGH]
        medium_findings = [f for f in self.findings if f.severity == Severity.MEDIUM]
        low_findings = [f for f in self.findings if f.severity == Severity.LOW]
        
        # Group findings by risk type
        hardcoded_findings = [f for f in self.findings if f.risk_type == RiskType.HARDCODED_SECRET]
        log_exposure_findings = [f for f in self.findings if f.risk_type == RiskType.DATA_EXPOSURE_LOGS]
        response_exposure_findings = [f for f in self.findings if f.risk_type == RiskType.DATA_EXPOSURE_RESPONSE]
        config_findings = [f for f in self.findings if f.risk_type == RiskType.SENSITIVE_CONFIG]
        
        # Group findings by git status
        historical_findings = [f for f in self.findings if f.in_git_history]
        historical_tracked = [f for f in historical_findings if self.is_file_still_tracked(f.file_path)]
        historical_untracked = [f for f in historical_findings if not self.is_file_still_tracked(f.file_path)]
        
        # Get unique files with findings
        unique_files = set(f.file_path for f in self.findings)
        
        print("\n=== SCAN SUMMARY ===\n")
        print(f"🚨 Found {len(self.findings)} potential secrets in {len(unique_files)} files.")
        print(f"  🔴 HIGH SEVERITY: {len(high_findings)} findings")
        print(f"  🟠 MEDIUM SEVERITY: {len(medium_findings)} findings")
        print(f"  🟡 LOW SEVERITY: {len(low_findings)} findings")
        
        if historical_findings:
            print(f"\n  🔍 HISTORICAL FINDINGS: {len(historical_findings)} findings in files from Git history")
            print(f"    ⚠️ CRITICAL: {len(historical_tracked)} findings in files that are STILL TRACKED (needs immediate attention)")
            print(f"    ⚠️ IMPORTANT: {len(historical_untracked)} findings in files that need Git history cleanup")
        
        print("\n=== FINDINGS BY RISK TYPE ===\n")
        print("  📊 FINDINGS BY RISK TYPE:")
        print(f"     - {len(hardcoded_findings)} hardcoded secrets")
        print(f"     - {len(log_exposure_findings)} data exposures in logs")
        print(f"     - {len(response_exposure_findings)} data exposures in responses")
        print(f"     - {len(config_findings)} sensitive configuration items")
        print()
        
        # First highlight historical files still tracked (highest risk)
        if historical_tracked:
            print("=== CRITICAL: HISTORICAL FILES STILL TRACKED ===\n")
            print("The following files contain sensitive information, are in .gitignore,")
            print("but are STILL TRACKED by Git. These need immediate attention!")
            
            tracked_files = set(f.file_path for f in historical_tracked)
            for file_path in tracked_files:
                file_findings = [f for f in self.findings if f.file_path == file_path]
                high_count = sum(1 for f in file_findings if f.severity == Severity.HIGH)
                
                print(f"\n⚠️  CRITICAL: {file_path}")
                print(f"   {len(file_findings)} findings ({high_count} HIGH severity)")
                print("   This file needs to be removed from Git tracking!")
                
                # Show a sample finding
                if file_findings:
                    print("\n   Sample finding:")
                    finding = file_findings[0]
                    print(f"   Line {finding.line_number}: {finding.line_content}")
            
            print("\n   To remove these files from Git tracking (but keep them locally):")
            for file_path in tracked_files:
                rel_path = os.path.relpath(file_path, self.directory)
                print(f"   git rm --cached \"{rel_path}\"")
            print("   git commit -m \"Remove sensitive files that should be gitignored\"")
            print("   git push")
            print()
        
        # Now show details for all findings
        print("=== DETAILED MATCHES ===\n")
        
        # Display detailed matches
        for finding in self.findings:
            # Prepare status indicators
            status_indicators = []
            if finding.is_gitignored:
                status_indicators.append("🔍 GITIGNORED")
                if finding.in_git_history:
                    status_indicators.append("⚠️ IN GIT HISTORY")
            
            status_str = f" [{' - '.join(status_indicators)}]" if status_indicators else ""
            
            print(f"⚠️  {finding.severity.value} - {finding.risk_type.value} - MATCH FOUND in {finding.file_path} line {finding.line_number}{status_str}:")
            print(f"   FINGERPRINT: {finding.fingerprint}")
            print(f"   PATTERN: {finding.pattern}")
            
            print("   CODE CONTEXT:")
            print("   " + "-" * 50)
            
            context_lines = self._get_context_lines(finding.file_path, finding.line_number)
            start_line = max(1, finding.line_number - 2)
            
            for i, line in enumerate(context_lines):
                line_num = start_line + i
                if line_num == finding.line_number:
                    print(f"   {line_num:3d} | {line.rstrip()}  <-- ⚠️ FINDING HERE")
                else:
                    print(f"   {line_num:3d} | {line.rstrip()}")
            
            print("   " + "-" * 50)
            print()
        
        # Generate fingerprints file
        fingerprints_file = self._generate_fingerprints_file()
        
        # Provide remediation guidance
        print("\n=== REMEDIATION GUIDANCE ===\n")
        print("🛠️  Next steps by risk type:")
        
        if historical_findings:
            print("\n=== HISTORICAL FILE CLEANUP GUIDANCE ===\n")
            print("Some sensitive files have been detected in Git history. To properly clean them:")
            
            print("\n1. For files still tracked by Git, first remove them from tracking:")
            if historical_tracked:
                tracked_files = set(f.file_path for f in historical_tracked)
                for file_path in tracked_files:
                    rel_path = os.path.relpath(file_path, self.directory)
                    print(f"   git rm --cached \"{rel_path}\"")
                print("   git commit -m \"Remove sensitive files that should be gitignored\"")
                print("   git push")
        
                print("\n2. To completely remove these files from Git history, use BFG Repo-Cleaner:")
                print("   a. Download BFG from: https://rtyley.github.io/bfg-repo-cleaner/")
                
                # Create file listing all historical files with findings
                history_files = set(f.file_path for f in historical_findings)
                with open("sensitive-git-history-files.txt", "w") as f:
                    for file_path in history_files:
                        rel_path = os.path.relpath(file_path, self.directory)
                        f.write(f"{rel_path}\n")
                
                print("   b. We've created a file with all sensitive files: sensitive-git-history-files.txt")
                print("   c. Follow these steps to clean the history:")
                print("      git clone --mirror git://your-repo.git repo.git")
                print("      java -jar bfg.jar --delete-files sensitive-git-history-files.txt repo.git")
                print("      cd repo.git")
                print("      git reflog expire --expire=now --all")
                print("      git gc --prune=now --aggressive")
                print("      git push")
                
                print("\n⚠️ WARNING: This will rewrite Git history. Coordinate with your team before proceeding.")
   
        if hardcoded_findings:
            print()
            print(f"   🔑 HARDCODED SECRETS ({len(hardcoded_findings)} findings):")
            print("     - Remove hardcoded secrets from code and use environment variables instead")
            print("     - Store secrets in a secure vault like AWS Secrets Manager, HashiCorp Vault, etc.")
            print("     - Use a .env file (not committed to version control) for local development")
            print("     - Consider any already-committed secrets compromised and rotate them immediately")
        
        if log_exposure_findings:
            print()
            print(f"   📝 DATA EXPOSURE IN LOGS ({len(log_exposure_findings)} findings):")
            print("     - Never log sensitive values like passwords, tokens, or keys")
            print("     - Use redaction patterns like console.log('token:', '***REDACTED***')")
            print("     - Create helper functions that automatically redact sensitive fields")
            print("     - Implement proper debug levels to control what gets logged")
        
        if response_exposure_findings:
            print()
            print(f"   🌐 DATA EXPOSURE IN RESPONSES ({len(response_exposure_findings)} findings):")
            print("     - Never return sensitive values in API responses")
            print("     - Create data sanitization functions that strip sensitive fields before sending")
            print("     - Use response schemas or serializers that explicitly define what gets returned")
            print("     - Add unit tests to verify sensitive data isn't leaked in responses")
        
        if config_findings:
            print()
            print(f"   ⚙️ SENSITIVE CONFIGURATION ({len(config_findings)} findings):")
            print("     - Move sensitive values from configuration files to environment variables")
            print("     - Use .env.example files with placeholder values as templates")
            print("     - In CI/CD environments, use secure environment variable storage")
            print("     - For infrastructure-as-code, use secure variable handling mechanisms")
        
        print()
        print("🔁 CI/CD Integration:")
        print(f"   A file '{fingerprints_file}' has been created with fingerprints of all findings.")
        print("   To suppress known/acceptable findings in CI/CD:")
        print(f"   1. Review the fingerprints and copy acceptable ones to {self.allow_file}")
        print("   2. Run with --high-only flag to only fail on high severity findings")
        print("   Example: python secrets_scanner.py --high-only")
        
        print()
        print("🔄 Next Steps:")
        print("   1. Review all HIGH and MEDIUM severity findings immediately")
        print("   2. For each finding, follow the remediation guidance to fix the issue")
        print("   3. If a finding is a false positive, add it to the acceptable findings file")
        print("   4. For gitignored files with secrets that were previously committed, rotate those secrets")
        print("   5. Consider implementing pre-commit hooks to prevent new secrets from being committed")
        print("   6. Run the scanner regularly as part of your CI/CD pipeline using the --high-only flag")
        print()
        
        if high_findings:
            print("⚠️ HIGH SEVERITY FINDINGS REQUIRE IMMEDIATE ATTENTION")
            print("   Secrets exposed in your codebase pose a significant security risk and should be")
            print("   addressed as soon as possible. Consider rotating any exposed credentials.")
       
        # Return True if there are any high severity findings
        return len(high_findings) > 0

def is_file_still_tracked(self, file_path: str) -> bool:
    """Check if a file is still tracked by Git."""
    if not self.is_git_repo:
        return False
    
    try:
        result = subprocess.run(
            ["git", "-C", self.directory, "ls-files", "--error-unmatch", file_path],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False
        )
        return result.returncode == 0
    except Exception:
        return False

def main():
    """Main entry point for the script."""
    parser = argparse.ArgumentParser(
        description="Enhanced Python Secrets Scanner - Detects hardcoded credentials and sensitive data",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python secrets_scanner.py                      # Run in loose mode
  python secrets_scanner.py --mode strict        # Run in strict mode
  python secrets_scanner.py --verbose            # Run in loose mode with verbose output
  python secrets_scanner.py --high-only          # Run in loose mode, only fail on high severity
  python secrets_scanner.py --allow-file custom.txt  # Use custom allow file
  python secrets_scanner.py --use-detect-secrets # Also use detect-secrets library for additional scanning
        """
    )
    parser.add_argument("--mode", choices=["loose", "strict"], default="loose",
                        help="Scanning mode: 'loose' (fewer false positives) or 'strict' (more thorough)")
    parser.add_argument("--verbose", action="store_true",
                        help="Show more detailed output")
    parser.add_argument("--high-only", action="store_true",
                        help="Only fail on HIGH severity findings (good for CI/CD)")
    parser.add_argument("--allow-file", default=".gitleaks-acceptable.txt",
                        help="Path to acceptable findings file")
    parser.add_argument("--directory", default=".",
                        help="Directory to scan")
    parser.add_argument("--use-detect-secrets", action="store_true",
                        help="Also use detect-secrets library for additional scanning coverage")
    
    args = parser.parse_args()
    
    # Print header
    print("=" * 60)
    print("📦 Enhanced Python Secrets Scanner")
    print("=" * 60)
    
    scanner = SecretsScanner(
        mode=args.mode,
        verbose=args.verbose,
        high_only=args.high_only,
        allow_file=args.allow_file,
        directory=args.directory,
        use_detect_secrets=args.use_detect_secrets
    )
    
    # Run the scan - now includes checking historical files automatically
    scanner.scan()
    high_findings_exist = scanner.print_report()
    
    # Exit with the appropriate status code
    if args.high_only:
        if high_findings_exist:
            print("❌ CI/CD Check Failed: High severity findings detected")
            sys.exit(1)
        else:
            print("✅ CI/CD Check Passed: No high severity findings detected")
            sys.exit(0)
    elif scanner.findings:
        sys.exit(1)
    else:
        sys.exit(0)


if __name__ == "__main__":
    main()